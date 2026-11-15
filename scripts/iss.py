import sys

MASK = 0xFFFFFFFF


def sx(val, bits):
    val &= (1 << bits) - 1
    return val - (1 << bits) if val >> (bits - 1) else val


def s32(val):
    return sx(val, 32)


class ISS:
    def __init__(self, program, dmem_words=1024):
        self.imem = list(program)
        self.mem = bytearray(dmem_words * 4)
        self.msize = dmem_words * 4
        self.regs = [0] * 32
        self.pc = 0
        self.retired = 0

    def load(self, addr, size, signed):
        addr = (addr & MASK) % self.msize
        val = int.from_bytes(self.mem[addr:addr + size], "little")
        return sx(val, size * 8) & MASK if signed else val

    def store(self, addr, size, val):
        addr = (addr & MASK) % self.msize
        self.mem[addr:addr + size] = (val & ((1 << (size * 8)) - 1)).to_bytes(size, "little")

    def step(self):
        idx = self.pc >> 2
        instr = self.imem[idx] if idx < len(self.imem) else 0x00000013
        op = instr & 0x7F
        rd = (instr >> 7) & 0x1F
        f3 = (instr >> 12) & 0x7
        rs1 = (instr >> 15) & 0x1F
        rs2 = (instr >> 20) & 0x1F
        f7 = instr >> 25
        a = self.regs[rs1]
        b = self.regs[rs2]
        imm_i = sx(instr >> 20, 12)
        imm_s = sx(((instr >> 25) << 5) | ((instr >> 7) & 0x1F), 12)
        imm_b = sx((((instr >> 31) & 1) << 12) | (((instr >> 7) & 1) << 11) |
                   (((instr >> 25) & 0x3F) << 5) | (((instr >> 8) & 0xF) << 1), 13)
        imm_u = instr & 0xFFFFF000
        imm_j = sx((((instr >> 31) & 1) << 20) | (((instr >> 12) & 0xFF) << 12) |
                   (((instr >> 20) & 1) << 11) | (((instr >> 21) & 0x3FF) << 1), 21)

        next_pc = (self.pc + 4) & MASK
        result = None
        self.retired += 1

        if op == 0x37:
            result = imm_u
        elif op == 0x17:
            result = (self.pc + imm_u) & MASK
        elif op == 0x6F:
            result = next_pc
            next_pc = (self.pc + imm_j) & MASK
        elif op == 0x67:
            result = next_pc
            next_pc = (a + imm_i) & MASK & ~1
        elif op == 0x63:
            taken = {
                0: a == b, 1: a != b,
                4: s32(a) < s32(b), 5: s32(a) >= s32(b),
                6: a < b, 7: a >= b,
            }.get(f3, False)
            if taken:
                next_pc = (self.pc + imm_b) & MASK
        elif op == 0x03:
            addr = a + imm_i
            size = {0: 1, 1: 2, 2: 4, 4: 1, 5: 2}[f3]
            result = self.load(addr, size, f3 in (0, 1))
        elif op == 0x23:
            self.store(a + imm_s, {0: 1, 1: 2, 2: 4}[f3], b)
        elif op in (0x13, 0x33):
            if op == 0x13:
                rhs = imm_i & MASK
                sub = False
                sra = f3 == 5 and (instr >> 30) & 1
            else:
                rhs = b
                sub = f3 == 0 and (instr >> 30) & 1
                sra = f3 == 5 and (instr >> 30) & 1
            sh = rhs & 0x1F
            if f3 == 0:
                result = (a - rhs) if sub else (a + rhs)
            elif f3 == 1:
                result = a << sh
            elif f3 == 2:
                result = int(s32(a) < s32(rhs))
            elif f3 == 3:
                result = int(a < rhs)
            elif f3 == 4:
                result = a ^ rhs
            elif f3 == 5:
                result = (s32(a) >> sh) if sra else (a >> sh)
            elif f3 == 6:
                result = a | rhs
            else:
                result = a & rhs
            result &= MASK
        elif op == 0x0F:
            pass
        elif op == 0x73:
            return False
        else:
            raise RuntimeError(f"illegal instruction {instr:08x} at pc {self.pc:08x}")

        if result is not None and rd != 0:
            self.regs[rd] = result & MASK
        self.pc = next_pc
        return True

    def run(self, max_steps=1_000_000):
        for _ in range(max_steps):
            if not self.step():
                return True
        return False

    def dump(self, words=256):
        lines = [f"x{i} {self.regs[i]:08x}" for i in range(1, 32)]
        for i in range(words):
            w = int.from_bytes(self.mem[i * 4:i * 4 + 4], "little")
            lines.append(f"m{i} {w:08x}")
        return "\n".join(lines) + "\n"


def read_hex(path):
    with open(path) as f:
        return [int(line, 16) for line in f if line.strip()]


def main():
    if len(sys.argv) != 3:
        print("usage: iss.py <prog.hex> <dump.txt>")
        sys.exit(1)
    sim = ISS(read_hex(sys.argv[1]))
    if not sim.run():
        print("ISS timeout")
        sys.exit(1)
    with open(sys.argv[2], "w") as f:
        f.write(sim.dump())
    print(f"ISS halted after {sim.retired} instructions")


if __name__ == "__main__":
    main()
