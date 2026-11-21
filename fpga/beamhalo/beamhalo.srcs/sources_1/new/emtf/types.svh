`ifndef __TYPES__
`define __TYPES__


// EMTF segment types
typedef logic[12:0] emtf_phi_t;
typedef logic[7:0]  emtf_theta_t;
typedef logic signed [9:0] bend_t;
typedef logic [3:0] qual1_t;
typedef logic [3:0] emtf_time_t;
typedef logic [5:0] zones_t;     // bitmap for which zones are valid (need a bit for every zone)

// Types use in track finding
typedef logic[5:0] trk_qual_t;
typedef logic[3:0] trk_patt_t;
typedef logic[8:0] trk_col_t;
typedef logic[2:0] trk_zone_t;  // number specifying the zone

// Output Types
typedef logic signed [12:0] trk_feat_t;
typedef logic signed [13:0] trk_invpt_t;


typedef struct packed {
	emtf_phi_t     phi;
	bend_t         bend;
	emtf_theta_t   theta1;
	emtf_theta_t   theta2;
	qual1_t        qual1;
	emtf_time_t    emtf_time;
	zones_t        zones;     // bitmap for which zones are valid (need a bit for every zone)
	logic          valid;
} emtf_seg_t;


typedef struct packed {
    trk_patt_t patt;
    trk_qual_t qual;
} patt_match_t;


typedef struct packed {
    trk_patt_t patt;
    trk_qual_t qual;
    trk_col_t  col;
    trk_zone_t zone;
} best_trk_t;


typedef struct packed {
    logic ihost; // within layer
    logic [2:0] ichamber;   // 8 max (0->7) - within host
    logic [2:0] iseg;       // 8 max        - within chamber
    //logic [2:0] ibx;        // 8 max
} seg_id_t;


// segments with seg ids
typedef struct packed {
    emtf_seg_t emtf_seg;
    seg_id_t   seg_id;
} emtf_seg_wid_t;


typedef struct packed {
    emtf_seg_t emtf_seg;
    seg_id_t   seg_id;
    emtf_phi_t diff;
} emtf_seg_wid_and_diff_t;
    


`endif
