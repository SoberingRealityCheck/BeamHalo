# plots the beam halo road (pattern): the window each hitmap row searches around a column
#
# reads bh_zone_pd straight out of Osvaldo's EMTFModel.cc, same as make_patterns_bh.py.
# (the regex is copied from there on purpose. wait for a third script before sharing it.)
#
# how to read it: pick a candidate column (x = 0, measured at ME31+ME32). bright cells are the columns, around it,
# where a segment in that row counts as a hit. same row/column layout as the hitmap.
#
# usage: python3 python/plot_roads_bh.py [path/to/EMTFModel.cc]

import sys
import matplotlib.pyplot as plt

from bh_tables import CC, load

OUT = "plots/roads_bh.png"
cc_path = sys.argv[1] if len(sys.argv) > 1 else CC

# what each hitmap row is. from bh_zone_hm in EMTFModel.cc
ROW_NAMES = ["ME12", "RE12", "GE21+RE22", "ME21+ME22", "ME31+ME32", "RE31+RE32", "ME41+ME42", "RE41+RE42"]

rows, _ = load(cc_path)   # each row is (begin, center, end)
assert len(rows) == len(ROW_NAMES), f"expected {len(ROW_NAMES)} rows, got {len(rows)}"

# the road as an image, same layout as the hitmap: rows down, columns across.
# columns are measured from the center column of the REF_ROW row (ME31+ME32).
# right now every row has the same center (55), so the picture is the same whichever row you pick.
# if the centers ever differ per row, this is where they get lined up.
REF_ROW = 4
ref_center = rows[REF_ROW][1]
HALF = 32
cols = range(-HALF, HALF + 1)
image = [[1 if (begin - ref_center) <= c <= (end - ref_center) else 0 for c in cols]
         for (begin, center, end) in rows]

fig, ax = plt.subplots(figsize=(6, 5))
ax.imshow(image, aspect="auto",
          interpolation="nearest", extent=[-HALF - 0.5, HALF + 0.5, len(rows) - 0.5, -0.5])

ax.set_yticks(range(len(rows)))
ax.set_yticklabels([f"{i}  {name}" for i, name in enumerate(ROW_NAMES)])
ax.set_xticks(range(-30, 31, 10))
ax.set_xlabel("cols from road center")
ax.set_title("Beam halo road: search window per hitmap row")
ax.tick_params(length=0)
for side in ax.spines.values():
    side.set_visible(False)

fig.tight_layout()
fig.savefig(OUT, dpi=150)
print("wrote", OUT)
plt.show()
