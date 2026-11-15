# 5-Stage Pipelined RISC-V (RV32I) Processor

A 5-stage in-order RV32I core written in synthesizable Verilog. It's verified against a Python golden reference model using directed tests and constrained-random instruction streams.

## Architecture

```
        +------+     +------+     +------+     +------+     +------+
  PC -->|  IF  |---->|  ID  |---->|  EX  |---->| MEM  |---->|  WB  |
        +------+ IF/ +------+ ID/ +------+ EX/ +------+ MEM/ +------+
           ^     ID     |     EX     |  ^   MEM    |    WB     |
           |            |            |  |          |           |
           |       regfile read      |  +--- fwd --+--- fwd ---+
           |       (write-through)   |
           +------ branch/jump redirect (flush IF/ID, ID/EX)
                        ^
                 hazard unit: load-use stall (1 bubble)
```

| Stage | What happens |
|-------|--------------|
| IF  | PC drives instruction memory; PC+4 or redirect target |
| ID  | Decode, immediate generation, register read, load-use detection |
| EX  | ALU, branch compare, branch/jump target, forwarding muxes |
| MEM | Byte-enabled stores, sign/zero-extended loads |
| WB  | Register write-back (ALU result, load data, or PC+4) |

### Hazard handling
- **Data hazards:** full forwarding from EX/MEM and MEM/WB into EX. The register file uses write-through, so WB to ID needs no extra stall.
- **Load-use:** the hazard unit stalls PC and IF/ID for one cycle and inserts a bubble into ID/EX. It only checks source registers the instruction actually reads.
- **Control hazards:** branches and jumps resolve in EX. A taken branch, JAL or JALR flushes IF/ID and ID/EX, so the penalty is 2 cycles. Static predict-not-taken.
- **Halt:** ECALL/EBREAK freezes fetch once decoded, so no younger instruction can commit after it.

### ISA coverage
All 37 RV32I user-level instructions: LUI, AUIPC, JAL, JALR, 6 branches, 5 loads, 3 stores, 9 immediate ALU ops, 10 register ALU ops. FENCE executes as a NOP. ECALL/EBREAK halt the core.

## Verification

```
 test.s --> asm.py --> prog.hex --+--> Icarus RTL sim (tb_riscv.v) --> rtl dump --+
                                  |                                               +--> compare
                                  +--> iss.py (golden model) ---------> ref dump --+
```

- **Golden model (`scripts/iss.py`):** an instruction-accurate RV32I simulator. After the halt, the final values of all 31 registers and 256 data-memory words must match the RTL exactly, plus the retired instruction count.
- **Directed tests (`sw/tests/`):** ALU edge cases (overflow, signed/unsigned compares, shifts), every forwarding path, load-use, x0 writes, all branch types taken and not taken, JAL/JALR, byte/half/word memory with sign extension, plus bubble sort and Fibonacci programs.
- **Constrained-random tests (`scripts/gen_random.py`):** seeded streams of about 300 instructions. They use a small register pool to keep hazard density high, include interesting values (0, -1, INT_MIN, INT_MAX, boundaries), random loads/stores, and forward branches/jumps.
- **Mutation testing:** each of these injected bugs was caught by the regression: no EX/MEM forwarding, no MEM/WB forwarding, no load-use stall, no register-file write-through, no flush on taken branch, and BGE compared unsigned.

## Results

| Metric | Value |
|--------|-------|
| Regression | 106/106 tests passing (6 directed + 100 random) |
| Instructions verified | ~27,000 |
| Average CPI | 1.25 (includes pipeline fill, stalls, and flushes) |
| Synthesis (Yosys, Xilinx 7-series) | ~1,060 LUTs, 413 FFs, 12 RAM32M, 60 CARRY4 (core only, excludes memories) |

Fmax isn't reported. Run the design through Vivado place-and-route for real timing numbers.

## Running

Requirements: Icarus Verilog, Python 3. Optional: GTKWave, Yosys.

```bash
make test                     # compile + 6 directed + 100 random tests
make quick                    # directed tests only
make wave TEST=hazards        # dump VCD and open GTKWave
make synth                    # Yosys synthesis for Xilinx 7-series
python3 scripts/asm.py prog.s prog.hex
```

## Layout

```
rtl/        riscv_core.v (pipeline), alu, control, imm_gen, regfile,
            branch_unit, hazard_unit, forwarding_unit, imem, dmem, riscv_top
tb/         tb_riscv.v
scripts/    asm.py, iss.py, gen_random.py, run_tests.py
sw/tests/   directed assembly tests
syn/        Yosys script and log
```

## Possible extensions
- Branch prediction (BTB + 2-bit counters), then measure the CPI improvement
- Resolve branches in ID to cut the penalty to 1 cycle
- M extension (multiply/divide)
- Run the official riscv-tests suite
- SystemVerilog/UVM testbench with functional coverage
- RTL to GDS with OpenLane on Sky130
