#!/usr/bin/env python3
"""Benchmark stock Clang against GraceOpt on the native CPU."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
from bench_build import build_harness, build_variant
from bench_sample import collect
from toolchain import REPO_ROOT, add_toolchain_args, toolchain_from_args
from workloads import KERNELS, VARIANTS


def positive(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def git_output(*args):
    return subprocess.run(["git", *args], cwd=REPO_ROOT, capture_output=True,
                          text=True, check=True).stdout.strip()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    add_toolchain_args(ap)
    ap.add_argument("--kernels", nargs="+", choices=KERNELS, default=list(KERNELS))
    ap.add_argument("--variants", nargs="+", choices=VARIANTS,
                    default=["stock", "grace", "stock-o3", "grace-o3"])
    ap.add_argument("--samples", type=positive, default=9)
    ap.add_argument("--compile-repeats", type=positive, default=3)
    ap.add_argument("--size", type=positive, help="override every workload size (matmul: dimension)")
    ap.add_argument("--warmups", type=positive, default=2)
    ap.add_argument("--target-seconds", type=float, default=.05)
    ap.add_argument("--timeout", type=positive, default=120)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--cflag", action="append", default=[], help="shared kernel/harness flag; use --cflag=-mcpu=native")
    ap.add_argument("--cpu", type=int, help="pin to a Linux logical CPU")
    ap.add_argument("--output", type=Path, default=REPO_ROOT / "results/latest.json")
    ap.add_argument("--artifact-dir", type=Path, default=REPO_ROOT / "bench/out/native")
    args = ap.parse_args()
    if args.samples < 2 or not (0 < args.target_seconds <= 60):
        ap.error("need >=2 samples and target-seconds in (0, 60]")
    if len(set(args.variants)) != len(args.variants):
        ap.error("variants must be unique")
    if args.cpu is not None:
        if not hasattr(os, "sched_setaffinity"):
            ap.error("--cpu requires Linux sched_setaffinity")
        os.sched_setaffinity(0, {args.cpu})
    tc = toolchain_from_args(args)
    out = args.artifact_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    harness, harness_command = build_harness(tc, out, args.cflag)
    data = {"schema_version": 1, "created_utc": datetime.now(timezone.utc).isoformat(),
            "host": {"platform": platform.platform(), "machine": platform.machine(),
                     "processor": platform.processor(), "cpu_count": os.cpu_count(),
                     "cpu_affinity": sorted(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else None,
                     "processor_identifier": os.environ.get("PROCESSOR_IDENTIFIER")},
            "compiler": tc.version(), "plugin_sha256": sha256(tc.plugin),
            "git_revision": git_output("rev-parse", "HEAD"),
            "git_dirty": bool(git_output("status", "--porcelain")),
            "config": {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items()},
            "harness_command": harness_command,
            "source_sha256": {p.relative_to(REPO_ROOT).as_posix(): sha256(p)
                              for p in sorted((REPO_ROOT / "bench").rglob("*"))
                              if p.suffix in (".h", ".c") and "out" not in p.parts},
            "workloads": []}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    for kernel in args.kernels:
        print(f"building and sampling {kernel}", flush=True)
        builds = [build_variant(tc, kernel, VARIANTS[v], out, harness, args.cflag,
                                args.compile_repeats) for v in args.variants]
        measured = collect(builds, args.size or KERNELS[kernel], args.samples,
                           args.target_seconds, args.warmups, args.timeout, args.seed)
        data["workloads"].append({"name": kernel, "size": args.size or KERNELS[kernel],
                                  "builds": builds, **measured})
        # Keep completed workloads if a later command fails; complete marks usability.
        data["complete"] = False
        args.output.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    data["complete"] = True
    args.output.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"saved {args.output}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)
