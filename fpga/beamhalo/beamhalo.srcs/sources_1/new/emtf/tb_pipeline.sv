`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/20/2022 09:42:20 AM
// Design Name: 
// Module Name: tb_pipeline
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

module tb_pipeline
#( parameter prompt_or_displaced=0,
    parameter emtf_segs_delay_40MHz=5) 
(
    emtf_segs_i, best_tracks_i,
    
    attached_seg_ids_o, trk_features_o, trk_seg_v_o,
    attached_seg_ids_rm, trk_features_rm, trk_seg_v_rm,
    
    clk40,
    clk160
);

    `include "common.svh"
    
    input emtf_seg_t emtf_segs_i[num_hosts][max_ch_host][max_seg_ch];
    input best_trk_t best_tracks_i[num_tracks];

    output seg_id_t attached_seg_ids_o[max_num_layers];
    output trk_feat_t trk_features_o[num_trk_features];
    output wire trk_seg_v_o[max_num_layers];
    
    output seg_id_t attached_seg_ids_rm[max_num_layers];
    output trk_feat_t trk_features_rm[num_trk_features];
    output wire trk_seg_v_rm[max_num_layers];

    input clk40, clk160;

    
    // Get next track index (use track 0 at clk period 1)
    wire [$clog2(num_tracks)-1:0] next_track_idx;
    synced_fold_counter #(.divisor(num_tracks), .period_to_zero(0)) i_curr_trk_counter(.clk_slow(clk40), .clk_fast(clk160), .count_out(next_track_idx));
    
    best_trk_t curr_track;
    emtf_seg_t curr_emtf_segs_r160[num_hosts][max_ch_host][max_seg_ch];
    always @(posedge clk160) begin
        // EMTF segs and track are registered together
        curr_track <= best_tracks_i[next_track_idx];
        curr_emtf_segs_r160 <= emtf_segs_i;
    end


    // *** Build the current track ***
    single_trk_builder #(prompt_or_displaced) i_single_trk_builder( 
        .best_trk(curr_track), 
        .emtf_segs(curr_emtf_segs_r160), 
        .attached_seg_ids_o(attached_seg_ids_o), .trk_features_o(trk_features_o), .trk_seg_v_o(trk_seg_v_o), 
        .clk(clk160)
    );

    // *** Duplicate Removal ***
    localparam trk_build_delay = 9; // 8 for trk building + 1 for the emtf_segs_r160 reg
    dupe_removal #(trk_build_delay % 4) i_dupe_removal(.attached_seg_ids(attached_seg_ids_o), .trk_features(trk_features_o), .trk_seg_v(trk_seg_v_o), 
                                    .attached_seg_ids_rm(attached_seg_ids_rm), .trk_features_rm(trk_features_rm), .trk_seg_v_rm(trk_seg_v_rm), .clk160(clk160), .clk40(clk40));   






endmodule
