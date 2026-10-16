`timescale 1ns/1ps
module tb_nba_initial;
    reg clk;
    reg data, sampled;
    always #5 clk = ~clk;
    always @(posedge clk) sampled <= data;
    initial begin
        clk = 0;
        data = 0;
        sampled = 0;
        @(posedge clk);
        data <= 1;
        if (data !== 0)
            $fatal(1, "INITIAL_NBA_CHANGED_IMMEDIATELY: data=%b", data);
        #1;
        if (sampled !== 0)
            $fatal(1, "INITIAL_NBA_SAME_EDGE: sampled=%b", sampled);
        @(posedge clk);
        #1;
        if (sampled !== 1) $fatal(1, "INITIAL_NBA_NEXT_EDGE");
        $display("PASS initial NBA: old input sampled, new input accepted next edge");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "WATCHDOG initial NBA");
    end
endmodule
