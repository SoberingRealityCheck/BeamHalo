`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/20/2024 01:14:12 PM
// Design Name: 
// Module Name: recombine_folds
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

module recombine_folds(
    new_hitmap_flag,
    merged_cols_fold,
    merged_cols_all,
    
    clk
);
    
    `include "common.svh"
    
    input new_hitmap_flag; // needs to be delayed
    input best_trk_t merged_cols_fold[num_zones][num_merged_fold_cols];
    
    output best_trk_t merged_cols_all[num_zones][num_merged_hitmap_cols]; // mcols after single merge8
    
    input clk;


    // ************* Timing Config (*** Change this if you change the pipeline)  ****************
    // This control how much to delay new hitmap flag for column merging - if you add a register in the pipeline, add 1 of these
    // $clog2(patts) is added bc patt matching delay varies w/num_patterns
    localparam COLS_FLAG_DELAY = (5 + $clog2(num_patterns)) % 9; 
       
    logic [COLS_FLAG_DELAY-1:0] new_cols_flag;
    
    always @(posedge clk) begin 
        new_cols_flag[COLS_FLAG_DELAY-1] <= new_hitmap_flag;
        for(int i=0; i<COLS_FLAG_DELAY-1; i++)
            new_cols_flag[i] <= new_cols_flag[i+1]; 
    end
    
    
        
    // Recombine the folds: shift them in, then register them all together (this keeps outputs stable for 9 clks)
    best_trk_t merged_cols_fold_sr[fold_factor][num_zones][num_merged_fold_cols]; // mcols after single merge8

    always @(posedge clk) begin
        best_trk_t merged_cols_tmp[num_zones][num_merged_hitmap_cols];
        merged_cols_tmp = '{default: '0};
        
        // Shift the merged cols into shift register
        merged_cols_fold_sr[fold_factor-1] <= merged_cols_fold;
        for(int fold=0; fold<fold_factor-1; fold++)
            merged_cols_fold_sr[fold] <= merged_cols_fold_sr[fold+1]; 


        // Add correction for column number (from fold column, to actual column) 
        for(int zone=0; zone<num_zones; zone++) begin
            for(int fold=0; fold<fold_factor; fold++) begin 
                for(int col=0; col<num_merged_fold_cols; col++) begin
                    merged_cols_tmp[zone][fold*num_merged_fold_cols + col] = merged_cols_fold_sr[fold][zone][col];
                    merged_cols_tmp[zone][fold*num_merged_fold_cols + col].col = merged_cols_tmp[zone][fold*num_merged_fold_cols + col].col + (fold * num_fold_cols);
                end
            end
        end // zone
            
        // Register all of the folds together when they are all ready
        if(new_cols_flag[0] == 1'b1) begin  
            merged_cols_all <= merged_cols_tmp;
        end
    end // always @()
    
       

endmodule
