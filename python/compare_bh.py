# compares the testbench dumps (stage0..2) against the python model (bh_model.py output)
#
# usage: python3 python/bh_model.py                      (writes model_*.txt)
#        python3 python/compare_bh.py [rtl_dir] [model_dir]    (both default to fpga/sim_data/out)
#
# stage0: do the segments the DUT sees match the hit file?
# stage1: is the hitmap the DUT built the hitmap the model built?
# stage2: are the per-column road qualities the same? (bh_stages.align_stage2 explains the alignment search)

import sys
from bh_model import read_events
from bh_stages import *

rtl = sys.argv[1] if len(sys.argv) > 1 else "fpga/sim_data/out"
mdl = sys.argv[2] if len(sys.argv) > 2 else "fpga/sim_data/out"
HIT_FILE = "fpga/sim_data/hit_data_bh.txt"

events = read_events(HIT_FILE)
n_events = len(events)

# ---------------- stage 0 ----------------
want = sorted((h["host"], h["ch"], h["phi"] >> 4) for ev in events for h in ev if h["valid"])
got = sorted((host, ch, phi_col) for _bx, _phase, host, ch, phi_col in load_stage0(rtl))
print(f"stage0 segments : {'OK' if want == got else 'MISMATCH'}  ({len(got)} seen, {len(want)} in the hit file)")

# ---------------- stage 1 ----------------
rtl_hm, mdl_hm = load_stage1(rtl), load_model_hitmaps(mdl)
rtl_groups = [rtl_hm[b] for b in sorted(rtl_hm)]
mdl_groups = [mdl_hm[e] for e in sorted(mdl_hm)]
bad = [i for i, (a, b) in enumerate(zip(rtl_groups, mdl_groups)) if a != b]
same_n = len(rtl_groups) == len(mdl_groups)
print(f"stage1 hitmaps  : {'OK' if same_n and not bad else 'MISMATCH'}  "
      f"({len(rtl_groups)} non-empty from the DUT, {len(mdl_groups)} from the model, {len(bad)} differ)")
for i in bad[:5]:
    ev = sorted(mdl_hm)[i]
    for r in sorted(set(rtl_groups[i]) | set(mdl_groups[i])):
        a, b = rtl_groups[i].get(r), mdl_groups[i].get(r)
        if a != b:
            print(f"    event {ev} row {r}\n      dut   {a:072x}\n      model {b:072x}")

# ---------------- stage 2 ----------------
model_roads = load_model_roads(mdl)
K, D, S, score, clash = align_stage2(load_stage2(rtl), model_roads, n_events)
g, _ = group_stage2(load_stage2(rtl), K, D, S)
print(f"stage2 roads    : {'OK' if score == n_events else 'MISMATCH'}  "
      f"({score}/{n_events} events match the model; best alignment K={K} D={D} S={S}; {clash} clashing columns)")
for e in range(n_events):
    a, b = g.get(e, {}), model_roads.get(e, {})
    if a != b:
        diff = sorted(c for c in set(a) | set(b) if a.get(c) != b.get(c))
        print(f"    event {e}: {len(diff)} columns differ, e.g. col {diff[0]} dut={a.get(diff[0])} model={b.get(diff[0])}")
