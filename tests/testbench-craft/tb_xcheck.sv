`timescale 1ns/1ps
module tb_xcheck;
    reg [7:0] value;
    initial begin
        value = 8'hxx;
        #1;
        if (value !== 8'h00)
            $fatal(1, "UNKNOWN_REJECTED: value=%h", value);
        $display("PASS x probe: X initialization became zero, not proof of no unknowns");
        $finish;
    end
endmodule
