`timescale 1ns / 1ps



`include "types.svh"

module hitmap_builder_bh(
    curr_seg_cols,          // current segment columns
    curr_seg_valid,         // valid bit of our current segment
    hm_new_bx_flag,         // new bunch crossing flag
    merged_hitmaps,         // output 
    new_hitmap_flag_o,      // output to tell when a new hitmap has been published
    trk_find_clk            // clock
);

    `include "common.svh"

    // current track columns is an array of track column types
    input trk_col_t curr_seg_cols[num_hosts][max_ch_host]; 
    // is this segment valid? beam halo ignores zones and only needs this bit
    input logic curr_seg_valid[num_hosts][max_ch_host];
    // new bunch crossing flag is a 1bit
    input hm_new_bx_flag;

    output reg [num_hitmap_cols-1:0] merged_hitmaps[num_zones][num_hitmap_rows] = '{default: '0};
    output reg new_hitmap_flag_o;
    input trk_find_clk;

    // parameters, pretty much copied from normal track finder
    localparam single_ch_cols = 90;

    // beam halo rows. these replace num_hosts_by_row and hosts_by_row from common.svh
    // this is bc our zones are different for beam halo: 
    // we are trying to gather data around a path with a roughly consistent distance from the beam pipe 
    // (and we don't really care about small theta) 
    // so we only really have one singular zone to worry about
    // from EMTFModel.cc bh_zone_hm, with C++ site names turned into our host names:
    //   row0 ME12 | row1 RE12 | row2 GE21+RE22 | row3 ME21+ME22
    //   row4 ME31+ME32 | row5 RE31+RE32 | row6 ME41+ME42 | row7 RE41+RE42
    localparam int unsigned num_hosts_by_row_bh[num_hitmap_rows] = '{1, 1, 2, 2, 2, 2, 2, 2};
    localparam [31:0] hosts_by_row_bh[num_hitmap_rows][2] = '{
        {ME12, no_host}, {RE12, no_host}, {GE21, RE22}, {ME21, ME22},
        {ME31, ME32},    {RE31, RE32},    {ME41, ME42}, {RE41, RE42}
    };

    // build hitmap for each row or reset if necessary, copied from normal track finder
    reg [num_hitmap_cols-1:0] single_seg_hitmaps[num_zones][num_hitmap_rows];
    reg [num_hitmap_cols-1:0] hitmaps[num_zones][num_hitmap_rows]; 
    reg new_hitmap_flag, new_hitmap_flag_r; 
    reg [num_hitmap_cols-1:0] hitmaps_sr[bxs][num_zones][num_hitmap_rows] = '{default: '0}; // registered hitmap

    // clocked loop 
    always @(posedge trk_find_clk) begin
        
        // pass on the flag to fold the hitmap in later?
        new_hitmap_flag <= hm_new_bx_flag;      // Flag to restart hitmap
        new_hitmap_flag_r <= new_hitmap_flag;   // Flag saved along with new hitmap
        new_hitmap_flag_o <= new_hitmap_flag_r; // Flag passed to output with merged hitmap

        // main important chunk here: build the hitmaps! nested loopss iterate over every row,col coord 
        for(int zone=0; zone<num_zones; zone++) begin
            for(int row=0; row<num_hitmap_rows; row++) begin
                automatic reg [ph_init_max+single_ch_cols:0] row_hm_tmp = '0; // extra room for the last ME0 chamber, same as the main track finder

                // beam halo has one zone. zones 1 and up never touch row_hm_tmp, so they stay empty
                if (zone == 0) begin
                    // select a host in this row
                    for(int host_in_row=0; host_in_row<num_hosts_by_row_bh[row]; host_in_row++) begin
                        automatic int unsigned curr_host = hosts_by_row_bh[row][host_in_row];
                        automatic int unsigned ch_type = type_by_host[curr_host];
                        // pick a chamber within that host
                        for(int ch=0; ch<ch_per_host_bt[ch_type]; ch++) begin
                            automatic reg [single_ch_cols-1:0] ch_hitmap_tmp = '0;
                            automatic trk_col_t seg_col_idx = curr_seg_cols[curr_host][ch] - ph_init_bt[ch_type][ch]; // chamber column

                            // beam halo only needs the segment to be valid. zones don't matter
                            if(curr_seg_valid[curr_host][ch])
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
                end // zone 0

                // // Row for single segment number
                single_seg_hitmaps[zone][row] <= row_hm_tmp[hitmap_offset +: num_hitmap_cols];
            end // row
        end //zone



        // cool, now we combine the single segment hitmaps 
        // nested zone, row loops again
        for(int zone=0; zone<num_zones; zone++) begin
            for(int row=0; row<num_hitmap_rows; row++) begin
                // if it's a new hitmap we reset from the beginning!
                if(new_hitmap_flag == 1'b1) begin
                    hitmaps[zone][row] <= single_seg_hitmaps[zone][row]; // Restart hitmap from 1st segment
                    
                    hitmaps_sr[bxs-1][zone][row] <= hitmaps[zone][row]; // Save finished hitmap - next hitmap belongs to next bx
                    
                    for(int i=0; i<bxs-1; i++)
                        hitmaps_sr[i][zone][row] <= hitmaps_sr[i+1][zone][row]; // shift other bx hitmaps (if multiple bxs)
                end
                else begin
                    // otherwise, just keep layering single segments into the main hitmap
                    hitmaps[zone][row] <= hitmaps[zone][row] | single_seg_hitmaps[zone][row];
                end   
            end //row
        end // zone


        // exact same as main track finder
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