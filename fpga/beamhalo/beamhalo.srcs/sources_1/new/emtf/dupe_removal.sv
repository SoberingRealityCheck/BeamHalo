`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/22/2022 10:13:39 AM
// Design Name: 
// Module Name: dupe_removal
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

typedef struct packed{
    seg_id_t    seg_id;
    logic [2:0] sub_st_id;
    logic       valid;
} dupe_removal_t;


module dupe_removal
#(trk_build_delay=0)
(
    attached_seg_ids, trk_features, trk_seg_v,
    attached_seg_ids_rm, trk_features_rm, trk_seg_v_rm,
    
    clk160, clk40
);

    `include "common.svh"
    
    input seg_id_t attached_seg_ids[max_num_layers];
    input trk_feat_t trk_features[num_trk_features];
    input wire trk_seg_v[max_num_layers];
    
    output seg_id_t attached_seg_ids_rm[max_num_layers];
    output trk_feat_t trk_features_rm[num_trk_features];
    output logic trk_seg_v_rm[max_num_layers];
       
    input clk160, clk40; // clk40 is only used for synchronization
    
    
    // Keep Track of Current Track id
    wire [$clog2(num_tracks)-1:0] curr_trk_num;
    synced_fold_counter #(.divisor(num_tracks), .period_to_zero(trk_build_delay)) i_seg_id_counter(.clk_slow(clk40), .clk_fast(clk160), .count_out(curr_trk_num));
    
    
    localparam num_stations = 5;
    localparam num_sub_stations = 4;
    
    // Layer priorities for each station
    localparam int dupe_priorities[num_stations][num_sub_stations] = '{
        '{0,  9,   1,  5}, // ME11 GE11 ME12 RE1
        '{2,  10,  6, -1}, // ME2, GE21, RE2
        '{3,  7,  -1, -1}, // ME3 RE3
        '{4,  8,  -1, -1}, // ME4 RE4
        '{11, -1, -1, -1}  // ME0
    };
    

    dupe_removal_t station_ids_sr[num_tracks-1][num_stations] = '{default: '0}; 

    always @(posedge clk160) begin
        logic invalidate_track;
        dupe_removal_t station_ids_tmp[num_tracks-1][num_stations];
        dupe_removal_t curr_trk_ids[num_stations];
        
        // Build station ids for current trk
        for(int st=0; st<num_stations; st++) begin
            curr_trk_ids[st].valid = 1'b0; // default to invalid
            for(int sub_st=num_sub_stations-1; sub_st>=0; sub_st--) begin // prioritizies first substation
                automatic int layer = dupe_priorities[st][sub_st];          
                if(layer != -1 && trk_seg_v[layer]) begin
                    curr_trk_ids[st].seg_id = attached_seg_ids[layer];
                    curr_trk_ids[st].sub_st_id = sub_st;
                    curr_trk_ids[st].valid = 1'b1;
                end
            end
        end
        
        
        if(curr_trk_num == '0)
            station_ids_tmp = '{default: '0};   // for tracks 0, compare with nothing and reset the sr
        else
            station_ids_tmp = station_ids_sr;
        
        
        // Compare Current Track with previous event tracks
        invalidate_track = 1'b0;
        for(int trk=0; trk<num_tracks-1; trk++)
            for(int st=0; st<num_stations; st++)
                if(curr_trk_ids[st].valid && curr_trk_ids[st] == station_ids_tmp[trk][st]) begin
                    invalidate_track |= 1'b1;
                end

        
        // Write Outputs
        if(invalidate_track) begin
            attached_seg_ids_rm <= '{default: '0};
            trk_features_rm <= '{default: '0};
            trk_seg_v_rm <= '{default: '0};
        end
        else begin
            attached_seg_ids_rm <= attached_seg_ids;
            trk_features_rm <= trk_features;
            trk_seg_v_rm <= trk_seg_v;
        end
        
        // Save track ids for next track
        if(invalidate_track)
            station_ids_sr[0] <= '{default: '0}; // Invalidated track cannot be used to remove future track
        else
            station_ids_sr[0] <= curr_trk_ids; 
            
        for(int trk=1; trk<num_tracks-1; trk++) begin
            station_ids_sr[trk] <= station_ids_tmp[trk-1]; // either the track before, or all 0's (for a new bx) 
        end
        
    
    end
    
    
    
    
    
    
    
    
    
endmodule
