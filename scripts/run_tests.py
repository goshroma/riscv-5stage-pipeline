import argparse
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

from asm import assemble, write_hex
from iss import ISS
from gen_random import gen

BUILD = os.path.join(ROOT, "build")
SIM = os.path.join(BUILD, "sim.vvp")


def compile_rtl():
    os.makedirs(BUILD, exist_ok=True)
    srcs = sorted(glob.glob(os.path.join(ROOT, "rtl", "*.v"))) + [os.path.join(ROOT, "tb", "tb_riscv.v")]
    cmd = ["iverilog", "-g2012", "-Wall", "-I", os.path.join(ROOT, "rtl"), "-o", SIM] + srcs
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(res.stdout + res.stderr)
        sys.exit(1)
    warnings = [l for l in (res.stdout + res.stderr).splitlines() if l.strip() and "timescale" not in l]
    for w in warnings:
        print("  warn:", w)


def run_one(name, src, vcd=False):
    words = assemble(src)
    hexf = os.path.join(BUILD, f"{name}.hex")
    rtl_dump = os.path.join(BUILD, f"{name}.rtl.txt")
    iss_dump = os.path.join(BUILD, f"{name}.iss.txt")
    write_hex(words, hexf)

    iss = ISS(words)
    if not iss.run():
        return name, "ISS-TIMEOUT", 0, 0, []
    with open(iss_dump, "w") as f:
        f.write(iss.dump())

    args = ["vvp", "-n", SIM, f"+hex={hexf}", f"+dump={rtl_dump}"]
    if vcd:
        args.append(f"+vcd={os.path.join(BUILD, name + '.vcd')}")
    res = subprocess.run(args, capture_output=True, text=True)
    m = re.search(r"RESULT HALT cycles=(\d+) retired=(\d+)", res.stdout)
    if not m:
        return name, "RTL-TIMEOUT", 0, 0, []
    cycles, retired = int(m.group(1)), int(m.group(2))

    with open(rtl_dump) as f:
        rtl = f.read().splitlines()
    with open(iss_dump) as f:
        ref = f.read().splitlines()
    diffs = [(r, g) for r, g in zip(rtl, ref) if r != g]
    if retired != iss.retired:
        diffs.append((f"retired {retired}", f"retired {iss.retired}"))
    return name, "PASS" if not diffs else "FAIL", cycles, retired, diffs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--random", type=int, default=50)
    ap.add_argument("--only", default=None)
    ap.add_argument("--vcd", action="store_true")
    args = ap.parse_args()

    compile_rtl()

    jobs = []
    for path in sorted(glob.glob(os.path.join(ROOT, "sw", "tests", "*.s"))):
        name = os.path.splitext(os.path.basename(path))[0]
        with open(path) as f:
            jobs.append((name, f.read()))
    for seed in range(1, args.random + 1):
        jobs.append((f"random_{seed:03d}", gen(seed)))
    if args.only:
        jobs = [j for j in jobs if j[0] == args.only]

    print(f"{'test':<16}{'result':<14}{'cycles':>8}{'instrs':>8}{'CPI':>7}")
    print("-" * 53)
    failed = 0
    tot_c = tot_i = 0
    for name, src in jobs:
        name, status, cycles, retired, diffs = run_one(name, src, args.vcd)
        cpi = f"{cycles / retired:.2f}" if retired else "-"
        print(f"{name:<16}{status:<14}{cycles:>8}{retired:>8}{cpi:>7}")
        if status != "PASS":
            failed += 1
            for rtl, ref in diffs[:8]:
                print(f"    rtl: {rtl:<22} expected: {ref}")
        else:
            tot_c += cycles
            tot_i += retired
    print("-" * 53)
    print(f"{len(jobs) - failed}/{len(jobs)} passed", end="")
    if tot_i:
        print(f", overall CPI {tot_c / tot_i:.2f} over {tot_i} instructions")
    else:
        print()
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
