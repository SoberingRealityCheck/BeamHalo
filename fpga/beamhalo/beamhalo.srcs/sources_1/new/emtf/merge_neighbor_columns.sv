`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/09/2022 02:36:07 PM
// Design Name: 
// Module Name: merge_neighbor_columns
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

`include "types.svh"

module merge_neighbor_columns(
    patt_matches,
    merged_cols,
    clk
);
    
    `include "common.svh"
    
    `include "sort_functions.svh"
    
    input patt_match_t patt_matches[num_zones][num_fold_cols_wmux];   
    output best_trk_t merged_cols[num_zones][num_merged_fold_cols]; // Output from: merge_neighbors -> sort4 -> single merge 8 layer (div by 2)
    
    input clk;
    
    // Intermediate Registered Values
    best_trk_t suppressed_cols[num_zones][num_suppressed_fold_cols];
    
    always @(posedge clk) begin

        reg [num_fold_cols-1:0] suppress[num_zones];
        best_trk_t suppressed_cols_tmp[num_zones][num_suppressed_fold_cols];    
        
        // Set initially to 0
        suppressed_cols_tmp = '{default: '0};
        
        for(int zone=0; zone<num_zones; zone++) begin
            // suppress cols that aren't local maximum quality eg: if(q <= qbefore || q < qafter)
            // Skip first and last cols (they are from neighbor fold)
            suppress[zone] = '0;
            for(int col=1; col<num_fold_cols_wmux-1; col++) begin
                if ((patt_matches[zone][col].qual <= patt_matches[zone][col-1].qual) || (patt_matches[zone][col].qual < patt_matches[zone][col+1].qual)) begin
                    suppress[zone][col-1] = 1'b1;
                end
            end
            
            // Pick best of every neighbor pair (half the # of columns)
            for(int scol=0; scol<num_suppressed_fold_cols; scol++) begin
                if (suppress[zone][2*scol] == 1'b0) begin 
                    suppressed_cols_tmp[zone][scol].qual = patt_matches[zone][2*scol+1].qual;
                    suppressed_cols_tmp[zone][scol].patt = patt_matches[zone][2*scol+1].patt;
                    suppressed_cols_tmp[zone][scol].col = 2*scol;
                end
                else  if (suppress[zone][2*scol+1] == 1'b0) begin
                    suppressed_cols_tmp[zone][scol].qual = patt_matches[zone][2*scol+2].qual;
                    suppressed_cols_tmp[zone][scol].patt = patt_matches[zone][2*scol+2].patt;
                    suppressed_cols_tmp[zone][scol].col = 2*scol+1;
                end
                else begin
                    suppressed_cols_tmp[zone][scol] = '0; // suppressed
                end        
            end
       end
       
       // Register intermediate values
       suppressed_cols <= suppressed_cols_tmp;
   
   end // always @()
   
   

   // Sort Every Four - ~3ns - 3clks
   best_trk_t sort4_stage1_cols[num_zones][num_suppressed_fold_cols];
   best_trk_t sort4_stage2_cols[num_zones][num_suppressed_fold_cols];
   best_trk_t suppressed_and_sorted_cols[num_zones][num_suppressed_fold_cols];
   always @(posedge clk) begin
       for(int zone=0; zone<num_zones; zone++) begin
            // Sort every 4
            for(int scol=0; scol<num_suppressed_fold_cols; scol+=4) begin
                // Staged Sort 4 
                best_trk_t stg1_out[4];
                best_trk_t stg2_out[4];
                best_trk_t stg3_out[4];
                
                sort_four_stage1( suppressed_cols[zone][scol +: 4], stg1_out);
                sort_four_stage2( sort4_stage1_cols[zone][scol +: 4], stg2_out);
                sort_four_stage3( sort4_stage2_cols[zone][scol +: 4], stg3_out);
                
                sort4_stage1_cols[zone][scol +: 4] <= stg1_out;
                sort4_stage2_cols[zone][scol +: 4] <= stg2_out;
                suppressed_and_sorted_cols[zone][scol +: 4] <= stg3_out;
            end            
        end
    end // always @()

    
    
    best_trk_t merge8_l1_out[num_zones][(num_suppressed_fold_cols/2)];
    
    generate
        for(genvar zone=0; zone<num_zones; zone++) begin
            // First Merge 8 layer (16 -> 8 fold cols) - 3clks
            merge8 #(num_suppressed_fold_cols) merge8_layer1(.roads_in(suppressed_and_sorted_cols[zone]), .roads_out(merge8_l1_out[zone]), .clk(clk));
            
            // Second Merge 8 layer (8 -> 4 fold cols) - 3clks
            merge8 #(num_suppressed_fold_cols/2) merge8_layer2(.roads_in(merge8_l1_out[zone]), .roads_out(merged_cols[zone]), .clk(clk));
        end
    endgenerate
       
    
endmodule
