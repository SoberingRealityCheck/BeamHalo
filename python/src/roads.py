"""the road quality the firmware dumps: one quality per hitmap column."""

from dataclasses import dataclass, field
from typing import Dict

from .geometry import NUM_COLS

# HACK: the testbench stamps lines with bx and clock ticks, not event numbers. these offsets were found by searching
# for the ones that make the roads of all 19 events line up. they hold only for the current testbench and pipeline.
ROAD_LAG_BX = 2             # roads of event N come out ROAD_LAG_BX bx after the event, in 9 folds ("cycles") per bx
FIRST_CYCLE = 5             # clk360 tick on which a burst of 9 folds starts
FOLD_SHIFT = 5              # the printed fold number runs ahead of the real one by this much
FOLDS, FOLD_COLS = 9, 32    # the hitmap goes through the pattern matcher in 9 pieces of 32 columns


@dataclass
class Roads:
    quality: Dict[int, int] = field(default_factory=dict)   # hitmap column -> quality. columns with no sample are left out

    def columns(self):
        return sorted(self.quality)

    def best_column(self):
        """the middle column of the highest hump, or None if there are no roads"""
        peaks = self.peaks(1)
        return max(peaks, key=self.quality.get) if peaks else None

    def peaks(self, min_quality: int):
        """the best road of each hump: the middle column of every run of equal quality that is higher than both its
        neighbors, and at least min_quality. a flat top gives one column. the emulator's own road sorting is not modeled."""
        peaks = []
        columns = self.columns()
        i = 0
        while i < len(columns):
            j = i
            while j + 1 < len(columns) and columns[j + 1] == columns[j] + 1 and self.quality[columns[j + 1]] == self.quality[columns[i]]:
                j += 1
            q = self.quality[columns[i]]
            if q >= min_quality and q > self.quality.get(columns[i] - 1, 0) and q > self.quality.get(columns[j] + 1, 0):
                peaks.append((columns[i] + columns[j]) // 2)
            i = j + 1
        return peaks


def read_roads(path: str, event: int) -> Roads:
    """the roads of one event from a stage2_matches.txt dump. lines are 'bx fold zone col pattern quality cycle'."""
    roads = Roads()
    for line in open(path):
        _bx, fold, _zone, col, _pattern, quality, cycle = (int(x) for x in line.split())
        if (cycle - FIRST_CYCLE) // FOLDS - ROAD_LAG_BX == event:
            column = FOLD_COLS * ((fold - FOLD_SHIFT) % FOLDS) + col - 1       # a fold has one extra column on each side
            if 0 <= column < NUM_COLS:
                roads.quality[column] = quality
    return roads
