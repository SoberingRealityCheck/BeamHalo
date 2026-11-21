
task automatic sort_four(input best_trk_t in[4], output best_trk_t out[4]);
    // Sorts four unsorted inputs (not stable) - input struct must have .qual
    best_trk_t tmp_1_0, tmp_1_1, tmp_1_2, tmp_1_3;  // stage 1
    best_trk_t tmp_2_0, tmp_2_1, tmp_2_2, tmp_2_3;  // stage 2
    best_trk_t tmp_3_1, tmp_3_2;                    // stage 3
    
    begin
        // Stage 1: compare-swap if (wire[i] < wire[j]) swap(wire[j], wire[i])
        tmp_1_0 = (in[0].qual < in[1].qual) ? in[1] : in[0];
        tmp_1_1 = (in[0].qual < in[1].qual) ? in[0] : in[1];
        tmp_1_2 = (in[2].qual < in[3].qual) ? in[3] : in[2];
        tmp_1_3 = (in[2].qual < in[3].qual) ? in[2] : in[3];
    
        // Stage 2
        tmp_2_0 = (tmp_1_0.qual < tmp_1_2.qual) ? tmp_1_2 : tmp_1_0;
        tmp_2_1 = (tmp_1_1.qual < tmp_1_3.qual) ? tmp_1_3 : tmp_1_1;
        tmp_2_2 = (tmp_1_0.qual < tmp_1_2.qual) ? tmp_1_0 : tmp_1_2;
        tmp_2_3 = (tmp_1_1.qual < tmp_1_3.qual) ? tmp_1_1 : tmp_1_3;
    
        // Stage 3
        tmp_3_1 = (tmp_2_1.qual < tmp_2_2.qual) ? tmp_2_2 : tmp_2_1;
        tmp_3_2 = (tmp_2_1.qual < tmp_2_2.qual) ? tmp_2_1 : tmp_2_2;

        // Output
        out[0] = tmp_2_0;
        out[1] = tmp_3_1;
        out[2] = tmp_3_2;
        out[3] = tmp_2_3;
    end
endtask // sort_four



task automatic merge_eight (input best_trk_t in[8], output best_trk_t out[4]);
    // Unstable Bitonic Parrallel sort, first four and last four must be pre-sorted - input struct must have .qual
    best_trk_t tmp_1_0, tmp_1_1, tmp_1_2, tmp_1_3, tmp_1_4, tmp_1_5;    // stage 1
    best_trk_t tmp_2_2, tmp_2_3, tmp_2_4;                               // stage 2
    best_trk_t tmp_3_1, tmp_3_2, tmp_3_3;                               // stage 3
    
    begin
        // Stage 1: compare-swap if (wire[i] < wire[j]) swap(wire[j], wire[i])
        tmp_1_0 = (in[0].qual < in[4].qual) ? in[4] : in[0];
        tmp_1_1 = (in[1].qual < in[5].qual) ? in[5] : in[1];
        tmp_1_2 = (in[2].qual < in[6].qual) ? in[6] : in[2];
        tmp_1_3 = (in[3].qual < in[7].qual) ? in[7] : in[3];
        tmp_1_4 = (in[0].qual < in[4].qual) ? in[0] : in[4];
        tmp_1_5 = (in[1].qual < in[5].qual) ? in[1] : in[5];
    
        // Stage 2
        tmp_2_2 = (tmp_1_2.qual < tmp_1_4.qual) ? tmp_1_4 : tmp_1_2;
        tmp_2_3 = (tmp_1_3.qual < tmp_1_5.qual) ? tmp_1_5 : tmp_1_3;
        tmp_2_4 = (tmp_1_2.qual < tmp_1_4.qual) ? tmp_1_2 : tmp_1_4;
    
        // Stage 3
        tmp_3_1 = (tmp_1_1.qual < tmp_2_2.qual) ? tmp_2_2 : tmp_1_1;
        tmp_3_2 = (tmp_1_1.qual < tmp_2_2.qual) ? tmp_1_1 : tmp_2_2;
        tmp_3_3 = (tmp_2_3.qual < tmp_2_4.qual) ? tmp_2_4 : tmp_2_3;
    
        // Output
        out[0] = tmp_1_0;
        out[1] = tmp_3_1;
        out[2] = tmp_3_2;
        out[3] = tmp_3_3;
    end

endtask // merge_eight


