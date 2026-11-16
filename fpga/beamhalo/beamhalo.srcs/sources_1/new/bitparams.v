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


// ==== locations of bits =====
// phi is the first value in the index
// we just go down the list from here
// one segment is stored in the following sequence:
// phi, bend, theta1, 
localparam PHI_LO   = 0;
localparam BEND_LO  = PHI_LO   + PHI_W;
localparam THETA1_LO= BEND_LO  + BEND_W;
localparam 