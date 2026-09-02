"""Locate the LLVM toolchain and the GraceOpt plugin.

Resolution order for LLVM binaries:
  1. --llvm-bin command line argument (callers pass it through)
  2. GRACEOPT_LLVM_BIN environment variable
  3. `llvm-config --bindir`
  4. whatever `clang` is on PATH
"""

from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

PLUGIN_SUFFIX = {
    "Windows": ".dll",
    "Darwin": ".dylib",
}.get(platform.system(), ".so")


@dataclass
class Toolchain:
    bindir: Path
    plugin: Path

    def tool(self, name: str) -> str:
        exe = self.bindir / (name + (".exe" if os.name == "nt" else ""))
        if exe.exists():
            return str(exe)
        raise FileNotFoundError(f"LLVM tool '{name}' not found in {self.bindir} ")

    @property
    def clang(self) -> str:
        return self.tool("clang")

    @property
    def opt(self) -> str:
        return self.tool("opt")

    @property
    def llc(self) -> str:
        return self.tool("llc")

    @property
    def filecheck(self) -> str:
        return self.tool("FileCheck")

    @property
    def mca(self) -> str:
        return self.tool("llvm-mca")

    def version(self) -> str:
        out = subprocess.run([self.clang, "--version"], capture_output=True, text=True, check=True)
        return out.stdout.splitlines()[0].strip()


def _llvm_config_bindir() -> Path | None:
    cfg = shutil.which("llvm-config")
    if not cfg:
        return None
    try:
        out = subprocess.run([cfg, "--bindir"], capture_output=True, text=True, check=True)
        return Path(out.stdout.strip())
    except (OSError, subprocess.CalledProcessError):
        return None


def find_toolchain(llvm_bin: str | None = None, plugin: str | None = None,
                   build_dir: str | None = None) -> Toolchain:
    candidates = [llvm_bin, os.environ.get("GRACEOPT_LLVM_BIN")]
    bindir: Path | None = None
    for c in candidates:
        if c:
            bindir = Path(c)
            break
    if bindir is None:
        bindir = _llvm_config_bindir()
    if bindir is None:
        clang = shutil.which("clang")
        if not clang:
            sys.exit("error: cannot find LLVM; set GRACEOPT_LLVM_BIN or pass --llvm-bin")
        bindir = Path(clang).resolve().parent

    if not bindir.is_dir():
        sys.exit(f"error: LLVM binary directory does not exist: {bindir}")
    if plugin:
        plugin_path = Path(plugin)
    else:
        bdir = Path(build_dir) if build_dir else REPO_ROOT / "build"
        plugin_path = bdir / "lib" / f"GraceOpt{PLUGIN_SUFFIX}"
        if not plugin_path.exists():
            # Multi-config generators (MSVC) nest a configuration directory.
            for cfg in ("Release", "RelWithDebInfo", "Debug"):
                alt = bdir / "lib" / cfg / f"GraceOpt{PLUGIN_SUFFIX}"
                if alt.exists():
                    plugin_path = alt
                    break
    if not plugin_path.exists():
        sys.exit(f"error: plugin not found at {plugin_path}; build the project first "
                 "or pass --plugin")
    return Toolchain(bindir=bindir.resolve(), plugin=plugin_path.resolve())


def add_toolchain_args(parser) -> None:
    """Register the standard --llvm-bin/--plugin/--build-dir options."""
    parser.add_argument("--llvm-bin", help="directory containing clang/opt/llc")
    parser.add_argument("--plugin", help="path to the GraceOpt plugin library")
    parser.add_argument("--build-dir", help="CMake build directory (default: build)")


def toolchain_from_args(args) -> Toolchain:
    return find_toolchain(args.llvm_bin, args.plugin, args.build_dir)
