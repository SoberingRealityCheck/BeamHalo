`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2026 05:16:35 PM
// Design Name: 
// Module Name: SectorProcessor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//  Simplified Sector Processor approximation that focuses specifically on building the Beam Halo tracks.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SectorProcessor(
    input seg_to_hit, // in the original code, this is like a map that gives us hit ids when we request a given segment
    // perhaps this could be implemented as a lookup table here? unsure how necessary this is in an FPGA context
    input segments,
    // this is our actual segments for this sector.theoretically this is like a very big number?? hmm
    input clk,
    // clock signal
    output out_tracks,
    // output tracks that it has produced
    output beamhalo_tag
    // binary "is there a beamhalo in this BX?" tag 
);
    
    wire [7:0] beamhalo_tracks;
    
    // track builder module
    BeamHaloTrackBuilder BeamHaloTrackFinder_1 (
        .segments(segments),
        .clk(clk),
        .beamhalo_tracks(beamhalo_tracks)
    );
    
    
    
    
    // some logic that basically just says "is there tracks present? if so, return a bit"
    always @(posedge clk) begin
        case (beamhalo_tracks)
            // this is a placeholder bc idk how big the actual data size will be.
            // right now i just made it an arbitrary 8 bits. but it's probably like orders of magnitude more than that
            // but basically: is the track data non-zero? do we have tracks?
            
            8'b0    : beamhalo_tag <= 1'b0;         // if there's no tracks, our beam halo tag should be zero
            
            default : beamhalo_tag <= 1'b1;         // otherwise, we have tracks, turn the tag on
        
        endcase 
    end
    
    
    
endmodule
