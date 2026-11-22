`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/07/2022 03:45:57 PM
// Design Name: 
// Module Name: pattern_matcher_bh
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

module pattern_matcher_bh
(
    hitmap_section,
    curr_fold_num_i,
    patt_matches_r,
    clk
);
    
    `include "common.svh"
    
    // beam halo tables. 1 zone and 1 pattern padded out to the same aspect ratio so stuff doesnt break TODO: is this a stupid way of solving this problem?
    `include "patterns_bh.svh"
    
    input [padded_fold_cols_wmux-1:0] hitmap_section[num_zones][num_hitmap_rows];
    input logic [$clog2(fold_factor)-1:0] curr_fold_num_i;
    output patt_match_t patt_matches_r[num_zones][num_fold_cols_wmux];
    
    input clk;
    
    
    /****************************** Get Activations - compare hm section to patterns *******************************/
    wire [num_hitmap_rows-1:0] activations[num_zones][num_fold_cols_wmux][num_patterns];

    // this uses a variable bitwidth selection so it's easier in generate statement
    genvar zone,row,patt,col;
    generate        
        for(zone=0; zone < num_zones; zone++) begin
            for(row=0; row < num_hitmap_rows; row++) begin
                for(col=0; col<num_fold_cols_wmux; col++) begin
                    for(patt=0; patt < num_patterns; patt++) begin            
                        // Bitwise OR hitmap columns in pattern range
                        localparam col_start = col + col_start_table_bh[zone][patt][row];
                        localparam col_stop = col + col_stop_table_bh[zone][patt][row];
                        assign activations[zone][col][patt][row] = |hitmap_section[zone][row][col_stop : col_start];
                    end
                end
            end
        end
    endgenerate
    

    // ***************************** Quality Lookup - 2clks **********************
    (* rom_style = "distributed" *) logic [num_hitmap_rows-1:0] col_activations[num_zones][num_fold_cols_wmux][num_patterns];
    (* rom_style = "distributed" *) trk_qual_t activation_qualities[num_zones][num_fold_cols_wmux][num_patterns];
    
    always @(posedge clk) begin
        for(int zone=0; zone < num_zones; zone++)begin
            for(int col=0; col<num_fold_cols_wmux; col++)begin
                for(int patt=0; patt < num_patterns; patt++)begin
                    // zones and patterns past num_zones_bh / num_patterns_bh are padding. force them to "nothing hit" (quality 0)
                    // we keep the loops at 3 x 7 so the pipeline latency matches his (recombine_folds depends on it)
                    // see earlier TODO in this file for more details but this may be a dumb fix
                    // but hey it works
                    if( zone >= num_zones_bh || patt >= num_patterns_bh
                        || (col==0 && curr_fold_num_i==0) || (col==num_fold_cols_wmux-1 && curr_fold_num_i==fold_factor-1))
                        col_activations[zone][col][patt] <= '0; // For off the edge columns, set activations to 0 (needed because we multiplex using folds)
                    else
                        col_activations[zone][col][patt] <= activations[zone][col][patt];
                    activation_qualities[zone][col][patt] <= pattern_activations_bh[zone][col_activations[zone][col][patt]];
                end
            end
        end    
    end // always @(posedge clk)
    
    
    
    // ************************** Intra column sorting - clog2(num_patterns) clks **********************
    // Timing: ~2.7ns (for full sorting)

    localparam n_sort_stages = $clog2(num_patterns) + 1; // 7patts -> 4 stages, 9patts -> 5 stages (sorting is done between stages, so 4 stages has 3 sorts)
    patt_match_t qual_sorting[num_zones][num_fold_cols_wmux][n_sort_stages][num_patterns+1] = '{default: '0}; // extra 1 for odd # of patterns to have a pair
    
    // First sorting pipeline stage
    always @(posedge clk) begin
        patt_match_t qual_sorting_tmp[num_zones][num_fold_cols_wmux][n_sort_stages][num_patterns+1]; // extra 1 for odd # of patterns to have a pair
              
        // Get best quality for each col
        for(int zone=0; zone < num_zones; zone++)begin
            for(int col=0; col<num_fold_cols_wmux; col++)begin
            
                // Assign first stage (already registered)         
                for(int patt=0; patt < num_patterns; patt++)begin
                    qual_sorting[zone][col][0][patt].qual = activation_qualities[zone][col][patt];
                    qual_sorting[zone][col][0][patt].patt = patt;
                end
                
                // go through sorting stages: best quality of every pair goes to next stage (lower pattern # takes priority if equal)
                for(int stage=0; stage<n_sort_stages-1; stage++) begin
                    for(int patt=0; patt<num_patterns; patt+=2) begin
                        automatic patt_match_t tmp1 = qual_sorting[zone][col][stage][patt];  // pat_num
                        automatic patt_match_t tmp2 = qual_sorting[zone][col][stage][patt+1]; // pat_num+1
                        qual_sorting[zone][col][stage+1][patt/2] <= (tmp2.qual > tmp1.qual)? tmp2 : tmp1;
                    end
                end
            end
        end        
    end // always @()
    
    
    // Assign module output (already registered)
    always @(*) begin
        for(int zone=0; zone < num_zones; zone++)
            for(int col=0; col<num_fold_cols_wmux; col++)
                patt_matches_r[zone][col] = qual_sorting[zone][col][n_sort_stages-1][0]; // highest quality end at position 0
    end
    
    
endmodule
