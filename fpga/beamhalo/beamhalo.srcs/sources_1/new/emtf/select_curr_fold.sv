`timescale 1ns / 1ps

/**************** Details ******************
*    -Takes merged hitmaps (for 1 or more bxs) and outputs a single fold per trk_find_clk period
*       - New hitmap flag - input that says hitmap input is a new hitmap
*        
*   Delay Information: (2 clks)
*       - 1 clk for loading the hitmap into a selection shift register
*       - 1 clk for loading correct fold into output register
*********************************************/


`include "types.svh"

module select_curr_fold(
    merged_hitmaps, new_hitmap_flag,
    curr_fold_section_r,
    curr_fold_num_o,
    
    trk_find_clk
);
    
    `include "common.svh"
    
    localparam delay_extra_clks = 1;
    
    input [num_hitmap_cols-1:0] merged_hitmaps[num_zones][num_hitmap_rows];
    input new_hitmap_flag;
    
    output logic [padded_fold_cols_wmux-1:0] curr_fold_section_r[num_zones][num_hitmap_rows];   // current section of hitmaps (input to matcher)
    output logic [$clog2(fold_factor)-1:0] curr_fold_num_o;
    
    input trk_find_clk;
    
    
    reg [padded_hitmap_cols_wmux-1:0] padded_merged_hitmaps_r[num_zones][num_hitmap_rows]; // registered hitmaps
    
    always @(posedge trk_find_clk) begin
        
        for(int zone=0; zone<num_zones; zone++) begin
            for(int row=0; row<num_hitmap_rows; row++) begin
                automatic reg [max_padding_wmux-1:0] padding = '0;
                
                // Select folds
                if(new_hitmap_flag) // load hm
                    padded_merged_hitmaps_r[zone][row] <= {padding, merged_hitmaps[zone][row], padding};
                else // shift hm
                    padded_merged_hitmaps_r[zone][row][0 +: (padded_hitmap_cols_wmux - num_fold_cols)] <= padded_merged_hitmaps_r[zone][row][num_fold_cols +: (padded_hitmap_cols_wmux - num_fold_cols)];
                    
                curr_fold_section_r[zone][row] <= padded_merged_hitmaps_r[zone][row][0 +: padded_fold_cols_wmux];
                
            end
        end
        
        // Output the fold number
        if(new_hitmap_flag)
            curr_fold_num_o <= fold_factor-delay_extra_clks; // when new hitmap is recieved, last fold section is output
        else begin
            if(curr_fold_num_o == fold_factor-1)
                curr_fold_num_o <= '0;   
             else
                curr_fold_num_o <= curr_fold_num_o + 1; 
        end
        
    end // always ()
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    /********************** OLD IMPLEMENTATION - (uses MUX selection instead of gapped shift register) **********************
    input wire [num_hitmap_cols-1:0] hitmaps_r40[num_zones][num_hitmap_rows]; // must be registered before module
    output wire [padded_fold_cols_wmux-1:0] curr_fold_section_r[num_zones][num_hitmap_rows];      // current section of hitmaps (input to matcher)
    
    input clk40, trk_find_clk;
    
    wire [max_padding_wmux-1:0] padding = '0;
    reg [padded_hitmap_cols_wmux-1:0] hitmaps_padded[num_zones][num_hitmap_rows]; // full hitmaps padded
    reg [padded_fold_cols_wmux-1:0] next_fold_sr[delay_input_clks][num_zones][num_hitmap_rows];     // register to hold next section
    
    
    // Wire the output 
    assign curr_fold_section_r = next_fold_sr[0];
     
    // Get the period of the trk finding clock
    wire [$clog2(fold_factor)-1:0] curr_period_count; 
    synced_fold_counter #(.divisor(fold_factor), .period_to_zero(0)) i_input_fold_counter(.clk_slow(clk40), .clk_fast(trk_find_clk), .count_out(curr_period_count));  
       
        
    // handle fold section shift register
    always @(posedge trk_find_clk) begin

        for(int zone=0; zone<num_zones; zone++) begin
            for(int row=0; row<num_hitmap_rows; row++) begin
            
                // Register input @trk_find_clk rate with padding
                hitmaps_padded[zone][row] <= {padding, hitmaps_r40[zone][row], padding};
                
                // Fill the shift register with each section (if timing is tight, this can be done in stages)
                next_fold_sr[delay_input_clks-1][zone][row] <= hitmaps_padded[zone][row][(curr_period_count * num_fold_cols) +: padded_fold_cols_wmux];
                
                // shift (not used when delay is only 1)
                for(int i=0; i<delay_input_clks-1; i++) begin
                    next_fold_sr[i][zone][row] <= next_fold_sr[i+1][zone][row]; 
                end         
            end
        end  
    end
    */ 
    
    
endmodule
