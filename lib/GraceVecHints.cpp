//===-- GraceVecHints.cpp - Target-aware loop vectorization hints -----------===//

#include "graceopt/GraceVecHints.h"
#include "graceopt/LoopOpportunityAnalysis.h"
#include "graceopt/Utils.h"

#include "llvm/ADT/Statistic.h"
#include "llvm/Analysis/IVDescriptors.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/OptimizationRemarkEmitter.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Operator.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Debug.h"
#include "llvm/TargetParser/Triple.h"
#include "llvm/Transforms/Utils/LoopUtils.h"

using namespace llvm;
using namespace graceopt;

#define DEBUG_TYPE "grace-vec-hints"

STATISTIC(NumLoopsHinted, "Number of loops annotated with vectorization hints");
STATISTIC(NumReductionsReassociated,
          "Number of FP reduction chains granted reassoc");

// Command line knobs. They are read by opt (-grace-...) and by clang through
// -mllvm -grace-....
static cl::opt<int> InterleaveOverride(
    "grace-interleave", cl::init(0), cl::Hidden,
    cl::desc("Interleave count to request for candidate loops "
             "(0 = derive from the target CPU, -1 = never hint)"));

static cl::opt<bool> PreferScalable(
    "grace-prefer-scalable", cl::init(false), cl::Hidden,
    cl::desc("Request scalable (SVE) vectors on targets that support them"));

static cl::opt<bool> ForceVectorize(
    "grace-force-vectorize", cl::init(false), cl::Hidden,
    cl::desc("Set llvm.loop.vectorize.enable on every candidate loop"));

static cl::opt<bool> AllowFPReassoc(
    "grace-fp-reassoc", cl::init(false), cl::Hidden,
    cl::desc("Grant 'reassoc' to floating-point reduction chains so they can "
             "be vectorized (changes rounding)"));

namespace {

/// What we know about the CPU the function is compiled for.
struct TargetProfile {
  bool IsAArch64 = false;
  bool HasSVE = false;
  StringRef CPU;
  /// 0 means "no opinion, leave it to the vectorizer".
  unsigned InterleaveCount = 0;
};

TargetProfile profileTarget(const Function &F) {
  TargetProfile P;
  Triple TT(F.getParent()->getTargetTriple());
  P.IsAArch64 = TT.isAArch64();
  P.CPU = F.getFnAttribute("target-cpu").getValueAsString();
  StringRef Features = F.getFnAttribute("target-features").getValueAsString();
  SmallVector<StringRef, 16> FeatureList;
  Features.split(FeatureList, ',');
  for (StringRef Feature : FeatureList) {
    if (Feature == "+sve") P.HasSVE = true;
    if (Feature == "-sve") P.HasSVE = false;
  }

  if (P.IsAArch64) {
    // Number of 128-bit SIMD/FP pipes per core. Interleaving by that factor
    // gives the out-of-order engine one independent vector chain per pipe,
    // which matters most for reductions, whose chain is otherwise serial.
    if (P.CPU == "neoverse-v2" || P.CPU == "neoverse-v1" ||
        P.CPU == "neoverse-v3")
      P.InterleaveCount = 4; // Grace / Graviton3 / V3 class: 4 pipes
    else if (P.CPU == "neoverse-n2" || P.CPU == "neoverse-n1")
      P.InterleaveCount = 2;
    else
      P.InterleaveCount = 2; // Conservative default for generic AArch64.
  }
  if (InterleaveOverride > 0)
    P.InterleaveCount = InterleaveOverride;
  else if (InterleaveOverride < 0)
    P.InterleaveCount = 0;
  return P;
}

bool hasUserHint(const Loop &L, StringRef Name) {
  return findStringMetadataForLoop(&L, Name).has_value();
}

/// Grant reassociation to the FP reduction chain rooted at \p Phi. Returns
/// true if any flag changed.
bool allowReassociation(PHINode &Phi, Loop &L, RecurrenceDescriptor &RD) {
  bool Changed = false;
  for (Instruction *I : RD.getReductionOpChain(&Phi, &L)) {
    if (!isa<FPMathOperator>(I) || I->hasAllowReassoc())
      continue;
    I->setHasAllowReassoc(true);
    Changed = true;
  }
  if (!Phi.hasAllowReassoc()) {
    Phi.setHasAllowReassoc(true);
    Changed = true;
  }
  return Changed;
}

} // namespace

