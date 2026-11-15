`timescale 1ns/1ps

`include "riscv_defs.vh"

module control (
    input  wire [31:0] instr,
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  wb_sel,
    output reg  [1:0]  alu_a_sel,
    output reg         alu_b_imm,
    output reg  [3:0]  alu_op,
    output reg         branch,
    output reg         jal,
    output reg         jalr,
    output reg  [2:0]  imm_sel,
    output reg         uses_rs1,
    output reg         uses_rs2,
    output reg         halt,
    output reg         illegal
);

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire       f7b5   = instr[30];

    reg [3:0] arith_op;

    always @(*) begin
        case (funct3)
            3'b000:  arith_op = `ALU_ADD;
            3'b001:  arith_op = `ALU_SLL;
            3'b010:  arith_op = `ALU_SLT;
            3'b011:  arith_op = `ALU_SLTU;
            3'b100:  arith_op = `ALU_XOR;
            3'b101:  arith_op = f7b5 ? `ALU_SRA : `ALU_SRL;
            3'b110:  arith_op = `ALU_OR;
            default: arith_op = `ALU_AND;
        endcase
    end

    always @(*) begin
        reg_write = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        wb_sel    = `WB_ALU;
        alu_a_sel = `A_RS1;
        alu_b_imm = 1'b0;
        alu_op    = `ALU_ADD;
        branch    = 1'b0;
        jal       = 1'b0;
        jalr      = 1'b0;
        imm_sel   = `IMM_I;
        uses_rs1  = 1'b0;
        uses_rs2  = 1'b0;
        halt      = 1'b0;
        illegal   = 1'b0;

        case (opcode)
            `OP_LUI: begin
                reg_write = 1'b1;
                alu_a_sel = `A_ZERO;
                alu_b_imm = 1'b1;
                imm_sel   = `IMM_U;
            end
            `OP_AUIPC: begin
                reg_write = 1'b1;
                alu_a_sel = `A_PC;
                alu_b_imm = 1'b1;
                imm_sel   = `IMM_U;
            end
            `OP_JAL: begin
                reg_write = 1'b1;
                wb_sel    = `WB_PC4;
                jal       = 1'b1;
                imm_sel   = `IMM_J;
            end
            `OP_JALR: begin
                reg_write = 1'b1;
                wb_sel    = `WB_PC4;
                jalr      = 1'b1;
                imm_sel   = `IMM_I;
                uses_rs1  = 1'b1;
            end
            `OP_BRANCH: begin
                branch    = 1'b1;
                imm_sel   = `IMM_B;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
            end
            `OP_LOAD: begin
                reg_write = 1'b1;
                mem_read  = 1'b1;
                wb_sel    = `WB_MEM;
                alu_b_imm = 1'b1;
                imm_sel   = `IMM_I;
                uses_rs1  = 1'b1;
            end
            `OP_STORE: begin
                mem_write = 1'b1;
                alu_b_imm = 1'b1;
                imm_sel   = `IMM_S;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
            end
            `OP_IMM: begin
                reg_write = 1'b1;
                alu_b_imm = 1'b1;
                alu_op    = arith_op;
                imm_sel   = `IMM_I;
                uses_rs1  = 1'b1;
            end
            `OP_REG: begin
                reg_write = 1'b1;
                alu_op    = (funct3 == 3'b000 && f7b5) ? `ALU_SUB : arith_op;
                uses_rs1  = 1'b1;
                uses_rs2  = 1'b1;
            end
            `OP_FENCE: begin
            end
            `OP_SYSTEM: begin
                halt = 1'b1;
            end
            default: begin
                illegal = 1'b1;
            end
        endcase
    end

endmodule
