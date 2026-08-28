//===-- Plugin.cpp - GraceOpt pass plugin entry point ---------------------===//
//
// Registers the GraceOpt passes with the new pass manager so that they can be
// requested by name from opt (-passes=...) and injects them into the standard
// optimization pipeline when the plugin is loaded by clang (-fpass-plugin).
//
// Pass names:
//   grace-licm                   loop-invariant code motion
//   grace-rce                    redundant computation elimination
//   grace-vec-hints              target-aware vectorization hints
//   print<grace-loop-analysis>   dump the loop opportunity report
//
// Pipeline injection (clang -O1 and above):
//   ScalarOptimizerLate EP   -> grace-licm, grace-rce
//   VectorizerStart EP       -> grace-vec-hints
// Controlled by -mllvm -grace-pipeline=<all|none|licm,rce,vec-hints>.
//
//===----------------------------------------------------------------------===//

#include "graceopt/GraceLICM.h"
#include "graceopt/GraceRCE.h"
#include "graceopt/GraceVecHints.h"
#include "graceopt/LoopOpportunityAnalysis.h"

#include "llvm/ADT/StringRef.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/raw_ostream.h"

// LLVM 22 moved the plugin header; support both layouts.
#if __has_include("llvm/Plugins/PassPlugin.h")
#include "llvm/Plugins/PassPlugin.h"
#else
#include "llvm/Passes/PassPlugin.h"
#endif

using namespace llvm;

static cl::opt<std::string> PipelineSelection(
    "grace-pipeline", cl::init("all"), cl::Hidden,
    cl::desc("Which GraceOpt passes to inject into the clang pipeline: "
             "'all', 'none', or a comma-separated subset of licm,rce,vec-hints"));

namespace {

bool pipelineWants(StringRef Pass) {
  StringRef Sel = PipelineSelection;
  if (Sel == "none")
    return false;
  if (Sel == "all")
    return true;
  SmallVector<StringRef, 4> Parts;
  Sel.split(Parts, ',', -1, /*KeepEmpty=*/false);
  return llvm::is_contained(Parts, Pass);
}

void registerPasses(PassBuilder &PB) {
  PB.registerAnalysisRegistrationCallback([](FunctionAnalysisManager &FAM) {
    FAM.registerPass([] { return graceopt::LoopOpportunityAnalysis(); });
  });

  // Explicit use from opt: -passes="grace-licm,grace-rce".
  PB.registerPipelineParsingCallback(
      [](StringRef Name, FunctionPassManager &FPM,
         ArrayRef<PassBuilder::PipelineElement>) {
        if (Name == "grace-licm") {
          FPM.addPass(graceopt::GraceLICMPass());
          return true;
        }
        if (Name == "grace-rce") {
          FPM.addPass(graceopt::GraceRCEPass());
          return true;
        }
        if (Name == "grace-vec-hints") {
          FPM.addPass(graceopt::GraceVecHintsPass());
          return true;
        }
        if (Name == "print<grace-loop-analysis>") {
          FPM.addPass(graceopt::LoopOpportunityPrinterPass(errs()));
          return true;
        }
        return false;
      });

  // Automatic use from clang -fpass-plugin. The scalar passes run late in the
  // function simplification pipeline, after LLVM's own LICM/GVN have had their
  // turn, so anything they still find is a genuine gap. The hint pass runs
  // immediately before the loop vectorizer reads loop metadata.
  PB.registerScalarOptimizerLateEPCallback(
      [](FunctionPassManager &FPM, OptimizationLevel Level) {
        if (Level == OptimizationLevel::O0)
          return;
        if (pipelineWants("licm"))
          FPM.addPass(graceopt::GraceLICMPass());
        if (pipelineWants("rce"))
          FPM.addPass(graceopt::GraceRCEPass());
      });
  PB.registerVectorizerStartEPCallback(
      [](FunctionPassManager &FPM, OptimizationLevel Level) {
        if (Level == OptimizationLevel::O0)
          return;
        if (pipelineWants("vec-hints"))
          FPM.addPass(graceopt::GraceVecHintsPass());
      });
}

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "GraceOpt", LLVM_VERSION_STRING,
          registerPasses};
}
