/* Freestanding equivalents for cross-target IR/assembly; no target sysroot. */
typedef __SIZE_TYPE__ size_t;
void saxpy(float *restrict y, const float *restrict x, float a, size_t n) {
  for (size_t i = 0; i < n; ++i) y[i] = a * x[i] + y[i];
}
double dot(const float *restrict x, const float *restrict y, size_t n) {
  double sum = 0;
  for (size_t i = 0; i < n; ++i) sum += (double)x[i] * y[i];
  return sum;
}
void invariant(float *restrict out, const float *restrict x, float a, float b, size_t n) {
  for (size_t i = 0; i < n; ++i) out[i] = x[i] * ((a * a + b) / (a + 1.0f));
}
void stencil(float *restrict out, const float *restrict x, size_t n) {
  for (size_t i = 1; i + 1 < n; ++i)
    out[i] = 0.25f * x[i - 1] + 0.5f * x[i] + 0.25f * x[i + 1];
}
void matmul(float *restrict c, const float *restrict a, const float *restrict b, size_t n) {
  for (size_t i = 0; i < n; ++i)
    for (size_t j = 0; j < n; ++j) {
      float sum = 0;
      for (size_t k = 0; k < n; ++k) sum += a[i*n+k] * b[k*n+j];
      c[i*n+j] = sum;
    }
}
