`timescale 1ns / 1ps


`include "types.svh"

module sp_wout_PC(
    // EMTF segments
    emtf_segs_i, 
    new_bx_flag_i,
    
    // Track Outputs
    pr_attached_seg_ids_o, pr_trk_features_o, pr_trk_seg_v_o,
    disp_attached_seg_ids_o, disp_trk_features_o, disp_trk_seg_v_o,
    pr_invpt_o, disp_invpt_o, disp_dist_o,
    
    // Clks
    clk40, clk160, clk360 
);
    
    `include "common.svh"
    
    // EMTF Segment Inputs
    input emtf_seg_t emtf_segs_i[num_hosts][max_ch_host]; // segments come in serialized @360MHz
    input new_bx_flag_i;
    
    // EMTF Outputs
    output seg_id_t pr_attached_seg_ids_o[max_num_layers];
    output trk_feat_t pr_trk_features_o[num_trk_features];
    output logic pr_trk_seg_v_o[max_num_layers];
    output seg_id_t disp_attached_seg_ids_o[max_num_layers];
    output trk_feat_t disp_trk_features_o[num_trk_features];
    output logic disp_trk_seg_v_o[max_num_layers];
    output logic [13:0] pr_invpt_o; 
    output logic [13:0]disp_invpt_o;
    output logic [13:0] disp_dist_o;
    
    // Clock Inputs
    input clk40, clk160, clk360;
    


    // ----------- Track Finding ---------------
    best_trk_t prompt_best_tracks[num_tracks];
    best_trk_t disp_best_tracks[num_tracks];
    
    track_finder i_track_finder(
        .emtf_segs_i(emtf_segs_i), 
        .new_bx_flag_i(new_bx_flag_i), 
        .prompt_best_tracks_o(prompt_best_tracks), 
        .disp_best_tracks_o(disp_best_tracks),
        .clk40(clk40), 
        .trk_find_clk(clk360)
    );
    
    
    // ----------- EMTF Segs Delay -------------- 
    emtf_seg_t emtf_segs_delayed[num_hosts][max_ch_host][max_seg_ch]; // multi-bx output (if using multiple bxs)
    
    coord_delay i_coord_delay(
        .emtf_segs_i(emtf_segs_i),
        .new_bx_flag_i(new_bx_flag_i),
        .emtf_segs_delayed(emtf_segs_delayed),
        .clk360(clk360),
        .clk40(clk40)
    );
   
   

    // ----------- Track Building ---------------          
    (* dont_touch="true" *) seg_id_t    pr_attached_seg_ids_rm[max_num_layers];
    (* dont_touch="true" *) seg_id_t    disp_attached_seg_ids_rm[max_num_layers];
    (* dont_touch="true" *) trk_feat_t  pr_trk_features_rm[num_trk_features];
    (* dont_touch="true" *) trk_feat_t  disp_trk_features_rm[num_trk_features];
    (* dont_touch="true" *) logic       pr_trk_seg_v_rm[max_num_layers];
    (* dont_touch="true" *) logic       disp_trk_seg_v_rm[max_num_layers];   
    
    track_builder i_track_builder(
                    emtf_segs_delayed, prompt_best_tracks, disp_best_tracks, // Inputs
                    pr_attached_seg_ids_rm, disp_attached_seg_ids_rm,
                    pr_trk_features_rm,     disp_trk_features_rm,
                    pr_trk_seg_v_rm,        disp_trk_seg_v_rm,
                    clk40, clk160
    );
                          
                          
    // ----------- Neural Networks ---------------
    //NN_wrapper i_NN_wrapper( pr_trk_features_rm, disp_trk_features_rm, pr_invpt_o, disp_invpt_o, disp_dist_o, clk160);
    
    // Outputs 
    assign pr_attached_seg_ids_o = pr_attached_seg_ids_rm; 
    assign pr_trk_features_o = pr_trk_features_rm;
    assign pr_trk_seg_v_o = pr_trk_seg_v_rm;
    assign disp_attached_seg_ids_o = disp_attached_seg_ids_rm; 
    assign disp_trk_features_o = disp_trk_features_rm;
    assign disp_trk_seg_v_o = disp_trk_seg_v_rm;
    

endmodule
