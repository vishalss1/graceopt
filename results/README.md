# Recorded GraceOpt findings

These experiments validate the framework and provide a baseline. They do not
establish a native speedup from GraceOpt or a runtime result on NVIDIA Grace.

## Native measurements

The [main report](recorded/native-windows.md), [raw samples](recorded/native-windows.json)
and [CSV](recorded/native-windows.csv) were produced with LLVM/Clang 22.1.4 on
Windows 11 x86-64, an AMD Family 25 processor, and no CPU affinity. Each of six
workloads was compiled as stock/plugin at O2/O3, using 5 warmed compilation
samples and 9 runtime samples of approximately 50 ms each. All 216 measured
checksums passed. No codegen inspector or other project verification command
ran concurrently with this main experiment.

Every O2 stock/plugin speedup interval crosses 1. The O3 SAXPY comparison has a
nominal slowdown, 0.983x with interval [0.965, 0.993]. However,
[native object disassembly hashes](recorded/native-disassembly.json) match for
every stock/plugin pair at the same optimization level. Executable sizes also
match. Thus this experiment does not demonstrate that GraceOpt changed native
kernel execution performance. Unpinned scheduling, thermal/cache drift and
multiple comparisons can produce nominal differences even for identical code.
The evidence supports treating the apparent O3 slowdown as an unconfirmed timing
effect, rather than attributing it to a particular transformation.

Measured compile deltas range from -9.3% to +12.4%. They include process overhead,
fixed-order builds and OS/cache variation. Negative values do not establish that
loading more passes intrinsically makes Clang compile faster. Rerun on an idle,
pinned host before drawing conclusions about small compile-cost differences.

An earlier [individual-pass experiment](recorded/native-ablations.json) includes
LICM, RCE and hint-only variants (378 checked runtime samples). Some codegen work
ran during its early portion, so it is exploratory evidence. Its nominal small
wins did not reproduce consistently in the main experiment. Together with equal
object disassembly, this illustrates why isolated bootstrap intervals are not
sufficient evidence of a compiler improvement.

## AArch64 code generation

The [profile manifest](recorded/aarch64-manifest.json) covers generic NEON,
Neoverse V2 without SVE, V2 with 128-bit SVE, and V2 with scalable SVE at O2/O3.
The [pass-isolation manifest](recorded/aarch64-ablations.json) tests V2/SVE128/O2
with all passes, disabled injection, LICM alone, RCE alone and hints alone.
Scalable preference was enabled in plugin configurations; reassociation was not.

For the freestanding V2/SVE128/O2 kernels:

| Pipeline | Static instruction lines | Normalized behavior relative to stock |
|---|---:|---|
| Stock | 333 | Baseline |
| Plugin loaded, injection disabled | 333 | Exact assembly SHA256 matches stock |
| LICM only | 333 | Exact assembly SHA256 matches stock |
| RCE only | 333 | Exact assembly SHA256 matches stock |
| Hints only | 371 | Exact assembly SHA256 matches all passes |
| All passes | 371 | Matrix multiplication code changes |

Retained [stock assembly](recorded/aarch64/grace-sve128-O2-stock.s) and
[plugin assembly](recorded/aarch64/grace-sve128-O2-grace.s), along with IR and
remarks in that directory, show that the first four functions are unchanged.
The matrix multiplication inner reduction differs: stock remarks say interleaving
is not beneficial, whereas plugin hints request interleave 4 and the vectorizer
interleaves the loop. The output has a larger tail/control structure, separate
multiply/add operations in the main interleaved loop, and additional callee-saved
register saves/restores. Instruction-line count increases by about 11.4% across
the file. This is a plausible regression mechanism through code growth and
register pressure, not a measured slowdown. Instruction counts are not cycle
estimates; execution on Grace is still required to assess the tradeoff.

The manifest records original local output paths and exact commands. The two
representative compiler outputs are retained byte-for-byte so assembly SHA256
values survive a checkout; other artifacts can be regenerated with
`inspect_codegen.py`. JSON formatting is not part of the artifact hash. Native
object files/executables remain under ignored `bench/out/native`; regenerate them
with the commands in each experiment record.

## Reproduce and extend

Follow [benchmark methodology](../docs/benchmarking.md) to run native comparisons
or build and measure on Grace hardware. Use `inspect_native.py` for native object
hashes and `inspect_codegen.py --pipelines all none licm rce vec-hints` for codegen
attribution. Match LLVM/plugin versions and keep the same inputs and flags across
paired variants. Timing intervals are per comparison, without a multiple-testing
correction. Stock LLVM already handles these straightforward scalar opportunities;
late custom scalar passes can find nothing to change while still requiring work.
