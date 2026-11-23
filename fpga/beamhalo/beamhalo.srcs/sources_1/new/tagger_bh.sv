`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Rice University
// Engineer: Clay Goldsmith
// 
// Create Date: 11/06/2026 05:28:56 PM
// Design Name: 
// Module Name: BeamHaloTrackBuilder
// Project Name: EMTF Beam Halo Tagger
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
`include "types.svh"

module tagger_bh (
    emtf_segs_i,                // we're using segment types to make this work
    new_bx_flag_i,              // this tells us when our data has reset 
                                    // (basically just a 1 whenever a given bit is another 'first' bit of a BX)
    beamhalo_tag_o,             // beamhalo tag output! 1 bit
    clk40,                      // clock (40 MHz?)
                                    // new bunch crossings occur at this rate
    clk360                      // clock (360 MHz?);  9 ticks per bunch crossing 
                                    // new segments come in at this rate 
);
    // host info
    `include "common.svh"

    // seg types are like 50 smth bits long structs
    input  emtf_seg_t emtf_segs_i[num_hosts][max_ch_host];  // 1 seg per clk360
    // aforementioned new bunch crossing flag
    input  new_bx_flag_i;                                   // pulses at phase 0
    // using logic because patrick says it's better than wire TODO: understand that better
    output logic beamhalo_tag_o;
    // clocks
    input  clk40, clk360;

    // a track tags the event if its road quality is at least this. same cut as the beam halo study (quality 10 or more)
    localparam trk_qual_t tag_min_qual = 10;

    // storing our tracks in case we need them
    best_trk_t best_tracks[num_tracks];

    // wow it's so nice that a track finder already exists
    track_finder_bh i_track_finder_bh (
        .emtf_segs_i(emtf_segs_i), .new_bx_flag_i(new_bx_flag_i),
        .best_tracks_o(best_tracks),
        .clk40(clk40), .trk_find_clk(clk360)
    );

    // TODO: what is "always_comb"? combinatorial? 
    // we're allowed to just throw some C into our verilog like this?
    // is this a systemverilog thing???
    always_comb begin
        beamhalo_tag_o = 1'b0;
        for (int t = 0; t < num_tracks; t++)
            if (best_tracks[t].qual >= tag_min_qual) beamhalo_tag_o = 1'b1;
    end
endmodule