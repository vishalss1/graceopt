//===-- LoopOpportunityAnalysis.cpp - Loop optimization opportunity report ===//

#include "graceopt/LoopOpportunityAnalysis.h"
#include "graceopt/Utils.h"

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/Analysis/IVDescriptors.h"
#include "llvm/Analysis/LoopAccessAnalysis.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/Analysis/TargetTransformInfo.h"
#include "llvm/Analysis/ValueTracking.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"

#include <map>
#include <optional>
#include <tuple>
#include <vector>

using namespace llvm;
using namespace graceopt;

AnalysisKey LoopOpportunityAnalysis::Key;

namespace {

/// Find instructions in the loop that duplicate an earlier identical pure
/// computation. Blocks are visited in dominator-tree order so the "original"
/// is always the one that executes first.
void findRedundancies(Loop &L, DominatorTree &DT,
                      std::vector<RedundantPair> &Out) {
  std::map<ExprKey, const Instruction *> Seen;
  // Walk the dominator subtree rooted at the header; loop blocks are visited
  // only after every block that dominates them.
  for (DomTreeNode *N : depth_first(DT.getNode(L.getHeader()))) {
    BasicBlock *BB = N->getBlock();
    if (!L.contains(BB))
      continue;
    for (Instruction &I : *BB) {
      if (!isPureComputation(I))
        continue;
      ExprKey K = makeExprKey(I);
      auto It = Seen.find(K);
      if (It == Seen.end()) {
        Seen.emplace(std::move(K), &I);
        continue;
      }
      // Only a dominating original makes the duplicate fully redundant; a
      // sibling-branch twin would need partial redundancy elimination.
      if (DT.dominates(It->second, &I))
        Out.push_back({It->second, &I});
    }
  }
}

/// Everything the analysis needs from the pass manager.
struct AnalysisContext {
  ScalarEvolution &SE;
  AAResults &AA;
  DominatorTree &DT;
  LoopAccessInfoManager &LAIs;
  TargetTransformInfo &TTI;
};

/// Populate the vectorization profile of an innermost loop, recording every
/// reason the loop vectorizer would refuse it.
void profileVectorization(Loop &L, AnalysisContext &Ctx, LoopReport &R) {
  auto Block = [&](const Twine &Why) { R.VecBlockers.push_back(Why.str()); };

  if (!L.isLoopSimplifyForm())
    Block("loop is not in simplified form (missing preheader or latch)");
  if (!L.getExitingBlock())
    Block("multiple exiting blocks");
  if (isa<SCEVCouldNotCompute>(Ctx.SE.getBackedgeTakenCount(&L)))
    Block("trip count is not computable by ScalarEvolution");

  // Instruction-level blockers and the memory access profile.
  for (BasicBlock *BB : L.blocks()) {
    for (Instruction &I : *BB) {
      if (auto *CB = dyn_cast<CallBase>(&I)) {
        if (!isa<IntrinsicInst>(CB)) {
          StringRef Callee = CB->getCalledFunction()
                                 ? CB->getCalledFunction()->getName()
                                 : StringRef("<indirect>");
          Block("call to '" + Callee + "'");
        }
        continue;
      }
      Value *Ptr = nullptr;
      if (auto *LI = dyn_cast<LoadInst>(&I)) {
        ++R.NumLoads;
        Ptr = LI->getPointerOperand();
        if (!LI->isSimple())
          Block("volatile or atomic load");
      } else if (auto *SI = dyn_cast<StoreInst>(&I)) {
        ++R.NumStores;
        Ptr = SI->getPointerOperand();
        if (!SI->isSimple())
          Block("volatile or atomic store");
      }
      if (!Ptr)
        continue;
      const SCEV *S = Ctx.SE.getSCEV(Ptr);
      if (Ctx.SE.isLoopInvariant(S, &L)) {
        ++R.NumUniformAccesses;
      } else if (auto *AR = dyn_cast<SCEVAddRecExpr>(S);
                 AR && AR->getLoop() == &L && AR->isAffine()) {
        ++R.NumAffineAccesses;
      } else {
        Block("non-affine memory access (would need gather/scatter)");
      }
    }
  }

  // Loop-carried values: every header PHI must be an induction or a
  // recognised reduction.
  for (PHINode &Phi : L.getHeader()->phis()) {
    InductionDescriptor ID;
    if (InductionDescriptor::isInductionPHI(&Phi, &L, &Ctx.SE, ID))
      continue;
    RecurrenceDescriptor RD;
    if (RecurrenceDescriptor::isReductionPHI(&Phi, &L, RD, /*DB=*/nullptr,
                                             /*AC=*/nullptr, &Ctx.DT,
                                             &Ctx.SE)) {
      ++R.NumReductions;
      if (RD.isOrdered()) {
        R.HasOrderedFPReduction = true;
        if (!Ctx.TTI.enableOrderedReductions())
          Block("floating-point reduction lacks 'reassoc' and target has no "
                "in-order vector reduction");
      }
      continue;
    }
    Block("unrecognised loop-carried value '" +
          (Phi.hasName() ? Phi.getName() : StringRef("<unnamed phi>")) + "'");
  }

  // Memory dependence legality via LLVM's LoopAccessAnalysis, the same oracle
  // the loop vectorizer consults.
  if (R.NumStores > 0 && L.isLoopSimplifyForm()) {
    const LoopAccessInfo &LAI = Ctx.LAIs.getInfo(L);
    if (!LAI.canVectorizeMemory()) {
      std::string Msg = "memory dependence prevents vectorization";
      if (const auto *Rep = LAI.getReport())
        Msg += ": " + Rep->getMsg();
      Block(Msg);
    } else if (LAI.getNumRuntimePointerChecks() > 0) {
      R.NeedsRuntimeChecks = true;
    }
  }
}

LoopReport analyzeLoop(Loop &L, AnalysisContext &Ctx) {
  ScalarEvolution &SE = Ctx.SE;
  AAResults &AA = Ctx.AA;
  DominatorTree &DT = Ctx.DT;
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
        if (auto Info = classifyLoopInvariant(I, L, AA, DT, Known)) {
          Known.insert(&I);
          R.Invariants.push_back({&I, Info->SafeToSpeculate});
          Changed = true;
        }
      }
  }
  findRedundancies(L, DT, R.Redundancies);
  if (R.IsInnermost)
    profileVectorization(L, Ctx, R);
  return R;
}

} // namespace

