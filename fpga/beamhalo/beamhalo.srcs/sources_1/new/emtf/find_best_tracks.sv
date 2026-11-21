`timescale 1ns / 1ps

`include "types.svh"

module find_best_tracks(
    merged_cols_i,
    best_tracks,
    clk
);
    
    `include "common.svh"
    
    `include "sort_functions.svh"
    
    localparam num_stage1_trks = num_merged_hitmap_cols / 2;
    
    input best_trk_t merged_cols_i[num_zones][num_merged_hitmap_cols];
    output best_trk_t best_tracks[num_tracks];
    
    input clk;
    

    

    /****** Presort from 36 roads down to 32 (merge8's of first 8 roads) *******/
    // Note, this could be done when recombining to save latency
    
    localparam int sort_width = 32; // 32 for 36 merged_cols
    
    localparam nstages = $clog2(sort_width/4) + 1; // number of sorting stages (after pre-sort) = 5 (1 is for loading only)
    best_trk_t sort_stage1[num_zones][sort_width];
    
    // Merge8 for each zone
    generate
        for(genvar zone=0; zone<num_zones; zone++)
            merge8 #(8) merge8_presort(.roads_in(merged_cols_i[zone][0 +: 8]), .roads_out(sort_stage1[zone][0+:4]), .clk(clk));
    endgenerate
    
    // Hold rest of roads until merge8 is done
    best_trk_t merged_cols_delay[2][num_zones][num_merged_hitmap_cols];
    always @(posedge clk) begin 
        merged_cols_delay[1] <= merged_cols_i;
        merged_cols_delay[0] <= merged_cols_delay[1];
        
        for(int zone=0; zone<num_zones; zone++) 
            sort_stage1[zone][4 +: 28] <= merged_cols_delay[0][zone][8 +: 28];
    end
    
       
    /*******  Sort 32 roads per zone down to best 4 ********/
    best_trk_t sort_stage2[num_zones][16]; // 32->16
    best_trk_t sort_stage3[num_zones][8]; // 16->8
    best_trk_t sort_zones_stage1[12]; // 8->4 (per zone)
    
    // Sort from 32 to 4 in each zone
    generate
        for(genvar zone=0; zone<num_zones; zone++) begin
            merge8 #(32) merge8_stage1(.roads_in(sort_stage1[zone]), .roads_out(sort_stage2[zone]), .clk(clk));
            merge8 #(16) merge8_stage2(.roads_in(sort_stage2[zone]), .roads_out(sort_stage3[zone]), .clk(clk));
            merge8 #(8) merge8_stage3(.roads_in(sort_stage3[zone]), .roads_out(sort_zones_stage1[(zone*4) +: 4]), .clk(clk));
        end
    endgenerate
    
    
    
    /*******  Sort 12 roads (4 per zone) down to best 4 ********/
    best_trk_t sort_zones_stage2[8]; // 8->4 (per zone)
    
    // Hold last 4 roads, while first 8 are merged
    best_trk_t sort_zones_stage1_delay[2][4];
    always @(posedge clk) begin 
        sort_zones_stage1_delay[1] <= sort_zones_stage1[8+:4];
        sort_zones_stage1_delay[0] <= sort_zones_stage1_delay[1];
        sort_zones_stage2[4+:4] <= sort_zones_stage1_delay[0];
    end
    
    // Zone merging
    merge8 #(8) merge8_zones_stage1(.roads_in(sort_zones_stage1[0+:8]), .roads_out(sort_zones_stage2[0+:4]), .clk(clk));
    merge8 #(8) merge8_zones_stage2(.roads_in(sort_zones_stage2), .roads_out(best_tracks), .clk(clk));
    

            
endmodule