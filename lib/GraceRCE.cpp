//===-- GraceRCE.cpp - Redundant computation elimination --------------------===//

#include "graceopt/GraceRCE.h"
#include "graceopt/Utils.h"

#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/OptimizationRemarkEmitter.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/Support/Debug.h"

#include <map>

using namespace llvm;
using namespace graceopt;

#define DEBUG_TYPE "grace-rce"

STATISTIC(NumComputationsRemoved,
          "Number of redundant pure computations eliminated");
STATISTIC(NumLoadsForwarded,
          "Number of loads replaced by an earlier load or store in the block");

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
    if (DT.dominates(Def, I) &&
        (!isa<CallBase>(I) || Def->isSameOperationAs(I)))
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

unsigned eliminateRedundancies(Function &F, DominatorTree &DT,
                               OptimizationRemarkEmitter &ORE) {
  AvailableMap Avail;
  unsigned NumRemoved = 0;

  // Dominator-tree preorder guarantees that every instruction that could make
  // the current one redundant has already been recorded.
  for (DomTreeNode *N : depth_first(DT.getRootNode())) {
    AvailableMemory Mem; // Memory facts do not survive across blocks.
    for (Instruction &I : make_early_inc_range(*N->getBlock())) {
      if (isa<FenceInst>(I) || (isa<LoadInst>(I) &&
                               !cast<LoadInst>(I).isSimple())) {
        Mem.clear(); // Synchronization can make a later plain load observe new data.
        continue;
      }
      if (auto *Load = dyn_cast<LoadInst>(&I)) {
        if (Value *V = findAvailableLoad(Mem, *Load)) {
          LLVM_DEBUG(dbgs() << "[grace-rce] forwarding " << *V << " to " << I
                            << "\n");
          ORE.emit([&]() {
            return OptimizationRemark(DEBUG_TYPE, "LoadForwarded", Load)
                   << "forwarded earlier value to redundant load";
          });
          if (auto *Earlier = dyn_cast<LoadInst>(V))
            Earlier->dropPoisonGeneratingMetadata();
          Load->replaceAllUsesWith(V);
          Load->eraseFromParent();
          ++NumRemoved;
          ++NumLoadsForwarded;
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
        ORE.emit([&]() {
          return OptimizationRemark(DEBUG_TYPE, "Eliminated", &I)
                 << "eliminated redundant "
                 << ore::NV("Opcode", I.getOpcodeName());
        });
        I.replaceAllUsesWith(Def);
        I.eraseFromParent();
        ++NumRemoved;
        ++NumComputationsRemoved;
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
  auto &ORE = FAM.getResult<OptimizationRemarkEmitterAnalysis>(F);
  if (eliminateRedundancies(F, DT, ORE) == 0)
    return PreservedAnalyses::all();
  PreservedAnalyses PA;
  PA.preserveSet<CFGAnalyses>();
  return PA;
}
