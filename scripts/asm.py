import re
import sys

ABI = "zero ra sp gp tp t0 t1 t2 s0 s1 a0 a1 a2 a3 a4 a5 a6 a7 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 t3 t4 t5 t6".split()
REGS = {f"x{i}": i for i in range(32)}
REGS.update({name: i for i, name in enumerate(ABI)})
REGS["fp"] = 8

R_OPS = {
    "add": (0, 0x00), "sub": (0, 0x20), "sll": (1, 0x00), "slt": (2, 0x00), "sltu": (3, 0x00),
    "xor": (4, 0x00), "srl": (5, 0x00), "sra": (5, 0x20), "or": (6, 0x00), "and": (7, 0x00),
}
I_OPS = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
SH_OPS = {"slli": (1, 0x00), "srli": (5, 0x00), "srai": (5, 0x20)}
L_OPS = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
S_OPS = {"sb": 0, "sh": 1, "sw": 2}
B_OPS = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}


class AsmError(Exception):
    pass


def reg(tok):
    tok = tok.strip().lower()
    if tok not in REGS:
        raise AsmError(f"bad register '{tok}'")
    return REGS[tok]


def num(tok):
    return int(tok.strip(), 0)


def mem_operand(tok):
    m = re.fullmatch(r"\s*(-?[\w]+)?\s*\(\s*(\w+)\s*\)\s*", tok)
    if not m:
        raise AsmError(f"bad memory operand '{tok}'")
    off = num(m.group(1)) if m.group(1) else 0
    return off, reg(m.group(2))


def check_range(val, bits, signed=True):
    lo, hi = (-(1 << (bits - 1)), (1 << (bits - 1)) - 1) if signed else (0, (1 << bits) - 1)
    if not lo <= val <= hi:
        raise AsmError(f"immediate {val} out of range for {bits} bits")


