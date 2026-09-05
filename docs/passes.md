# Pass design and correctness boundaries

GraceOpt is a C++17 LLVM 22 new-pass-manager plugin. Build it against the same
LLVM installation as `opt` and `clang`; plugins are not portable across LLVM
versions, operating systems or CPU architectures. The implementation follows
[LLVM's plugin and analysis APIs](https://llvm.org/docs/WritingAnLLVMNewPMPass.html).

## Loop opportunity analysis

`print<grace-loop-analysis>` prints each natural loop's depth, block/instruction
counts, constant trip count when known, invariant chains, redundant expressions,
memory access classification and vectorization blockers. It uses LoopInfo,
DominatorTree, ScalarEvolution, AliasAnalysis, LoopAccessAnalysis and
TargetTransformInfo. Outer loops appear before their children.

Invariant discovery reaches a fixed point so a chain can be discovered even
when block traversal order does not match dependency order. Pure-expression
matching uses opcode, result type, exact GEP source type, comparison predicate
and canonicalized operands. A dominating definition is required; twins in
sibling branches are retained separately.

Vectorization analysis is a conservative opportunity screen, not a reproduction
of the entire vectorizer's legality and profitability checks. Affine accesses
can still be strided, expensive or require gathers. Runtime alias checks are
reported. Unknown trip counts, implicit calls, volatile/atomic accesses,
unsupported recurrences and unsafe memory dependence block candidates. LLVM's
vectorizer makes the final decision after receiving hints.

## LICM

`grace-licm` creates loop preheaders using LLVM LoopSimplify and processes inner
loops first. It hoists only supported pure computations and simple loads whose
memory cannot be clobbered in the loop. Alias analysis distinguishes disjoint
stores from stores that could modify the invariant load. Synchronization and
volatile/atomic accesses conservatively block load hoisting.

Speculation is checked at the destination preheader, not at the original body
location. Non-speculatable instructions require LLVM's implicit-control-flow
must-execute proof, so a call that can unwind or not return before a load/divide
prevents hoisting. This also preserves the behavior of zero-trip loops.
Speculated instructions drop UB-implying attributes/metadata. Moving instructions
invalidates cached ScalarEvolution results; updated LoopInfo and DominatorTree
are preserved. Side-effecting calls, allocations and unsupported intrinsic
operations remain in place.

## Redundant computation elimination

`grace-rce` walks the dominator tree and reuses dominating supported expressions.
IR flags are intersected so merging an `add nsw` with a plain `add` does not
introduce signed-overflow poison. GEPs with different aggregate source types do
not collide. Freeze, aggregate indices and shuffle masks are excluded; only a
small deterministic arithmetic-intrinsic whitelist is eligible, with call
operation equivalence checked separately.

Load/store forwarding is block-local and keyed by pointer identity plus value
type. Any potential write clears memory facts; a simple store establishes its
own fact. Fences and non-simple loads also clear facts. Earlier load poison
metadata is dropped before forwarding. Facts do not cross block boundaries;
this is deliberately simpler than MemorySSA-based load elimination.

## Target hints

`grace-vec-hints` adds interleave metadata to innermost candidates. The default
heuristic requests 4 for Neoverse V1/V2/V3, 2 for generic AArch64 and N1/N2, and
leaves other architectures to LLVM. Existing user metadata wins, and an explicit
vectorization disable also prevents floating-point reassociation.

[NVIDIA Grace](https://www.nvidia.com/en-us/data-center/grace-cpu-superchip/) uses
Neoverse V2 cores and 128-bit SVE2 execution resources. The interleave factor is
a heuristic, not a guarantee of greater throughput. It can grow code or register
pressure, particularly for strict reductions. SVE features are read as exact,
ordered tokens so `+sve2` is not mistaken for `+sve` and a later `-sve` wins.

| Option | Default | Effect |
|---|---|---|
| `-grace-interleave=N` | 0 | 0 derives a heuristic, positive N overrides it, negative disables it |
| `-grace-prefer-scalable` | false | Prefer scalable vectors when `+sve` is enabled |
| `-grace-force-vectorize` | false | Add an enable hint; LLVM still checks legality |
| `-grace-fp-reassoc` | false | Grant reassociation only when an ordered FP reduction is the sole blocker |
| `-grace-pipeline=SELECTION` | all | `all`, `none`, or a comma-separated subset of `licm,rce,vec-hints` |

Pass the options directly to `opt`, or with `-mllvm` when using Clang. Reassociation
changes rounding and is excluded from default benchmarks. Ordered reductions
supported by the target need not grant reassociation. Pipeline selection controls
automatic injection only; explicitly named `opt -passes` still run.

## Automatic placement

At Clang `-O1` and higher, LICM/RCE run at ScalarOptimizerLate and hints run at
VectorizerStart. Stock LLVM already performs strong scalar optimization before
these callbacks. A pass that changes nothing may still incur analysis or loop
simplification cost. Analysis objects with instruction/loop pointers must be
invalidated after transformations; they must never be treated as stable snapshots.

Useful diagnostics are `-verify-each`, `-pass-remarks=grace-licm`,
`-pass-remarks=grace-rce` and `-pass-remarks=grace-vec-hints` in opt, or
`-Rpass='grace-.*'` in Clang. LLVM statistics depend on how LLVM itself was built.