LoopOpportunityAnalysis::Result
LoopOpportunityAnalysis::run(Function &F, FunctionAnalysisManager &FAM) {
  auto &LI = FAM.getResult<LoopAnalysis>(F);
  auto &SE = FAM.getResult<ScalarEvolutionAnalysis>(F);
  auto &AA = FAM.getResult<AAManager>(F);
  auto &DT = FAM.getResult<DominatorTreeAnalysis>(F);
  auto &LAIs = FAM.getResult<LoopAccessAnalysis>(F);
  auto &TTI = FAM.getResult<TargetIRAnalysis>(F);
  AnalysisContext Ctx{SE, AA, DT, LAIs, TTI};

  FunctionLoopReport Report;
  // Visit loops outermost-first in program order so the printed report reads
  // naturally; nested loops follow their parent.
  for (Loop *Top : LI) {
    for (Loop *L : depth_first(Top))
      Report.Loops.push_back(analyzeLoop(*L, Ctx));
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
    if (!R.Redundancies.empty()) {
      OS.indent(R.Depth * 2 + 2) << "redundant=" << R.Redundancies.size()
                                 << ":\n";
      for (const RedundantPair &P : R.Redundancies) {
        OS.indent(R.Depth * 2 + 4);
        P.Duplicate->print(OS, /*IsForDebug=*/true);
        OS << "  ; duplicates ";
        P.Original->printAsOperand(OS, /*PrintType=*/false);
        OS << "\n";
      }
    }
    if (R.IsInnermost) {
      OS.indent(R.Depth * 2 + 2)
          << "memory: loads=" << R.NumLoads << " stores=" << R.NumStores
          << " affine=" << R.NumAffineAccesses
          << " uniform=" << R.NumUniformAccesses
          << " reductions=" << R.NumReductions
          << (R.HasOrderedFPReduction ? " (ordered-fp)" : "")
          << (R.NeedsRuntimeChecks ? " runtime-checks" : "") << "\n";
      if (R.isVectorizationCandidate()) {
        OS.indent(R.Depth * 2 + 2) << "vectorize: candidate\n";
      } else {
        OS.indent(R.Depth * 2 + 2) << "vectorize: blocked\n";
        for (const std::string &Why : R.VecBlockers)
          OS.indent(R.Depth * 2 + 4) << "- " << Why << "\n";
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
