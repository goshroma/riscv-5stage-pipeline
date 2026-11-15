`timescale 1ns/1ps

module riscv_top #(
    parameter IMEM_WORDS = 1024,
    parameter DMEM_WORDS = 1024
) (
    input  wire clk,
    input  wire rst,
    output wire halted,
    output wire retire
);

    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_we;

    riscv_core u_core (
        .clk        (clk),
        .rst        (rst),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_we    (dmem_we),
        .dmem_rdata (dmem_rdata),
        .halted     (halted),
        .retire     (retire)
    );

    imem #(.WORDS(IMEM_WORDS)) u_imem (
        .addr  (imem_addr),
        .rdata (imem_rdata)
    );

    dmem #(.WORDS(DMEM_WORDS)) u_dmem (
        .clk   (clk),
        .addr  (dmem_addr),
        .wdata (dmem_wdata),
        .we    (dmem_we),
        .rdata (dmem_rdata)
    );

endmodule
