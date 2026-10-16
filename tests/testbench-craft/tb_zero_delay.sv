`timescale 1ns/1ps
module tb_zero_delay;
    reg clk, sampled;
    always #5 clk = ~clk;
    always @(posedge clk) sampled <= 1;
    initial begin
        clk = 0;
        sampled = 0;
        @(posedge clk);
        #0;
        if (sampled !== 0) $fatal(1, "ZERO_DELAY_NOT_PRE_NBA");
        #1;
        if (sampled !== 1) $fatal(1, "POSITIVE_DELAY_NOT_POST_NBA");
        $display("PASS zero delay: #0 observes old register; #1 observes new register");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "WATCHDOG zero delay");
    end
endmodule
