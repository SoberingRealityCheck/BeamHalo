// Contains some general settings and parameters as well as useful mappings (from hosts -> layers, etc....)

/* Hosts:
*   0: GE0
*   1: GE11
*   2: ME11
*   3: ME12
*   4: RE12
*   5: GE21 
*   6: RE22 
*   7: ME21 
*   8: ME22 
*   9: ME31 
*   10: ME32 
*   11: RE31 
*   12: RE32 
*   13: ME41 
*   14: ME42 
*   15: RE41 
*   16: RE42
*/

localparam seg_ch_csc = 2;
localparam seg_ch_rpc = 2;
localparam seg_ch_re12 = seg_ch_rpc;
localparam seg_ch_re34 = seg_ch_rpc * 2; // 4
localparam seg_ch_irpc = 4; 
localparam seg_ch_gem = 4; 
localparam seg_ch_ge11 = 4;
localparam seg_ch_ge21 = 4;
localparam seg_ch_me0 = 6; 

localparam gem_layers = 2;

localparam num_hosts = 18;
localparam max_ch_host = 7;
localparam max_seg_ch = 6; // ***** MUST BE <= fold_factor (based on how hm_builder is serialized)
localparam bxs = 1;

// Parameters for localparam patterns/zones/etc (I filled the localparams, but you don't need to test with all the zone/patterns)
localparam num_zones_filled = 3;
localparam num_patterns_filled = 7;

// Adjust num of zones and patterns (must be less than the number "filled" (above))
localparam num_zones = 3;
localparam num_patterns = 7;

// Hitmap Parameters
localparam num_hitmap_rows = 8;
localparam num_hitmap_cols = 288;
localparam hitmap_offset = 27;
localparam num_full_hitmap_cols = num_hitmap_cols + hitmap_offset; // 315
 
localparam num_tracks = 4; // if this changes, major changes are needed in sorting best tracks
localparam num_trk_features = 40;

// Pattern Matching
localparam fold_factor = 9; // must divide evenly into hitmap width (2,4,6,8,9,12) and match the clock
localparam num_fold_cols = num_hitmap_cols / fold_factor;
localparam max_padding = 55;
localparam padded_hitmap_cols = num_hitmap_cols + 2*max_padding;
localparam padded_fold_cols = num_fold_cols + 2*max_padding;

// changes to pipeline MUX columns (need to add a column on each side of hitmap fold for local suppression)
localparam max_padding_wmux = max_padding + 1;
localparam padded_hitmap_cols_wmux = padded_hitmap_cols + 2;
localparam num_fold_cols_wmux = num_fold_cols + 2;
localparam padded_fold_cols_wmux = padded_fold_cols + 2;

// Sorting
localparam num_suppressed_fold_cols = num_fold_cols / 2;        // half of the columns are suppressed
localparam num_merged_fold_cols = num_suppressed_fold_cols / 4; // Num cols after two merge 8 layers (4)
localparam num_merged_hitmap_cols = num_merged_fold_cols * fold_factor; // 36 cols

// Track Building
localparam max_num_layers = 12;
localparam bits_to_shift = 4;
localparam middle_of_range = (1 << (bits_to_shift-1)); // 8
localparam max_ch_per_layer = 11;
localparam max_hosts_per_layer = 2;


enum int unsigned { GE0=0, GE11, ME11, ME12, RE12, GE21, RE22, ME21, ME22, ME31, ME32, RE31, RE32, ME41, ME42, RE41, RE42=16, ME13 } hosts;

// Used to load PC_LUT init values
localparam string HOST_NAMES[num_hosts] = '{"GE0", "GE11", "ME11", "ME12", "RE12", "GE21", "RE22", "ME21", "ME22", "ME31", "ME32", "RE31", "RE32", "ME41", "ME42", "RE41", "RE42", "ME13"};

enum int unsigned { ten_deg=0, twenty_deg=1, twenty_me0=2 } angle_types;

localparam num_ch_angle_types = 3;

localparam int unsigned ch_per_host_bt[num_ch_angle_types] = {7, 4, 4};           // bt: organized by type - 10deg, 20deg, me0

localparam int unsigned no_chamb = '1;
localparam int unsigned ph_init_bt[num_ch_angle_types][max_ch_host] = '{ 
    '{38, 75, 113, 150, 188, 225, 263},
    '{0,  75, 150, 225, no_chamb, no_chamb, no_chamb},
    '{0,  75, 150, 225, no_chamb, no_chamb, no_chamb}  // FIXME: GE0 4 chambers - this won't be correct right now
    //'{0,  56, 131, 206, 281, no_chamb, no_chamb}     // OLD GE0: gave a buffer of 7 below current (ph_init >> 4) values
};

