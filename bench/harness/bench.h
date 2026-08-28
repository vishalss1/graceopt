/*
 * GraceOpt benchmark kernel interface.
 *
 * Every kernel translation unit defines one `BENCH_KERNEL` describing how to
 * allocate its data, run one timed repetition and release it again. The
 * harness (main.c) is compiled once with fixed flags; only the kernel object
 * changes between benchmark variants, so measured differences come from the
 * kernel code alone.
 */
#ifndef GRACEOPT_BENCH_H
#define GRACEOPT_BENCH_H

#include <stddef.h>
#include <stdint.h>

typedef struct {
  const char *name;
  /* Problem size the kernel uses when the harness is not told otherwise. */
  size_t default_n;
  /* Allocate and deterministically initialise inputs for size n. */
  void (*setup)(size_t n);
  /* One timed repetition. Returns a checksum so variants can be compared. */
  double (*run)(void);
  void (*teardown)(void);
} bench_kernel;

extern const bench_kernel BENCH_KERNEL;

/* Small deterministic PRNG shared by the kernels (SplitMix64). */
static inline uint64_t bench_next(uint64_t *state) {
  uint64_t z = (*state += 0x9E3779B97F4A7C15ull);
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
  return z ^ (z >> 31);
}

/* Uniform float in [0, 1). */
static inline float bench_randf(uint64_t *state) {
  return (float)(bench_next(state) >> 40) * (1.0f / 16777216.0f);
}

#endif /* GRACEOPT_BENCH_H */
