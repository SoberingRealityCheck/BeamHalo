`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Rice University
// Engineer: Clay Goldsmith
// 
// Create Date: 11/06/2026 05:16:35 PM
// Design Name: 
// Module Name: SectorProcessor
// Project Name: EMTF Beam Halo Tagger
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
    assign beamhalo_tag = |beamhalo_tracks;
    
    // test 2!
    
endmodule


// will we want a module to fake upstream data & send it in? does that belong in its own test bench file? TODO