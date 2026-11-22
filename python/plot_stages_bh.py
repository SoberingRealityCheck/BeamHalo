# one plot per stage of the testbench run, every event on one figure. default matplotlib colors.
#
# usage: python3 python/bh_model.py       (the model is how output gets matched to event numbers)
#        python3 python/plot_stages_bh.py [rtl_dir] [model_dir]       (both default to fpga/sim_data/out)
# writes plots/stages/stage*.png
#
# stage0 segments the DUT sees        x = hitmap column, y = event, color = hitmap row
# stage1 hitmaps                      8 rows per event, stacked
# stage2 road quality per column      x = hitmap column, y = event, color = quality
# stage4 best tracks + stage5 tag     only if the run produced any. the verilator run stubs those stages, so it won't.

import os
import sys
import matplotlib.pyplot as plt

from bh_model import read_events, HOST_ROW
from bh_stages import *

rtl = sys.argv[1] if len(sys.argv) > 1 else "fpga/sim_data/out"
mdl = sys.argv[2] if len(sys.argv) > 2 else "fpga/sim_data/out"
OUT = "plots/stages"
os.makedirs(OUT, exist_ok=True)

events = read_events("fpga/sim_data/hit_data_bh.txt")
n = len(events)


def save(fig, name):
    fig.tight_layout()
    fig.savefig(f"{OUT}/{name}", dpi=130)
    plt.close(fig)
    print("wrote", f"{OUT}/{name}")


# ---- stage 0: segments, one dot per hit ----
by_event = stage0_by_event(load_stage0(rtl), events)
xs, ys, rows = [], [], []
for e, segs in by_event.items():
    for host, ch, phi_col in segs:
        if host in HOST_ROW:
            xs.append(phi_col - HITMAP_OFFSET)
            ys.append(e)
            rows.append(HOST_ROW[host])
fig, ax = plt.subplots(figsize=(9, 5))
sc = ax.scatter(xs, ys, c=rows, s=18)
ax.set_xlim(0, NCOLS)
ax.set_ylim(n - 0.5, -0.5)
ax.set_xlabel("hitmap column")
ax.set_ylabel("event")
ax.set_title("Stage 0: segments entering the DUT")
fig.colorbar(sc, ax=ax, label="hitmap row")
save(fig, "stage0_segments.png")

# ---- stage 1: hitmaps, 8 rows per event stacked ----
hm = load_stage1(rtl)
nonempty_events = sorted(load_model_hitmaps(mdl))              # which events have a hitmap, in order
groups = {e: hm[bx] for e, bx in zip(nonempty_events, sorted(hm))}
image = [[0] * NCOLS for _ in range(n * 8)]
for e, rows_e in groups.items():
    for r, bits in rows_e.items():
        for c in range(NCOLS):
            image[e * 8 + r][c] = (bits >> c) & 1
fig, ax = plt.subplots(figsize=(9, 8))
ax.imshow(image, aspect="auto", interpolation="nearest")
ax.set_yticks([e * 8 + 3.5 for e in range(n)])
ax.set_yticklabels(range(n))
for e in range(1, n):
    ax.axhline(e * 8 - 0.5, color="white", linewidth=0.5)
ax.set_xlabel("hitmap column")
ax.set_ylabel("event (8 rows each, row 0 on top)")
ax.set_title("Stage 1: hitmaps")
save(fig, "stage1_hitmaps.png")

# ---- stage 2: road quality per column ----
K, D, S, score, clash = align_stage2(load_stage2(rtl), load_model_roads(mdl), n)
g, _ = group_stage2(load_stage2(rtl), K, D, S)
image = [[g.get(e, {}).get(c, 0) for c in range(NCOLS)] for e in range(n)]
fig, ax = plt.subplots(figsize=(9, 5))
im = ax.imshow(image, aspect="auto", interpolation="nearest")
ax.set_xlabel("hitmap column")
ax.set_ylabel("event")
ax.set_yticks(range(n))
ax.set_title("Stage 2: road quality per column")
fig.colorbar(im, ax=ax, label="quality")
save(fig, "stage2_roads.png")

# ---- stage 4 + 5: best tracks and the tag, if the run has any ----
tracks, tag = load_stage4(rtl), load_stage5(rtl)
if not tracks and not any(t for _, t in tag):
    print("stage4 / stage5: nothing in this run (stubbed in verilator, or no track found). skipped.")
else:
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(9, 5), sharex=True, gridspec_kw={"height_ratios": [3, 1]})
    if tracks:
        sc = a1.scatter([t[0] for t in tracks], [t[4] for t in tracks], c=[t[3] for t in tracks], s=30)
        fig.colorbar(sc, ax=[a1, a2], label="quality")
    a1.set_ylabel("track column")
    a1.set_title("Stage 4 + 5: best tracks and the tag (bx is clock ticks, not event number)")
    a2.step([b for b, _ in tag], [t for _, t in tag], where="post")
    a2.set_ylabel("tag")
    a2.set_xlabel("bx")
    save(fig, "stage45_tracks_tag.png")
