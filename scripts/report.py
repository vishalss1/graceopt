#!/usr/bin/env python3
"""Generate Markdown and CSV comparisons from recorded raw samples."""
import argparse
import csv
import json
from pathlib import Path
import statistics
from bench_stats import compare, describe
from workloads import PAIRS


def rows(data):
    if data.get("schema_version") != 1 or not data.get("complete"):
        raise ValueError("report requires a complete schema version 1 experiment")
    for workload in data["workloads"]:
        builds = {b["name"]: b for b in workload["builds"]}
        for baseline, candidate in PAIRS:
            if baseline not in builds or candidate not in builds:
                continue
            a = [v["seconds"] for v in workload["samples"][baseline]]
            b = [v["seconds"] for v in workload["samples"][candidate]]
            comparison = compare(a, b)
            yield {"kernel": workload["name"], "baseline": baseline, "candidate": candidate,
                   "baseline_ms": describe(a)["median"] * 1000,
                   "candidate_ms": describe(b)["median"] * 1000,
                   "speedup": comparison["speedup"], "ci_low": comparison["ci95"][0],
                   "ci_high": comparison["ci95"][1], "verdict": comparison["verdict"],
                   "candidate_cv": describe(b)["cv"],
                   "binary_delta_percent": 100 * (builds[candidate]["binary_bytes"] / builds[baseline]["binary_bytes"] - 1),
                   "compile_delta_percent": 100 * (statistics.median(builds[candidate]["compile_seconds"]) /
                                                    statistics.median(builds[baseline]["compile_seconds"]) - 1)}


def markdown(data, records):
    lines = ["# GraceOpt benchmark report", "", f"Compiler: {data['compiler']}",
             f"Host: {data['host']['platform']} ({data['host']['machine']})",
             f"Revision: `{data['git_revision']}`; dirty: {data['git_dirty']}", "",
             "Speedup = paired stock time / plugin time. Intervals are a paired bootstrap of medians.",
             "Binary size is total executable bytes; compile cost excludes linking and harness compilation.", "",
             "| Workload | Comparison | Stock ms | Plugin ms | Speedup [95% interval] | Verdict | Size delta | Compile delta |",
             "|---|---|---:|---:|---|---|---:|---:|"]
    for r in records:
        lines.append(f"| {r['kernel']} | {r['baseline']} → {r['candidate']} | {r['baseline_ms']:.3f} | "
                     f"{r['candidate_ms']:.3f} | {r['speedup']:.3f} [{r['ci_low']:.3f}, {r['ci_high']:.3f}] | "
                     f"{r['verdict']} | {r['binary_delta_percent']:+.1f}% | {r['compile_delta_percent']:+.1f}% |")
    lines += ["", "## Interpretation", "",
              "Intervals crossing 1 are inconclusive. High dispersion, thermal drift, background load,",
              "cache state and process launch calibration can obscure small changes; rerun pinned on an idle host.",
              "Stock LLVM already performs LICM and CSE, so these late scalar passes often add compile cost",
              "without changing machine code. Interleave hints can increase register pressure or code size.",
              "Inspect assembly and per-pass ablations before attributing a regression to a specific transform.",
              "Checksums passed the recorded tolerance; they detect many errors but are not a proof of equivalence.",
              "These are measurements on the recorded native host, not inferred NVIDIA Grace timings.", ""]
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", type=Path)
    ap.add_argument("--markdown", type=Path)
    ap.add_argument("--csv", type=Path)
    args = ap.parse_args()
    data = json.loads(args.input.read_text(encoding="utf-8"))
    records = list(rows(data))
    text = markdown(data, records)
    if args.markdown:
        args.markdown.parent.mkdir(parents=True, exist_ok=True)
        args.markdown.write_text(text, encoding="utf-8")
    else:
        print(text)
    if args.csv and records:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        with args.csv.open("w", newline="", encoding="utf-8") as file:
            writer = csv.DictWriter(file, fieldnames=records[0])
            writer.writeheader(); writer.writerows(records)


if __name__ == "__main__":
    main()
