// lint-only stand-ins for two of Patrick's modules that verilator can't parse (non-constant slices).
// same ports as his. no logic. NOT for synthesis or sim.
`include "types.svh"
module merge_neighbor_columns(patt_matches, merged_cols, clk);
    `include "common.svh"
    input patt_match_t patt_matches[num_zones][num_fold_cols_wmux];
    output best_trk_t merged_cols[num_zones][num_merged_fold_cols];
    input clk;
    always @(posedge clk) merged_cols <= '{default:'0};
endmodule
module find_best_tracks(merged_cols_i, best_tracks, clk);
    `include "common.svh"
    input best_trk_t merged_cols_i[num_zones][num_merged_hitmap_cols];
    output best_trk_t best_tracks[num_tracks];
    input clk;
    always @(posedge clk) best_tracks <= '{default:'0};
endmodule
