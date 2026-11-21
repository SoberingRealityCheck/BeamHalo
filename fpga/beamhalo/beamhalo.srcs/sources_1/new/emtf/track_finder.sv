`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/22/2022 11:27:04 AM
// Design Name: 
// Module Name: track_finder
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

module track_finder(
    // Inputs
    emtf_segs_i,
    new_bx_flag_i,
    
    // Outputs
    prompt_best_tracks_o, disp_best_tracks_o,
    
    clk40, trk_find_clk 
);
   
    `include "common.svh" 
    
    input emtf_seg_t emtf_segs_i[num_hosts][max_ch_host]; // segments come in serialized @360MHz
    //input trk_col_t curr_seg_cols_i[num_hosts][max_ch_host];
    //input zones_t curr_seg_zones_v_i[num_hosts][max_ch_host];
    input new_bx_flag_i;
    
    output best_trk_t prompt_best_tracks_o[num_tracks];
    output best_trk_t disp_best_tracks_o[num_tracks];
   
    input clk40;
    input trk_find_clk;
    
    
    // ******** SLR CROSSING REGISTERS ************** //
    localparam SLR_CROSSING_REGS = 3;
    
    (* shreg_extract = "no" *) logic tf_new_bx_flag[SLR_CROSSING_REGS];
    (* shreg_extract = "no" *) trk_col_t curr_seg_cols[SLR_CROSSING_REGS][num_hosts][max_ch_host] = '{default:'0};
    (* shreg_extract = "no" *) zones_t curr_seg_zones_v[SLR_CROSSING_REGS][num_hosts][max_ch_host] = '{default:'0};
    
    always @(posedge trk_find_clk) begin
        tf_new_bx_flag[SLR_CROSSING_REGS-1] <= new_bx_flag_i; 
        
        for(int host=0; host<num_hosts; host++) begin
            automatic int unsigned ch_type = type_by_host[host];
            for(int ch=0; ch<ch_per_host_bt[ch_type]; ch++) begin
                curr_seg_cols[SLR_CROSSING_REGS-1][host][ch] <= (emtf_segs_i[host][ch].phi >> 4); // Conversion to double-strip resolution
                curr_seg_zones_v[SLR_CROSSING_REGS-1][host][ch] <= emtf_segs_i[host][ch].zones;
            end
        end
        
        for(int i=0; i<SLR_CROSSING_REGS-1; i++) begin 
            tf_new_bx_flag[i]   <= tf_new_bx_flag[i+1];
            curr_seg_cols[i]    <= curr_seg_cols[i+1]; 
            curr_seg_zones_v[i] <= curr_seg_zones_v[i+1];
        end
    end // always @()
    
    
    
    // ******** Run Track Finding Algorithm ************** //
    
    // Joint Hitmap Building (for now, if zones are the same)
    wire [num_hitmap_cols-1:0] merged_hitmaps[num_zones][num_hitmap_rows];
    wire new_hitmap_flag;
    hitmap_builder i_hitmap_builder(curr_seg_cols[0], curr_seg_zones_v[0], tf_new_bx_flag[0], merged_hitmaps, new_hitmap_flag, trk_find_clk);

    // Track Finding
    best_trk_t prompt_best_tracks[num_tracks], disp_best_tracks[num_tracks];
    tf_pipeline #(.prompt_or_displaced(0)) i_prompt_tf_pipeline(merged_hitmaps, new_hitmap_flag, prompt_best_tracks, trk_find_clk);
    tf_pipeline #(.prompt_or_displaced(1)) i_disp_tf_pipeline(merged_hitmaps, new_hitmap_flag, disp_best_tracks, trk_find_clk);

    
    
    // ******** Output SLR Crossing Registers ************** //
    
    always @(posedge clk40) begin
        prompt_best_tracks_o <= prompt_best_tracks;   
        disp_best_tracks_o <= disp_best_tracks;
    end
    
    
    
endmodule
