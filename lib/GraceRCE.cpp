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

unsigned eliminateRedundancies(Function &F, DominatorTree &DT) {
  AvailableMap Avail;
  unsigned NumRemoved = 0;

  // Dominator-tree preorder guarantees that every instruction that could make
  // the current one redundant has already been recorded.
  for (DomTreeNode *N : depth_first(DT.getRootNode())) {
    for (Instruction &I : make_early_inc_range(*N->getBlock())) {
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
