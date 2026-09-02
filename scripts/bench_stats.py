"""Descriptive statistics and reproducible paired bootstrap estimates."""
import math
import random
import statistics


def describe(values):
    if not values or any(not math.isfinite(v) or v <= 0 for v in values):
        raise ValueError("measurements must be finite and positive")
    median = statistics.median(values)
    return {"median": median, "min": min(values), "max": max(values),
            "mad": statistics.median(abs(v - median) for v in values),
            "cv": statistics.stdev(values) / statistics.mean(values) if len(values) > 1 else 0,
            "count": len(values)}


def compare(baseline, candidate, seed=42, resamples=2000):
    if len(baseline) != len(candidate) or len(baseline) < 2:
        raise ValueError("at least two paired samples are required")
    describe(baseline); describe(candidate)
    ratios = [a / b for a, b in zip(baseline, candidate)]
    rng = random.Random(seed)
    boot = sorted(statistics.median(rng.choices(ratios, k=len(ratios)))
                  for _ in range(resamples))
    low, high = boot[int(.025 * resamples)], boot[min(resamples - 1, int(.975 * resamples))]
    return {"speedup": statistics.median(ratios), "ci95": [low, high],
            "verdict": "faster" if low > 1 else "slower" if high < 1 else "inconclusive"}
