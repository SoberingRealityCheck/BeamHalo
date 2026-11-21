// this file stores the config variables i'm using to determine how the data flow works

// number of chambers: this is how many chambers exist in our endcap that can collect and store hit segments
localparam NUM_CHAMBERS    = 115;

// two segments per chamber. This is our limit on the number of hit segments we are storing for each chamber
localparam CHAMBER_SEGS    = 2;

// number of total hit segments we can store is a simple multiple of the two
localparam NUM_SEGS        = NUM_CHAMBERS * CHAMBER_SEGS;

// hitmap_cols is the number of columns in our hitmap image 
// (essentially the number of phi "buckets" we group things by)
// one column covers 16 "phi units", about .27 degrees ?? 
localparam HITMAP_COLS     = 288;


// ==== list of bit widths ====
// bit width needed to store a column number: 9, matches trk_col_t
localparam COL_W           = $clog2(HITMAP_COLS);   

// bit width needed to store a phi number
// 8192 possible values, 13 bits
localparam PHI_W = 13;

// bit width needed to store a bend number
// 
localparam BEND_W = 10; 

// bit width needed to store a theta number
localparam THETA_W = 8; 

// bit width needed to store a quality number
localparam QUAL_W = 4; 

// bit width needed to store a time number
localparam TIME_W = 4;

// bit width needed to store a zone number
localparam ZONES_W = 3;

// bit width needed to store a timezone number
localparam TZONES_W = 3; 

// bit width needed to store a bunch crossing term 
// (i don't fully understand this one.. isn't there just a max of 2 bunch crossings?)
localparam BX_W = 2;      

// 1-bit pieces of segment data
localparam CSCFR_W = 1; // is this from front or rear of the csc?   1=rear,     0=front
localparam LAYER_W = 1; // idk what this means                      1=????,     0=???
localparam VALID_W = 1; // is this hit valid?                       1=valid,    0=invalid


// ==== locations of bits =====
// phi is the first value in the index
// we just go down the list from here
// one segment is stored in the following sequence:
// [ phi, bend, theta1, theta2, qual1, qual2, time, zones, tzones, cscfr, layer, bx, valid ] (62 total bits)
// with 230 total segments in our data flow
localparam PHI_LO    = 0;
localparam BEND_LO   = PHI_LO    + PHI_W;
localparam THETA1_LO = BEND_LO   + BEND_W;
localparam THETA2_LO = THETA1_LO + THETA_W;
localparam QUAL1_LO  = THETA2_LO + THETA_W;
localparam QUAL2_LO  = QUAL1_LO  + QUAL_W;
localparam TIME_LO   = QUAL2_LO  + QUAL_W;
localparam ZONES_LO  = TIME_LO   + TIME_W;
localparam TZONES_LO = ZONES_LO  + ZONES_W;
localparam CSCFR_LO  = TZONES_LO + TZONES_W;
localparam LAYER_LO  = CSCFR_LO  + CSCFR_W;
localparam BX_LO     = LAYER_LO  + LAYER_W;
localparam VALID_LO  = BX_LO     + BX_W;
localparam SEG_W     = VALID_LO  + VALID_W;   // should be 62
localparam SEGS_W    = NUM_SEGS * SEG_W;      // 14260, the whole input bus