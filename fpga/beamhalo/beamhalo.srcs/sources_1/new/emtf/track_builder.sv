`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/22/2022 11:21:26 AM
// Design Name: 
// Module Name: track_builder
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

module track_builder
(
    // Inputs
    emtf_segs,
    prompt_best_tracks, disp_best_tracks,
    
    // Outputs
    pr_attached_seg_ids_rm, disp_attached_seg_ids_rm,
    pr_trk_features_rm,     disp_trk_features_rm,
    pr_trk_seg_v_rm,        disp_trk_seg_v_rm,
    
    // Clocks
    clk40,
    clk160
);

    `include "common.svh"

    input emtf_seg_t emtf_segs[num_hosts][max_ch_host][max_seg_ch];
    input best_trk_t prompt_best_tracks[num_tracks];
    input best_trk_t disp_best_tracks[num_tracks];
        
    output seg_id_t pr_attached_seg_ids_rm[max_num_layers]; 
    output seg_id_t disp_attached_seg_ids_rm[max_num_layers];
    output trk_feat_t pr_trk_features_rm[num_trk_features];
    output trk_feat_t disp_trk_features_rm[num_trk_features];
    output logic pr_trk_seg_v_rm[max_num_layers];
    output logic disp_trk_seg_v_rm[max_num_layers];   
                          
    input clk40;
    input clk160;
    
    
    // Prompt Track Building                                                                    
    tb_pipeline #(.prompt_or_displaced(0)) i_prompt_tb_pipeline( 
        .emtf_segs_i(emtf_segs), 
        .best_tracks_i(prompt_best_tracks),
        .attached_seg_ids_rm(pr_attached_seg_ids_rm), .trk_features_rm(pr_trk_features_rm), .trk_seg_v_rm(pr_trk_seg_v_rm),
        .clk40(clk40), .clk160(clk160)
    );
    
    // Displaced Track Building
    tb_pipeline #(.prompt_or_displaced(1)) i_disp_tb_pipeline( 
        .emtf_segs_i(emtf_segs), 
        .best_tracks_i(disp_best_tracks),
        .attached_seg_ids_rm(disp_attached_seg_ids_rm), .trk_features_rm(disp_trk_features_rm), .trk_seg_v_rm(disp_trk_seg_v_rm),
        .clk40(clk40), .clk160(clk160)
    );


endmodule