task automatic median_of_three (input emtf_theta_t in[3], output emtf_theta_t out);
    // Takes median, or min if any value is invalid (0 converted to 255 for this)
    emtf_theta_t a0,a1,a2;
    emtf_theta_t tmp_1_0, tmp_1_1, tmp_2_1, tmp_3_0, tmp_3_1;
    emtf_theta_t invalid_val = '1;
       
    begin
      // Make 0 values invalid (set all bits to 1)
      a0 = (in[0] == '0)? invalid_val : in[0];
      a1 = (in[1] == '0)? invalid_val : in[1];
      a2 = (in[2] == '0)? invalid_val : in[2];
    
      // Stage 1: compare-swap if (wire[i] > wire[j]) swap(wire[j], wire[i])
      tmp_1_0 = (a0 > a1) ? a1 : a0;    // min(a0,a1) - def: a0
      tmp_1_1 = (a0 > a1) ? a0 : a1;    // max(a0,a1) - def: a1
    
      // Stage 2
      tmp_2_1 = (tmp_1_1 > a2) ? a2 : tmp_1_1; // min(a2, max(a0,a1))
    
      // Stage 3
      tmp_3_0 = (tmp_1_0 > tmp_2_1) ? tmp_2_1 : tmp_1_0;    // min
      tmp_3_1 = (tmp_1_0 > tmp_2_1) ? tmp_1_0 : tmp_2_1;    // middle
    
      // Output - if any are invalid, take the min
      out = (a0==invalid_val || a1==invalid_val || a2==invalid_val) ? tmp_3_0 : tmp_3_1;
      
      if(out == '1) // if out is invalid
        out = '0;   // return to normal invalid theta value
    end
endtask // median_of_three







// Staged Sort Four
task automatic sort_four_stage1(input best_trk_t in[4], output best_trk_t out[4]);
    begin
        // Stage 1: compare-swap if (wire[i] < wire[j]) swap(wire[j], wire[i])
        out[0] = (in[0].qual < in[1].qual) ? in[1] : in[0];
        out[1] = (in[0].qual < in[1].qual) ? in[0] : in[1];
        out[2] = (in[2].qual < in[3].qual) ? in[3] : in[2];
        out[3] = (in[2].qual < in[3].qual) ? in[2] : in[3];
    end
endtask // sort_four

task automatic sort_four_stage2(input best_trk_t in[4], output best_trk_t out[4]);
    begin
        // Stage 2:
        out[0] = (in[0].qual < in[2].qual) ? in[2] : in[0];
        out[1] = (in[1].qual < in[3].qual) ? in[3] : in[1];
        out[2] = (in[0].qual < in[2].qual) ? in[0] : in[2];
        out[3] = (in[1].qual < in[3].qual) ? in[1] : in[3];
    end
endtask // sort_four

task automatic sort_four_stage3(input best_trk_t in[4], output best_trk_t out[4]);
    begin
        // Stage 3
        out[0] = in[0];
        out[1] = (in[1].qual < in[2].qual) ? in[2] : in[1];
        out[2] = (in[1].qual < in[2].qual) ? in[1] : in[2];
        out[3] = in[3];
    end
endtask // sort_four



// Staged Merge 8
task automatic merge_eight_stage1(input best_trk_t in[8], output best_trk_t out[6]);
    begin
        // Stage 1: compare-swap if (wire[i] < wire[j]) swap(wire[j], wire[i]) - lowest 2 don't make it past this stage
        out[0] = (in[0].qual < in[4].qual) ? in[4] : in[0];
        out[1] = (in[1].qual < in[5].qual) ? in[5] : in[1];
        out[2] = (in[2].qual < in[6].qual) ? in[6] : in[2];
        out[3] = (in[3].qual < in[7].qual) ? in[7] : in[3];
        out[4] = (in[0].qual < in[4].qual) ? in[0] : in[4];
        out[5] = (in[1].qual < in[5].qual) ? in[1] : in[5];
    end
endtask // merge_eight_stage1


task automatic merge_eight_stage2(input best_trk_t in[6], output best_trk_t out[5]);
    begin
        // Stage 2 
        out[0] = in[0];
        out[1] = in[1];
        out[2] = (in[2].qual < in[4].qual) ? in[4] : in[2];
        out[3] = (in[3].qual < in[5].qual) ? in[5] : in[3];
        out[4] = (in[2].qual < in[4].qual) ? in[2] : in[4];
    end
endtask // merge_eight_stage2


task automatic merge_eight_stage3(input best_trk_t in[5], output best_trk_t out[4]);
    begin
        // Stage 3
        out[0] = in[0];
        out[1] = (in[1].qual < in[2].qual) ? in[2] : in[1];
        out[2] = (in[1].qual < in[2].qual) ? in[1] : in[2];
        out[3] = (in[3].qual < in[4].qual) ? in[4] : in[3];
    end
endtask // merge_eight_stage3





