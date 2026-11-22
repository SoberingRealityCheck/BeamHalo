Runs tb_tagger_bh on this Mac with verilator and checks it against the python model. No Vivado needed.

    bash verilator/run.sh        (from the repo root)

What it stands in for:
  stubs.sv        merge_neighbor_columns and find_best_tracks. verilator can't parse the non-constant slices in
                  his versions (merge8 too, but that one is only reached through find_best_tracks).
                  the stubs output zeros, so stage3, stage4 and stage5 are empty here. stages 0, 1, 2 are real.
  clkwiz_sim.sv   the clk_wiz_for_tb IP. 360 MHz from a delay, 40 MHz from every 9th clk360 edge.

This checks function only. It is not xsim and it says nothing about timing or fit.

