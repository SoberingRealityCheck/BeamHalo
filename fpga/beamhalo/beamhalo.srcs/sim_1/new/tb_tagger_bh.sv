`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/09/2024 12:41:08 PM
// Design Name: 
// Module Name: tb_tagger_bh
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
 

`include "types.svh"

module tb_tagger_bh();
    localparam string SIM_RELATIVE_PATH = "../../../../../sim_data/";

    `include "common.svh"

    
    // clks
    reg i_clk40; 
    wire clk40, clk160, clk360, clk_locked;  
               
    // ~40MHz Clock Input Signal  
    initial begin
        i_clk40 = 1'b1;
        forever
            #12.5 i_clk40 = ~i_clk40;
    end
    
    clk_wiz_for_tb i_clk_wiz_for_tb(.clk40_i(i_clk40), .clk40(clk40), .clk160(clk160), .clk360(clk360), .locked(clk_locked));
    
    
    
    
    // EMTF Segment Inputs
    emtf_seg_t emtf_segs[num_hosts][max_ch_host][9];
    emtf_seg_t emtf_segs_r360[num_hosts][max_ch_host];
    logic new_bx_flag;
    
    // Tagger output
    logic beamhalo_tag;

    // bx counts clk40 ticks once events start going in. every dump file is stamped with it.
    // set bx_run in the event driver below
    logic bx_run = 1'b0;
    int bx = 0;
    int cyc = 0;   // clk360 ticks since bx_run. stage2 prints it so folds can be lined up


    // Input emtf segments @360MHz (1 segment at a time)
    logic [3:0] clk_phase = 5;
    always @(posedge clk360) begin
        if(clk_phase < 8)
            clk_phase <= clk_phase + 1;
        else 
            clk_phase <= 0;
                    
        // When Clock Phase is 0, input segment 0 and pulse new_bx_flag (these are actually input when clk_phase is 1)
        for(int host=0; host<num_hosts; host++) begin 
            for(int ch=0; ch<max_ch_host; ch++) 
                emtf_segs_r360[host][ch] <= emtf_segs[host][ch][clk_phase];
        end
        
        if(clk_phase == 0) 
            new_bx_flag <= 1'b1;
        else
            new_bx_flag <= 1'b0;
    end
    
    
    

    tagger_bh DUT_tagger_bh(
        .emtf_segs_i(emtf_segs_r360), 
        .new_bx_flag_i(new_bx_flag),
        .beamhalo_tag_o(beamhalo_tag),
        .clk40(clk40),
        .clk360(clk360)
    );
    
    
    
    // ********************** Read Events from File at beginning ***************************** //
    localparam n_evts = 20;
    localparam n_hits = 64;    // was 30. raised so the noisier test events fit. the reader stops at each 12345 anyway
    localparam n_data_per_hit = 14;
    int hits[n_evts][n_hits][n_data_per_hit] = '{default: '0};
    
    int val;
    int status; // file descriptor
    int fd_inputs;
    string input_data_filename = {SIM_RELATIVE_PATH, "hit_data_bh.txt"};

    initial begin
        
        fd_inputs = $fopen({input_data_filename},"r");
        if(fd_inputs == 0) begin
            $write("\nInput data file is invalid\n");
            $display(input_data_filename);
            $finish;
        end
            
        // n_evts - 1 so last evt is all zeros
        for(int evt=0; evt<n_evts-1; evt++) begin
            for(int ihit=0; ihit<n_hits; ihit++) begin
                for(int i=0; i<n_data_per_hit; i++) begin
                    status = $fscanf(fd_inputs,"%d",val);
                    
                    if(val == 12345)
                        break; // new event
                    else
                        hits[evt][ihit][i] = val;
                end
                
                if(val == 12345)
                    break;
            end
        end    
            
        $fclose(fd_inputs);
       
       // Check that loading works
       /*
       for(int evt=0; evt<n_evts; evt++) begin
            for(int ihit=0; ihit<n_hits; ihit++) begin
                for(int i=0; i<n_data_per_hit; i++) begin
                    $write("%d, ", hits[evt][ihit][i]);
                end
                $write("\n");
            end
            $write("\n");
        end 
        */            

    end 
    
    
    
    // ********************** Add EMTF Segments into the Input ***************************** //
    int evt;
    
    initial begin         
        evt = 0;
        emtf_segs = '{default: '0};   
    
        // Wait for clocks to lock and start data slightly after that
        wait(clk_locked == 1'b1 && (clk_phase==0)); 
        # 0.5;
        bx_run = 1'b1;  // start the bx counter used by the dump files

        for(evt=0; evt<n_evts; evt++) begin
            if(clk_phase != 0) begin 
                $display("Phase != 0, something weird happened with clocks");
                $finish;
            end
            
            emtf_segs = '{default: '0}; // zero everything
            // Add the hits
            for(int hit=0; hit<n_hits; hit++) begin
            
                automatic int endcap = hits[evt][hit][0];
                automatic int sector = hits[evt][hit][1];
                automatic int host = hits[evt][hit][2];
                automatic int ch = hits[evt][hit][3];
                automatic int seg = hits[evt][hit][4];
                automatic int phi = hits[evt][hit][5];
                automatic int theta1 = hits[evt][hit][6];
                automatic int theta2 = hits[evt][hit][7];
                automatic int bend = hits[evt][hit][8];
                automatic int qual1 = hits[evt][hit][9];
                automatic int qual2 = hits[evt][hit][10];
                automatic int zones = hits[evt][hit][11];
                automatic int emtf_time = hits[evt][hit][12];
                automatic int valid = hits[evt][hit][13];

                if(valid == 1) begin
                    //$display("Valid Segment: [Evt %4d, %4d, %4d, %4d]", evt, host, ch, seg);
                    emtf_segs[host][ch][seg].phi = phi;            
                    emtf_segs[host][ch][seg].theta1 = theta1;
                    emtf_segs[host][ch][seg].theta2 = theta2;
                    emtf_segs[host][ch][seg].zones = zones;
                    emtf_segs[host][ch][seg].bend = bend;
                    emtf_segs[host][ch][seg].qual1 = qual1;
                    emtf_segs[host][ch][seg].emtf_time = emtf_time;
                    emtf_segs[host][ch][seg].valid = valid;
                end
                
            end
            
            #25; // delay 1 clk40    
        end // for(evt)
       
        #500;
        $finish; 
    end
    


    // ********************** Dump Every Stage to Text Files ***************************** //
    // One file per stage in fpga/sim_data/out/. Only nonzero things get written.
    // Every line starts with bx. Input event N goes in during bx N.
    // Outputs show up several bx later (track finding is about 60 clk360 = 7 bx).
    // To line up input and output in python, find the first bx where the tag goes high
    // and compare to the event that should have caused it.
    //
    //   stage0_segs.txt     bx phase host ch phi bend theta1 theta2 qual1 time zones
    //   stage1_hitmaps.txt  bx zone row hex      (288-bit row, bit 0 = column 0)
    //   stage2_matches.txt  bx fold zone col patt qual cyc
    //   stage3_cols.txt     bx zone idx patt qual col
    //   stage4_tracks.txt   bx trk patt qual col zone
    //   stage5_tag.txt      bx tag               (every bx)
    //
    // stage2: fold is curr_fold_num when sampled. The matches come out a few clocks
    // after that fold goes in, so the fold number is early by a fixed amount. check it on the waveform.

    localparam string OUT_PATH = {SIM_RELATIVE_PATH, "out/"};
    int fd_segs, fd_hitmaps, fd_matches, fd_cols, fd_tracks, fd_tag;

    initial begin
        fd_segs    = $fopen({OUT_PATH, "stage0_segs.txt"},    "w");
        fd_hitmaps = $fopen({OUT_PATH, "stage1_hitmaps.txt"}, "w");
        fd_matches = $fopen({OUT_PATH, "stage2_matches.txt"}, "w");
        fd_cols    = $fopen({OUT_PATH, "stage3_cols.txt"},    "w");
        fd_tracks  = $fopen({OUT_PATH, "stage4_tracks.txt"},  "w");
        fd_tag     = $fopen({OUT_PATH, "stage5_tag.txt"},     "w");
    end


    // ---- clk360 stages: segments in, hitmaps, pattern matches ----
    always @(posedge clk360) begin
        if (bx_run) begin
            cyc <= cyc + 1;
            // stage 0: what the DUT sees on its input this clock
            for (int host = 0; host < num_hosts; host++)
                for (int ch = 0; ch < max_ch_host; ch++)
                    if (emtf_segs_r360[host][ch].valid)
                        $fwrite(fd_segs, "%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d\n",
                            bx, clk_phase, host, ch,
                            emtf_segs_r360[host][ch].phi,
                            emtf_segs_r360[host][ch].bend,
                            emtf_segs_r360[host][ch].theta1,
                            emtf_segs_r360[host][ch].theta2,
                            emtf_segs_r360[host][ch].qual1,
                            emtf_segs_r360[host][ch].emtf_time,
                            emtf_segs_r360[host][ch].zones);

            // stage 1: finished hitmap, once per bx (flag travels with it)
            if (DUT_tagger_bh.i_track_finder_bh.new_hitmap_flag)
                for (int zone = 0; zone < num_zones; zone++)
                    for (int row = 0; row < num_hitmap_rows; row++)
                        if (DUT_tagger_bh.i_track_finder_bh.merged_hitmaps[zone][row] != '0)
                            $fwrite(fd_hitmaps, "%0d %0d %0d %h\n", bx, zone, row,
                                DUT_tagger_bh.i_track_finder_bh.merged_hitmaps[zone][row]);

            // stage 2: best pattern match per column, one fold section per clock
            for (int zone = 0; zone < num_zones; zone++)
                for (int col = 0; col < num_fold_cols_wmux; col++)
                    if (DUT_tagger_bh.i_track_finder_bh.i_tf_pipeline_bh.best_fold_matches_r[zone][col].qual != 0)
                        $fwrite(fd_matches, "%0d %0d %0d %0d %0d %0d %0d\n", bx,
                            DUT_tagger_bh.i_track_finder_bh.i_tf_pipeline_bh.curr_fold_num,
                            zone, col,
                            DUT_tagger_bh.i_track_finder_bh.i_tf_pipeline_bh.best_fold_matches_r[zone][col].patt,
                            DUT_tagger_bh.i_track_finder_bh.i_tf_pipeline_bh.best_fold_matches_r[zone][col].qual,
                            cyc);
        end
    end


    // ---- clk40 stages: merged columns, best tracks, tag ----
    // merged_cols_all holds still for 9 clk360, so one sample per bx sees each copy once
    always @(posedge clk40) begin
        if (bx_run) begin
            // stage 3: best road per merged column group
            for (int zone = 0; zone < num_zones; zone++)
                for (int i = 0; i < num_merged_hitmap_cols; i++)
                    if (DUT_tagger_bh.i_track_finder_bh.i_tf_pipeline_bh.merged_cols_all[zone][i].qual != 0)
                        $fwrite(fd_cols, "%0d %0d %0d %0d %0d %0d\n", bx, zone, i,
                            DUT_tagger_bh.i_track_finder_bh.i_tf_pipeline_bh.merged_cols_all[zone][i].patt,
                            DUT_tagger_bh.i_track_finder_bh.i_tf_pipeline_bh.merged_cols_all[zone][i].qual,
                            DUT_tagger_bh.i_track_finder_bh.i_tf_pipeline_bh.merged_cols_all[zone][i].col);

            // stage 4: the 4 best tracks
            for (int t = 0; t < num_tracks; t++)
                if (DUT_tagger_bh.best_tracks[t].qual != 0)
                    $fwrite(fd_tracks, "%0d %0d %0d %0d %0d %0d\n", bx, t,
                        DUT_tagger_bh.best_tracks[t].patt,
                        DUT_tagger_bh.best_tracks[t].qual,
                        DUT_tagger_bh.best_tracks[t].col,
                        DUT_tagger_bh.best_tracks[t].zone);

            // stage 5: the tag
            $fwrite(fd_tag, "%0d %0d\n", bx, beamhalo_tag);

            bx <= bx + 1;
        end
    end

endmodule
