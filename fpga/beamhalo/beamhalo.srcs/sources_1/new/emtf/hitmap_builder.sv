`timescale 1ns / 1ps

/**************** Details **************************************************************************
*    -Takes 1bx of emtf segments per 40MHz clock and builds a merged hitmap (with 1 or more bxs)
*        -For resource savings, it serializes the building by doing 1 segment per chamber in each trk_find_clk period
*        
*   Timing:
        1 trk_find_clk to build single segment hitmaps (ch hitmap for a single segment)
        1 trk_find_clk to merge single segment hitmaps 
        1 trk_find_clk to merge hitmaps across bx (regardless of if hm is only 1 bx)
        
        So, merged_hitmaps should change at the same time the new_hitmap_flag_o is pulsed 
*
*****************************************************************************************************/

`include "types.svh"

module hitmap_builder(
    curr_seg_cols, curr_seg_zones_v, hm_new_bx_flag,
    merged_hitmaps, new_hitmap_flag_o,
    trk_find_clk
);
    
    
     `include "common.svh"
    
    input trk_col_t curr_seg_cols[num_hosts][max_ch_host];
    input zones_t curr_seg_zones_v[num_hosts][max_ch_host];
    input hm_new_bx_flag;
    
    output reg [num_hitmap_cols-1:0] merged_hitmaps[num_zones][num_hitmap_rows] = '{default: '0};
    output reg new_hitmap_flag_o;
    
    input trk_find_clk;

    // Parameters
    localparam single_ch_cols = 90;

    // Build Hitmap for each row or reset if necessary
    reg [num_hitmap_cols-1:0] single_seg_hitmaps[num_zones][num_hitmap_rows];
    reg [num_hitmap_cols-1:0] hitmaps[num_zones][num_hitmap_rows]; 
    reg new_hitmap_flag, new_hitmap_flag_r; 
    reg [num_hitmap_cols-1:0] hitmaps_sr[bxs][num_zones][num_hitmap_rows] = '{default: '0}; // registered hitmap

    always @(posedge trk_find_clk) begin
        
        // Pass on flag - Needed later for folding hitmap
        new_hitmap_flag <= hm_new_bx_flag;      // Flag to restart hitmap
        new_hitmap_flag_r <= new_hitmap_flag;   // Flag saved along with new hitmap
        new_hitmap_flag_o <= new_hitmap_flag_r; // Flag passed to output with merged hitmap

        // Build Hitmaps for each row (using only current segments)          
        for(int zone=0; zone<num_zones; zone++) begin
            for(int row=0; row<num_hitmap_rows; row++) begin
                automatic reg [ph_init_max+single_ch_cols:0] row_hm_tmp = '0; // simple fix for last ME0 chamber (allow space for it, then just cut it off later) 
                for(int host_in_row=0; host_in_row<num_hosts_by_row[zone][row]; host_in_row++) begin
                    automatic int unsigned curr_host = hosts_by_row[zone][row][host_in_row];
                    automatic int unsigned ch_type = type_by_host[curr_host];               
                    for(int ch=0; ch<ch_per_host_bt[ch_type]; ch++) begin
                        automatic reg [single_ch_cols-1:0] ch_hitmap_tmp = '0;
                        automatic trk_col_t seg_col_idx = curr_seg_cols[curr_host][ch] - ph_init_bt[ch_type][ch]; // Calculate the chamber column
                        
                        if(curr_seg_zones_v[curr_host][ch][zone])
                            ch_hitmap_tmp[seg_col_idx] = 1'b1;
                                     
                        // 3 chamber types have different offsets and coverage
                        if( ch_type == ten_deg)
                            row_hm_tmp[ph_init_bt[0][ch] +: max_coverage_bt[0]] |= ch_hitmap_tmp[0 +: max_coverage_bt[0]];
                        else if(ch_type == twenty_deg)
                            row_hm_tmp[ph_init_bt[1][ch] +: max_coverage_bt[1]] |= ch_hitmap_tmp[0 +: max_coverage_bt[1]];
                        else
                            row_hm_tmp[ph_init_bt[2][ch] +: max_coverage_bt[2]] |= ch_hitmap_tmp[0 +: max_coverage_bt[2]];  
                                          
                    end // chamber
                end // host    
                
                single_seg_hitmaps[zone][row] <= row_hm_tmp[hitmap_offset +: num_hitmap_cols]; // Row for single segment number
            end // row
        end // zone
        

        // Combine single segment hitmaps (clear it for new bx batch)
        for(int zone=0; zone<num_zones; zone++) begin
            for(int row=0; row<num_hitmap_rows; row++) begin
                if(new_hitmap_flag == 1'b1) begin
                    hitmaps[zone][row] <= single_seg_hitmaps[zone][row]; // Restart hitmap from 1st segment
                    
                    hitmaps_sr[bxs-1][zone][row] <= hitmaps[zone][row]; // Save finished hitmap - next hitmap belongs to next bx
                    
                    for(int i=0; i<bxs-1; i++)
                        hitmaps_sr[i][zone][row] <= hitmaps_sr[i+1][zone][row]; // shift other bx hitmaps (if multiple bxs)
                end
                else begin
                    hitmaps[zone][row] <= hitmaps[zone][row] | single_seg_hitmaps[zone][row];
                end   
            end // row   
        end // zone  


        // Handle BX merging - hitmaps in sr are finished
        for(int zone=0; zone<num_zones; zone++) begin
            for(int row=0; row<num_hitmap_rows; row++) begin
                automatic reg [num_hitmap_cols-1:0] merged_hitmaps_tmp = '0;
                // Merge Hitmaps Across BXs
                for(int bx=0; bx < bxs; bx++) begin
                    merged_hitmaps_tmp |= hitmaps_sr[bx][zone][row];
                end
                
                merged_hitmaps[zone][row] <= merged_hitmaps_tmp;
            end
        end    
                   
    end // always()
          
endmodule
