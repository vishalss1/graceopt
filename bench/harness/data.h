#ifndef GRACEOPT_DATA_H
#define GRACEOPT_DATA_H
#include "bench.h"
#include <stdio.h>
#include <stdlib.h>
static size_t count;
static float *a, *b, *c;
static void *bench_alloc(size_t n, size_t element_size) {
  if (!n || n > SIZE_MAX / element_size) {
    fputs("allocation size overflow\n", stderr); exit(2);
  }
  void *p = malloc(n * element_size);
  if (!p) { fputs("allocation failed\n", stderr); exit(2); }
  return p;
}
static void init_arrays(size_t n) {
  count = n;
  a = bench_alloc(n, sizeof(*a)); b = bench_alloc(n, sizeof(*b));
  c = bench_alloc(n, sizeof(*c));
  uint64_t state = 42;
  for (size_t i = 0; i < n; ++i) {
    a[i] = bench_randf(&state); b[i] = bench_randf(&state); c[i] = 0;
  }
}
static void free_arrays(void) { free(a); free(b); free(c); }
static double checksum(void) {
  double sum = 0;
  for (size_t i = 0; i < count; ++i) sum += c[i];
  return sum;
}
#endif
