`timescale 1ns/1ps
module race_order #(parameter REVERSE = 0)(input wire clk);
    reg data = 0, sampled = 0;
    integer current_value = 0, old_value = 0;
    generate
        if (REVERSE) begin : reverse_order
            always @(posedge clk) sampled <= data;
            // Deliberate bad example: drive on the DUT sampling edge.
            always @(posedge clk) data = ~data;
        end else begin : forward_order
            always @(posedge clk) data = ~data;
            always @(posedge clk) sampled <= data;
        end
    endgenerate
    always @(negedge clk) begin
        if (sampled === data) current_value = current_value + 1;
        else old_value = old_value + 1;
    end
    final $display("OBSERVE race reverse=%0d current=%0d old=%0d",
                   REVERSE, current_value, old_value);
endmodule

module tb_race;
    reg clk = 0;
    always #5 clk = ~clk;
    race_order #(.REVERSE(0)) a(clk);
    race_order #(.REVERSE(1)) b(clk);
    initial begin
        #81;
        $display("PASS race probe completed; neither ordering is a portable contract");
        $finish;
    end
endmodule
