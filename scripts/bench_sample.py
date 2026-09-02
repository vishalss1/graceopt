"""Calibrate and sample executable kernels with correctness gates."""
import json
import math
import random
from bench_build import command


def execute(executable, size, repetitions, warmups, timeout):
    _, proc = command([executable, size, repetitions, warmups], timeout)
    value = json.loads(proc.stdout)
    if (value["size"] != size or value["repetitions"] != repetitions or
            not math.isfinite(value["seconds"]) or value["seconds"] <= 0 or
            not math.isfinite(value["checksum"])):
        raise ValueError(f"invalid benchmark output: {proc.stdout}")
    return value


def collect(builds, size, samples, target_seconds, warmups, timeout, seed,
            relative_tolerance=1e-9, absolute_tolerance=1e-7):
    pilot = execute(builds[0]["executable"], size, 1, warmups, timeout)
    reps = max(1, min(1_000_000, math.ceil(target_seconds / pilot["seconds"])))
    rng = random.Random(seed)
    result = {b["name"]: [] for b in builds}
    order = []
    for round_index in range(samples):
        indices = list(range(len(builds)))
        rng.shuffle(indices)
        order.append([builds[i]["name"] for i in indices])
        for i in indices:
            build = builds[i]
            value = execute(build["executable"], size, reps, warmups, timeout)
            if not math.isclose(pilot["checksum"], value["checksum"],
                                rel_tol=relative_tolerance, abs_tol=absolute_tolerance):
                raise ValueError(f"checksum mismatch for {build['name']}: "
                                 f"{value['checksum']} vs {pilot['checksum']}")
            result[build["name"]].append(value)
    return {"repetitions": reps, "samples": result, "execution_order": order,
            "reference_checksum": pilot["checksum"],
            "tolerance": {"relative": relative_tolerance, "absolute": absolute_tolerance}}
