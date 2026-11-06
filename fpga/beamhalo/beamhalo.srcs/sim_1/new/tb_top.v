`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2026 04:52:53 PM
// Design Name: 
// Module Name: tb_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_top(
);


    reg clk_in;
    wire clk_out;
    
    initial begin
        clk_in = 1'b0;
        
        forever begin
            #2.5 clk_in = ~clk_in;   
        end
    end

   clk_wiz_0 clock_instance
   (
    // Clock out ports
    .clk_out1(clk_out),     // output clk_out1
   // Clock in ports
    .clk_in1(clk_in)      // input clk_in1
);


endmodule
