`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/23/2022 11:11:44 AM
// Design Name: 
// Module Name: find_th_median
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

module find_th_median(
    best_trk,
    attached_segs,
    th_median,
    clk
);
    
    `include "common.svh"
    
    `include "sort_functions.svh"
    
    input best_trk_t best_trk; 
    input emtf_seg_t attached_segs[max_num_layers];
    
    output emtf_theta_t th_median;
   
    input clk;
    
    
    
    localparam num_of_methods = 3; // 3 ways to calculate theta
    localparam thetas_per_method = 9; // each method requires 9 thetas
    localparam num_of_sections = 3; // 3 sections of 3 thetas
    
    localparam int layer_indices_for_median_calc[num_of_methods][thetas_per_method] = '{
                '{ 2,  3,  4, 2, 3, 4, 10,  7,  8}, // [ME2_t1, ME3_t1, ME4_t1, ME2_t2, ME3_t2, ME4_t2, GE2, RE3, RE4]
                '{ 2,  3,  4, 2, 3, 4,  6,  7,  8}, // [ME2_t1, ME3_t1, ME4_t1, ME2_t2, ME3_t2, ME4_t2, RE2, RE3, RE4]
                '{ 1,  0, 11, 1, 0, 11,  5,  9, 11} // [ME12_t1, ME11_t1, ME0_t2, ME12_t2, ME11_t2, ME0_t2, RE1, GE1, ME0_t1]
    };
    
    localparam int which_theta_to_use[num_of_methods][thetas_per_method] = '{ '{1,1,1, 2,2,2, 1,1,1}, '{1,1,1, 2,2,2, 1,1,1}, '{1,1,2, 2,2,2, 1,1,1} };
    
    
    localparam zone_to_use_alternative = 2;
    
    
    /****** Theta Median Stage 1 *******/
    best_trk_t best_trk_r; // hold best_trk for next stage
    emtf_theta_t median_of_sections[num_of_methods][num_of_sections]; // Output of this stage (the median of each section for each option)

    always @(posedge clk) begin
    
        emtf_theta_t thetas[num_of_methods][thetas_per_method]; // theta values for finding median
        emtf_theta_t median_of_sections_tmp[num_of_methods][num_of_sections]; // Output of this stage
        
        for(int opt=0; opt<num_of_methods; opt++) begin
            for(int th=0; th<thetas_per_method; th++) begin
                automatic int layer = layer_indices_for_median_calc[opt][th];
                automatic int which_th = which_theta_to_use[opt][th];

                if(attached_segs[layer].valid)
                    thetas[opt][th] = (which_th == 1)? attached_segs[layer].theta1 : attached_segs[layer].theta2;
                else
                    thetas[opt][th] = '0;
            end
        end
               
        // For each option (non-st1 default, non-st1 alternative, st1), Find median of every 3, then find median of those 
        for(int opt=0; opt<num_of_methods; opt++) begin        
            median_of_three(thetas[opt][0 +: 3], median_of_sections_tmp[opt][0]); // section 0
            median_of_three(thetas[opt][3 +: 3], median_of_sections_tmp[opt][1]); // section 1
            median_of_three(thetas[opt][6 +: 3], median_of_sections_tmp[opt][2]); // section 2
        end
        
        // Shift to next stage
        median_of_sections <= median_of_sections_tmp;
        best_trk_r <= best_trk;
    end
    
    
    
    /******* Theta Median Stage 2 *********/  
    always @(posedge clk) begin
        emtf_theta_t median_options[3];
            emtf_theta_t th_median_tmp;
        
        // For each option (non-st1 default, non-st1 alternative, st1), Find median of every 3, then find median of those 
        for(int opt=0; opt<3; opt++) begin
            median_of_three(median_of_sections[opt][0 +: 3], median_options[opt]);
        end

        if( best_trk_r.zone != zone_to_use_alternative)
            th_median_tmp = median_options[0];  // use standard (w/GE2)
        else
            th_median_tmp = median_options[1];  // use alternative (no GE2)

        // If above fails, try station 1 median
        if(th_median_tmp == '0)
            th_median_tmp = median_options[2];
        
        // If all of theta fails, the median is invalid
        if(th_median_tmp == '0)
            th_median_tmp = '0; // invalid theta value

        th_median <= th_median_tmp;      
    end

endmodule
