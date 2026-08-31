#include "../harness/data.h"
static double run(void) {
  float *restrict out = c;
  const float *restrict x = a, *restrict y = b;
  for (size_t i = 0; i < count; ++i) out[i] = 1.25f * x[i] + y[i];
  return checksum();
}
const bench_kernel BENCH_KERNEL = {"saxpy", 262144, init_arrays, run, free_arrays};
