"""Workload registry and comparable compiler configurations."""
from dataclasses import dataclass
from toolchain import REPO_ROOT

KERNELS = {"saxpy": 262144, "dot": 262144, "invariant": 262144,
           "redundant": 65536, "stencil": 262144, "matmul": 96}

@dataclass(frozen=True)
class Variant:
    name: str
    flags: tuple[str, ...]
    pipeline: str | None = None

VARIANTS = {v.name: v for v in (
    Variant("stock", ("-O2",)),
    Variant("grace", ("-O2",), "all"),
    Variant("licm", ("-O2",), "licm"),
    Variant("rce", ("-O2",), "rce"),
    Variant("vec", ("-O2",), "vec-hints"),
    Variant("stock-o3", ("-O3",)),
    Variant("grace-o3", ("-O3",), "all"),
    Variant("stock-scalar", ("-O2", "-fno-vectorize", "-fno-slp-vectorize")),
    Variant("grace-scalar", ("-O2", "-fno-vectorize", "-fno-slp-vectorize"), "licm,rce"),
)}
PAIRS = (("stock", "grace"), ("stock", "licm"), ("stock", "rce"),
         ("stock", "vec"), ("stock-o3", "grace-o3"),
         ("stock-scalar", "grace-scalar"))

def kernel_source(name):
    if name not in KERNELS:
        raise ValueError(f"unknown workload: {name}")
    return REPO_ROOT / "bench" / "kernels" / f"{name}.c"
