`timescale 1ns/1ps

module tb_riscv;

    reg clk = 1'b0;
    reg rst = 1'b1;

    wire halted;
    wire retire;

    always #5 clk = ~clk;

    riscv_top dut (
        .clk    (clk),
        .rst    (rst),
        .halted (halted),
        .retire (retire)
    );

    reg [8*256-1:0] hexfile;
    reg [8*256-1:0] dumpfile;
    reg [8*256-1:0] vcdfile;

    integer max_cycles;
    integer dump_words;
    integer cycles;
    integer retired;
    integer i;
    integer fd;

    initial begin
        if (!$value$plusargs("hex=%s", hexfile))   hexfile = "prog.hex";
        if (!$value$plusargs("dump=%s", dumpfile)) dumpfile = "rtl_dump.txt";
        if (!$value$plusargs("max=%d", max_cycles)) max_cycles = 200000;
        if (!$value$plusargs("words=%d", dump_words)) dump_words = 256;

        if ($value$plusargs("vcd=%s", vcdfile)) begin
            $dumpfile(vcdfile);
            $dumpvars(0, tb_riscv);
        end

        $readmemh(hexfile, dut.u_imem.mem);

        cycles  = 0;
        retired = 0;

        repeat (3) @(negedge clk);
        rst = 1'b0;

        while (!halted && cycles < max_cycles) begin
            @(negedge clk);
            cycles = cycles + 1;
            if (retire)
                retired = retired + 1;
        end

        if (!halted) begin
            $display("RESULT TIMEOUT cycles=%0d", cycles);
            $finish;
        end

        fd = $fopen(dumpfile, "w");
        for (i = 1; i < 32; i = i + 1)
            $fdisplay(fd, "x%0d %08x", i, dut.u_core.u_rf.regs[i]);
        for (i = 0; i < dump_words; i = i + 1)
            $fdisplay(fd, "m%0d %08x", i, dut.u_dmem.mem[i]);
        $fclose(fd);

        $display("RESULT HALT cycles=%0d retired=%0d", cycles, retired);
        $finish;
    end

endmodule
