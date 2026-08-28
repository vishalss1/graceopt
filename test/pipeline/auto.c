// RUN: %clang -O2 --target=aarch64-linux-gnu -mcpu=neoverse-v2 -c -o %t.o -Rpass=grace-vec-hints %s 2>&1 | FileCheck %s --check-prefix=REMARK
// RUN: %clang -O2 --target=aarch64-linux-gnu -mcpu=neoverse-v2 -c -o %t.o -Rpass=grace-vec-hints -mllvm -grace-pipeline=none %s 2>&1 | FileCheck %s --check-prefix=NONE --allow-empty
// RUN: %clang -O2 --target=aarch64-linux-gnu -mcpu=neoverse-v2 -fno-vectorize -fno-unroll-loops -S -emit-llvm -o - %s | FileCheck %s --check-prefix=V2
// RUN: %clang -O2 --target=aarch64-linux-gnu -mcpu=neoverse-v2 -fno-vectorize -fno-unroll-loops -S -emit-llvm -o - -mllvm -grace-pipeline=licm,rce %s | FileCheck %s --check-prefix=NOHINT
// RUN: %clang -O1 -c -o %t.o -Rpass=grace-licm -Rpass=grace-rce %s 2>&1 | FileCheck %s --check-prefix=SCALAR --allow-empty
//
// End to end: loading the plugin into clang runs the passes automatically at
// the configured extension points. The hint pass reports the candidate loop
// with the Neoverse V2 interleave factor; with vectorization and unrolling
// disabled the metadata it attaches survives to the output.

extern float opaque_scale(void) __attribute__((const));

void kernel(float *restrict y, const float *restrict x, float a, float b, int n) {
  for (int i = 0; i < n; i++)
    y[i] = (a * b) * x[i] + opaque_scale();
}

// REMARK: remark: vectorization candidate; requested interleave count 4 for cpu neoverse-v2 [-Rpass=grace-vec-hints]
// NONE-NOT: remark

// V2: !{!"llvm.loop.interleave.count", i32 4}
// NOHINT-NOT: llvm.loop.interleave.count

// Stock -O1 already hoists a*b and dedupes the index math, so the scalar
// passes should find nothing left to do here. This guards against the passes
// "optimizing" IR that is already optimal.
// SCALAR-NOT: remark
