`timescale 1ns/1ps

module hazard_unit (
    input  wire       id_ex_mem_read,
    input  wire [4:0] id_ex_rd,
    input  wire [4:0] if_id_rs1,
    input  wire [4:0] if_id_rs2,
    input  wire       if_id_uses_rs1,
    input  wire       if_id_uses_rs2,
    output wire       load_use_stall
);

    wire rs1_hit = if_id_uses_rs1 && (id_ex_rd == if_id_rs1);
    wire rs2_hit = if_id_uses_rs2 && (id_ex_rd == if_id_rs2);

    assign load_use_stall = id_ex_mem_read && (id_ex_rd != 5'd0) && (rs1_hit || rs2_hit);

endmodule
