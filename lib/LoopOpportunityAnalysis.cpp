//===-- LoopOpportunityAnalysis.cpp - Loop optimization opportunity report ===//

#include "graceopt/LoopOpportunityAnalysis.h"

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"

#include <optional>

using namespace llvm;
using namespace graceopt;

AnalysisKey LoopOpportunityAnalysis::Key;

namespace {

/// Does any instruction in the loop possibly write memory that \p Load reads?
bool loadMayBeClobberedInLoop(LoadInst &Load, Loop &L, AAResults &AA) {
  MemoryLocation Loc = MemoryLocation::get(&Load);
  for (BasicBlock *BB : L.blocks())
    for (Instruction &I : *BB)
      if (I.mayWriteToMemory() && isModSet(AA.getModRefInfo(&I, Loc)))
        return true;
  return false;
}

/// Decide whether \p I is a loop-invariant computation that could be hoisted
/// to the preheader of \p L. Mirrors the legality rules GraceLICM applies.
std::optional<InvariantCandidate>
classifyInvariant(Instruction &I, Loop &L, AAResults &AA, DominatorTree &DT,
                  const SmallPtrSetImpl<const Instruction *> &KnownInvariant) {
  if (isa<PHINode>(I) || I.isTerminator() || I.isEHPad())
    return std::nullopt;
  // Operands must be invariant either because they are defined outside the
  // loop, or because they are themselves candidates found earlier (so that
  // chains like `t = a*b; u = t/c` are discovered transitively).
  for (Value *Op : I.operands()) {
    if (L.isLoopInvariant(Op))
      continue;
    if (auto *OpI = dyn_cast<Instruction>(Op); OpI && KnownInvariant.count(OpI))
      continue;
    return std::nullopt;
  }
  // Anything that writes memory, throws, or has other side effects stays put.
  if (I.mayWriteToMemory() || I.mayThrow() || !I.willReturn())
    return std::nullopt;
  if (isa<AllocaInst>(I) || isa<CallBase>(I) && !isa<IntrinsicInst>(I))
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

  InvariantCandidate C;
  C.I = &I;
  C.SafeToSpeculate = isSafeToSpeculativelyExecute(&I, /*CtxI=*/nullptr,
                                                   /*AC=*/nullptr, &DT);
  if (!C.SafeToSpeculate) {
    // Not speculatable (e.g. a division that might trap, or a load from a
    // pointer we cannot prove dereferenceable). It is still hoistable when the
    // instruction is guaranteed to execute on every iteration, i.e. its block
    // dominates every loop exit.
    SmallVector<BasicBlock *, 4> Exits;
    L.getExitBlocks(Exits);
    bool DominatesExits = !Exits.empty();
    for (BasicBlock *E : Exits)
      if (!DT.dominates(I.getParent(), E)) {
        DominatesExits = false;
        break;
      }
    if (!DominatesExits)
      return std::nullopt;
  }
  return C;
}

LoopReport analyzeLoop(Loop &L, ScalarEvolution &SE, AAResults &AA,
                       DominatorTree &DT) {
  LoopReport R;
  R.L = &L;
  R.HeaderName = L.getHeader()->hasName() ? L.getHeader()->getName().str()
                                          : std::string("<unnamed>");
  R.Depth = L.getLoopDepth();
  R.NumBlocks = L.getNumBlocks();
  for (BasicBlock *BB : L.blocks())
    R.NumInsts += BB->size();
  R.TripCount = SE.getSmallConstantTripCount(&L);
  R.IsInnermost = L.isInnermost();

  // Iterate to a fixpoint so that invariant chains are picked up regardless
  // of the order blocks are visited in.
  SmallPtrSet<const Instruction *, 16> Known;
  bool Changed = true;
  while (Changed) {
    Changed = false;
    for (BasicBlock *BB : L.blocks())
      for (Instruction &I : *BB) {
        if (Known.count(&I))
          continue;
        if (auto C = classifyInvariant(I, L, AA, DT, Known)) {
          Known.insert(&I);
          R.Invariants.push_back(*C);
          Changed = true;
        }
      }
  }
  return R;
}

} // namespace

LoopOpportunityAnalysis::Result
LoopOpportunityAnalysis::run(Function &F, FunctionAnalysisManager &FAM) {
  auto &LI = FAM.getResult<LoopAnalysis>(F);
  auto &SE = FAM.getResult<ScalarEvolutionAnalysis>(F);
  auto &AA = FAM.getResult<AAManager>(F);
  auto &DT = FAM.getResult<DominatorTreeAnalysis>(F);

  FunctionLoopReport Report;
  // Visit loops outermost-first in program order so the printed report reads
  // naturally; nested loops follow their parent.
  for (Loop *Top : LI) {
    for (Loop *L : depth_first(Top))
      Report.Loops.push_back(analyzeLoop(*L, SE, AA, DT));
  }
  return Report;
}

void FunctionLoopReport::print(raw_ostream &OS) const {
  if (Loops.empty()) {
    OS << "  (no loops)\n";
    return;
  }
  for (const LoopReport &R : Loops) {
    OS.indent(R.Depth * 2) << "loop '" << R.HeaderName << "' depth=" << R.Depth
                           << " blocks=" << R.NumBlocks
                           << " insts=" << R.NumInsts << " trip=";
    if (R.TripCount)
      OS << R.TripCount;
    else
      OS << "unknown";
    if (R.IsInnermost)
      OS << " innermost";
    OS << "\n";
    if (!R.Invariants.empty()) {
      OS.indent(R.Depth * 2 + 2) << "invariants=" << R.Invariants.size()
                                 << ":\n";
      for (const InvariantCandidate &C : R.Invariants) {
        OS.indent(R.Depth * 2 + 4)
            << (C.SafeToSpeculate ? "[speculatable] " : "[guarded]      ");
        C.I->print(OS, /*IsForDebug=*/true);
        OS << "\n";
      }
    }
  }
}

PreservedAnalyses LoopOpportunityPrinterPass::run(Function &F,
                                                  FunctionAnalysisManager &FAM) {
  OS << "GraceOpt loop report for function '" << F.getName() << "':\n";
  FAM.getResult<LoopOpportunityAnalysis>(F).print(OS);
  return PreservedAnalyses::all();
}
