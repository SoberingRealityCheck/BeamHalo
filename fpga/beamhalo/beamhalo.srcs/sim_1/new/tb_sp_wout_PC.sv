`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/09/2024 12:41:08 PM
// Design Name: 
// Module Name: tb_sp_wout_PC
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

module tb_sp_wout_PC();
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
    
    // EMTF Outputs
    seg_id_t pr_attached_seg_ids[max_num_layers];
    trk_feat_t pr_trk_features[num_trk_features];
    logic pr_trk_seg_v[max_num_layers];
    seg_id_t disp_attached_seg_ids[max_num_layers];
    trk_feat_t disp_trk_features[num_trk_features];
    logic disp_trk_seg_v[max_num_layers];
    logic [13:0] pr_invpt; 
    logic [13:0] disp_invpt;
    logic [13:0] disp_dist;
    

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
    
    
    

    sp_wout_PC DUT_sp_wout_PC(
        .emtf_segs_i(emtf_segs_r360), 
        .new_bx_flag_i(new_bx_flag),
        .pr_attached_seg_ids_o(pr_attached_seg_ids), 
        .pr_trk_features_o(pr_trk_features), 
        .pr_trk_seg_v_o(pr_trk_seg_v),
        .disp_attached_seg_ids_o(disp_attached_seg_ids), 
        .disp_trk_features_o(disp_trk_features), 
        .disp_trk_seg_v_o(disp_trk_seg_v),
        .pr_invpt_o(pr_invpt), 
        .disp_invpt_o(disp_invpt), 
        .disp_dist_o(disp_dist),
        .clk40(clk40), 
        .clk160(clk160), 
        .clk360(clk360) 
    );      
    
    
    
    // ********************** Read Events from File at beginning ***************************** //
    localparam n_evts = 20;
    localparam n_hits = 30;
    localparam n_data_per_hit = 14;
    int hits[n_evts][n_hits][n_data_per_hit] = '{default: '0};
    
    int val;
    int status; // file descriptor
    int fd_inputs;
    string input_data_filename = {SIM_RELATIVE_PATH, "hit_data.txt"};

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
    


    // Printing Best Track Info (after sorting stage)
    initial begin
    
        int fd_best_trk_outputs;   
        fd_best_trk_outputs = $fopen({SIM_RELATIVE_PATH, "best_track_fw_output.txt"},"w");
        
        // Wait for clocks to lock
        wait(clk_locked == 1'b1 && (clk_phase==0)); 
        # 0.5;
        
        forever begin
            for(int trk=0; trk<num_tracks; trk++) begin
                if(DUT_sp_wout_PC.prompt_best_tracks[trk].qual != 0) begin
                    $fwrite(fd_best_trk_outputs, "0 %0d %0d %0d \n",
                        DUT_sp_wout_PC.prompt_best_tracks[trk].patt,
                        DUT_sp_wout_PC.prompt_best_tracks[trk].qual,
                        DUT_sp_wout_PC.prompt_best_tracks[trk].col
                        //DUT_sp_wout_PC.prompt_best_tracks[trk].zone
                    );
                end
            end

            for(int trk=0; trk<num_tracks; trk++) begin
                if(DUT_sp_wout_PC.disp_best_tracks[trk].qual != 0) begin
                    $fwrite(fd_best_trk_outputs, "1 %0d %0d %0d \n",
                        DUT_sp_wout_PC.disp_best_tracks[trk].patt,
                        DUT_sp_wout_PC.disp_best_tracks[trk].qual,
                        DUT_sp_wout_PC.disp_best_tracks[trk].col
                        //DUT_sp_wout_PC.disp_best_tracks[trk].zone
                    );
                end
            end
            
            $fwrite(fd_best_trk_outputs,"\n"); 
            #25;
            
        end // forever
    end // initial


    // Printing Track Feature Outputs 
    initial begin
    
        int fd_prompt, fd_disp, fd_no_rm_disp;   
        fd_prompt = $fopen({SIM_RELATIVE_PATH, "prompt_track_feat_fw_output.txt"},"w");
        fd_disp = $fopen({SIM_RELATIVE_PATH, "disp_track_feat_fw_output.txt"},"w");
        
        fd_no_rm_disp = $fopen({SIM_RELATIVE_PATH, "no_rm_disp_track_feat_fw_output.txt"},"w");

        // Wait for clocks to lock
        wait(clk_locked == 1'b1 && (clk_phase==0)); 
        # 0.5;
                
        forever begin    
            // Tracks before Dupe Removal      
            if(DUT_sp_wout_PC.i_track_builder.i_disp_tb_pipeline.trk_features_o[38] != '0) begin
                for(int feat=0; feat<40; feat++)
                    $fwrite(fd_no_rm_disp, "%0d ", DUT_sp_wout_PC.i_track_builder.i_disp_tb_pipeline.trk_features_o[feat]);
                $fwrite(fd_no_rm_disp, "\n");
            end
            
            if(pr_trk_features[38] != '0) begin
                for(int feat=0; feat<40; feat++)
                    $fwrite(fd_prompt, "%0d ", pr_trk_features[feat]);
                $fwrite(fd_prompt, "\n");
            end
            
            if(disp_trk_features[38] != '0) begin
                for(int feat=0; feat<40; feat++)
                    $fwrite(fd_disp, "%0d ", disp_trk_features[feat]);
                $fwrite(fd_disp, "\n");
            end
                 
            #6.25;
        end
    end


    
endmodule
