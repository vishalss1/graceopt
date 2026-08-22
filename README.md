# GraceOpt

An out-of-tree LLVM optimization pass plugin and benchmarking framework.

GraceOpt analyzes C/C++ programs at the LLVM IR level, identifies loop
optimization opportunities, transforms the IR, and measures whether the
resulting machine code runs faster than what stock Clang produces. The
CPU-specific work targets ARM64/AArch64, the architecture of NVIDIA Grace.
