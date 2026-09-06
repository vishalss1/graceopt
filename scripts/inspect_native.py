#!/usr/bin/env python3
"""Save kernel object disassembly and hashes to diagnose timing differences."""
import argparse
import hashlib
import json
from pathlib import Path
from bench_build import command
from toolchain import REPO_ROOT, add_toolchain_args, toolchain_from_args
from workloads import KERNELS, VARIANTS


def normalized_disassembly(text):
    return "\n".join(line for line in text.splitlines()
                     if line.strip() and "file format" not in line)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    add_toolchain_args(ap)
    ap.add_argument("--artifacts", type=Path, default=REPO_ROOT / "bench/out/native")
    ap.add_argument("--output", type=Path, default=REPO_ROOT / "bench/out/native-inspection")
    args = ap.parse_args()
    tc = toolchain_from_args(args)
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = {"method": "llvm-objdump -d on kernel objects; discard blank lines and file-format header",
                "compiler": tc.version(), "workloads": []}
    for kernel in KERNELS:
        variants = []
        for name in VARIANTS:
            obj = args.artifacts / f"{kernel}-{name}.o"
            if not obj.exists():
                continue
            argv = [tc.tool("llvm-objdump"), "-d", obj]
            _, proc = command(argv)
            normalized = normalized_disassembly(proc.stdout)
            (args.output / f"{kernel}-{name}.txt").write_text(proc.stdout, encoding="utf-8")
            variants.append({"name": name, "object_sha256": hashlib.sha256(obj.read_bytes()).hexdigest(),
                             "disassembly_sha256": hashlib.sha256(normalized.encode()).hexdigest(),
                             "command": list(map(str, argv))})
        if variants:
            manifest["workloads"].append({"kernel": kernel, "variants": variants})
    if not manifest["workloads"]:
        ap.error("no benchmark objects found; run benchmark.py first")
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"saved {args.output / 'manifest.json'}")


if __name__ == "__main__":
    main()