localparam int unsigned ph_init_max = 281;

localparam int unsigned max_coverage_bt[num_ch_angle_types] = { 53, 90, 90 }; // ten_deg, 20_deg, 20_deg_me0
   
localparam int unsigned type_by_host[num_hosts] = { 
                                            twenty_me0,                                 // Station 0 
                                            ten_deg, ten_deg, ten_deg, ten_deg,         // Station 1
                                            twenty_deg, ten_deg, twenty_deg, ten_deg,   // Station 2
                                            twenty_deg, ten_deg, twenty_deg, ten_deg,   // Station 3
                                            twenty_deg, ten_deg, twenty_deg, ten_deg,   // Staiton 4
                                            ten_deg // unused ME13
                                       }; 

localparam int unsigned ch_per_host[num_hosts] = { 
                                            4, 7, 7,               // Station 0 
                                            7, 7,                           // Station 1
                                            4, 7, 4, 7,   // Station 2
                                            4, 7, 4, 7,   // Station 3
                                            4, 7, 4, 7,   // Staiton 4
                                            7 // unused ME13
                                       }; 
                                       
localparam int host_seg_ch[num_hosts] = {
                                        seg_ch_me0, seg_ch_ge11, seg_ch_csc,                // Station 0: ME0, GE11, ME11
                                        seg_ch_csc, seg_ch_re12,                            // Station 1: ME12, RE12
                                        seg_ch_ge21, seg_ch_csc, seg_ch_re12, seg_ch_csc,   // Station 2: GE21, ME21, RE22, ME22
                                        seg_ch_csc, seg_ch_irpc, seg_ch_csc, seg_ch_re34,   // Station 3: ME31, iRE31, ME32, RE32
                                        seg_ch_csc, seg_ch_irpc, seg_ch_csc, seg_ch_re34,    // Station 4: ME41, iRE41, ME42, RE42
                                        seg_ch_csc // unused ME13
                                    };



localparam int unsigned no_host = '1;
localparam max_hosts_in_row = 4;

localparam int unsigned num_hosts_by_row[num_zones_filled][num_hitmap_rows] = '{ 
        '{1,1,1,1,1,1,1,2}, // Zone 0
        '{1,1,2,1,1,2,2,4}, // Zone 1
        '{1,1,1,1,1,1,1,1}  // Zone 2
};

localparam [31:0] hosts_by_row[num_zones_filled][num_hitmap_rows][max_hosts_in_row] = '{ 
        // Zone 0
        '{
            {GE0,  no_host, no_host, no_host}, 
            {GE11, no_host, no_host, no_host}, 
            {ME11, no_host, no_host, no_host}, 
            {GE21, no_host, no_host, no_host}, 
            {ME21, no_host, no_host, no_host},  
            {ME31, no_host, no_host, no_host},  
            {RE31, no_host, no_host, no_host}, 
            {ME41, RE41,    no_host, no_host}
        }, 
        // Zone 1 
        '{ 
            {GE11, no_host, no_host, no_host}, 
            {ME11, no_host, no_host, no_host},  
            {ME12, RE12,    no_host, no_host}, 
            {GE21, no_host, no_host, no_host},  
            {ME21, no_host, no_host, no_host},  
            {ME31, ME32,    no_host, no_host}, 
            {RE31, RE32,    no_host, no_host}, 
            {ME41, ME42,    RE41,    RE42}
        }, 
        // Zone 2
        '{ 
            {ME12, no_host, no_host, no_host}, 
            {RE12, no_host, no_host, no_host}, 
            {RE22, no_host, no_host, no_host}, 
            {ME22, no_host, no_host, no_host},  
            {ME32, no_host, no_host, no_host}, 
            {RE32, no_host, no_host, no_host}, 
            {ME42, no_host, no_host, no_host}, 
            {RE42, no_host, no_host, no_host}
        }                                                                                                                                             
};


localparam [31:0] map_layers_to_hosts[max_num_layers][2] = '{ 
                                    '{ME11, no_host}, 
                                    '{ME12, no_host},
                                    '{ME21, ME22},
                                    '{ME31, ME32},
                                    '{ME41, ME42},
                                    '{RE12, no_host},
                                    '{RE22, no_host},
                                    '{RE31, RE32},
                                    '{RE41, RE42},
                                    '{GE11, no_host},
                                    '{GE21, no_host},
                                    '{GE0, no_host}
};


