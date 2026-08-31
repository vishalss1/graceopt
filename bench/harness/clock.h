#ifndef GRACEOPT_CLOCK_H
#define GRACEOPT_CLOCK_H
#include <stdio.h>
#include <stdlib.h>
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
static double bench_seconds(void) {
  LARGE_INTEGER frequency, ticks;
  if (!QueryPerformanceFrequency(&frequency) || !QueryPerformanceCounter(&ticks)) {
    fputs("performance counter failed\n", stderr); exit(2);
  }
  return (double)ticks.QuadPart / (double)frequency.QuadPart;
}
#else
#include <time.h>
static double bench_seconds(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts)) { perror("clock_gettime"); exit(2); }
  return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}
#endif
#endif
