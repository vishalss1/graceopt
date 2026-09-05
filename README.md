# GraceOpt

A C++17 LLVM 22 optimization pass plugin and CPU benchmarking framework.
GraceOpt analyzes natural loops, hoists loop-invariant computations, eliminates
redundant expressions and simple loads, and explores vectorization hints for
AArch64 / NVIDIA Grace. Its benchmarks compare actual native execution against
stock Clang and report runtime uncertainty, executable size and compilation cost.

## Build and verify

Install a matching LLVM 22 development distribution containing Clang, opt,
FileCheck, LLVM headers/libraries and `LLVMConfig.cmake`, plus CMake 3.20+, Ninja
and Python 3.10+. All tools and the plugin must use the same LLVM installation.

```sh
cmake -S . -B build -G Ninja -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_DIR="$(llvm-config --cmakedir)"
cmake --build build
cmake --build build --target check
ctest --test-dir build --output-on-failure
```

Locally verified with MSYS2 UCRT64 LLVM/Clang 22.1.4 on Windows x86-64. Linux
builds use the same CMake project but have not been executed in this environment.
On Windows use the UCRT64 toolchain paths and `GraceOpt.dll`; on Linux the plugin
is `GraceOpt.so`. The default plugin path is `build/lib/GraceOpt` plus the platform
suffix; multi-configuration Release/Debug directories are also discovered.
`GRACEOPT_LLVM_BIN` or `--llvm-bin` selects tools explicitly. Windows builds
require LLVM's shared library; the MSYS2 distribution used here supplies it.

## Analyze and transform IR

```sh
clang -O0 -Xclang -disable-O0-optnone -S -emit-llvm input.c -o input.ll
opt -load-pass-plugin=build/lib/GraceOpt.so -passes='mem2reg,loop-simplify,print<grace-loop-analysis>' -disable-output input.ll
opt -load-pass-plugin=build/lib/GraceOpt.so -passes='mem2reg,grace-licm,grace-rce,grace-vec-hints' -verify-each -S input.ll -o optimized.ll
clang -O2 -fpass-plugin=build/lib/GraceOpt.so input.c -o optimized
```

Clang injects scalar passes late in its scalar pipeline and hints immediately
before vectorization. Use `-mllvm -grace-pipeline=licm,rce` to isolate scalar
passes or `-mllvm -grace-pipeline=none` for a loaded-but-disabled control.
Reassociation is opt-in and off by default; user vectorization metadata wins.
See [pass design](docs/passes.md) for legality rules and configuration options.

## Benchmark and inspect AArch64

```sh
python scripts/benchmark.py --variants stock grace stock-o3 grace-o3
python scripts/report.py results/latest.json --markdown results/latest.md --csv results/latest.csv
python scripts/inspect_codegen.py --prefer-scalable
```

Six deterministic C workloads cover SAXPY, dot products, invariants, redundant
index math, stencils and dense matrix multiplication. The runner uses a shared
harness, warmup, shuffled paired samples and checksum checks. Raw results retain
commands, hashes and environment information. Individual-pass and scalar control
variants are available. [Methodology and Grace commands](docs/benchmarking.md)
explain sizes, uncertainty, measurement boundaries and regression analysis.

[Recorded findings](results/README.md) include native Windows measurements and
AArch64 assembly comparisons. Cross-generated AArch64 code has not been timed
on Grace hardware. Stock LLVM already performs strong scalar optimization;
GraceOpt does not assume a custom pass improves every workload.

## Repository layout

- `lib/`, `include/graceopt/`: C++ plugin, passes and shared legality helpers.
- `test/`: FileCheck IR regressions, Clang pipeline checks and Python integrity tests.
- `bench/harness/`, `bench/kernels/`: portable C harness and native workloads.
- `bench/codegen/`: freestanding cross-target inspection kernels.
- `scripts/`: toolchain resolution, experiment automation, statistics and reports.
- `results/recorded/`: measured evidence; `bench/out/` holds generated local artifacts.
- `.github/workflows/ci.yml`: Windows LLVM build and correctness workflow.

Python scripts use only the standard library. See [LICENSE](LICENSE).
