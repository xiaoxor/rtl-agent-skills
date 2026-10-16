// Illustrative SystemVerilog template, not a drop-in testbench.
// Assumptions: rising-edge DUT; no input ready/backpressure; an input accepted
// on edge N produces registered out_valid/out_data after edge N+1; one input
// transaction is sent at a time. Replace the ports and identity reference()
// with the real DUT interface and an independently derived reference model.
// Adapt latency, reset effects, response shape, and wait conditions to the DUT.
// Falling-edge output checks require the DUT output to be stable at that edge.
// MAX_CYCLES is a watchdog, not an expected-latency guarantee.
`timescale 1ns/1ps
module tb_dut;
    localparam integer MAX_CYCLES = 1000;
    reg clk;
    reg rst_n;
    reg in_valid;
    reg [7:0] in_data;
    wire out_valid;
    wire [7:0] out_data;
    integer cycles;
    integer checked;

    always #5 clk = ~clk;

    // Replace with actual DUT instance and actual port names.
    dut u_dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_data(in_data),
        .out_valid(out_valid), .out_data(out_data)
    );

    // Independent golden function. Replace this illustrative identity.
    function automatic [7:0] reference(input [7:0] x);
        reference = x;
    endfunction

    // Global bounded cycle watchdog. Reset independent for simplicity.
    always @(posedge clk) begin
        cycles = cycles + 1;
        if (cycles > MAX_CYCLES)
            $fatal(1, "GLOBAL TIMEOUT: cycles=%0d checked=%0d", cycles, checked);
    end

    task automatic run_one(input [7:0] x);
        reg [7:0] expected;
        integer waited;
        begin
            expected = reference(x);
            // Drive only on falling edge; stable before next rising edge.
            @(negedge clk);
            in_data  = x;
            in_valid = 1'b1;
            // Accepted on next rising edge (no ready/backpressure).
            @(posedge clk);
            @(negedge clk);
            in_valid = 1'b0;

            // Check stable registered outputs at falling edges, after NBA.
            // Since there is no overlapping traffic, a single result
            // corresponds to this input. For pipelines, use a scoreboard.
            waited = 0;
            while (out_valid !== 1'b1) begin
                if (waited >= 20)
                    $fatal(1, "LOCAL TIMEOUT: input=%02h", x);
                @(negedge clk);
                waited = waited + 1;
            end
            if (out_data !== expected)
                $fatal(1, "MISMATCH: input=%02h expected=%02h actual=%02h",
                       x, expected, out_data);
            checked = checked + 1;
            // Leave an idle cycle before the next single-flight transaction.
            @(negedge clk);
        end
    endtask

    initial begin
        // Initialize signals before the first sampling edge.
        clk = 1'b0;
        rst_n = 1'b0;
        in_valid = 1'b0;
        in_data = 8'h00;
        cycles = 0;
        checked = 0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        run_one(8'h00);
        run_one(8'h01);
        run_one(8'hff);
        if (checked != 3)
            $fatal(1, "INCOMPLETE: checked=%0d", checked);
        $display("PASS: %0d transactions checked", checked);
        $finish;
    end
endmodule
