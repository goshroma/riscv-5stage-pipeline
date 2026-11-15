`timescale 1ns/1ps

module forwarding_unit (
    input  wire [4:0] id_ex_rs1,
    input  wire [4:0] id_ex_rs2,
    input  wire       ex_mem_reg_write,
    input  wire [4:0] ex_mem_rd,
    input  wire       mem_wb_reg_write,
    input  wire [4:0] mem_wb_rd,
    output reg  [1:0] fwd_a,
    output reg  [1:0] fwd_b
);

    always @(*) begin
        if (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs1)
            fwd_a = 2'd2;
        else if (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs1)
            fwd_a = 2'd1;
        else
            fwd_a = 2'd0;

        if (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs2)
            fwd_b = 2'd2;
        else if (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs2)
            fwd_b = 2'd1;
        else
            fwd_b = 2'd0;
    end

endmodule
