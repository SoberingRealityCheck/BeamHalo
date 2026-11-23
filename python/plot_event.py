"""plots one event from the testbench dump as one figure of 3 columns by 3 rows.
column 1 is what the firmware saw: segments, then the hitmap with the road windows on it, then the legend for the whole figure.
column 2 is the side view: the particles, the hits they left, then the road quality at every column.
column 3 is the cross-section: the particles, the hits they left, and the best roads that pass the tag cut.
a road is navy if it is a true positive (it holds halo hits) and red if it is a false positive, in every panel that shows it.

usage: python3 python/plot_event.py [event] [dump_dir] [hit_file]
  defaults: 0, verilator/run/sim_data/out, fpga/sim_data/hit_data_bh.txt
writes plots/event_<N>.png
"""

import os
import sys

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import ListedColormap, to_rgba
from matplotlib.lines import Line2D
from matplotlib.patches import Polygon

from src.events import read_events, read_truth
from src.geometry import HITMAP_OFFSET, HOST_BY_NUMBER, NUM_COLS, NUM_ROWS, ROW_NAMES
from src.hitmap import read_hitmap
from src.patterns import CENTER, MIN_TAG_QUALITY, START, STOP, road_covers
from src.roads import read_roads
from src.views import CrossSectionView, SideView

KIND_COLORS = {"halo": "tab:green", "collision": "gold", "noise": "tab:purple", "cosmic": "tab:blue"}   # what made the hit or the track
# the two kinds of road. neither color looks like a kind color above, so a road is never mistaken for a kind of hit.
TP_COLOR, FP_COLOR = "navy", "tab:red"
HITMAP_LAG_BX = 2           # hitmap of event N is stamped bx N + 2. same hack as the road offsets in src/roads.py


