//===-- GraceVecHints.h - Target-aware loop vectorization hints -------------===//
//
// Annotates innermost loops that LoopOpportunityAnalysis classifies as
// vectorization candidates with loop metadata that steers LLVM's loop
// vectorizer, using knowledge of the target CPU:
//
//   * llvm.loop.interleave.count   - matched to the number of SIMD pipes of
//                                    the CPU (4 on Neoverse V2 / NVIDIA Grace)
//   * llvm.loop.vectorize.scalable.enable - optionally prefer SVE over NEON
//   * llvm.loop.vectorize.enable   - optionally force vectorization
//
// It can also, on explicit request, grant `reassoc` to floating-point
// reduction chains so that otherwise serial reductions vectorize. This changes
// rounding (like -ffast-math would for the reduction alone) and is opt-in.
//
// Run this right before the loop vectorizer (the plugin registers it at the
// VectorizerStart extension point).
//
//===----------------------------------------------------------------------===//

#ifndef GRACEOPT_GRACEVECHINTS_H
#define GRACEOPT_GRACEVECHINTS_H

#include "llvm/IR/PassManager.h"

namespace graceopt {

class GraceVecHintsPass : public llvm::PassInfoMixin<GraceVecHintsPass> {
public:
  llvm::PreservedAnalyses run(llvm::Function &F,
                              llvm::FunctionAnalysisManager &FAM);
};

} // namespace graceopt

#endif // GRACEOPT_GRACEVECHINTS_H
