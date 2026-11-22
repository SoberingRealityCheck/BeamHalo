// sim-only stand-in for the clk_wiz_for_tb IP, for verilator. NOT the real thing.
// clk360 has a period of 2.7778 ns, 9 of them make one 25 ns clk40. clk40 rises on every 9th clk360 edge.
`timescale 1ns / 1ps
module clk_wiz_for_tb(input clk40_i, output logic clk40, output logic clk160, output logic clk360, output logic locked);
    int n = 0;
    initial begin clk360 = 0; clk40 = 0; locked = 0; #20 locked = 1; end
    always #1.3889 clk360 = ~clk360;
    always @(posedge clk360) begin
        n <= (n == 8) ? 0 : n + 1;
        clk40 <= (n == 8) || (n < 3);
    end
    assign clk160 = clk40;   // nothing in the beam halo path uses clk160
endmodule
