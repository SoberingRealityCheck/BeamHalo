`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/23/2022 10:04:26 AM
// Design Name: 
// Module Name: find_best_segs_in_phi
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

module find_best_segs_in_phi
#( parameter prompt_or_displaced=0) // prompt = 0
(
    best_trk,
    emtf_segs_i,
    
    best_phi_segs,
    best_seg_ids,
    
    clk
);

    `include "common.svh"
    
    `include "patterns.svh"
    
    input best_trk_t best_trk;
    input emtf_seg_t emtf_segs_i[num_hosts][max_ch_host][max_seg_ch];
    
    output emtf_seg_t best_phi_segs[max_num_layers];
    output seg_id_t best_seg_ids[max_num_layers];

    input clk;
    
    
    // ******* Stage 1: Get the possible segments for this track ************

    // Values to hold for later stages
    emtf_seg_t emtf_segs[num_hosts][max_ch_host][max_seg_ch];
    trk_col_t patt_start_col_padded[num_hosts];
    trk_col_t patt_mid_col_padded[num_hosts];
    trk_col_t patt_stop_col_padded[num_hosts];
    trk_col_t patt_mid_col[num_hosts];
    emtf_phi_t patt_mid_ph[num_hosts];
    trk_zone_t trk_zone;
    
    
    // Get track pattern parameters for each host
    always @(posedge clk) begin
        automatic trk_zone_t trk_zone_tmp = best_trk.zone;
        automatic trk_patt_t trk_patt_tmp = best_trk.patt; 
        automatic trk_col_t col_corr_tmp = best_trk.col + hitmap_offset;  // 27 bc of start of col offset (get column for full 315 col width)

        // These hold pattern info for each row
        trk_col_t patt_start_col_padded_br[num_hitmap_rows];
        trk_col_t patt_mid_col_padded_br[num_hitmap_rows];
        trk_col_t patt_stop_col_padded_br[num_hitmap_rows];
        trk_col_t patt_mid_col_br[num_hitmap_rows];
        emtf_phi_t patt_mid_ph_br[num_hitmap_rows];
        
        // Get Pattern info by row
        for(int row=0; row<num_hitmap_rows; row++) begin     
            patt_start_col_padded_br[row] = col_corr_tmp + col_start_table[prompt_or_displaced][trk_zone_tmp][trk_patt_tmp][row]; // tables have max_padding build in
            patt_mid_col_padded_br[row]   = col_corr_tmp + col_mid_table  [prompt_or_displaced][trk_zone_tmp][trk_patt_tmp][row];
            patt_stop_col_padded_br[row]  = col_corr_tmp + col_stop_table [prompt_or_displaced][trk_zone_tmp][trk_patt_tmp][row];
            patt_mid_col_br[row] = (patt_mid_col_padded_br[row] <= max_padding)? '0 : (patt_mid_col_padded_br[row] - max_padding);  
            patt_mid_ph_br[row] = (patt_mid_col_br[row] << bits_to_shift) + middle_of_range; // middle of pattern for this row at phi precision
        end
        
        
        ////////// Register the tracks parameters and emtf segments ///////////////
        emtf_segs <= emtf_segs_i;
        trk_zone  <= trk_zone_tmp;
        
        for(int host=0; host<num_hosts; host++) begin
            automatic int host_row = host_row_by_zone[trk_zone_tmp][host]; // -1 is invalid
            if(host_row != -1) begin
                // These values don't matter if this host isn't in this zone
                patt_start_col_padded[host] <= patt_start_col_padded_br[host_row]; // tables have max_padding build in
                patt_mid_col_padded[host]   <= patt_mid_col_padded_br[host_row];
                patt_stop_col_padded[host]  <= patt_stop_col_padded_br[host_row];
                patt_mid_col[host] <= patt_mid_col_br[host_row];
                patt_mid_ph[host]  <= patt_mid_ph_br[host_row];
            end
        end   
    end // always @()    
        
        
        
    // Values passed to  later stages
    trk_col_t patt_start_col_padded_r[num_hosts];
    trk_col_t patt_mid_col_padded_r[num_hosts];
    trk_col_t patt_stop_col_padded_r[num_hosts];
    trk_col_t patt_mid_col_r[num_hosts];
    emtf_phi_t patt_mid_ph_r[num_hosts];
    trk_zone_t trk_zone_r;
    
    emtf_seg_wid_t segs_wid_r[num_hosts][max_ch_per_gate][max_seg_ch];
    
    
    // Get Potential Segments for Track
    always @(posedge clk) begin
    
        emtf_seg_wid_t segs_wid_tmp[num_hosts][max_ch_per_gate][max_seg_ch];
        segs_wid_tmp = '{default: '0};

        // Get valid segments for each host
        for(int host=0; host<num_hosts; host++) begin
            automatic int host_type = type_by_host[host];
            automatic logic invalid_host = (host_row_by_zone[trk_zone][host] == -1)? 1'b1 : 1'b0; // -1 means host isn't in this tracks zone
               
            for(int ch_in_gate=0; ch_in_gate<ch_per_gate_bt[host_type]; ch_in_gate++) begin
                
                // Get the current gate (gives the possible chambers for this track)
                automatic logic [$clog2(num_gates):0] curr_gate = 0;
                for(int i=0; i<num_gates-1; i++) begin
                    if(patt_mid_col[host] >= gate_edges[i])
                        curr_gate = i+1; // max is (num_gates-1)
                end
            
                for(int iseg=0; iseg<host_seg_ch[host]; iseg++) begin                   
                    // The real chamber id in current host (note if host is invalid this could be any gate)
                    automatic int curr_ch = map_gated_chambers_bt[host_type][curr_gate][ch_in_gate]; 
                    
                    if(invalid_host == 1'b0) begin
                        // Fill these values (and use emtf_seg.valid to handle invalid host)
                        segs_wid_tmp[host][ch_in_gate][iseg].emtf_seg = emtf_segs[host][curr_ch][iseg];
                        segs_wid_tmp[host][ch_in_gate][iseg].seg_id.ichamber = curr_ch;
                        segs_wid_tmp[host][ch_in_gate][iseg].seg_id.iseg = iseg;
                    end
                end // iseg              
            end // chamber in gate
        end // host   
                  
        // Register things for next stage
        segs_wid_r  <= segs_wid_tmp;
        trk_zone_r  <= trk_zone;
        patt_start_col_padded_r <= patt_start_col_padded;
        patt_mid_col_padded_r   <= patt_mid_col_padded;
        patt_stop_col_padded_r  <= patt_stop_col_padded;
        patt_mid_col_r          <= patt_mid_col;
        patt_mid_ph_r           <= patt_mid_ph;
        
    end // always()
   
   
   
   
    // *********** Get Segment and Pattern Middle diffs and find best segment ************
    
    emtf_seg_wid_and_diff_t seg_sorting_r1[num_hosts][max_ch_per_gate][max_seg_ch];
    
    always @(posedge clk) begin
        emtf_seg_wid_and_diff_t gated_segs_and_diffs_tmp[num_hosts][max_ch_per_gate][max_seg_ch];
   
        for(int host=0; host<num_hosts; host++) begin
            automatic int host_type = type_by_host[host];

            for(int ch_in_gate=0; ch_in_gate<ch_per_gate_bt[host_type]; ch_in_gate++) begin
                for(int iseg=0; iseg<host_seg_ch[host]; iseg++) begin
                    emtf_seg_t curr_seg;
                    trk_col_t curr_seg_col_padded;
                    logic good_segment;
                    
                    curr_seg = segs_wid_r[host][ch_in_gate][iseg].emtf_seg;
                    curr_seg_col_padded = (curr_seg.phi >> 4) + max_padding; //real 315bit col w/ padding
   
                    good_segment = (curr_seg.valid &&                                    // Segment is valid 
                                    curr_seg.zones[trk_zone_r] == 1 &&          // Segment is within this zone
                                    curr_seg_col_padded >= patt_start_col_padded_r[host] && // Segment is within pattern
                                    curr_seg_col_padded <= patt_stop_col_padded_r[host]);

                    if(good_segment) begin
                        // abs diff
                        emtf_phi_t diff;
                        
                        if(patt_mid_ph_r[host] > curr_seg.phi)
                            diff = patt_mid_ph_r[host]- curr_seg.phi;
                        else
                            diff = curr_seg.phi - patt_mid_ph_r[host];

                        gated_segs_and_diffs_tmp[host][ch_in_gate][iseg].diff = diff;
                    end
                    else begin
                        gated_segs_and_diffs_tmp[host][ch_in_gate][iseg].diff = '1; // max diff (marks invalid segment for this track)
                    end
                    
                    gated_segs_and_diffs_tmp[host][ch_in_gate][iseg].seg_id = segs_wid_r[host][ch_in_gate][iseg].seg_id;
                    gated_segs_and_diffs_tmp[host][ch_in_gate][iseg].emtf_seg = curr_seg;       
                              
                    // Register the segments for sorting
                    seg_sorting_r1[host][ch_in_gate][iseg] <= gated_segs_and_diffs_tmp[host][ch_in_gate][iseg];             

                end // iseg                
            end // chamber
        end // host 
    end // always()
    
    
    
    // **************** Get the best segments in each chamber ************
    emtf_seg_wid_and_diff_t best_ch_segs[num_hosts][max_ch_per_gate];
    
    always @(posedge clk) begin 
        emtf_seg_wid_and_diff_t ch_sorting_tmp[num_hosts][max_ch_per_gate][max_seg_ch];  
        ch_sorting_tmp = seg_sorting_r1;
        
        for(int host=0; host<num_hosts; host++) begin
            automatic int host_type = type_by_host[host];
            for(int ch_in_gate=0; ch_in_gate<ch_per_gate_bt[host_type]; ch_in_gate++) begin

                // Sorting within Chamber
                for(int n_segs_to_comp=host_seg_ch[host]; n_segs_to_comp>1; n_segs_to_comp=(n_segs_to_comp / 2)+1) begin  
                    for(int iseg=0; iseg<n_segs_to_comp; iseg+=2) begin        
                        if((iseg+1 >= n_segs_to_comp) || ch_sorting_tmp[host][ch_in_gate][iseg].diff <= ch_sorting_tmp[host][ch_in_gate][iseg+1].diff)
                            ch_sorting_tmp[host][ch_in_gate][iseg/2] = ch_sorting_tmp[host][ch_in_gate][iseg]; // pass on lower diff (or extra one if there is an extra)
                        else
                            ch_sorting_tmp[host][ch_in_gate][iseg/2] = ch_sorting_tmp[host][ch_in_gate][iseg+1];
                    end
                    ch_sorting_tmp[host][ch_in_gate][n_segs_to_comp / 2] = '{default:'1}; // invalidate extra seg if it exists
                    if(n_segs_to_comp <= 2)
                        n_segs_to_comp = 0; // ends the loop
                end

                // Register best segment in each chamber
                best_ch_segs[host][ch_in_gate] <= ch_sorting_tmp[host][ch_in_gate][0];
            end
  
        end // host    
    end // always()
    
    


    // ************** Get the Best Segments by layer ***************************
    // Note: up to this point, diff='1 has signified an invalid segment (need to invalidate it here)
    
    always @(posedge clk) begin
        emtf_seg_wid_and_diff_t best_host_segs[num_hosts];
        
        for(int host=0; host<num_hosts; host++) begin
            automatic int host_type = type_by_host[host];
            best_host_segs[host] = best_ch_segs[host][0];
            
            // Runs once for 20deg chambers, twice for 10deg chambers
            for(int ch_in_gate=1; ch_in_gate<ch_per_gate_bt[host_type]; ch_in_gate++) begin
                if( best_ch_segs[host][ch_in_gate].diff < best_host_segs[host].diff)
                    best_host_segs[host] = best_ch_segs[host][ch_in_gate];
                else if(best_ch_segs[host][ch_in_gate].diff == best_host_segs[host].diff && best_ch_segs[host][ch_in_gate].seg_id.ichamber < best_host_segs[host].seg_id.ichamber)
                    best_host_segs[host] = best_ch_segs[host][ch_in_gate]; // next chamber has priority over current best chamber and diffs are equal
            end
        end
        
        
        for(int layer=0; layer< max_num_layers; layer++) begin
            emtf_seg_wid_and_diff_t best_layer_seg;
            
            
            automatic int host0 = map_layers_to_hosts[layer][0];
            automatic int host1 = map_layers_to_hosts[layer][1];
        
            best_layer_seg = best_host_segs[host0];
            best_layer_seg.seg_id.ihost = 0;
            
            if(host1 != no_host) begin
                automatic logic tie_goes_to_host1 = ((best_host_segs[host0].seg_id.ichamber * 2) > (best_host_segs[host1].seg_id.ichamber +1));
                
                if( (best_host_segs[host1].diff < best_host_segs[host0].diff) || (tie_goes_to_host1 && best_host_segs[host1].diff == best_host_segs[host0].diff)) begin
                    best_layer_seg = best_host_segs[host1];
                    best_layer_seg.seg_id.ihost = 1;
                end
            end
            
            // Invalidate segments if diff is max 
            if( best_layer_seg.diff == '1) begin
                best_layer_seg.emtf_seg = '{default: '0}; // Zero everything (can change this to .valid only)
            end
            
            best_phi_segs[layer] <= best_layer_seg.emtf_seg;
            best_seg_ids[layer]  <= best_layer_seg.seg_id;
        end
        
    end    
    
    
    
endmodule
