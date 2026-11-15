import random
import sys

POOL = ["x1", "x2", "x3", "x4", "x5", "x6", "x7", "x9", "x10", "x11", "x12", "x13"]
BASE = "x8"
LINK = "x31"

R_OPS = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
I_OPS = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
SH_OPS = ["slli", "srli", "srai"]
B_OPS = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]
LOADS = [("lb", 1), ("lh", 2), ("lw", 4), ("lbu", 1), ("lhu", 2)]
STORES = [("sb", 1), ("sh", 2), ("sw", 4)]

INTERESTING = [0, 1, -1, 0x7FFFFFFF, -0x80000000, 0x80, 0xFF, 0xFFFF, 0x8000, -2048, 2047, 31, 32]


def rand_value(rng):
    if rng.random() < 0.4:
        return rng.choice(INTERESTING)
    return rng.randint(-(1 << 31), (1 << 31) - 1)


def gen(seed, length=300):
    rng = random.Random(seed)
    lines = [f"    li {BASE}, 0x100"]
    for r in POOL:
        lines.append(f"    li {r}, {rand_value(rng)}")
    label = 0
    pending = []
    i = 0
    while i < length:
        if pending and pending[0][0] <= i:
            lines.append(f"L{pending.pop(0)[1]}:")
            continue
        rd = rng.choice(POOL)
        rs1 = rng.choice(POOL + ["x0"])
        rs2 = rng.choice(POOL + ["x0"])
        kind = rng.choices(
            ["r", "i", "sh", "lui", "auipc", "load", "store", "branch", "jal", "jalr"],
            weights=[25, 18, 8, 3, 2, 14, 12, 10, 4, 4],
        )[0]
        if kind == "r":
            lines.append(f"    {rng.choice(R_OPS)} {rd}, {rs1}, {rs2}")
        elif kind == "i":
            lines.append(f"    {rng.choice(I_OPS)} {rd}, {rs1}, {rng.randint(-2048, 2047)}")
        elif kind == "sh":
            lines.append(f"    {rng.choice(SH_OPS)} {rd}, {rs1}, {rng.randint(0, 31)}")
        elif kind == "lui":
            lines.append(f"    lui {rd}, {rng.randint(0, 0xFFFFF)}")
        elif kind == "auipc":
            lines.append(f"    auipc {rd}, {rng.randint(0, 0xFFFFF)}")
        elif kind == "load":
            op, size = rng.choice(LOADS)
            off = rng.randrange(0, 512, size)
            lines.append(f"    {op} {rd}, {off}({BASE})")
        elif kind == "store":
            op, size = rng.choice(STORES)
            off = rng.randrange(0, 512, size)
            lines.append(f"    {op} {rs2}, {off}({BASE})")
        elif kind in ("branch", "jal"):
            skip = rng.randint(1, 4)
            if kind == "branch":
                lines.append(f"    {rng.choice(B_OPS)} {rs1}, {rs2}, L{label}")
            else:
                lines.append(f"    jal {rd}, L{label}")
            pending.append((i + 1 + skip, label))
            pending.sort()
            label += 1
        elif kind == "jalr":
            lines.append(f"    auipc {LINK}, 0")
            lines.append(f"    jalr {rd}, 12({LINK})")
            lines.append(f"    addi {rd}, {rd}, 1")
            i += 2
        i += 1
    for _, lab in pending:
        lines.append(f"L{lab}:")
    lines.append("    ecall")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    sys.stdout.write(gen(seed))
