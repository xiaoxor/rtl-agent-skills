`timescale 1ns/1ps
module tb_scheduling;
    reg clk;
    reg [7:0] nba_input, nba_output;
    reg [7:0] off_input, off_output;
    reg [7:0] expected_nba, expected_off;
    reg [7:0] previous_nba, previous_off;

    always #5 clk = ~clk;
    always @(posedge clk) nba_input <= nba_input + 8'd1;
    always @(posedge clk) begin
        nba_output <= nba_input;
        off_output <= off_input;
    end

    initial begin
        clk = 0;
        nba_input = 0;
        nba_output = 0;
        off_input = 0;
        off_output = 0;
        expected_nba = 0;
        expected_off = 0;
        previous_nba = 0;
        previous_off = 0;
        repeat (4) begin
            @(posedge clk);
            if (nba_input !== expected_nba || nba_output !== previous_nba ||
                off_output !== previous_off)
                $fatal(1, "ACTIVE_VALUES: time=%0t input=%0d output=%0d", $time,
                       nba_input, nba_output);
            // 1 ns is after NBA and before the next edge (5 ns away).
            #1;
            if (nba_input !== expected_nba + 8'd1 || nba_output !== expected_nba ||
                off_output !== expected_off)
                $fatal(1, "POST_NBA_VALUES: time=%0t", $time);
            previous_nba = expected_nba;
            previous_off = expected_off;
            expected_nba = expected_nba + 8'd1;
            @(negedge clk);
            off_input = off_input + 8'h11;
            expected_off = off_input;
        end
        $display("PASS scheduling: same-edge always NBA, Active sampling, off-edge drive");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "WATCHDOG scheduling");
    end
endmodule