def enc_r(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(imm, rs1, f3, rd, op):
    check_range(imm, 12)
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(imm, rs2, rs1, f3, op):
    check_range(imm, 12)
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op


def enc_b(imm, rs2, rs1, f3, op):
    check_range(imm, 13)
    if imm & 1:
        raise AsmError("branch offset must be even")
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | op


def enc_u(imm, rd, op):
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | op


def enc_j(imm, rd, op):
    check_range(imm, 21)
    if imm & 1:
        raise AsmError("jump offset must be even")
    imm &= 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | \
           (((imm >> 12) & 0xFF) << 12) | (rd << 7) | op


def split_li(value):
    value &= 0xFFFFFFFF
    sval = value - (1 << 32) if value & 0x80000000 else value
    if -2048 <= sval <= 2047:
        return None, sval
    hi = ((value + 0x800) >> 12) & 0xFFFFF
    lo = value - (hi << 12)
    lo = ((lo + 0x800) & 0xFFF) - 0x800
    return hi, lo


def expand(mn, ops):
    if mn == "nop":
        return [("addi", ["x0", "x0", "0"])]
    if mn == "mv":
        return [("addi", [ops[0], ops[1], "0"])]
    if mn == "not":
        return [("xori", [ops[0], ops[1], "-1"])]
    if mn == "neg":
        return [("sub", [ops[0], "x0", ops[1]])]
    if mn == "j":
        return [("jal", ["x0", ops[0]])]
    if mn == "jr":
        return [("jalr", ["x0", f"0({ops[0]})"])]
    if mn == "ret":
        return [("jalr", ["x0", "0(ra)"])]
    if mn == "call":
        return [("jal", ["ra", ops[0]])]
    if mn == "beqz":
        return [("beq", [ops[0], "x0", ops[1]])]
    if mn == "bnez":
        return [("bne", [ops[0], "x0", ops[1]])]
    if mn == "bgt":
        return [("blt", [ops[1], ops[0], ops[2]])]
    if mn == "ble":
        return [("bge", [ops[1], ops[0], ops[2]])]
    if mn == "li":
        hi, lo = split_li(num(ops[1]))
        if hi is None:
            return [("addi", [ops[0], "x0", str(lo)])]
        out = [("lui", [ops[0], str(hi)])]
        if lo:
            out.append(("addi", [ops[0], ops[0], str(lo)]))
        return out
    return [(mn, ops)]


def target(tok, labels, pc):
    tok = tok.strip()
    if tok in labels:
        return labels[tok] - pc
    return num(tok)


def encode(mn, ops, pc, labels):
    if mn in R_OPS:
        f3, f7 = R_OPS[mn]
        return enc_r(f7, reg(ops[2]), reg(ops[1]), f3, reg(ops[0]), 0x33)
    if mn in I_OPS:
        return enc_i(num(ops[2]), reg(ops[1]), I_OPS[mn], reg(ops[0]), 0x13)
    if mn in SH_OPS:
        f3, f7 = SH_OPS[mn]
        sh = num(ops[2])
        check_range(sh, 5, signed=False)
        return enc_r(f7, sh, reg(ops[1]), f3, reg(ops[0]), 0x13)
    if mn in L_OPS:
        off, base = mem_operand(ops[1])
        return enc_i(off, base, L_OPS[mn], reg(ops[0]), 0x03)
    if mn in S_OPS:
        off, base = mem_operand(ops[1])
        return enc_s(off, reg(ops[0]), base, S_OPS[mn], 0x23)
    if mn in B_OPS:
        return enc_b(target(ops[2], labels, pc), reg(ops[1]), reg(ops[0]), B_OPS[mn], 0x63)
    if mn == "lui":
        return enc_u(num(ops[1]), reg(ops[0]), 0x37)
    if mn == "auipc":
        return enc_u(num(ops[1]), reg(ops[0]), 0x17)
    if mn == "jal":
        if len(ops) == 1:
            ops = ["ra", ops[0]]
        return enc_j(target(ops[1], labels, pc), reg(ops[0]), 0x6F)
    if mn == "jalr":
        if len(ops) == 1:
            return enc_i(0, reg(ops[0]), 0, 1, 0x67)
        if "(" in ops[1]:
            off, base = mem_operand(ops[1])
        else:
            base, off = reg(ops[1]), num(ops[2]) if len(ops) > 2 else 0
        return enc_i(off, base, 0, reg(ops[0]), 0x67)
    if mn == "ecall":
        return 0x00000073
    if mn == "ebreak":
        return 0x00100073
    if mn == "fence":
        return 0x0FF0000F
    raise AsmError(f"unknown instruction '{mn}'")


def parse(src):
    items = []
    labels = {}
    pc = 0
    for lineno, raw in enumerate(src.splitlines(), 1):
        line = raw.split("#")[0].strip()
        while True:
            m = re.match(r"^([A-Za-z_.][\w.]*):\s*(.*)$", line)
            if not m:
                break
            labels[m.group(1)] = pc
            line = m.group(2)
        if not line or line.startswith("."):
            continue
        parts = line.split(None, 1)
        mn = parts[0].lower()
        ops = [o.strip() for o in parts[1].split(",")] if len(parts) > 1 else []
        try:
            for emn, eops in expand(mn, ops):
                items.append((emn, eops, pc, lineno, raw))
                pc += 4
        except (AsmError, ValueError, IndexError) as e:
            raise AsmError(f"line {lineno}: {e}: {raw.strip()}")
    return items, labels


def assemble(src):
    items, labels = parse(src)
    words = []
    for mn, ops, pc, lineno, raw in items:
        try:
            words.append(encode(mn, ops, pc, labels) & 0xFFFFFFFF)
        except (AsmError, ValueError, IndexError) as e:
            raise AsmError(f"line {lineno}: {e}: {raw.strip()}")
    return words


def write_hex(words, path):
    with open(path, "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")


def main():
    if len(sys.argv) != 3:
        print("usage: asm.py <input.s> <output.hex>")
        sys.exit(1)
    with open(sys.argv[1]) as f:
        words = assemble(f.read())
    write_hex(words, sys.argv[2])
    print(f"{len(words)} instructions -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
