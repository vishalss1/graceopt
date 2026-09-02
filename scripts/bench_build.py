"""Build only kernel objects with variant flags; share the fixed harness."""
import os
import subprocess
import time
from pathlib import Path
from toolchain import REPO_ROOT
from workloads import kernel_source


def command(argv, timeout=120):
    start = time.perf_counter()
    proc = subprocess.run(list(map(str, argv)), capture_output=True, text=True,
                          timeout=timeout)
    elapsed = time.perf_counter() - start
    if proc.returncode:
        raise RuntimeError(f"command failed ({proc.returncode}): {argv}\n{proc.stderr}")
    return elapsed, proc


def build_harness(tc, output, extra_flags):
    obj = output / "harness.o"
    argv = [tc.clang, "-std=c11", "-O2", *extra_flags, "-c",
            REPO_ROOT / "bench/harness/main.c", "-o", obj]
    command(argv)
    return obj, list(map(str, argv))


def build_variant(tc, kernel, variant, output, harness, extra_flags, repeats):
    obj = output / f"{kernel}-{variant.name}.o"
    exe = output / (f"{kernel}-{variant.name}" + (".exe" if os.name == "nt" else ""))
    flags = [*variant.flags, *extra_flags]
    if variant.pipeline is not None:
        flags += [f"-fpass-plugin={tc.plugin}", "-mllvm",
                  f"-grace-pipeline={variant.pipeline}"]
    argv = [tc.clang, "-std=c11", *flags, "-c", kernel_source(kernel), "-o", obj]
    times = [command(argv)[0] for _ in range(repeats)]
    link = [tc.clang, harness, obj, "-o", exe]
    if os.name != "nt":
        link.append("-lm")
    link_time, _ = command(link)
    return {"name": variant.name, "compile_seconds": times,
            "link_seconds": link_time, "binary_bytes": exe.stat().st_size,
            "object_bytes": obj.stat().st_size, "executable": str(exe),
            "compile_command": list(map(str, argv)), "link_command": list(map(str, link))}
