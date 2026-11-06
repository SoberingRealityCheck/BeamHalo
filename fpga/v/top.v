`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2026 04:49:21 PM
// Design Name: 
// Module Name: top
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


module top(
    input SYSCLK_P,
    input SYSCLK_N,
    output reg GPIO_LED_4_LS
);

    reg [29:0] cnt = 0;
    wire rst_cnt;
   wire sysclk;
   
   IBUFDS IBUFDS_inst (
      .O(sysclk),   // 1-bit output: Buffer output
      .I(SYSCLK_P),   // 1-bit input: Diff_p buffer input (connect directly to top-level port)
      .IB(SYSCLK_N)  // 1-bit input: Diff_n buffer input (connect directly to top-level port)
   );
   
   clk_wiz_0 clock_instance
   (
    // Clock out ports
    .clk_out1(sysclk100),     // output clk_out1
   // Clock in ports
    .clk_in1(sysclk)      // input clk_in1
);


   
    always @(posedge sysclk100) begin
        if(cnt >= 200_000_000 || rst_cnt) begin
            cnt <= 0;
            GPIO_LED_4_LS <= ~GPIO_LED_4_LS;
        end
        else 
            cnt <= cnt + 1;
          
    end
    
    vio_0 your_instance_name (
      .clk(sysclk100),                // input wire clk
      .probe_out0(rst_cnt)  // output wire [0 : 0] probe_out0
    );
    
    
    ila_0 ila_instance (
	.clk(sysclk100), // input wire clk


	.probe0(cnt), // input wire [29:0]  probe0  
	.probe1(GPIO_LED_4_LS) // input wire [0:0]  probe1
);

endmodule