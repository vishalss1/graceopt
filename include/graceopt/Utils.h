//===-- Utils.h - Shared legality helpers for GraceOpt passes -------------===//
//
// Small, well-defined predicates shared between the opportunity analysis and
// the transformation passes so that "what the analysis reports" and "what the
// transforms do" can never drift apart.
//
//===----------------------------------------------------------------------===//

#ifndef GRACEOPT_UTILS_H
#define GRACEOPT_UTILS_H

#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/IR/PassManager.h"

#include <optional>
#include <tuple>
#include <vector>

namespace llvm {
class AAResults;
class AssumptionCache;
class DominatorTree;
class Function;
class Instruction;
class LoadInst;
class Loop;
class LoopInfo;
class ScalarEvolution;
class Type;
class Value;
} // namespace llvm

namespace graceopt {

/// Result of classifying an instruction as loop-invariant.
struct InvariantInfo {
  /// The instruction may execute unconditionally before the loop: it cannot
  /// trap, has no side effects and any pointer it reads is dereferenceable.
  bool SafeToSpeculate = false;
  /// The instruction's block dominates every loop exit, so it already runs on
  /// every trip through the loop body.
  bool GuaranteedToExecute = false;
};

/// Put every loop of \p F into loop-simplify form (dedicated preheader, single
/// latch, dedicated exits), which the GraceOpt passes rely on just like LLVM's
/// own loop passes do. Passes placed at pipeline extension points cannot
/// assume that form still holds, because SimplifyCFG may have merged the
/// preheader away. Updates the analyses in place and, when the CFG changed,
/// invalidates every other cached function analysis via \p FAM.
/// Returns true if the CFG changed.
bool simplifyAllLoops(llvm::Function &F, llvm::FunctionAnalysisManager &FAM);

/// Does any instruction in \p L possibly write memory that \p Load reads?
bool loadMayBeClobberedInLoop(llvm::LoadInst &Load, llvm::Loop &L,
                              llvm::AAResults &AA);

/// Decide whether \p I is a loop-invariant computation that could legally be
/// hoisted to the preheader of \p L. Operands count as invariant when they are
/// defined outside the loop or are in \p KnownInvariant (instructions already
/// decided to be hoistable), which lets callers discover chains transitively.
///
/// Returns std::nullopt when hoisting is illegal. Non-speculatable
/// instructions are only accepted when their block dominates all loop exits,
/// i.e. they are guaranteed to execute whenever the loop body runs.
std::optional<InvariantInfo> classifyLoopInvariant(
    llvm::Instruction &I, llvm::Loop &L, llvm::AAResults &AA,
    llvm::DominatorTree &DT,
    const llvm::SmallPtrSetImpl<const llvm::Instruction *> &KnownInvariant);

/// Is \p I a side-effect-free computation whose result depends only on its
/// operands? Such instructions can be value-numbered and de-duplicated.
bool isPureComputation(const llvm::Instruction &I);

/// Structural key identifying "the same computation": opcode, result type, an
/// opcode-specific discriminator (predicate, cast kind, GEP source type,
/// intrinsic id) and the operand list, canonicalised for commutative ops.
using ExprKey =
    std::tuple<unsigned, llvm::Type *, unsigned, llvm::Type *, std::vector<llvm::Value *>>;

ExprKey makeExprKey(const llvm::Instruction &I);

} // namespace graceopt

#endif // GRACEOPT_UTILS_H
