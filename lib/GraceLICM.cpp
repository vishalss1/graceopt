//===-- GraceLICM.cpp - Loop-invariant code motion -------------------------===//

#include "graceopt/GraceLICM.h"
#include "graceopt/Utils.h"

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/OptimizationRemarkEmitter.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/Debug.h"

using namespace llvm;
using namespace graceopt;

#define DEBUG_TYPE "grace-licm"

STATISTIC(NumHoisted, "Number of loop-invariant instructions hoisted");
STATISTIC(NumSpeculated,
          "Number of hoisted instructions that were not guaranteed to execute");

namespace {

/// Hoist every legal invariant out of \p L. Returns the number of
/// instructions moved.
unsigned hoistLoopInvariants(Loop &L, AAResults &AA, DominatorTree &DT,
                             OptimizationRemarkEmitter &ORE) {
  BasicBlock *Preheader = L.getLoopPreheader();
  if (!Preheader)
    return 0; // Not in simplified form; run loop-simplify first.

  Instruction *InsertPt = Preheader->getTerminator();
  SmallPtrSet<const Instruction *, 16> Hoisted;
  unsigned Count = 0;

  // Iterate to a fixpoint: hoisting `t = a*b` makes `u = t/c` invariant.
  // Blocks are visited in loop order and instructions in program order, so an
  // instruction's operands always reach the preheader before it does.
  bool Changed = true;
  while (Changed) {
    Changed = false;
    for (BasicBlock *BB : L.blocks()) {
      // Collect first: moving instructions while iterating a block is unsafe.
      SmallVector<std::pair<Instruction *, InvariantInfo>, 8> Batch;
      for (Instruction &I : *BB) {
        if (Hoisted.count(&I))
          continue;
        if (auto Info = classifyLoopInvariant(I, L, AA, DT, Hoisted)) {
          Hoisted.insert(&I);
          Batch.emplace_back(&I, *Info);
        }
      }
      for (auto &[I, Info] : Batch) {
        LLVM_DEBUG(dbgs() << "[grace-licm] hoisting " << *I << " out of loop '"
                          << L.getHeader()->getName() << "'\n");
        I->moveBefore(InsertPt->getIterator());
        if (!Info.GuaranteedToExecute) {
          // The instruction now runs even on paths where it previously did
          // not. Metadata such as !noundef would then assert facts that are
          // no longer guaranteed, so strip it.
          I->dropUBImplyingAttrsAndMetadata();
          ++NumSpeculated;
        }
        ++NumHoisted;
        ++Count;
        Changed = true;
        ORE.emit([&]() {
          return OptimizationRemark(DEBUG_TYPE, "Hoisted", I)
                 << "hoisted loop-invariant "
                 << ore::NV("Opcode", I->getOpcodeName()) << " out of loop '"
                 << ore::NV("Loop", L.getHeader()->getName()) << "'";
        });
      }
    }
  }
  return Count;
}

} // namespace

PreservedAnalyses GraceLICMPass::run(Function &F,
                                     FunctionAnalysisManager &FAM) {
  // Guarantee preheaders to hoist into, whatever ran before us.
  bool CFGChanged = simplifyAllLoops(F, FAM);
  auto &LI = FAM.getResult<LoopAnalysis>(F);
  auto &DT = FAM.getResult<DominatorTreeAnalysis>(F);
  auto &AA = FAM.getResult<AAManager>(F);
  auto &ORE = FAM.getResult<OptimizationRemarkEmitterAnalysis>(F);

  unsigned Total = 0;
  // Innermost loops first: what we hoist into an inner preheader sits inside
  // the enclosing loop and may be hoisted again when that loop is processed.
  SmallVector<Loop *, 8> Loops = LI.getLoopsInPreorder();
  for (Loop *L : reverse(Loops))
    Total += hoistLoopInvariants(*L, AA, DT, ORE);

  if (Total == 0 && !CFGChanged)
    return PreservedAnalyses::all();

  PreservedAnalyses PA;
  if (!CFGChanged)
    PA.preserveSet<CFGAnalyses>(); // Instructions moved, no edges touched.
  PA.preserve<DominatorTreeAnalysis>();
  PA.preserve<LoopAnalysis>();
  // Moving instructions can invalidate cached SCEV dispositions.
  return PA;
}
