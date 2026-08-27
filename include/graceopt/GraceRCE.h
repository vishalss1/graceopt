//===-- GraceRCE.h - Redundant computation elimination ----------------------===//
//
// Removes pure computations that recompute a value already available from an
// identical, dominating instruction. This is a dominator-tree based common
// subexpression elimination over the whole function; the loop opportunity
// analysis reports the per-loop subset of what this pass removes.
//
//===----------------------------------------------------------------------===//

#ifndef GRACEOPT_GRACERCE_H
#define GRACEOPT_GRACERCE_H

#include "llvm/IR/PassManager.h"

namespace graceopt {

class GraceRCEPass : public llvm::PassInfoMixin<GraceRCEPass> {
public:
  llvm::PreservedAnalyses run(llvm::Function &F,
                              llvm::FunctionAnalysisManager &FAM);
};

} // namespace graceopt

#endif // GRACEOPT_GRACERCE_H
