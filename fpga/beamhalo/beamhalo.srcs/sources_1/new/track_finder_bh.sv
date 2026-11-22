`include "types.svh"

module track_finder_bh(
    // Inputs!
    emtf_segs_i,            // emtf segment data input
    new_bx_flag_i,          // new bunch crossing flag input

    // Outputs!
    best_tracks_o,          // track output

    // clocks
    clk40,                  // 40 MHz BX rate
    trk_find_clk            // rate of new segment data
);
    `include "common.svh"

    input emtf_seg_t  emtf_segs_i[num_hosts][max_ch_host]; 
    input new_bx_flag_i;

    output best_trk_t best_tracks_o[num_tracks];

    input clk40;
    input trk_find_clk;


    // not sure what this does, TODO: figure out 
    // seems like some hardware interface technical thing
    // largely unrelated to algorithm
    // to send our track back out?
    // ******** SLR CROSSING REGISTERS ************** //
    localparam SLR_CROSSING_REGS = 3;
    
    (* shreg_extract = "no" *) logic tf_new_bx_flag[SLR_CROSSING_REGS];
    (* shreg_extract = "no" *) trk_col_t curr_seg_cols[SLR_CROSSING_REGS][num_hosts][max_ch_host] = '{default:'0};
    (* shreg_extract = "no" *) logic curr_seg_valid[SLR_CROSSING_REGS][num_hosts][max_ch_host] = '{default:'0};
    
    always @(posedge trk_find_clk) begin
        tf_new_bx_flag[SLR_CROSSING_REGS-1] <= new_bx_flag_i; 
        
        for(int host=0; host<num_hosts; host++) begin
            automatic int unsigned ch_type = type_by_host[host];
            for(int ch=0; ch<ch_per_host_bt[ch_type]; ch++) begin
                curr_seg_cols[SLR_CROSSING_REGS-1][host][ch] <= (emtf_segs_i[host][ch].phi >> 4); // Conversion to double-strip resolution
                curr_seg_valid[SLR_CROSSING_REGS-1][host][ch] <= emtf_segs_i[host][ch].valid;
            end
        end
        
        for(int i=0; i<SLR_CROSSING_REGS-1; i++) begin 
            tf_new_bx_flag[i]   <= tf_new_bx_flag[i+1];
            curr_seg_cols[i]    <= curr_seg_cols[i+1]; 
            curr_seg_valid[i]   <= curr_seg_valid[i+1];
        end
    end // always @()



    // ===== Running the track finding algorithm! =====

    // build joint hitmap (using our unique beamhalo hitmap builder)
    wire [num_hitmap_cols-1:0] merged_hitmaps[num_zones][num_hitmap_rows];
    wire new_hitmap_flag;
    hitmap_builder_bh i_hitmap_builder_bh(curr_seg_cols[0], curr_seg_valid[0], tf_new_bx_flag[0], merged_hitmaps, new_hitmap_flag, trk_find_clk);

    // track finding
    best_trk_t best_tracks[num_tracks];
    tf_pipeline_bh i_tf_pipeline_bh(merged_hitmaps, new_hitmap_flag, best_tracks, trk_find_clk);



    // ==== output: SLR crossing registers ====

    // literally just update tracks at same frequency as new BX 
    always @(posedge clk40) begin
        best_tracks_o <= best_tracks;
    end

endmodule