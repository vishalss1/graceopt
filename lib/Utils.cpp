//===-- Utils.cpp - Shared legality helpers for GraceOpt passes -----------===//

#include "graceopt/Utils.h"

#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/MemoryLocation.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"

using namespace llvm;

namespace graceopt {

bool loadMayBeClobberedInLoop(LoadInst &Load, Loop &L, AAResults &AA) {
  MemoryLocation Loc = MemoryLocation::get(&Load);
  for (BasicBlock *BB : L.blocks())
    for (Instruction &I : *BB)
      if (I.mayWriteToMemory() && isModSet(AA.getModRefInfo(&I, Loc)))
        return true;
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
  if (isa<AllocaInst>(I) || (isa<CallBase>(I) && !isa<IntrinsicInst>(I)))
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
  Info.SafeToSpeculate = isSafeToSpeculativelyExecute(&I, /*CtxI=*/nullptr,
                                                      /*AC=*/nullptr, &DT);
  if (!Info.SafeToSpeculate) {
    // Not speculatable (e.g. a division that might trap, or a load from a
    // pointer we cannot prove dereferenceable). Still hoistable when the
    // instruction is guaranteed to execute on every iteration, i.e. its block
    // dominates every loop exit.
    SmallVector<BasicBlock *, 4> Exits;
    L.getExitBlocks(Exits);
    if (Exits.empty())
      return std::nullopt;
    for (BasicBlock *E : Exits)
      if (!DT.dominates(I.getParent(), E))
        return std::nullopt;
  }
  return Info;
}

bool isPureComputation(const Instruction &I) {
  if (isa<PHINode>(I) || isa<AllocaInst>(I) || isa<LandingPadInst>(I) ||
      I.isTerminator() || I.isEHPad())
    return false;
  if (I.mayReadOrWriteMemory() || I.mayHaveSideEffects())
    return false;
  if (auto *CB = dyn_cast<CallBase>(&I))
    return isa<IntrinsicInst>(CB) && CB->doesNotAccessMemory();
  return true;
}

ExprKey makeExprKey(const Instruction &I) {
  unsigned Extra = 0;
  if (auto *Cmp = dyn_cast<CmpInst>(&I))
    Extra = Cmp->getPredicate();
  else if (auto *Cast = dyn_cast<CastInst>(&I))
    Extra = Cast->getOpcode();
  else if (auto *GEP = dyn_cast<GetElementPtrInst>(&I))
    Extra = GEP->getSourceElementType()->getTypeID();
  else if (auto *CB = dyn_cast<CallBase>(&I))
    Extra = CB->getCalledFunction() ? CB->getCalledFunction()->getIntrinsicID()
                                    : 0;
  std::vector<Value *> Ops(I.op_begin(), I.op_end());
  if (I.isCommutative() && Ops.size() == 2 && Ops[0] > Ops[1])
    std::swap(Ops[0], Ops[1]);
  return {I.getOpcode(), I.getType(), Extra, std::move(Ops)};
}

} // namespace graceopt