class EventPlot:
    """everything known about one event, and the panels that draw it"""

    def __init__(self, event_number: int, dump_dir: str, hit_file: str, truth_file: str):
        self.number = event_number
        events = read_events(hit_file)
        self.event = events[event_number]
        self.particles = read_truth(truth_file, events)[event_number]
        self.hitmap = read_hitmap(f"{dump_dir}/stage1_hitmaps.txt", event_number + HITMAP_LAG_BX)
        self.roads = read_roads(f"{dump_dir}/stage2_matches.txt", event_number)
        self.kind_of_hit = {id(h): p.kind for p in self.particles for h in p.hits}     # a hit with no particle is noise
        self.best_roads = self.passing_roads()      # [(column, quality, hits)]

    def kind(self, hit) -> str:
        return self.kind_of_hit.get(id(hit), "noise")

    # ---- the roads that pass the cut
    def passing_roads(self):
        """(column, quality, hits) for the best road of every hump at or above the tag cut. hits are the event's hits inside
        that road's windows, from any particle or noise. the matcher doesn't know which particle made them.
        HACK: python picks the roads (Roads.peaks) and the hits (road_covers). the firmware dumps neither. in this
        simulation the track sorter is stubbed out (stubs.sv, stage3 and stage4 are empty), so there is no firmware list to compare to."""
        roads = []
        for col in self.roads.peaks(MIN_TAG_QUALITY):
            hits = [h for h in self.event if road_covers(col, HOST_BY_NUMBER[h.host].row, h.col - HITMAP_OFFSET)]
            roads.append((col, self.roads.quality[col], hits))
        return roads

    def road_color(self, hits) -> str:
        """navy for a true positive road, red for a false positive one. HACK: a road is a true positive if even one of the
        hits in its windows is a halo hit. a noise road that picks up a stray halo hit would count as true."""
        return TP_COLOR if any(self.kind(h) == "halo" for h in hits) else FP_COLOR

    # ---- column 1 and the quality plot
    def draw_segments(self, ax):
        """one dot per hit, at its hitmap column, on the row of its host. hits left of the hitmap land at negative columns."""
        for hit in self.event:
            ax.plot(hit.col - HITMAP_OFFSET, HOST_BY_NUMBER[hit.host].row, "o", color=KIND_COLORS[self.kind(hit)])
        ax.set_yticks(range(NUM_ROWS), ROW_NAMES)
        ax.set_ylim(NUM_ROWS - 0.5, -0.5)
        ax.set_title("Segments sent to the tagger")

    def draw_hitmap(self, ax):
        """the hits as black cells, inside an outline for every best road. the outline is the road's window in each row:
        a hit inside it counts for the road. rows top to bottom, columns left to right."""
        for col, _quality, hits in self.best_roads:
            color = self.road_color(hits)
            left =[col + START[row] - CENTER - 0.5 for row in range(NUM_ROWS)]
            right = [col + STOP[row] - CENTER + 0.5 for row in range(NUM_ROWS)]
            down_the_left = [p for row in range(NUM_ROWS) for p in ((left[row], row - 0.5), (left[row], row + 0.5))]
            up_the_right = [p for row in reversed(range(NUM_ROWS)) for p in ((right[row], row + 0.5), (right[row], row - 0.5))]
            ax.add_patch(Polygon(down_the_left + up_the_right, closed=True, facecolor=to_rgba(color, 0.08), edgecolor=color, lw=1.5))
        ax.imshow(np.ma.masked_equal(np.array(self.hitmap.as_grid()), 0), aspect="auto", cmap=ListedColormap(["black"]), interpolation="nearest")
        ax.set_yticks(range(NUM_ROWS), ROW_NAMES)
        ax.set_title("Hitmap + road windows")
        ax.set_xlabel("hitmap column")

    def draw_roads(self, ax):
        """a bar for every column the firmware gave a quality for. columns it gave nothing for stay empty,
        so the plot doesn't make up numbers between them. the best roads are navy (TP) or red (FP)."""
        columns = self.roads.columns()
        colors = {col: self.road_color(hits) for col, _q, hits in self.best_roads}
        ax.bar(columns, [self.roads.quality[c] for c in columns], width=1.0, color=[colors.get(c, "lightsteelblue") for c in columns])
        ax.axhline(MIN_TAG_QUALITY, color="black", linestyle="--")
        ax.set_title("Road quality by column")
        ax.set_xlabel("hitmap column")
        ax.set_ylabel("quality")
        ax.set_xlim(0, NUM_COLS)

    def draw_legend(self, ax):
        """one short legend for the whole figure, in its own empty panel. only the kinds of hit that are in this event"""
        ax.axis("off")
        kinds = {self.kind(h) for h in self.event} | {p.kind for p in self.particles}
        handles = [Line2D([], [], color=color, marker="o", lw=2, label=kind) for kind, color in KIND_COLORS.items() if kind in kinds]
        handles += [Line2D([], [], color=TP_COLOR, lw=6, alpha=0.6, label="TP road (has halo hits)"),
                    Line2D([], [], color=FP_COLOR, lw=6, alpha=0.6, label="FP road (no halo hits)"),
                    Line2D([], [], color="gray", marker="o", markeredgecolor="black", markeredgewidth=1.5, lw=0, label="hit in a road"),
                    Line2D([], [], color="gray", marker="o", alpha=0.3, lw=0, label="hit in no road"),
                    Line2D([], [], color="black", linestyle="--", label=f"tag cut (quality {MIN_TAG_QUALITY})")]
        ax.legend(handles=handles, loc="center", fontsize=12)

    # ---- the particles, the hits and the roads, seen in any view from src/views.py
    def draw_view(self, view, axes, with_roads=True):
        """the particles and the hits they left. with_roads adds a third panel with the roads that pass the cut.
        only the cross-section can draw a road. a road has a column and no radius, so a side view of it would be made up."""
        ax_true, ax_hits = axes[:2]
        for ax in axes[:3 if with_roads else 2]:
            view.draw_background(ax)
        ax_true.set_title(f"{view.title}: particle paths")
        for p in self.particles:
            view.draw_particle(ax_true, p, KIND_COLORS[p.kind])

        ax_hits.set_title("Chamber hits")
        for hit in self.event:
            view.draw_hit(ax_hits, hit, KIND_COLORS[self.kind(hit)])
        if not with_roads:
            return

        ax_tag = axes[2]
        ax_tag.set_title(f"best_roads)")
        for col, _quality, hits in self.best_roads:
            view.draw_road(ax_tag, col, self.road_color(hits))
        in_a_road = {id(h) for _, _, hits in self.best_roads for h in hits}
        for hit in self.event:
            if id(hit) in in_a_road:
                view.draw_hit(ax_tag, hit, KIND_COLORS[self.kind(hit)], outline="black")
            else:
                view.draw_hit(ax_tag, hit, KIND_COLORS[self.kind(hit)], alpha=0.3)

    def save(self) -> str:
        fig, axes = plt.subplots(3, 3, figsize=(27, 17), gridspec_kw={"width_ratios": [1, 1, 0.85], "height_ratios": [1, 1, 1.5]})   # the wedge needs room to show the roads
        self.draw_segments(axes[0][0])
        self.draw_hitmap(axes[1][0])
        for ax in (axes[0][0], axes[1][0]):
            ax.set_xlim(0, NUM_COLS)
        self.draw_legend(axes[2][0])
        self.draw_view(SideView(), [row[1] for row in axes], with_roads=False)
        self.draw_roads(axes[2][1])
        self.draw_view(CrossSectionView(), [row[2] for row in axes])
        with_halo = any(p.kind == "halo" for p in self.particles)
        fig.suptitle(f"Event {self.number} sim, {'with' if with_halo else 'without'} beam halo", fontsize=16)
        os.makedirs("plots", exist_ok=True)
        path = f"plots/event_{self.number}.png"
        fig.tight_layout(rect=(0, 0, 1, 0.97))
        fig.savefig(path, dpi=80)
        return path


if __name__ == "__main__":
    event_number = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    dump_dir = sys.argv[2] if len(sys.argv) > 2 else "verilator/run/sim_data/out"
    hit_file = sys.argv[3] if len(sys.argv) > 3 else "fpga/sim_data/hit_data_bh.txt"
    plot = EventPlot(event_number, dump_dir, hit_file, hit_file.replace("hit_data", "hit_truth"))
    print(f"wrote {plot.save()}")
