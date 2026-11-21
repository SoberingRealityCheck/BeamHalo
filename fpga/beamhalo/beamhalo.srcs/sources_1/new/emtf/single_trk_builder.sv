`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/09/2024 12:26:25 PM
// Design Name: 
// Module Name: single_trk_builder
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

module single_trk_builder
#( parameter prompt_or_displaced=0) // prompt = 0
(
    best_trk,
    emtf_segs,
    
    attached_seg_ids_o,
    trk_features_o,
    trk_seg_v_o,
 
    clk
);

    `include "common.svh"
    
    `include "patterns.svh"
    
    `include "sort_functions.svh"
  
    input best_trk_t best_trk;
    input emtf_seg_t emtf_segs[num_hosts][max_ch_host][max_seg_ch];

    output seg_id_t attached_seg_ids_o[max_num_layers];
    output trk_feat_t trk_features_o[num_trk_features];
    output reg trk_seg_v_o[max_num_layers];

    input clk;
    
    
    localparam attach_segs_delay = 5;   // Takes 4 clks
    localparam th_median_delay = 2;     // Takes 2 clk
    localparam combined_delay = attach_segs_delay + th_median_delay;

        
    
    // Shift registers to hold output until last stage
    best_trk_t best_trk_sr[combined_delay];
    emtf_seg_t attached_segs_sr[combined_delay][max_num_layers];
    seg_id_t attached_seg_ids_sr[combined_delay][max_num_layers];
    
    // Stage outputs
    emtf_theta_t th_median;
    emtf_seg_t attached_segs[max_num_layers];
    seg_id_t attached_seg_ids[max_num_layers];   
    
    
    // Shifting for values that need to be held
    always @(posedge clk) begin
        // Add vals to sr
        best_trk_sr[0] <= best_trk;
        attached_segs_sr[0] <= attached_segs;
        attached_seg_ids_sr[0] <= attached_seg_ids;
        
        // shift
        for(int i=0; i<combined_delay-1; i++) begin
            best_trk_sr[i+1]        <= best_trk_sr[i];
            attached_segs_sr[i+1]   <= attached_segs_sr[i];
            attached_seg_ids_sr[i+1] <= attached_seg_ids_sr[i];
        end
    end
    
    
    // Stage 1: Find segment based on Phi
    find_best_segs_in_phi #(prompt_or_displaced) i_find_best_segs_in_phi( .best_trk(best_trk), .emtf_segs_i(emtf_segs), .best_phi_segs(attached_segs), .best_seg_ids(attached_seg_ids), .clk(clk));

    // Stage 2: Find Theta Median using attached segments
    find_th_median i_find_th_median(.best_trk(best_trk_sr[attach_segs_delay-1]), .attached_segs(attached_segs), .th_median(th_median), .clk(clk));
    
    // Stage 3: Build the track


    /************************** Stage 3 select best thetas, and prepare output ************************/
    
    //localparam th_window = 8; // if diff <= th_window, it is invalid 
    localparam int unsigned theta_window_map[2][num_zones][max_num_layers] = '{
        '{ // prompt
            {5, 0, 2, 2, 2, 34, 0, 3, 3, 5, 6, 5},
            {5, 9, 5, 4, 5, 14, 7, 7, 7, 7, 7, 4},
            {11, 6, 5, 6, 6, 10, 8, 8, 9, 8, 0, 0}
        },
        '{ // displaced
            {14, 40, 4, 3, 3, 45, 0, 4, 4, 15, 8, 13},
            {16, 18, 7, 5, 5, 22, 7, 7, 8, 17, 9, 14},
            {26, 15, 8, 9, 9, 17, 11, 9, 10, 26, 21, 0}
        }
    };
    
    
    
        
    always @(posedge clk) begin    
        emtf_seg_t tmp_segs[max_num_layers];
        
        trk_feat_t trk_features_tmp[num_trk_features];
        reg trk_seg_v_tmp[max_num_layers];
        
        emtf_phi_t ph_median;
        ph_median = ( (best_trk_sr[combined_delay-1].col + hitmap_offset) << bits_to_shift) + middle_of_range; // Ph Median Calculation
          
        for(int layer=0; layer<max_num_layers; layer++) begin
            emtf_seg_t curr_hit;
            curr_hit = attached_segs_sr[th_median_delay-1][layer];
            tmp_segs[layer] = curr_hit;
                     
            if(curr_hit.valid) begin
                // set with invalid values
                automatic emtf_theta_t th_window = theta_window_map[prompt_or_displaced][best_trk_sr[combined_delay-1].zone][layer];
                automatic emtf_theta_t diff1 = th_window + 1;
                automatic emtf_theta_t diff2 = th_window + 1;

                // Calc abs theta 1 diff
                if(curr_hit.theta1 != 0) begin
                    if(th_median > curr_hit.theta1)
                        diff1 = th_median - curr_hit.theta1;
                    else
                        diff1 = curr_hit.theta1 - th_median;
                end

                // Calc abs theta 2 diff
                if(curr_hit.theta2 != 0) begin
                    if(th_median > curr_hit.theta2)
                        diff2 = th_median - curr_hit.theta2;
                    else
                        diff2 = curr_hit.theta2 - th_median;
                end

                if(diff2 < diff1 && diff2 < th_window) begin
                    // Attach theta 2 as correct theta
                    tmp_segs[layer].theta1 = tmp_segs[layer].theta2;
                end
                else if( diff1 >= th_window) begin
                    tmp_segs[layer].theta1 = 0; // invalid
                    tmp_segs[layer].valid = 0;
                end
            end
        end // layer

        
        
        // zero all track features to make sure everything gets set 
        trk_features_tmp = '{default: '0};
    
    
        // Collect Segment Features Phi, Theta, and valid bits
        for(int layer=0; layer<max_num_layers; layer++) begin
            if(tmp_segs[layer].valid) begin
                trk_features_tmp[layer] = tmp_segs[layer].phi - ph_median; // get signed phi difference
                trk_features_tmp[layer+max_num_layers] = tmp_segs[layer].theta1 - th_median; // get signed theta difference
                trk_seg_v_tmp[layer] = 1'b1;
            end
            else begin
                trk_features_tmp[layer] = '0;
                trk_features_tmp[layer+max_num_layers] = '0; // get signed phi difference
                trk_seg_v_tmp[layer] = 1'b0;
            end
        end
          
        // Collect the rest of the features manually for now
        trk_features_tmp[24] = $signed( (tmp_segs[0].valid)? tmp_segs[0].bend : '0); // Bends are sign extended
        trk_features_tmp[25] = $signed( (tmp_segs[1].valid)? tmp_segs[1].bend : '0);
        trk_features_tmp[26] = $signed( (tmp_segs[2].valid)? tmp_segs[2].bend : '0);
        trk_features_tmp[27] = $signed( (tmp_segs[3].valid)? tmp_segs[3].bend : '0);
        trk_features_tmp[28] = $signed( (tmp_segs[4].valid)? tmp_segs[4].bend : '0);
        trk_features_tmp[29] = $signed( (tmp_segs[11].valid)? tmp_segs[11].bend : '0);
        
        trk_features_tmp[30] = (tmp_segs[0].valid)? tmp_segs[0].qual1 : '0;
        trk_features_tmp[31] = (tmp_segs[1].valid)? tmp_segs[1].qual1 : '0;
        trk_features_tmp[32] = (tmp_segs[2].valid)? tmp_segs[2].qual1 : '0;
        trk_features_tmp[33] = (tmp_segs[3].valid)? tmp_segs[3].qual1 : '0;
        trk_features_tmp[34] = (tmp_segs[4].valid)? tmp_segs[4].qual1 : '0;
        trk_features_tmp[35] = (tmp_segs[11].valid)? tmp_segs[11].qual1  : '0;
        
        trk_features_tmp[36] = (ph_median - 2744); // centers the ph_median range at 0 -> Note: 2744 = ((288cols/2 + 27) << 4) + 8
        trk_features_tmp[37] = th_median;
        trk_features_tmp[38] = best_trk_sr[combined_delay-1].qual;
        trk_features_tmp[39] = '0; //trk bx
        
        
        // If trk quality is 0, all outputs are 0 (everything else still runs but has no effect)
        if(best_trk_sr[combined_delay-1].qual == '0) begin
            for(int i=0; i<num_trk_features; i++)
                trk_features_tmp[i] = '0;
                
            for(int layer=0; layer<max_num_layers; layer++)
                trk_seg_v_tmp[layer] = 1'b0;
        end
        
        
        // Register the Outputs
        attached_seg_ids_o  <= attached_seg_ids_sr[th_median_delay-1];
        trk_features_o      <= trk_features_tmp;
        trk_seg_v_o         <= trk_seg_v_tmp;
        
    end // always @()

endmodule