PreservedAnalyses GraceVecHintsPass::run(Function &F,
                                         FunctionAnalysisManager &FAM) {
  // The loop vectorizer simplifies loops before judging them; do the same so
  // the analysis sees the loops the way the vectorizer will.
  bool CFGChanged = simplifyAllLoops(F, FAM);
  auto &Report = FAM.getResult<LoopOpportunityAnalysis>(F);
  auto &DT = FAM.getResult<DominatorTreeAnalysis>(F);
  auto &SE = FAM.getResult<ScalarEvolutionAnalysis>(F);
  auto &ORE = FAM.getResult<OptimizationRemarkEmitterAnalysis>(F);
  TargetProfile TP = profileTarget(F);

  bool Changed = false;
  for (const LoopReport &R : Report.Loops) {
    if (!R.IsInnermost)
      continue;
    Loop &L = *const_cast<Loop *>(R.L);
    // An explicit disable pragma also forbids granting reassociation.
    if (auto Hint = getOptionalBoolLoopAttribute(&L, "llvm.loop.vectorize.enable");
        Hint && !*Hint)
      continue;

    // Ordered FP reductions are the one blocker we can lift ourselves.
    bool Candidate = R.isVectorizationCandidate();
    if (!Candidate && AllowFPReassoc && R.HasOrderedFPReduction) {
      bool OnlyReductionBlocked = true;
      for (const std::string &Why : R.VecBlockers)
        if (Why.find("floating-point reduction") == std::string::npos)
          OnlyReductionBlocked = false;
      if (OnlyReductionBlocked) {
        for (PHINode &Phi : L.getHeader()->phis()) {
          RecurrenceDescriptor RD;
          if (RecurrenceDescriptor::isReductionPHI(&Phi, &L, RD, nullptr,
                                                   nullptr, &DT, &SE) &&
              RD.isOrdered() && allowReassociation(Phi, L, RD)) {
            Changed = true;
            ++NumReductionsReassociated;
            ORE.emit([&]() {
              return OptimizationRemark(DEBUG_TYPE, "Reassociated",
                                        L.getStartLoc(), L.getHeader())
                     << "granted reassoc to FP reduction so the loop can "
                        "vectorize";
            });
          }
        }
        Candidate = true;
      }
    }
    if (!Candidate)
      continue;

    if (TP.InterleaveCount > 0 && !hasUserHint(L, "llvm.loop.interleave.count")) {
      addStringMetadataToLoop(&L, "llvm.loop.interleave.count",
                              TP.InterleaveCount);
      Changed = true;
    }
    if (PreferScalable && TP.HasSVE &&
        !hasUserHint(L, "llvm.loop.vectorize.scalable.enable")) {
      addStringMetadataToLoop(&L, "llvm.loop.vectorize.scalable.enable", 1);
      Changed = true;
    }
    if (ForceVectorize && !hasUserHint(L, "llvm.loop.vectorize.enable")) {
      addStringMetadataToLoop(&L, "llvm.loop.vectorize.enable", 1);
      Changed = true;
    }
    LLVM_DEBUG(dbgs() << "[grace-vec-hints] annotated loop '"
                      << L.getHeader()->getName() << "' interleave="
                      << TP.InterleaveCount << "\n");
    ++NumLoopsHinted;
    ORE.emit([&]() {
      return OptimizationRemark(DEBUG_TYPE, "Hinted", L.getStartLoc(),
                                L.getHeader())
             << "vectorization candidate; requested interleave count "
             << ore::NV("Interleave", TP.InterleaveCount)
             << (TP.CPU.empty() ? "" : " for cpu ") << ore::NV("CPU", TP.CPU);
    });
  }

  if (!Changed && !CFGChanged)
    return PreservedAnalyses::all();
  PreservedAnalyses PA;
  if (!CFGChanged)
    PA.preserveSet<CFGAnalyses>(); // Only metadata and fast-math flags.
  PA.preserve<DominatorTreeAnalysis>();
  PA.preserve<LoopAnalysis>();
  // Fast-math changes may alter cached recurrence classification.
  return PA;
}
