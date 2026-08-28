#!/usr/bin/env python3
"""Minimal lit-style test runner for GraceOpt.

Each `.ll` (or `.c`) file under test/ may contain one or more `; RUN:`
(`// RUN:`) lines. A RUN line is a shell command with these substitutions:

  %s        path of the test file
  %t        a per-test temporary file path
  %opt      opt with the GraceOpt plugin loaded
  %clang    clang with the GraceOpt plugin loaded via -fpass-plugin
  %plugin   path of the plugin library
  FileCheck resolved to the LLVM FileCheck binary

RUN lines ending in a backslash continue on the next line. All RUN lines of a
test must exit 0 for the test to pass. Keep RUN lines shell-neutral (double
quotes only) so they work under both sh and cmd.exe.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
from toolchain import add_toolchain_args, toolchain_from_args  # noqa: E402

TEST_DIR = Path(__file__).resolve().parent
RUN_RE = re.compile(r"^(?:;|//)\s*RUN:\s*(.*)$")


def collect_run_lines(path: Path) -> list[str]:
    lines: list[str] = []
    pending = ""
    for raw in path.read_text(encoding="utf-8").splitlines():
        m = RUN_RE.match(raw.strip())
        if not m:
            continue
        cmd = m.group(1).rstrip()
        if cmd.endswith("\\"):
            pending += cmd[:-1] + " "
            continue
        lines.append((pending + cmd).strip())
        pending = ""
    return lines


def run_test(path: Path, tc, tmpdir: Path, verbose: bool) -> tuple[bool, str]:
    runs = collect_run_lines(path)
    if not runs:
        return False, "no RUN lines"
    subs = {
        "%opt": f'"{tc.opt}" -load-pass-plugin="{tc.plugin}"',
        "%clang": f'"{tc.clang}" -fpass-plugin="{tc.plugin}"',
        "%plugin": str(tc.plugin),
        "%s": str(path),
        "%t": str(tmpdir / (path.stem + ".tmp")),
    }
    log = []
    for cmd in runs:
        for k, v in subs.items():
            cmd = cmd.replace(k, v)
        cmd = re.sub(r"(?<![\w/\\])FileCheck(?![\w])", f'"{tc.filecheck}"', cmd)
        if verbose:
            log.append(f"$ {cmd}")
        proc = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if proc.returncode != 0:
            log.append(f"$ {cmd}")
            log.append(f"exit code {proc.returncode}")
            if proc.stdout:
                log.append(proc.stdout)
            if proc.stderr:
                log.append(proc.stderr)
            return False, "\n".join(log)
    return True, "\n".join(log)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    add_toolchain_args(ap)
    ap.add_argument("-v", "--verbose", action="store_true")
    ap.add_argument("filter", nargs="?", help="only run tests whose path contains this")
    args = ap.parse_args()
    tc = toolchain_from_args(args)

    tests = sorted(p for p in TEST_DIR.rglob("*") if p.suffix in (".ll", ".c"))
    if args.filter:
        tests = [t for t in tests if args.filter in str(t)]
    if not tests:
        print("no tests found")
        return 1

    failures = 0
    with tempfile.TemporaryDirectory(prefix="graceopt-test-") as td:
        for t in tests:
            ok, log = run_test(t, tc, Path(td), args.verbose)
            rel = t.relative_to(TEST_DIR).as_posix()
            print(f"{'PASS' if ok else 'FAIL'}: {rel}")
            if not ok or args.verbose:
                for line in log.splitlines():
                    print("    " + line)
            failures += 0 if ok else 1

    total = len(tests)
    print(f"\n{total - failures}/{total} tests passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
