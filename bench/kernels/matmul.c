#include "../harness/data.h"
static size_t dimension;
static void setup(size_t n) {
  if (n > SIZE_MAX / n) { fputs("matrix dimension overflow\n", stderr); exit(2); }
  dimension = n; init_arrays(n * n);
}
static double run(void) {
  size_t n = dimension;
  for (size_t i = 0; i < n; ++i)
    for (size_t j = 0; j < n; ++j) {
      float sum = 0;
      for (size_t k = 0; k < n; ++k) sum += a[i * n + k] * b[k * n + j];
      c[i * n + j] = sum;
    }
  return checksum();
}
const bench_kernel BENCH_KERNEL = {"matmul", 96, setup, run, free_arrays};
