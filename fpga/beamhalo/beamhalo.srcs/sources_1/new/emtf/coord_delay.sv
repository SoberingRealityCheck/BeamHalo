`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//      Coord delay is responsible for:
//          1) Taking the emtf segments in at 360MHz (1 segment per chamber at a time)
//          2) Crossing them to 40MHz, with all segments in parallel per bx
//          3) Holding them until track finding is finished
//

`include "types.svh"

module coord_delay
#(parameter emtf_segs_delay_40MHz=0)
(
    emtf_segs_i,
    new_bx_flag_i,
    
    emtf_segs_delayed,
    
    clk360,
    clk40
);
    
    `include "common.svh"
   
    input emtf_seg_t emtf_segs_i[num_hosts][max_ch_host]; // Segments come in at 360MHz
    input new_bx_flag_i;
    
    output emtf_seg_t emtf_segs_delayed[num_hosts][max_ch_host][max_seg_ch]; 

    input clk360;
    input clk40;
    

       
    // ********* Step 1: Shift in the emtf segments at 360MHz
    //     - the amount shifted depends on the delay of the track finder
    //        since we need to catch the segs at the same 360MHz clock phase as we catch track outputs
    
    localparam TRK_FIND_SR_DELAY = 9 + (60 % 9); // Track Finding takes 60 clocks (from first segment arrival),
    
    logic new_bx_flag_sr[TRK_FIND_SR_DELAY];
    emtf_seg_t emtf_segs_sr360[num_hosts][max_ch_host][TRK_FIND_SR_DELAY]; // segments come in serialized @360MHz
    emtf_seg_t emtf_segs_r360[num_hosts][max_ch_host][max_seg_ch];  // holds all possible segments
    
    always @(posedge clk360) begin 
        new_bx_flag_sr[TRK_FIND_SR_DELAY-1] <= new_bx_flag_i;
        for(int i=0; i<(TRK_FIND_SR_DELAY-1); i++) begin 
            new_bx_flag_sr[i] <= new_bx_flag_sr[i+1];
        end
        
        for(int host=0; host<num_hosts; host++) begin
            automatic int unsigned ch_type = type_by_host[host];
            for(int ch=0; ch<ch_per_host_bt[ch_type]; ch++) begin
                emtf_segs_sr360[host][ch][TRK_FIND_SR_DELAY-1] <= emtf_segs_i[host][ch];
                
                // Shift register
                for(int i=0; i<(TRK_FIND_SR_DELAY-1); i++) begin 
                    emtf_segs_sr360[host][ch][i] <= emtf_segs_sr360[host][ch][i+1];
                end
            end  
        end
        
        if(new_bx_flag_sr[0] == 1'b1) begin
            for(int host=0; host<num_hosts; host++)
                for(int ch=0; ch<max_ch_host; ch++)
                    for(int seg=0; seg<max_seg_ch; seg++)
                        emtf_segs_r360[host][ch][seg] <= emtf_segs_sr360[host][ch][seg]; // one frame per BX, save all segments
        end
    end 
    
    
    
    // ********* Step 2: Synchronous Clock Crossing to 40MHz clock
    emtf_seg_t emtf_segs_r40[num_hosts][max_ch_host][max_seg_ch];
    always @(posedge clk40) begin 
        emtf_segs_r40 <= emtf_segs_r360;
    end 
    
    
    // ********* Step 3: delay the segments until track finding is done
    localparam DELAY_FOR_EMTF_SEGS = 4;
    emtf_seg_t all_emtf_segs_sr[DELAY_FOR_EMTF_SEGS][num_hosts][max_ch_host][max_seg_ch]; // holds emtf_segs until trk_building can use them

    always @(posedge clk40) begin
        all_emtf_segs_sr[DELAY_FOR_EMTF_SEGS-1] <= emtf_segs_r40;
 
        for(int i=0; i<DELAY_FOR_EMTF_SEGS-1; i++)
            all_emtf_segs_sr[i] <= all_emtf_segs_sr[i+1];
    end
    
    // Wire the outputs out    
    assign emtf_segs_delayed = all_emtf_segs_sr[0];
    
    

endmodule
