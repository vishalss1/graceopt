# GraceOpt benchmark report

Compiler: clang version 22.1.4 (https://github.com/msys2/MINGW-packages 42681e05ad3617c25e48a935a48eddc72a3ac7e2)
Host: Windows-11-10.0.26300-SP0 (AMD64)
Revision: `58de8dd61d4242d9d2dd9b23fa748d81bbf87c5f`; dirty: False

Speedup = paired stock time / plugin time. Intervals are a paired bootstrap of medians.
Binary size is total executable bytes; compile cost excludes linking and harness compilation.

| Workload | Comparison | Stock ms | Plugin ms | Speedup [95% interval] | Verdict | Size delta | Compile delta |
|---|---|---:|---:|---|---|---:|---:|
| saxpy | stock → grace | 0.389 | 0.385 | 1.005 [0.981, 1.029] | inconclusive | +0.0% | +11.8% |
| saxpy | stock-o3 → grace-o3 | 0.381 | 0.391 | 0.983 [0.965, 0.993] | slower | +0.0% | -0.4% |
| dot | stock → grace | 0.328 | 0.327 | 1.007 [0.979, 1.015] | inconclusive | +0.0% | -3.1% |
| dot | stock-o3 → grace-o3 | 0.331 | 0.327 | 1.003 [0.993, 1.017] | inconclusive | +0.0% | +2.6% |
| invariant | stock → grace | 0.364 | 0.365 | 0.998 [0.988, 1.033] | inconclusive | +0.0% | -7.4% |
| invariant | stock-o3 → grace-o3 | 0.363 | 0.361 | 1.008 [0.995, 1.018] | inconclusive | +0.0% | -2.2% |
| redundant | stock → grace | 0.254 | 0.254 | 1.004 [0.988, 1.025] | inconclusive | +0.0% | -9.3% |
| redundant | stock-o3 → grace-o3 | 0.256 | 0.259 | 1.006 [0.978, 1.022] | inconclusive | +0.0% | +8.6% |
| stencil | stock → grace | 0.406 | 0.405 | 1.020 [0.958, 1.054] | inconclusive | +0.0% | -8.1% |
| stencil | stock-o3 → grace-o3 | 0.399 | 0.401 | 0.997 [0.978, 1.006] | inconclusive | +0.0% | +12.4% |
| matmul | stock → grace | 0.789 | 0.731 | 1.026 [0.976, 1.121] | inconclusive | +0.0% | -4.0% |
| matmul | stock-o3 → grace-o3 | 0.764 | 0.749 | 1.010 [0.987, 1.064] | inconclusive | +0.0% | +4.7% |

## Interpretation

Intervals crossing 1 are inconclusive. High dispersion, thermal drift, background load,
cache state and process launch calibration can obscure small changes; rerun pinned on an idle host.
Stock LLVM already performs LICM and CSE, so these late scalar passes often add compile cost
without changing machine code. Interleave hints can increase register pressure or code size.
Inspect assembly and per-pass ablations before attributing a regression to a specific transform.
Checksums passed the recorded tolerance; they detect many errors but are not a proof of equivalence.
Intervals are per comparison and are not corrected for multiple comparisons; nominal wins need replication.
Compare native object disassembly before attributing small timing differences to generated code.
These are measurements on the recorded native host, not inferred NVIDIA Grace timings.
