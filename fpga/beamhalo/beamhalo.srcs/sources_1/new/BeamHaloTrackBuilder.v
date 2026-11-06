`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2026 05:28:56 PM
// Design Name: 
// Module Name: BeamHaloTrackBuilder
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


// this module builds beam halo tracks and returns them if it has high enough confidence that they exist
module BeamHaloTrackBuilder(
    input segments,                 // big vector of segment data... big bus... probably hundreds of bits at least
    input clk,                      // incoming clock signal. i'm not sure what frequency we'll want this at yet
    output [7:0] beamhalo_tracks    // again, placeholder, idk how many bits these tracks will feasibly be
    // so for now it's just the CLEARLY incorrect value of 8
    );
    
    
    // ====  HITMAP BUILDING LAYER  ====
    
    
    // ====    ROAD SORTING LAYER   ====
    
    
    // ====  TRACK BUILDING LAYER   ====
    
    
    // ==== DUPLICATE REMOVAL LAYER ====
    
    
    // ====      OUTPUT LAYER       ====
    
    
endmodule
