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

// defining some bit width parameters lol 


// noting that this still uses segment terminology right now... 
// i think osvaldo mentioned they're called smth different in the hardware implementation?

// this module builds beam halo tracks and returns them if it has high enough confidence that they exist
module BeamHaloTrackBuilder(
    input segments,                 // big vector of segment data... big bus... probably hundreds of bits at least
    input clk,                      // incoming clock signal. i'm not sure what frequency we'll want this at yet
    output [7:0] beamhalo_tracks    // again, placeholder, idk how many bits these tracks will feasibly be
    // so for now it's just the CLEARLY incorrect value of 8
    );
    
    
    // ====  HITMAP BUILDING LAYER  ====
    wire [hitmap_t:0] zone_hitmaps;         // bus large enough to store a hitmap ? TODO

    HitmapBuildingLayer(
        segments,           // input: our hit segments layer 
        // algo,            // in the C++ version, we also input the algorithm... 
                            // don't think that translates nicely to verilog, prolly want to just implement it 
                            // within the module instead
        zone_hitmaps        // output: our zone hitmaps data
    );
    

    // ====  PATTERN MATCHING LAYER   ====
    wire [road_collection_t:0] zone_roads;  // bus large enough to store a road collection ? TODO

    PatternMatchingLayer(
        zone_hitmaps, 
        // algo,            // see HitmapBuildingLayer notes on algo
        zone_roads
    );

    // ====    ROAD SORTING LAYER   ====
    wire [road_t:0] best_roads;             // bus large enough to store a road ? TODO
    
    RoadSortingLayer( 
        v3::kNumTracks,     // not sure what this is in the C++ version? TODO
        zone_roads,         // input: our generated zone roads
        // algo,            // see HitmapBuildingLayer notes on algo
        best_roads          // output: our best roads
    );

    // ====  TRACK BUILDING LAYER   ====
    wire [track_t:0] tracks;            // TODO determine size

    TrackBuildingLayer( 
        segments,                   // input: raw hit segment data
        best_roads,                 // input: our best roads
        // algo_id_t::kBeamHalo,    // see HitmapBuildingLayer notes on algo
        tracks                      // output: our tracks!
    );


    // ==== DUPLICATE REMOVAL LAYER ====
    wire [track_t:0] tracks_dupe_removed; // TODO determine size

    DuplicateRemovalLayer(
        tracks,
        tracks_dupe_removed
    );
    
    // ====      OUTPUT LAYER       ====
    // format as an EMTF track collection?
    OutputLayerFormatter(
        EMTFTrackCollection,        // presumably some output wire bus we can connect into
        tracks_dupe_removed         // our new tracks
    );
    
    
endmodule
