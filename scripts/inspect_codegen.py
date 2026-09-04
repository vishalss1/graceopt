#!/usr/bin/env python3
"""Compare AArch64 compiler profiles; emit assembly, IR, remarks and a manifest."""
import argparse
import hashlib
import json
from pathlib import Path
import re
from bench_build import command
from toolchain import REPO_ROOT, add_toolchain_args, toolchain_from_args

PROFILES = {
    "generic-neon": ["-mcpu=generic", "-march=armv8-a+simd"],
    "grace-neon": ["-mcpu=neoverse-v2+nosve"],
    "grace-sve128": ["-mcpu=neoverse-v2", "-msve-vector-bits=128"],
    "grace-scalable": ["-mcpu=neoverse-v2", "-msve-vector-bits=scalable"],
}


def assembly_inventory(text):
    # Descriptive instruction-line counts, not a throughput or speedup model.
    lines = [line for line in text.splitlines() if re.match(r"^\s+[a-z][a-z0-9.]*\s", line)]
    return {"instruction_lines": len(lines),
            "sve_lines": sum(bool(re.search(r"\b(?:z\d+|p\d+)\.", line)) for line in lines),
            "neon_lines": sum(bool(re.search(r"\bv\d+\.", line)) for line in lines)}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    add_toolchain_args(ap)
    ap.add_argument("--profiles", nargs="+", choices=PROFILES, default=list(PROFILES))
    ap.add_argument("--levels", nargs="+", choices=["O2", "O3"], default=["O2", "O3"])
    ap.add_argument("--prefer-scalable", action="store_true")
    ap.add_argument("--output", type=Path, default=REPO_ROOT / "bench/out/aarch64")
    args = ap.parse_args()
    tc = toolchain_from_args(args)
    out = args.output.resolve(); out.mkdir(parents=True, exist_ok=True)
    source = REPO_ROOT / "bench/codegen/kernels.c"
    manifest = {"compiler": tc.version(), "target": "aarch64-unknown-linux-gnu",
                "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "plugin_sha256": hashlib.sha256(tc.plugin.read_bytes()).hexdigest(),
                "prefer_scalable": args.prefer_scalable, "artifacts": []}
    for profile in args.profiles:
        for level in args.levels:
            for variant in ("stock", "grace"):
                stem = f"{profile}-{level}-{variant}"
                flags = ["--target=aarch64-unknown-linux-gnu", "-ffreestanding", f"-{level}",
                         *PROFILES[profile], "-Rpass=grace-.*", "-Rpass=loop-vectorize",
                         "-Rpass-missed=loop-vectorize"]
                if variant == "grace":
                    flags += [f"-fpass-plugin={tc.plugin}"]
                    if args.prefer_scalable:
                        flags += ["-mllvm", "-grace-prefer-scalable"]
                assembly, ir = out / f"{stem}.s", out / f"{stem}.ll"
                asm_cmd = [tc.clang, *flags, "-S", source, "-o", assembly]
                elapsed, proc = command(asm_cmd)
                (out / f"{stem}.remarks.txt").write_text(proc.stderr, encoding="utf-8")
                ir_cmd = [tc.clang, *flags, "-S", "-emit-llvm", source, "-o", ir]
                command(ir_cmd)
                manifest["artifacts"].append({"profile": profile, "level": level,
                    "variant": variant, "assembly": str(assembly), "ir": str(ir),
                    "assembly_sha256": hashlib.sha256(assembly.read_bytes()).hexdigest(),
                    "assembly_bytes": assembly.stat().st_size, "compile_seconds": elapsed,
                    "commands": [list(map(str, asm_cmd)), list(map(str, ir_cmd))],
                    **assembly_inventory(assembly.read_text(encoding="utf-8"))})
                print(stem, flush=True)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"saved {out / 'manifest.json'}")


if __name__ == "__main__":
    main()
