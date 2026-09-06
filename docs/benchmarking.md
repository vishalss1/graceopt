# Reproducible CPU measurements

The native runner compiles a fixed `-O2` harness once, then separately compiles
kernel objects for each variant and links each to that harness. No LTO crosses
the boundary. Timed work includes each kernel's checksum reduction and indirect
call overhead; it excludes allocation, process launch, warmup and teardown.
Inputs use deterministic SplitMix64 initialization. Kernels recompute their
outputs each repetition so repeated runs do not accumulate floating-point drift.

| Kernel | Default size | Main opportunity |
|---|---:|---|
| saxpy | 262144 elements | Independent vector arithmetic and bandwidth |
| dot | 262144 elements | Strict ordered double accumulation |
| invariant | 262144 elements | Loop-invariant polynomial coefficient |
| redundant | 65536 elements | Repeated arithmetic and indexed accesses |
| stencil | 262144 elements | Neighboring affine memory accesses |
| matmul | 96 by 96 | Nested loops and strict float reduction |

Sizes are runtime inputs. `--size` overrides every workload; for matmul it means
matrix dimension, not element count. Large uniform size overrides are unsuitable
for matrix multiplication. Allocations check multiplication overflow.

## Run and report

With an LLVM 22 plugin already built:

```sh
python scripts/benchmark.py --llvm-bin /path/to/llvm/bin --plugin build/lib/GraceOpt.so --output results/latest.json
python scripts/report.py results/latest.json --markdown results/latest.md --csv results/latest.csv
```

The default experiment compares stock/plugin at `-O2` and `-O3`, takes 9 process
samples per variant, and measures each sample for approximately 50 ms. Calibration
uses the first selected variant to choose a common repetition count, capped at
1,000,000. Sample order is shuffled deterministically in each round. Each process
warms the workload before starting a monotonic timer. Checksums must match the
pilot within absolute `1e-7` plus relative `1e-9` tolerances; failure stops the run.
These tolerances are correctness gates, not a proof of semantic equivalence.

Kernel compilation gets one unmeasured warmup followed by 3 measured invocations.
Compile time includes the compiler process and backend but excludes linking and
harness compilation. Build order is fixed; compiler times can still be affected
by cache/OS drift and are descriptive. Binary size means total executable file
bytes; object file bytes are also recorded, not just `.text` bytes.

To isolate passes and disable vectorization for a scalar control:

```sh
python scripts/benchmark.py --variants stock grace licm rce vec stock-o3 grace-o3 stock-scalar grace-scalar --samples 15 --compile-repeats 5
```

Run on an idle native CPU. On Linux, `--cpu=N` pins the runner and child processes
to one logical CPU (choose one allowed by the host's affinity mask). Record CPU
frequency governor, thermal state and NUMA placement externally when they matter;
the runner does not change them. Windows affinity is not currently controlled.
Run multiple fresh experiments before interpreting small differences.

Results include raw per-round durations/checksums, launch order, measured compile
times, commands, file sizes, host/compiler information, source/plugin SHA256,
Git revision and dirty status. Failed partial experiments have `complete=false`
and are rejected by the report generator. Raw JSON is the source of truth;
Markdown and CSV are derived summaries. Existing files at the output path are
replaced, so choose distinct filenames to retain experiments.

The report uses the median of paired stock/plugin timing ratios. Its 95% interval
is a seeded paired bootstrap over rounds, not a hardware performance guarantee.
An interval crossing 1 is inconclusive. Short or noisy experiments and correlated
thermal drift can make bootstrap intervals optimistic; confidence must come from
repeat experiments as well. Intervals are per comparison without a multiple-testing
correction. The report includes median timings, coefficient of
variation in CSV, executable size delta and median compile-time delta.

## Grace / AArch64

Build the plugin on the Grace machine with its own LLVM 22 installation. Then use
native flags and pin to an allowed CPU, for example:

```sh
python scripts/benchmark.py --cflag=-mcpu=neoverse-v2 --cflag=-msve-vector-bits=128 --cpu=0 --samples=15 --target-seconds=.2 --output results/grace.json
```

Cross-compiled assembly does not supply runtime measurements. A freestanding
kernel file allows the codegen inspector to work without an AArch64 sysroot:

```sh
python scripts/inspect_codegen.py --prefer-scalable
python scripts/inspect_codegen.py --profiles grace-sve128 --levels O2 --pipelines all none licm rce vec-hints --prefer-scalable --output bench/out/ablations
```

It compares generic NEON, V2 without SVE, V2 fixed-128-bit SVE and V2 scalable SVE
at `-O2`/`-O3`. It saves `.s`, `.ll`, optimization remarks and a command/hash
manifest. Instruction/NEON/SVE line counts are descriptive syntax counts, not
cycle estimates. Freestanding kernels omit the runtime harness and checksum,
so their assembly is an inspection aid rather than the exact timed executable.
Run `python scripts/inspect_native.py` to save native kernel disassembly and
normalized hashes. `llvm-objdump -d bench/out/native/<kernel>-<variant>` inspects
the full native executable.

## Investigating regressions

1. Check raw dispersion, checksum and repeated measurements.
2. Compare `licm`, `rce`, `vec` and a loaded-but-disabled codegen `none` control.
3. Read emitted optimization remarks; compare IR and assembly for the changed loop.
4. Look for larger tails, extra spill/reload pairs, additional branches or lost FMAs.
5. Re-measure on Grace before assigning an AArch64 runtime benefit or regression.

The initial experiment and codegen evidence are recorded under `results/recorded`.
The project does not impose noisy timing thresholds in CI; CI checks correctness,
pass regression tests and cross-target compilation instead.
