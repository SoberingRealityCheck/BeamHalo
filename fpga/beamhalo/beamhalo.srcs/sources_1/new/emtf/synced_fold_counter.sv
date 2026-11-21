`timescale 1ns / 1ps

//  Takes 2 synchronous clocks (with no phase difference)
//  and outputs the fast clk period count within a slow clk period
//  -After a shared rising edge, the count is 0, and increments at each fast clk posedge


module synced_fold_counter
#( parameter divisor=6,       // how many fast clk periods are in 1 slow clk period
   parameter period_to_zero=0 //which period to reset counter to zero (if after slow clk edge: period_to_zero=0)
)
(
    clk_slow,
    clk_fast,
    count_out
);
    
    input clk_slow, clk_fast;
    output reg [$clog2(divisor)-1:0] count_out;
    
    reg sync_flag = 0;  // flips after a slow clk edge
    reg follow_sync_flag = 0;   // tracks the sync flag to know when change occurs
    reg [$clog2(divisor)-1:0] iphase = 0;
             
    always @(posedge clk_fast) begin
        reg [$clog2(divisor)-1:0] iphase_tmp;
        iphase_tmp = iphase;
        
        if(follow_sync_flag != sync_flag)
            iphase_tmp = 1;            
        else begin          
            if(iphase_tmp >= divisor-1)
                iphase_tmp = 0;
            else
                iphase_tmp++;   
        end
        
        count_out <= (iphase_tmp >= period_to_zero)? (iphase_tmp-period_to_zero) : (divisor-period_to_zero + iphase_tmp);
        iphase <= iphase_tmp;
        follow_sync_flag <= sync_flag;  // takes 1 clk after slow clk edge to be equal (so unequal flags means period=0)
    end
    
    always @(posedge clk_slow) begin
        sync_flag <= ~sync_flag;    // switch every clock cycle
    end
    
endmodule
