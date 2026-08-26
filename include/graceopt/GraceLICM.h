//===-- GraceLICM.h - Loop-invariant code motion ---------------------------===//
//
// Hoists loop-invariant, side-effect-free computations out of loops into the
// loop preheader so they execute once instead of once per iteration.
//
// The legality rules are shared with LoopOpportunityAnalysis (see Utils.h):
// everything the analysis lists as an invariant candidate is exactly what this
// pass hoists.
//
//===----------------------------------------------------------------------===//

#ifndef GRACEOPT_GRACELICM_H
#define GRACEOPT_GRACELICM_H

#include "llvm/IR/PassManager.h"

namespace graceopt {

class GraceLICMPass : public llvm::PassInfoMixin<GraceLICMPass> {
public:
  llvm::PreservedAnalyses run(llvm::Function &F,
                              llvm::FunctionAnalysisManager &FAM);
};

} // namespace graceopt

#endif // GRACEOPT_GRACELICM_H
