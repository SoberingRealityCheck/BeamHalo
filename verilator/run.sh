#!/bin/bash
# makes the hit file, runs the python model, builds + runs tb_tagger_bh under verilator, compares them.
set -e
cd "$(dirname "$0")/.."                                  # repo root
SRC=fpga/beamhalo/beamhalo.srcs
N=$SRC/sources_1/new
E=$N/emtf
V=verilator

python3 python/make_hits.py
python3 python/bh_model.py > /dev/null

rm -rf $V/obj $V/run
mkdir -p $V/run/a/b/c/d/e $V/run/sim_data/out           # the testbench path is ../../../../../sim_data/, five levels up
cp fpga/sim_data/hit_data_bh.txt $V/run/sim_data/

verilator --binary --timing -Wno-fatal -Wno-style -Wno-lint --top-module tb_tagger_bh -I$E -I$N --Mdir $V/obj -o simbh \
    $SRC/sim_1/new/tb_tagger_bh.sv $N/tagger_bh.sv $N/track_finder_bh.sv $N/hitmap_builder_bh.sv $N/tf_pipeline_bh.sv \
    $N/pattern_matcher_bh.sv $E/select_curr_fold.sv $E/recombine_folds.sv $V/stubs.sv $V/clkwiz_sim.sv > $V/build.log 2>&1 \
    || { echo "verilator build failed, see $V/build.log"; exit 1; }

(cd $V/run/a/b/c/d/e && ../../../../../../obj/simbh | tail -2)
python3 python/compare_bh.py $V/run/sim_data/out fpga/sim_data/out
