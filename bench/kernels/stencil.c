#include "../harness/data.h"
static double run(void) {
  c[0] = a[0];
  if (count > 1) c[count - 1] = a[count - 1];
  for (size_t i = 1; i + 1 < count; ++i)
    c[i] = 0.25f * a[i - 1] + 0.5f * a[i] + 0.25f * a[i + 1];
  return checksum();
}
const bench_kernel BENCH_KERNEL = {"stencil", 262144, init_arrays, run, free_arrays};
