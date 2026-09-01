#include "../harness/data.h"
static double run(void) {
  for (size_t i = 0; i < count; ++i) {
    size_t k = (i * 17 + 3) % count;
    float left = a[k] * b[k] + a[i];
    float right = b[k] * a[k] + b[i];
    c[i] = left * right;
  }
  return checksum();
}
const bench_kernel BENCH_KERNEL = {"redundant", 65536, init_arrays, run, free_arrays};
