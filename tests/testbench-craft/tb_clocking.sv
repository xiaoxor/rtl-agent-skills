`timescale 1ns/1ps
module tb_clocking;
    reg clk = 0;
    reg [7:0] data = 0, sampled = 0;
    always #5 clk = ~clk;
    always @(posedge clk) sampled <= data;
    clocking cb @(posedge clk);
        default input #1step output #0;
        input sampled;
        output data;
    endclocking
    initial begin
        @(cb);
        if (cb.sampled !== 0) $fatal(1, "CLOCKING_INITIAL");
        cb.data <= 8'h35;
        #1;
        if (sampled !== 0) $fatal(1, "CLOCKING_OUTPUT_TOO_EARLY");
        @(cb);
        if (cb.sampled !== 0) $fatal(1, "CLOCKING_INPUT_NOT_PRE_EDGE");
        #1;
        if (sampled !== 8'h35) $fatal(1, "CLOCKING_OUTPUT_NOT_ACCEPTED");
        @(cb);
        if (cb.sampled !== 8'h35) $fatal(1, "CLOCKING_INPUT_NEXT_EDGE");
        $display("PASS clocking: input #1step is pre-edge; output #0 drives after sampling");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "WATCHDOG clocking");
    end
endmodule
