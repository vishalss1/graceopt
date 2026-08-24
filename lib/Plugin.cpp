//===-- Plugin.cpp - GraceOpt pass plugin entry point ---------------------===//
//
// Registers the GraceOpt passes with the new pass manager so that they can be
// requested by name from opt (-passes=...) or injected into the clang
// pipeline via -fpass-plugin.
//
//===----------------------------------------------------------------------===//

#include "graceopt/LoopOpportunityAnalysis.h"

#include "llvm/IR/Function.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
// LLVM 22 moved the plugin header; support both layouts.
#if __has_include("llvm/Plugins/PassPlugin.h")
#include "llvm/Plugins/PassPlugin.h"
#else
#include "llvm/Passes/PassPlugin.h"
#endif
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {

/// Smoke-test pass: prints the name of every function it visits.
struct GraceHelloPass : PassInfoMixin<GraceHelloPass> {
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &) {
    errs() << "[graceopt] visiting function '" << F.getName() << "'\n";
    return PreservedAnalyses::all();
  }
  static bool isRequired() { return true; }
};

void registerPasses(PassBuilder &PB) {
  PB.registerAnalysisRegistrationCallback([](FunctionAnalysisManager &FAM) {
    FAM.registerPass([] { return graceopt::LoopOpportunityAnalysis(); });
  });

  PB.registerPipelineParsingCallback(
      [](StringRef Name, FunctionPassManager &FPM,
         ArrayRef<PassBuilder::PipelineElement>) {
        if (Name == "grace-hello") {
          FPM.addPass(GraceHelloPass());
          return true;
        }
        if (Name == "print<grace-loop-analysis>") {
          FPM.addPass(graceopt::LoopOpportunityPrinterPass(errs()));
          return true;
        }
        return false;
      });
}

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "GraceOpt", LLVM_VERSION_STRING,
          registerPasses};
}
