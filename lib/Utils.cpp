//===-- Utils.cpp - Shared legality helpers for GraceOpt passes -----------===//

#include "graceopt/Utils.h"

#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/Analysis/AssumptionCache.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/MemoryLocation.h"
#include "llvm/Analysis/MustExecute.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Transforms/Utils/LoopSimplify.h"

using namespace llvm;

namespace graceopt {

bool simplifyAllLoops(Function &F, FunctionAnalysisManager &FAM) {
  auto &LI = FAM.getResult<LoopAnalysis>(F);
  if (LI.empty())
    return false;
  auto &DT = FAM.getResult<DominatorTreeAnalysis>(F);
  auto &SE = FAM.getResult<ScalarEvolutionAnalysis>(F);
  auto &AC = FAM.getResult<AssumptionAnalysis>(F);

  bool Changed = false;
  for (Loop *L : LI)
    Changed |= simplifyLoop(L, &DT, &LI, &SE, &AC, /*MSSAU=*/nullptr,
                            /*PreserveLCSSA=*/false);
  if (!Changed)
    return false;

  // simplifyLoop kept DT/LI/SE/AC consistent; everything else that was
  // cached for F may now describe a stale CFG.
  PreservedAnalyses PA;
  PA.preserve<DominatorTreeAnalysis>();
  PA.preserve<LoopAnalysis>();
  PA.preserve<ScalarEvolutionAnalysis>();
  PA.preserve<AssumptionAnalysis>();
  FAM.invalidate(F, PA);
  return true;
}

bool loadMayBeClobberedInLoop(LoadInst &Load, Loop &L, AAResults &AA) {
  MemoryLocation Loc = MemoryLocation::get(&Load);
  for (BasicBlock *BB : L.blocks())
    for (Instruction &I : *BB) {
      if (isa<FenceInst>(I) || isa<AtomicRMWInst>(I) || isa<AtomicCmpXchgInst>(I) ||
          (isa<LoadInst>(I) && !cast<LoadInst>(I).isSimple()) ||
          (isa<StoreInst>(I) && !cast<StoreInst>(I).isSimple()))
        return true;
      if (I.mayWriteToMemory() && isModSet(AA.getModRefInfo(&I, Loc)))
        return true;
    }
  return false;
}

std::optional<InvariantInfo>
classifyLoopInvariant(Instruction &I, Loop &L, AAResults &AA,
                      DominatorTree &DT,
                      const SmallPtrSetImpl<const Instruction *> &Known) {
  if (isa<PHINode>(I) || I.isTerminator() || I.isEHPad())
    return std::nullopt;
  for (Value *Op : I.operands()) {
    if (L.isLoopInvariant(Op))
      continue;
    if (auto *OpI = dyn_cast<Instruction>(Op); OpI && Known.count(OpI))
      continue;
    return std::nullopt;
  }
  // Anything that writes memory, throws, or has other side effects stays put.
  if (I.mayWriteToMemory() || I.mayThrow() || !I.willReturn())
    return std::nullopt;
  if (!isa<LoadInst>(I) && !isPureComputation(I))
    return std::nullopt;
  if (auto *Load = dyn_cast<LoadInst>(&I)) {
    if (!Load->isSimple())
      return std::nullopt;
    if (loadMayBeClobberedInLoop(*Load, L, AA))
      return std::nullopt;
  } else if (I.mayReadFromMemory()) {
    // Memory-reading intrinsics etc.: be conservative.
    return std::nullopt;
  }

  InvariantInfo Info;
  BasicBlock *Preheader = L.getLoopPreheader();
  if (!Preheader)
    return std::nullopt;
  // Facts valid inside the body need not hold at the destination.
  Info.SafeToSpeculate = isSafeToSpeculativelyExecute(
      &I, Preheader->getTerminator(), /*AC=*/nullptr, &DT);
  ICFLoopSafetyInfo Safety;
  Safety.computeLoopSafetyInfo(&L);
  Info.GuaranteedToExecute = Safety.isGuaranteedToExecute(I, &DT, &L);
  // Not speculatable (e.g. a division that might trap, or a load from a
  // pointer we cannot prove dereferenceable) and not guaranteed to execute:
  // hoisting could introduce a fault that the original program never had.
  if (!Info.SafeToSpeculate && !Info.GuaranteedToExecute)
    return std::nullopt;
  return Info;
}

bool isPureComputation(const Instruction &I) {
  if (isa<PHINode>(I) || isa<AllocaInst>(I) || isa<LandingPadInst>(I) ||
      I.isTerminator() || I.isEHPad())
    return false;
  if (I.mayReadOrWriteMemory() || I.mayHaveSideEffects())
    return false;
  if (auto *CB = dyn_cast<CallBase>(&I)) {
    if (!isa<IntrinsicInst>(CB) || CB->isConvergent())
      return false;
    // Only deterministic arithmetic intrinsics are supported. Memory-free
    // alone does not rule out nondeterministic or context-dependent results.
    switch (cast<IntrinsicInst>(CB)->getIntrinsicID()) {
    case Intrinsic::sqrt: case Intrinsic::fabs: case Intrinsic::fma:
    case Intrinsic::fmuladd: case Intrinsic::bswap: case Intrinsic::bitreverse:
    case Intrinsic::ctpop: case Intrinsic::ctlz: case Intrinsic::cttz:
      return true;
    default:
      return false;
    }
  }
  // Freeze can choose a distinct value on each execution. Aggregate and
  // vector operations carry indices or masks that are not in ExprKey.
  return isa<BinaryOperator>(I) || isa<CastInst>(I) || isa<CmpInst>(I) ||
         isa<GetElementPtrInst>(I) || isa<SelectInst>(I) || isa<UnaryOperator>(I);
}

ExprKey makeExprKey(const Instruction &I) {
  unsigned Extra = 0;
  Type *SourceType = nullptr;
  if (auto *Cmp = dyn_cast<CmpInst>(&I))
    Extra = Cmp->getPredicate();
  else if (auto *Cast = dyn_cast<CastInst>(&I))
    Extra = Cast->getOpcode();
  else if (auto *GEP = dyn_cast<GetElementPtrInst>(&I))
    SourceType = GEP->getSourceElementType();
  else if (auto *CB = dyn_cast<CallBase>(&I))
    Extra = CB->getCalledFunction() ? CB->getCalledFunction()->getIntrinsicID()
                                    : 0;
  std::vector<Value *> Ops(I.op_begin(), I.op_end());
  if (I.isCommutative() && Ops.size() == 2 && Ops[0] > Ops[1])
    std::swap(Ops[0], Ops[1]);
  return {I.getOpcode(), I.getType(), Extra, SourceType, std::move(Ops)};
}

} // namespace graceopt
