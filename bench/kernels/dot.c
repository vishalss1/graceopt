#include "../harness/data.h"
static double run(void) {
  double sum = 0;
  for (size_t i = 0; i < count; ++i) sum += (double)a[i] * b[i];
  return sum;
}
const bench_kernel BENCH_KERNEL = {"dot", 262144, init_arrays, run, free_arrays};
