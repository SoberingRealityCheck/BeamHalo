`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
//  Handles a single Merge 8 layer - Sorting from 8 roads, down to 4
//      - Can take any multiple of 8 as an input length
//
//


`include "types.svh"

module merge8 #(
    parameter N_ROADS = 8 // number of merge 8's in parallel
)(
    input  best_trk_t roads_in[N_ROADS],
    output best_trk_t roads_out[N_ROADS/2],
    input clk
);

    // Make sure N_ROADS is a multiple of 8
    generate
        if( (N_ROADS % 8 != 0) && (N_ROADS > 0) ) begin
            $error("%m ** Illegal Condition ** N_ROADS(%d) is not a multiple of 8", N_ROADS);
        end
    endgenerate
    
    
    // Stage output registers
    best_trk_t stage1_outr[N_ROADS] = '{default: '0};
    best_trk_t stage2_outr[N_ROADS] = '{default: '0};

    always @(posedge clk) begin
        for(int road_num=0; road_num<N_ROADS; road_num+=8) begin            
            // Staged merge 8 
            best_trk_t in[8];
            best_trk_t stg1_out[6];
            best_trk_t stg2_in[6];
            best_trk_t stg2_out[5];
            best_trk_t stg3_in[5];
            best_trk_t stg3_out[4];
            
            
            // Stage 1: compare-swap if (wire[i] < wire[j]) swap(wire[j], wire[i]) - lowest 2 don't make it past this stage
            in = roads_in[road_num +: 8];
            stg1_out[0] = (in[0].qual < in[4].qual) ? in[4] : in[0];
            stg1_out[1] = (in[1].qual < in[5].qual) ? in[5] : in[1];
            stg1_out[2] = (in[2].qual < in[6].qual) ? in[6] : in[2];
            stg1_out[3] = (in[3].qual < in[7].qual) ? in[7] : in[3];
            stg1_out[4] = (in[0].qual < in[4].qual) ? in[0] : in[4];
            stg1_out[5] = (in[1].qual < in[5].qual) ? in[1] : in[5];
            
            // Stage 2 
            stg2_in = stage1_outr[road_num +: 6]; // grab registered stg1 outputs
            stg2_out[0] = stg2_in[0];
            stg2_out[1] = stg2_in[1];
            stg2_out[2] = (stg2_in[2].qual < stg2_in[4].qual) ? stg2_in[4] : stg2_in[2];
            stg2_out[3] = (stg2_in[3].qual < stg2_in[5].qual) ? stg2_in[5] : stg2_in[3];
            stg2_out[4] = (stg2_in[2].qual < stg2_in[4].qual) ? stg2_in[2] : stg2_in[4];
            
            // Stage 3
            stg3_in = stage2_outr[road_num +: 5]; // grab registered stg2 outputs
            stg3_out[0] = stg3_in[0];
            stg3_out[1] = (stg3_in[1].qual < stg3_in[2].qual) ? stg3_in[2] : stg3_in[1];
            stg3_out[2] = (stg3_in[1].qual < stg3_in[2].qual) ? stg3_in[1] : stg3_in[2];
            stg3_out[3] = (stg3_in[3].qual < stg3_in[4].qual) ? stg3_in[4] : stg3_in[3];
            
            // Register stage outputs
            stage1_outr[road_num +: 6] <= stg1_out;
            stage2_outr[road_num +: 5] <= stg2_out;
            roads_out[(road_num/2) +: 4] <= stg3_out;
        end
    end         
            


endmodule
