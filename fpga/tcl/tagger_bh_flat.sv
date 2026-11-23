// fallback top for synthesis only. same as tagger_bh, but the segments come in as one flat bit vector.
// use it if Vivado refuses the unpacked array of structs on tagger_bh's own ports (synth_tagger.tcl option "flat").
// bits [(host * max_ch_host + ch) * 54 +: 54] are the emtf_seg_t of that host and chamber.
`include "types.svh"

module tagger_bh_flat (
    emtf_segs_flat, new_bx_flag_i, beamhalo_tag_o, clk40, clk360
);
    `include "common.svh"

    input  [num_hosts*max_ch_host*$bits(emtf_seg_t)-1:0] emtf_segs_flat;
    input  new_bx_flag_i;
    output beamhalo_tag_o;
    input  clk40, clk360;

    emtf_seg_t segs[num_hosts][max_ch_host];

    always_comb begin
        for (int h = 0; h < num_hosts; h++)
            for (int c = 0; c < max_ch_host; c++)
                segs[h][c] = emtf_segs_flat[(h*max_ch_host + c)*$bits(emtf_seg_t) +: $bits(emtf_seg_t)];
    end

    tagger_bh i_tagger_bh (
        .emtf_segs_i(segs), .new_bx_flag_i(new_bx_flag_i), .beamhalo_tag_o(beamhalo_tag_o),
        .clk40(clk40), .clk360(clk360)
    );
endmodule
