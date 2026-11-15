`timescale 1ns/1ps

module regfile (
    input  wire        clk,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    output wire [31:0] rd1,
    output wire [31:0] rd2,
    input  wire        we,
    input  wire [4:0]  rd,
    input  wire [31:0] wd
);

    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'b0;
    end

    always @(posedge clk) begin
        if (we && rd != 5'd0)
            regs[rd] <= wd;
    end

    assign rd1 = (rs1 == 5'd0) ? 32'b0 : (we && rd == rs1) ? wd : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'b0 : (we && rd == rs2) ? wd : regs[rs2];

endmodule
