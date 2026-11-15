`timescale 1ns/1ps

`include "riscv_defs.vh"

module riscv_core (
    input  wire        clk,
    input  wire        rst,
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_we,
    input  wire [31:0] dmem_rdata,
    output wire        halted,
    output wire        retire
);

    wire        stall;
    wire        flush;
    wire        stop_fetch;
    wire [31:0] ex_target;

    reg  [31:0] pc;
    reg         halt_seen;

    reg  [31:0] if_id_pc;
    reg  [31:0] if_id_instr;
    reg         if_id_valid;

    reg         id_ex_valid;
    reg  [31:0] id_ex_pc;
    reg  [31:0] id_ex_rs1_data;
    reg  [31:0] id_ex_rs2_data;
    reg  [31:0] id_ex_imm;
    reg  [4:0]  id_ex_rs1;
    reg  [4:0]  id_ex_rs2;
    reg  [4:0]  id_ex_rd;
    reg  [2:0]  id_ex_funct3;
    reg         id_ex_reg_write;
    reg         id_ex_mem_read;
    reg         id_ex_mem_write;
    reg  [1:0]  id_ex_wb_sel;
    reg  [1:0]  id_ex_alu_a_sel;
    reg         id_ex_alu_b_imm;
    reg  [3:0]  id_ex_alu_op;
    reg         id_ex_branch;
    reg         id_ex_jal;
    reg         id_ex_jalr;
    reg         id_ex_halt;

    reg         ex_mem_valid;
    reg  [31:0] ex_mem_result;
    reg  [31:0] ex_mem_store_data;
    reg  [4:0]  ex_mem_rd;
    reg  [2:0]  ex_mem_funct3;
    reg         ex_mem_reg_write;
    reg         ex_mem_mem_read;
    reg         ex_mem_mem_write;
    reg  [1:0]  ex_mem_wb_sel;
    reg         ex_mem_halt;

    reg         mem_wb_valid;
    reg  [31:0] mem_wb_result;
    reg  [31:0] mem_wb_load_data;
    reg  [4:0]  mem_wb_rd;
    reg         mem_wb_reg_write;
    reg  [1:0]  mem_wb_wb_sel;
    reg         mem_wb_halt;

    wire [31:0] wb_data = (mem_wb_wb_sel == `WB_MEM) ? mem_wb_load_data : mem_wb_result;
    wire        wb_we   = mem_wb_valid && mem_wb_reg_write;

    assign imem_addr = pc;

    always @(posedge clk) begin
        if (rst)
            pc <= 32'b0;
        else if (flush)
            pc <= ex_target;
        else if (!stall && !stop_fetch)
            pc <= pc + 32'd4;
    end

    always @(posedge clk) begin
        if (rst || flush || stop_fetch) begin
            if_id_pc    <= 32'b0;
            if_id_instr <= `NOP;
            if_id_valid <= 1'b0;
        end else if (!stall) begin
            if_id_pc    <= pc;
            if_id_instr <= imem_rdata;
            if_id_valid <= 1'b1;
        end
    end

    wire [4:0] id_rs1 = if_id_instr[19:15];
    wire [4:0] id_rs2 = if_id_instr[24:20];
    wire [4:0] id_rd  = if_id_instr[11:7];
    wire [2:0] id_funct3 = if_id_instr[14:12];

    wire        c_reg_write, c_mem_read, c_mem_write;
    wire [1:0]  c_wb_sel, c_alu_a_sel;
    wire        c_alu_b_imm;
    wire [3:0]  c_alu_op;
    wire        c_branch, c_jal, c_jalr;
    wire [2:0]  c_imm_sel;
    wire        c_uses_rs1, c_uses_rs2;
    wire        c_halt, c_illegal;

    control u_control (
        .instr     (if_id_instr),
        .reg_write (c_reg_write),
        .mem_read  (c_mem_read),
        .mem_write (c_mem_write),
        .wb_sel    (c_wb_sel),
        .alu_a_sel (c_alu_a_sel),
        .alu_b_imm (c_alu_b_imm),
        .alu_op    (c_alu_op),
        .branch    (c_branch),
        .jal       (c_jal),
        .jalr      (c_jalr),
        .imm_sel   (c_imm_sel),
        .uses_rs1  (c_uses_rs1),
        .uses_rs2  (c_uses_rs2),
        .halt      (c_halt),
        .illegal   (c_illegal)
    );

    wire [31:0] id_imm;

    imm_gen u_imm_gen (
        .instr (if_id_instr),
        .sel   (c_imm_sel),
        .imm   (id_imm)
    );

    wire [31:0] id_rs1_data, id_rs2_data;

    regfile u_rf (
        .clk (clk),
        .rs1 (id_rs1),
        .rs2 (id_rs2),
        .rd1 (id_rs1_data),
        .rd2 (id_rs2_data),
        .we  (wb_we),
        .rd  (mem_wb_rd),
        .wd  (wb_data)
    );

    hazard_unit u_hazard (
        .id_ex_mem_read (id_ex_valid && id_ex_mem_read),
        .id_ex_rd       (id_ex_rd),
        .if_id_rs1      (id_rs1),
        .if_id_rs2      (id_rs2),
        .if_id_uses_rs1 (if_id_valid && c_uses_rs1),
        .if_id_uses_rs2 (if_id_valid && c_uses_rs2),
        .load_use_stall (stall)
    );

    wire id_halt = if_id_valid && c_halt && !flush;

    assign stop_fetch = halt_seen || id_halt;

    always @(posedge clk) begin
        if (rst)
            halt_seen <= 1'b0;
        else if (id_halt)
            halt_seen <= 1'b1;
    end

    always @(posedge clk) begin
        if (rst || flush || stall || !if_id_valid) begin
            id_ex_valid     <= 1'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read  <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_branch    <= 1'b0;
            id_ex_jal       <= 1'b0;
            id_ex_jalr      <= 1'b0;
            id_ex_halt      <= 1'b0;
            id_ex_rd        <= 5'b0;
            id_ex_rs1       <= 5'b0;
            id_ex_rs2       <= 5'b0;
        end else begin
            id_ex_valid     <= 1'b1;
            id_ex_reg_write <= c_reg_write;
            id_ex_mem_read  <= c_mem_read;
            id_ex_mem_write <= c_mem_write;
            id_ex_branch    <= c_branch;
            id_ex_jal       <= c_jal;
            id_ex_jalr      <= c_jalr;
            id_ex_halt      <= c_halt;
            id_ex_rd        <= id_rd;
            id_ex_rs1       <= c_uses_rs1 ? id_rs1 : 5'b0;
            id_ex_rs2       <= c_uses_rs2 ? id_rs2 : 5'b0;
        end
        id_ex_pc        <= if_id_pc;
        id_ex_rs1_data  <= id_rs1_data;
        id_ex_rs2_data  <= id_rs2_data;
        id_ex_imm       <= id_imm;
        id_ex_funct3    <= id_funct3;
        id_ex_wb_sel    <= c_wb_sel;
        id_ex_alu_a_sel <= c_alu_a_sel;
        id_ex_alu_b_imm <= c_alu_b_imm;
        id_ex_alu_op    <= c_alu_op;
    end

    wire [1:0] fwd_a, fwd_b;

    forwarding_unit u_fwd (
        .id_ex_rs1        (id_ex_rs1),
        .id_ex_rs2        (id_ex_rs2),
        .ex_mem_reg_write (ex_mem_valid && ex_mem_reg_write),
        .ex_mem_rd        (ex_mem_rd),
        .mem_wb_reg_write (wb_we),
        .mem_wb_rd        (mem_wb_rd),
        .fwd_a            (fwd_a),
        .fwd_b            (fwd_b)
    );

    wire [31:0] ex_rs1_val = (fwd_a == 2'd2) ? ex_mem_result :
                             (fwd_a == 2'd1) ? wb_data : id_ex_rs1_data;
    wire [31:0] ex_rs2_val = (fwd_b == 2'd2) ? ex_mem_result :
                             (fwd_b == 2'd1) ? wb_data : id_ex_rs2_data;

    wire [31:0] alu_a = (id_ex_alu_a_sel == `A_PC)   ? id_ex_pc :
                        (id_ex_alu_a_sel == `A_ZERO) ? 32'b0 : ex_rs1_val;
    wire [31:0] alu_b = id_ex_alu_b_imm ? id_ex_imm : ex_rs2_val;
    wire [31:0] alu_y;

    alu u_alu (
        .a  (alu_a),
        .b  (alu_b),
        .op (id_ex_alu_op),
        .y  (alu_y)
    );

    wire br_taken;

    branch_unit u_branch (
        .a      (ex_rs1_val),
        .b      (ex_rs2_val),
        .funct3 (id_ex_funct3),
        .taken  (br_taken)
    );

    wire [31:0] ex_pc4 = id_ex_pc + 32'd4;

    assign ex_target = id_ex_jalr ? ((ex_rs1_val + id_ex_imm) & ~32'd1) : (id_ex_pc + id_ex_imm);
    assign flush     = id_ex_valid && (id_ex_jal || id_ex_jalr || (id_ex_branch && br_taken));

    always @(posedge clk) begin
        if (rst) begin
            ex_mem_valid     <= 1'b0;
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read  <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_halt      <= 1'b0;
            ex_mem_rd        <= 5'b0;
        end else begin
            ex_mem_valid     <= id_ex_valid;
            ex_mem_reg_write <= id_ex_valid && id_ex_reg_write;
            ex_mem_mem_read  <= id_ex_valid && id_ex_mem_read;
            ex_mem_mem_write <= id_ex_valid && id_ex_mem_write;
            ex_mem_halt      <= id_ex_valid && id_ex_halt;
            ex_mem_rd        <= id_ex_rd;
        end
        ex_mem_result     <= (id_ex_wb_sel == `WB_PC4) ? ex_pc4 : alu_y;
        ex_mem_store_data <= ex_rs2_val;
        ex_mem_funct3     <= id_ex_funct3;
        ex_mem_wb_sel     <= id_ex_wb_sel;
    end

    wire [1:0] byte_off = ex_mem_result[1:0];

    reg [3:0]  store_be;
    reg [31:0] store_data;

    always @(*) begin
        case (ex_mem_funct3[1:0])
            2'b00: begin
                store_be   = 4'b0001 << byte_off;
                store_data = {4{ex_mem_store_data[7:0]}};
            end
            2'b01: begin
                store_be   = 4'b0011 << {byte_off[1], 1'b0};
                store_data = {2{ex_mem_store_data[15:0]}};
            end
            default: begin
                store_be   = 4'b1111;
                store_data = ex_mem_store_data;
            end
        endcase
    end

    assign dmem_addr  = ex_mem_result;
    assign dmem_wdata = store_data;
    assign dmem_we    = (ex_mem_valid && ex_mem_mem_write) ? store_be : 4'b0000;

    wire [31:0] load_shifted = dmem_rdata >> {byte_off, 3'b000};

    reg [31:0] load_data;

    always @(*) begin
        case (ex_mem_funct3)
            3'b000:  load_data = {{24{load_shifted[7]}},  load_shifted[7:0]};
            3'b001:  load_data = {{16{load_shifted[15]}}, load_shifted[15:0]};
            3'b100:  load_data = {24'b0, load_shifted[7:0]};
            3'b101:  load_data = {16'b0, load_shifted[15:0]};
            default: load_data = dmem_rdata;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            mem_wb_valid     <= 1'b0;
            mem_wb_reg_write <= 1'b0;
            mem_wb_halt      <= 1'b0;
            mem_wb_rd        <= 5'b0;
        end else begin
            mem_wb_valid     <= ex_mem_valid;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_halt      <= ex_mem_halt;
            mem_wb_rd        <= ex_mem_rd;
        end
        mem_wb_result    <= ex_mem_result;
        mem_wb_load_data <= load_data;
        mem_wb_wb_sel    <= ex_mem_wb_sel;
    end

    assign halted = mem_wb_valid && mem_wb_halt;
    assign retire = mem_wb_valid;

endmodule