localparam int ch_per_layer[max_num_layers] = '{7, 7, 11, 11, 11, 7, 7, 11, 11, 7, 4, 4};


localparam int map_layers_to_zone_rows[num_zones_filled][max_num_layers] = '{
            '{ 2, -1, 4, 5, 7, -1, -1, 6, 7,  1,  3,  0}, // Zone 0
            '{ 1,  2, 4, 5, 7,  2, -1, 6, 7,  0,  3, -1}, // Zone 1         
            '{ -1, 0, 3, 4, 6,  1,  2, 5, 7, -1, -1, -1}  // Zone 2       
};


// Get the row for each host and zone (-1 means host is not in this zone)
localparam int host_row_by_zone[num_zones_filled][num_hosts] = '{ 
        // ME0 GE11 ME11 ME12 RE12 GE21 RE22 ME21 ME22 ME31 ME32 RE31 RE32 ME41 ME42 RE41 RE42, ME13
        '{  0,  1,   2,   -1,  -1,  3,   -1,  4,   -1,  5,   -1,  6,   -1,  7,   -1,  7,   -1,  -1}, // Zone 0
        '{  -1, 0,   1,   2,   2,   3,   -1,  4,   -1,  5,   5,   6,   6,   7,   7,   7,   7,   -1}, // Zone 1
        '{  -1, -1,  -1,  0,   1,   -1,  2,   -1,  3,   -1,  4,   -1,  5,   -1,  6,   -1,  7,   -1}  // Zone 2

};


/***** Track-building Chamber Gating Parameters *******/

localparam max_ch_per_gate = 3; // for 10degree chambers
localparam int ch_per_gate_bt[max_ch_per_gate] = {3,2,2};

localparam int num_gates = 8;

localparam int gate_edges[num_gates-1] = '{101,120,158,176,195,233,251}; // col numbers where gate changes


// Gated chambers by chamber type (orginaized so chamber segments are only wired to 1 place)
// Gating means we don't have to loop through all of the chambers, we only loop through the 3 chambers near the column
localparam int map_gated_chambers_bt[num_ch_angle_types][num_gates][max_ch_per_gate] = '{
    '{  // Ten degree Chamber
        '{0,1,2},   // gate 0 - start ch0
        '{0,1,2},   // gate 1 - start ch0
        '{3,1,2},   // gate 2 - start ch1
        '{3,4,2},   // 3      - start ch2
        '{3,4,2},   // 4      - start ch2
        '{3,4,5},   // 5      - start ch3
        '{6,4,5},   // 6      - start ch4
        '{6,4,5}    // 7      - start ch4
   },
   '{  // Twenty degree Chamber
        '{0,1,no_chamb},   // gate 0 - start ch0
        '{0,1,no_chamb},   // gate 1 - start ch0
        '{1,2,no_chamb},   // gate 2 - start ch1
        '{1,2,no_chamb},   // 3      - start ch1
        '{1,2,no_chamb},   // 4      - start ch1
        '{3,2,no_chamb},   // 5      - start ch2
        '{3,2,no_chamb},   // 6      - start ch2
        '{3,2,no_chamb}    // 7      - start ch2
   },
   '{  // ME0 Chamber
        '{0,1,no_chamb},   // gate 0 - start ch0
        '{1,2,no_chamb},   // gate 1 - start ch1
        '{1,2,no_chamb},   // gate 2 - start ch1
        '{1,2,no_chamb},   // 3      - start ch1
        '{3,2,no_chamb},   // 4      - start ch2
        '{3,2,no_chamb},   // 5      - start ch2
        '{3,2,no_chamb},   // 6      - start ch2
        '{3,4,no_chamb}    // 7      - start ch3
   }
};

localparam int possible_chambers_start_bt[num_ch_angle_types][num_gates] = '{ 
    //edge:  0   1   2   3   4   5   6   
    //       |   |   |   |   |   |   |
        '{0,   0,  1,  2,  2,  3,  4,  4}, // ten degree chamber start
        '{0,   0,  1,  1,  1,  2,  2,  2}, // twenty degree chamber start
        '{0,   1,  1,  1,  2,  2,  2,  3}  // ME0 chambers
};


