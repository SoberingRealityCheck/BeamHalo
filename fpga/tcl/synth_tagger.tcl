# synthesizes (and optionally places and routes) tagger_bh for the Kintex-7 325T, out of context.
#
# out of context = no I/O pins. tagger_bh takes the whole sector's segments (6804 bits), far more than the part has pins,
# and in the real design they come from inside the chip anyway. so we time it as a block with its clocks constrained.
#
# usage, from the repo root:
#   mkdir -p fpga/build fpga/reports
#   vivado -mode batch -log fpga/build/run.log -journal fpga/build/run.jou -source fpga/tcl/synth_tagger.tcl -tclargs <clk360_period_ns> <synth|impl> [flat]
#   (-tclargs has to come last. everything after it goes to this script.)
#
#   <clk360_period_ns>  default 2.778 (360 MHz). clk40 is set to 9 times that so the two clocks stay in an exact 9:1 ratio.
#                       try 3.0, 3.5, 4.0 ... to find how fast the design can go on this part.
#   synth | impl        stop after synthesis, or go on to place and route. default impl.
#   flat                optional. use tagger_bh_flat.sv as the top (one flat input vector) if Vivado rejects tagger_bh's array ports.
#
# writes fpga/reports/p<period>/  utilization, utilization by module, timing, and summary.txt (the few numbers to quote)
# checkpoints go in fpga/build/ (not tracked)

set part xc7k325tffg900-2
set src  fpga/beamhalo/beamhalo.srcs/sources_1/new
set emtf $src/emtf

set clk360 2.778
set stage  impl
if {[llength $argv] > 0} { set clk360 [lindex $argv 0] }
if {[llength $argv] > 1} { set stage  [lindex $argv 1] }
set flat 0
if {[llength $argv] > 2 && [lindex $argv 2] eq "flat"} { set flat 1 }
set clk40  [format %.3f [expr {$clk360 * 9}]]

set tag "p$clk360"
if {$flat} { append tag "_flat" }
set rpt fpga/reports/$tag
set bld fpga/build/$tag
file mkdir $rpt $bld

# ---- sources: only what tagger_bh uses ----
read_verilog -sv [list \
    $src/tagger_bh.sv $src/track_finder_bh.sv $src/hitmap_builder_bh.sv $src/tf_pipeline_bh.sv $src/pattern_matcher_bh.sv \
    $emtf/select_curr_fold.sv $emtf/merge_neighbor_columns.sv $emtf/merge8.sv $emtf/recombine_folds.sv $emtf/find_best_tracks.sv]

set top tagger_bh
if {$flat} {
    read_verilog -sv fpga/tcl/tagger_bh_flat.sv
    set top tagger_bh_flat
}

# ---- clocks ----
set xdc $bld/clocks.xdc
set f [open $xdc w]
puts $f "create_clock -name clk360 -period $clk360 \[get_ports clk360\]"
puts $f "create_clock -name clk40  -period $clk40  \[get_ports clk40\]"
close $f
read_xdc $xdc

# ---- synthesis ----
synth_design -top $top -part $part -mode out_of_context -include_dirs [list $emtf $src]
write_checkpoint -force $bld/synth.dcp

proc grab {text label} {
    # finds one row of report_utilization by its name and returns "used of available (percent)".
    # the table is "| name | Used | Fixed | [Prohibited |] Available | Util% |". columns after Used vary by version, so
    # used is the first number and available and percent are the last two. returns n/a if the row is missing.
    foreach line [split $text "\n"] {
        set cols {}
        foreach c [split $line "|"] { lappend cols [string trim $c] }
        if {[llength $cols] > 5 && [lindex $cols 1] eq $label} {
            return "[lindex $cols 2] of [lindex $cols end-2] ([lindex $cols end-1] %)"
        }
    }
    return "n/a (see utilization.rpt)"
}

proc summarize {stage_name} {
    global rpt clk360 clk40 part
    report_utilization -file $rpt/utilization_$stage_name.rpt
    report_utilization -hierarchical -file $rpt/utilization_hier_$stage_name.rpt
    report_timing_summary -max_paths 10 -file $rpt/timing_$stage_name.rpt
    set u [report_utilization -return_string]
    set f [open $rpt/summary_$stage_name.txt w]
    puts $f "part:             $part (out of context, no pins)"
    puts $f "clk360 period:    $clk360 ns   clk40 period: $clk40 ns"
    puts $f "stage:            $stage_name"
    puts $f "Slice LUTs:       [grab $u {Slice LUTs*}]"
    puts $f "Slice registers:  [grab $u {Slice Registers}]"
    puts $f "Block RAM tiles:  [grab $u {Block RAM Tile}]"
    puts $f "DSPs:             [grab $u {DSPs}]"
    set p [get_timing_paths -setup -max_paths 1]
    if {[llength $p]} { puts $f "worst setup slack: [get_property SLACK $p] ns   (negative = fails timing)" }
    close $f
    puts "=============== $stage_name summary ==============="
    set f [open $rpt/summary_$stage_name.txt r]; puts [read $f]; close $f
}

summarize synth
if {$stage eq "synth"} { exit }

# ---- place and route ----
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force $bld/routed.dcp
summarize routed
report_clock_interaction -file $rpt/clock_interaction.rpt
report_design_analysis -timing -max_paths 10 -file $rpt/design_analysis.rpt
