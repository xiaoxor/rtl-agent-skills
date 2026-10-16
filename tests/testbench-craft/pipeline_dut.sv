`timescale 1ns/1ps
// Identity pipeline matching portable-valid-result.sv's N -> N+1 contract.
module dut (
    input wire clk, rst_n, in_valid,
    input wire [7:0] in_data,
    output reg out_valid = 0,
    output reg [7:0] out_data = 0
);
    reg pending = 0;
    reg [7:0] payload = 0;
    reg corrupt, drop;
    initial begin
        corrupt = $test$plusargs("corrupt");
        drop = $test$plusargs("drop");
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            pending <= 0;
            out_valid <= 0;
            payload <= 0;
            out_data <= 0;
        end else begin
            pending <= in_valid;
            payload <= in_data;
            out_valid <= pending && !drop;
            out_data <= corrupt ? (payload ^ 8'h01) : payload;
        end
    end
endmodule
