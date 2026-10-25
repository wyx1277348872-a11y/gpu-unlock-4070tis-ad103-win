# SPDX-License-Identifier: GPL-2.0-only
"""GEMM throughput + numeric fingerprint for the RTX 4090 unlock A/B test.

Usage:  python bench_gemm.py <label>      (label is e.g. pre or post)
Prints one JSON object at the end. Aborts if the GPU is busy so it does not
disturb other work. No files are written.
"""
import hashlib
import json
import subprocess
import sys
import time

import torch

LABEL = sys.argv[1] if len(sys.argv) > 1 else "run"
SIZES = (4096, 8192)
SECS = 2.0


def smi(fields):
    out = subprocess.run(
        ["nvidia-smi", "--query-gpu=" + fields, "--format=csv,noheader,nounits"],
        capture_output=True, text=True).stdout.strip()
    return [x.strip() for x in out.split(",")]


def bar1_total_mib():
    out = subprocess.run(["nvidia-smi", "-q", "-d", "MEMORY"], capture_output=True, text=True).stdout
    lines = out.splitlines()
    for i, line in enumerate(lines):
        if "BAR1 Memory Usage" in line:
            for nxt in lines[i + 1:i + 4]:
                if "Total" in nxt:
                    return nxt.split(":")[1].strip()
    return "unknown"


util = int(smi("utilization.gpu")[0])
if util > 30:
    print(json.dumps({"label": LABEL, "aborted": "GPU busy (%d%%)" % util}))
    sys.exit(2)

info = {
    "label": LABEL,
    "torch": torch.__version__,
    "cuda": torch.version.cuda,
    "driver": smi("driver_version")[0],
    "power_limit_w": smi("power.limit")[0],
    "bar1_total": bar1_total_mib(),
    "pcie_gen_max_width": smi("pcie.link.gen.max,pcie.link.width.max"),
}


def numeric_fingerprint():
    """Same inputs every run; the output bytes should be identical before/after."""
    torch.manual_seed(1234)
    n = 1024
    out = {}
    for name, dtype, tf32 in (("fp16", torch.float16, False), ("bf16", torch.bfloat16, False), ("tf32", torch.float32, True)):
        torch.backends.cuda.matmul.allow_tf32 = tf32
        torch.backends.cuda.matmul.allow_fp16_accumulation = False
        a = torch.randn(n, n, dtype=torch.float32).to(dtype).cuda()
        b = torch.randn(n, n, dtype=torch.float32).to(dtype).cuda()
        c = (a @ b).float().cpu()
        ref = (a.float().cpu().double() @ b.float().cpu().double())
        err = (c.double() - ref).abs().max().item()
        out[name] = {"sha256": hashlib.sha256(c.numpy().tobytes()).hexdigest()[:16], "max_abs_err_vs_fp64": round(err, 5)}
    return out


def bench(dtype, n, f16acc=False, tf32=False):
    torch.backends.cuda.matmul.allow_tf32 = tf32
    torch.backends.cuda.matmul.allow_fp16_accumulation = f16acc
    a = torch.randn(n, n, device="cuda", dtype=dtype)
    b = torch.randn(n, n, device="cuda", dtype=dtype)
    t0 = time.time()
    while time.time() - t0 < 1.0:
        a @ b
    torch.cuda.synchronize()
    iters = 0
    t0 = time.time()
    while time.time() - t0 < SECS:
        for _ in range(5):
            a @ b
        torch.cuda.synchronize()
        iters += 5
    dt = time.time() - t0
    tflops = 2.0 * n ** 3 * iters / dt / 1e12
    clk, watt, temp = smi("clocks.sm,power.draw,temperature.gpu")
    del a, b
    torch.cuda.empty_cache()
    return {"tflops": round(tflops, 1), "sm_mhz": int(float(clk)), "watts": round(float(watt), 0), "temp_c": int(float(temp)),
            "tflops_per_ghz": round(tflops / (float(clk) / 1000.0), 1)}


info["numeric"] = numeric_fingerprint()
res = {}
for n in SIZES:
    res["fp16_f32acc_%d" % n] = bench(torch.float16, n)
    res["bf16_f32acc_%d" % n] = bench(torch.bfloat16, n)
    res["fp16_f16acc_%d" % n] = bench(torch.float16, n, f16acc=True)
    res["tf32_%d" % n] = bench(torch.float32, n, tf32=True)
    res["fp32_%d" % n] = bench(torch.float32, n)
info["results"] = res
info["ratio_f16acc_over_f32acc_per_ghz"] = {
    str(n): round(res["fp16_f16acc_%d" % n]["tflops_per_ghz"] / res["fp16_f32acc_%d" % n]["tflops_per_ghz"], 2) for n in SIZES}
print(json.dumps(info))
