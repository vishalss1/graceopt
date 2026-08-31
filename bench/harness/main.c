#define _POSIX_C_SOURCE 200809L
#include "bench.h"
#include "clock.h"
#include <errno.h>
#include <inttypes.h>
#include <math.h>
#include <stdlib.h>

static size_t parse_positive(const char *s) {
  char *end;
  errno = 0;
  uintmax_t value = strtoumax(s, &end, 10);
  if (*s < '0' || *s > '9' || *end || errno || !value || value > SIZE_MAX) {
    fputs("arguments must be positive integers\n", stderr); exit(2);
  }
  return (size_t)value;
}

int main(int argc, char **argv) {
  if (argc > 4) { fputs("usage: benchmark [size [repetitions [warmups]]]\n", stderr); return 2; }
  size_t n = argc > 1 ? parse_positive(argv[1]) : BENCH_KERNEL.default_n;
  size_t reps = argc > 2 ? parse_positive(argv[2]) : 10;
  size_t warmups = argc > 3 ? parse_positive(argv[3]) : 2;
  BENCH_KERNEL.setup(n);
  volatile double sink = 0;
  for (size_t i = 0; i < warmups; ++i) sink = BENCH_KERNEL.run();
  double start = bench_seconds();
  for (size_t i = 0; i < reps; ++i) sink = BENCH_KERNEL.run();
  double elapsed = bench_seconds() - start;
  double checksum = sink;
  BENCH_KERNEL.teardown();
  if (!isfinite(checksum) || !isfinite(elapsed) || elapsed <= 0) {
    fputs("invalid checksum or timer measurement\n", stderr); return 3;
  }
  printf("{\"kernel\":\"%s\",\"size\":%zu,\"repetitions\":%zu,"
         "\"seconds\":%.17g,\"checksum\":%.17g}\n",
         BENCH_KERNEL.name, n, reps, elapsed / (double)reps, checksum);
  return 0;
}
