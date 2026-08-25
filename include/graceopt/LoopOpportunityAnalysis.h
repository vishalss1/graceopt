//===-- LoopOpportunityAnalysis.h - Loop optimization opportunity report --===//
//
// A function analysis that inventories every loop and records what GraceOpt's
// transformation passes could do with it: hoistable invariant instructions,
// redundant computations, and whether the loop looks like a vectorization
// candidate (and if not, why).
//
//===----------------------------------------------------------------------===//

#ifndef GRACEOPT_LOOPOPPORTUNITYANALYSIS_H
#define GRACEOPT_LOOPOPPORTUNITYANALYSIS_H

#include "llvm/IR/PassManager.h"
#include "llvm/Support/raw_ostream.h"

#include <string>
#include <vector>

namespace llvm {
class Function;
class Instruction;
class Loop;
} // namespace llvm

namespace graceopt {

/// An instruction whose operands are all loop-invariant and that could be
/// moved to the loop preheader.
struct InvariantCandidate {
  const llvm::Instruction *I = nullptr;
  /// True when the instruction can be executed unconditionally before the
  /// loop (no traps, no side effects, pointer provably dereferenceable).
  bool SafeToSpeculate = false;
};

/// A computation inside the loop that recomputes a value already produced by
/// an identical instruction (same opcode, type and operands) in the loop.
struct RedundantPair {
  const llvm::Instruction *Original = nullptr;
  const llvm::Instruction *Duplicate = nullptr;
};

/// Report for a single natural loop.
struct LoopReport {
  const llvm::Loop *L = nullptr;
  std::string HeaderName;
  unsigned Depth = 0;
  unsigned NumBlocks = 0;
  unsigned NumInsts = 0;
  /// Constant trip count if ScalarEvolution can prove one, otherwise 0.
  unsigned TripCount = 0;
  bool IsInnermost = false;

  /// Instructions that GraceLICM could hoist out of this loop.
  std::vector<InvariantCandidate> Invariants;
  /// Pure computations duplicated within the loop body.
  std::vector<RedundantPair> Redundancies;
};

/// Report for a whole function.
struct FunctionLoopReport {
  std::vector<LoopReport> Loops;

  void print(llvm::raw_ostream &OS) const;
};

/// Analysis pass producing a FunctionLoopReport.
class LoopOpportunityAnalysis
    : public llvm::AnalysisInfoMixin<LoopOpportunityAnalysis> {
  friend llvm::AnalysisInfoMixin<LoopOpportunityAnalysis>;
  static llvm::AnalysisKey Key;

public:
  using Result = FunctionLoopReport;
  Result run(llvm::Function &F, llvm::FunctionAnalysisManager &FAM);
};

/// Printer pass: `-passes='print<grace-loop-analysis>'`.
class LoopOpportunityPrinterPass
    : public llvm::PassInfoMixin<LoopOpportunityPrinterPass> {
  llvm::raw_ostream &OS;

public:
  explicit LoopOpportunityPrinterPass(llvm::raw_ostream &OS) : OS(OS) {}
  llvm::PreservedAnalyses run(llvm::Function &F,
                              llvm::FunctionAnalysisManager &FAM);
  static bool isRequired() { return true; }
};

} // namespace graceopt

#endif // GRACEOPT_LOOPOPPORTUNITYANALYSIS_H
