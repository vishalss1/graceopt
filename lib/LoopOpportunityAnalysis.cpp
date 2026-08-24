//===-- LoopOpportunityAnalysis.cpp - Loop optimization opportunity report ===//

#include "graceopt/LoopOpportunityAnalysis.h"

#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"

using namespace llvm;
using namespace graceopt;

AnalysisKey LoopOpportunityAnalysis::Key;

namespace {

LoopReport analyzeLoop(Loop &L, ScalarEvolution &SE) {
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
  return R;
}

} // namespace

LoopOpportunityAnalysis::Result
LoopOpportunityAnalysis::run(Function &F, FunctionAnalysisManager &FAM) {
  auto &LI = FAM.getResult<LoopAnalysis>(F);
  auto &SE = FAM.getResult<ScalarEvolutionAnalysis>(F);

  FunctionLoopReport Report;
  // Visit loops outermost-first in program order so the printed report reads
  // naturally; nested loops follow their parent.
  for (Loop *Top : LI) {
    for (Loop *L : depth_first(Top))
      Report.Loops.push_back(analyzeLoop(*L, SE));
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
  }
}

PreservedAnalyses LoopOpportunityPrinterPass::run(Function &F,
                                                  FunctionAnalysisManager &FAM) {
  OS << "GraceOpt loop report for function '" << F.getName() << "':\n";
  FAM.getResult<LoopOpportunityAnalysis>(F).print(OS);
  return PreservedAnalyses::all();
}
