`timescale 1ns/1ps

module imem #(
    parameter WORDS = 1024
) (
    input  wire [31:0] addr,
    output wire [31:0] rdata
);

    localparam AW = $clog2(WORDS);

    reg [31:0] mem [0:WORDS-1];

    integer i;
    initial begin
        for (i = 0; i < WORDS; i = i + 1)
            mem[i] = 32'h00000013;
    end

    assign rdata = mem[addr[AW+1:2]];

endmodule
