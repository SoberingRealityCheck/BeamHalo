`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/24/2022 11:09:20 AM
// Design Name: 
// Module Name: tf_pipeline_bh
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// this is exactly identical to the normal tf_pipeline module
// except for the fact that it instantiates the beamhalo pattern matcher
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "types.svh"

module tf_pipeline_bh
(
    merged_hitmaps, new_hitmap_flag,
    best_tracks_o,

    trk_find_clk
);
    
    `include "common.svh"
     
    input [num_hitmap_cols-1:0] merged_hitmaps[num_zones][num_hitmap_rows];
    input new_hitmap_flag; // pulsed for new hitmap
    
    output best_trk_t best_tracks_o[num_tracks];

    input trk_find_clk;

        
    /****************** Step 1: Get current hitmap section ***********************/
    wire [padded_fold_cols_wmux-1:0] curr_fold[num_zones][num_hitmap_rows];
    wire [$clog2(fold_factor)-1:0] curr_fold_num;
    select_curr_fold i_select_curr_fold(.merged_hitmaps(merged_hitmaps), .new_hitmap_flag(new_hitmap_flag), .curr_fold_section_r(curr_fold), .curr_fold_num_o(curr_fold_num), .trk_find_clk(trk_find_clk));
   
    /****************** Step 2: Pattern Matching  *************************/  
    patt_match_t best_fold_matches_r[num_zones][num_fold_cols_wmux];
    pattern_matcher_bh i_pattern_matcher_bh( .hitmap_section(curr_fold), .curr_fold_num_i(curr_fold_num), .patt_matches_r(best_fold_matches_r), .clk(trk_find_clk));
    
    /****************** Step 3: Initial Sorting of Column Matches  **********************/ 
    best_trk_t merged_cols_fold[num_zones][num_merged_fold_cols];
    merge_neighbor_columns i_merge_neighbor_columns( .patt_matches(best_fold_matches_r), .merged_cols(merged_cols_fold), .clk(trk_find_clk));
    
    /****************** Step 4: Recombine the folds before sorting *********************************/
    // Note: if your column numbers are wrong, it is probably because this modules timing is wrong
    best_trk_t merged_cols_all[num_zones][num_merged_hitmap_cols]; // mcols after single merge8
    recombine_folds i_recombine_folds(.new_hitmap_flag(new_hitmap_flag), .merged_cols_fold(merged_cols_fold), .merged_cols_all(merged_cols_all), .clk(trk_find_clk));

    /****************** Step 5: Track Sorting *********************************/
    find_best_tracks i_find_best_tracks( .merged_cols_i(merged_cols_all), .best_tracks(best_tracks_o), .clk(trk_find_clk));
    
   
endmodule
