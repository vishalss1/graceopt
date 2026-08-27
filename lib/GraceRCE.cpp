//===-- GraceRCE.cpp - Redundant computation elimination --------------------===//

#include "graceopt/GraceRCE.h"
#include "graceopt/Utils.h"

#include "llvm/ADT/SmallVector.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/Debug.h"

#include <map>

using namespace llvm;
using namespace graceopt;

#define DEBUG_TYPE "grace-rce"

namespace {

/// Available expressions, keyed structurally. Several instructions may share a
/// key when none dominates the other (e.g. twins in sibling branches), so each
/// key maps to the list of its defining instructions.
using AvailableMap = std::map<ExprKey, SmallVector<Instruction *, 2>>;

/// Find a definition of \p K that dominates \p I, if any.
Instruction *findDominatingDef(AvailableMap &Avail, const ExprKey &K,
                               Instruction *I, DominatorTree &DT) {
  auto It = Avail.find(K);
  if (It == Avail.end())
    return nullptr;
  for (Instruction *Def : It->second)
    if (DT.dominates(Def, I))
      return Def;
  return nullptr;
}

/// Block-local memory state: values known to be in memory at (pointer, type),
/// either because they were just loaded or just stored. Any instruction that
/// may write memory invalidates the whole table; this is deliberately simple
/// and does not consult alias analysis.
using MemKey = std::pair<Value *, Type *>;
using AvailableMemory = std::map<MemKey, Value *>;

/// Try to satisfy \p Load from a value already known to be in memory in this
/// block. Returns the replacement value or nullptr.
Value *findAvailableLoad(AvailableMemory &Mem, LoadInst &Load) {
  if (!Load.isSimple())
    return nullptr;
  auto It = Mem.find({Load.getPointerOperand(), Load.getType()});
  return It == Mem.end() ? nullptr : It->second;
}

unsigned eliminateRedundancies(Function &F, DominatorTree &DT) {
  AvailableMap Avail;
  unsigned NumRemoved = 0;

  // Dominator-tree preorder guarantees that every instruction that could make
  // the current one redundant has already been recorded.
  for (DomTreeNode *N : depth_first(DT.getRootNode())) {
    AvailableMemory Mem; // Memory facts do not survive across blocks.
    for (Instruction &I : make_early_inc_range(*N->getBlock())) {
      if (auto *Load = dyn_cast<LoadInst>(&I)) {
        if (Value *V = findAvailableLoad(Mem, *Load)) {
          LLVM_DEBUG(dbgs() << "[grace-rce] forwarding " << *V << " to " << I
                            << "\n");
          Load->replaceAllUsesWith(V);
          Load->eraseFromParent();
          ++NumRemoved;
        } else if (Load->isSimple()) {
          Mem[{Load->getPointerOperand(), Load->getType()}] = Load;
        }
        continue;
      }
      if (I.mayWriteToMemory()) {
        Mem.clear();
        // A plain store leaves exactly one known value behind: its own.
        if (auto *Store = dyn_cast<StoreInst>(&I); Store && Store->isSimple())
          Mem[{Store->getPointerOperand(),
               Store->getValueOperand()->getType()}] = Store->getValueOperand();
        continue;
      }
      if (!isPureComputation(I) || I.getType()->isVoidTy())
        continue;
      ExprKey K = makeExprKey(I);
      if (Instruction *Def = findDominatingDef(Avail, K, &I, DT)) {
        LLVM_DEBUG(dbgs() << "[grace-rce] replacing " << I << " with " << *Def
                          << "\n");
        // Only facts true of both copies may survive on the merged value:
        // `add nsw` + `add` must become a plain `add`.
        Def->andIRFlags(&I);
        I.replaceAllUsesWith(Def);
        I.eraseFromParent();
        ++NumRemoved;
        continue;
      }
      Avail[std::move(K)].push_back(&I);
    }
  }
  return NumRemoved;
}

} // namespace

PreservedAnalyses GraceRCEPass::run(Function &F, FunctionAnalysisManager &FAM) {
  auto &DT = FAM.getResult<DominatorTreeAnalysis>(F);
  if (eliminateRedundancies(F, DT) == 0)
    return PreservedAnalyses::all();
  PreservedAnalyses PA;
  PA.preserveSet<CFGAnalyses>();
  return PA;
}
