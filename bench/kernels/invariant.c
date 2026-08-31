#include "../harness/data.h"
static float scale, bias;
static void setup(size_t n) { init_arrays(n); scale = a[0] + 0.75f; bias = b[0]; }
static double run(void) {
  for (size_t i = 0; i < count; ++i)
    c[i] = a[i] * ((scale * scale + bias) / (scale + 1.0f)) + bias * bias;
  return checksum();
}
const bench_kernel BENCH_KERNEL = {"invariant", 262144, setup, run, free_arrays};
