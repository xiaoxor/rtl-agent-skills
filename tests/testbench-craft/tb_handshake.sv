`timescale 1ns/1ps
module tb_handshake;
    reg clk = 0, rst_n = 0;
    reg in_valid = 0, out_ready = 0;
    reg [7:0] in_data = 0;
    wire in_ready;
    reg out_valid = 0;
    reg [7:0] out_data = 0;
    integer accepted = 0, checked = 0, stalls = 0, simultaneous = 0;
    integer cycle = 0;
    reg was_stalled = 0, was_output_stalled = 0;
    reg [7:0] held_input = 0, held_output = 0;
    reg break_hold;
    assign in_ready = !out_valid || out_ready;
    always #5 clk = ~clk;

    // One-slot elastic DUT: reset discards an outstanding result.
    always @(posedge clk) begin
        if (!rst_n) out_valid <= 0;
        else if (in_ready) begin
            out_valid <= in_valid;
            if (in_valid) out_data <= in_data ^ 8'ha5;
        end
    end

    // All accounting uses the actual pre-NBA handshake values.
    always @(posedge clk) begin
        cycle = cycle + 1;
        if (cycle > 100) $fatal(1, "WATCHDOG handshake");
        if (!rst_n) begin
            accepted = 0;
            checked = 0;
            stalls = 0;
            simultaneous = 0;
            was_stalled = 0;
            was_output_stalled = 0;
        end else begin
            if (was_stalled && (!in_valid || in_data !== held_input))
                $fatal(1, "INPUT_HOLD: cycle=%0d expected=%h actual=%h", cycle, held_input, in_data);
            if (was_output_stalled && (!out_valid || out_data !== held_output))
                $fatal(1, "OUTPUT_HOLD: cycle=%0d", cycle);
            if (in_valid && in_ready) accepted = accepted + 1;
            if (out_valid && out_ready) begin
                if (checked >= accepted || out_data !== (8'(checked) ^ 8'ha5))
                    $fatal(1, "HANDSHAKE_DATA: cycle=%0d index=%0d actual=%h", cycle, checked, out_data);
                checked = checked + 1;
            end
            if (in_valid && in_ready && out_valid && out_ready)
                simultaneous = simultaneous + 1;
            was_stalled = in_valid && !in_ready;
            was_output_stalled = out_valid && !out_ready;
            held_input = in_data;
            held_output = out_data;
            if (was_stalled) stalls = stalls + 1;
        end
    end

    initial begin
        break_hold = $test$plusargs("break_hold");
        repeat (2) @(negedge clk);
        rst_n = 1;
        in_valid = 1;
        // Fill the output slot, then reset while it contains an unconsumed result.
        repeat (2) @(negedge clk);
        if (accepted != 1 || !out_valid) $fatal(1, "RESET_SETUP");
        rst_n = 0;
        in_valid = 0;
        repeat (2) @(negedge clk);
        if (out_valid || accepted != 0 || checked != 0) $fatal(1, "RESET_FLUSH");
        rst_n = 1;
        while (checked < 8) begin
            in_valid = (accepted < 8);
            in_data = 8'(accepted);
            out_ready = (cycle % 4 >= 2);
            if (break_hold && was_stalled) in_data = in_data ^ 8'h80;
            @(negedge clk);
        end
        in_valid = 0;
        // Drain two extra cycles so duplicates cannot hide behind the last result.
        out_ready = 1;
        repeat (2) @(negedge clk);
        if (accepted != 8 || checked != 8 || out_valid || stalls == 0 || simultaneous == 0)
            $fatal(1, "INCOMPLETE_HANDSHAKE: accepted=%0d checked=%0d stalls=%0d simultaneous=%0d",
                   accepted, checked, stalls, simultaneous);
        $display("PASS handshake: accepted=%0d checked=%0d stalls=%0d simultaneous=%0d; reset flushed",
                 accepted, checked, stalls, simultaneous);
        $finish;
    end
endmodule
