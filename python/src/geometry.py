"""where beam halo hits can land: which hosts feed which hitmap row, and where each chamber sits.

the numbers come from common.svh (the hosts list, ph_init_bt, max_coverage_bt) and hitmap_builder_bh.sv (the rows).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional

NUM_ROWS = 8
NUM_COLS = 288
HITMAP_OFFSET = 27   # chamber column 27 is hitmap column 0. everything left of it is cut off
COLS_PER_DEGREE = 3.75   # a ten degree chamber spans 37.5 columns (the chamber starts are 37 or 38 apart)
PAD = 55             # every pattern window is centered on this value

CHAMBER_STARTS = {10: [38, 75, 113, 150, 188, 225, 263], 20: [0, 75, 150, 225]}   # ph_init_bt, by chamber size in degrees
CHAMBER_WIDTH = {10: 53, 20: 90}                                                  # max_coverage_bt


@dataclass(frozen=True)
class Host:
    """a group of chambers. number is its place in the hosts list in common.svh."""
    number: int
    name: str
    row: int        # the hitmap row it feeds
    degrees: int    # 10 or 20, the chamber size


@dataclass(frozen=True)
class Chamber:
    host: Host
    index: int      # the "ch" in the hit file
    start: int      # first column
    width: int      # how many columns the firmware accepts

    @property
    def end(self) -> int:
        return self.start + self.width

    def covers(self, col: int) -> bool:
        return self.start <= col < self.end


# the 14 hosts that feed the beam halo hitmap, in row order
HOSTS = [
    Host(3, "ME12", 0, 10),
    Host(4, "RE12", 1, 10),
    Host(5, "GE21", 2, 20), Host(6, "RE22", 2, 10),
    Host(7, "ME21", 3, 20), Host(8, "ME22", 3, 10),
    Host(9, "ME31", 4, 20), Host(10, "ME32", 4, 10),
    Host(11, "RE31", 5, 20), Host(12, "RE32", 5, 10),
    Host(13, "ME41", 6, 20), Host(14, "ME42", 6, 10),
    Host(15, "RE41", 7, 20), Host(16, "RE42", 7, 10),
]
HOST_BY_NUMBER = {h.number: h for h in HOSTS}
HOSTS_BY_ROW: List[List[Host]] = [[h for h in HOSTS if h.row == r] for r in range(NUM_ROWS)]
ROW_NAMES = ["+".join(h.name for h in hosts) for hosts in HOSTS_BY_ROW]


def chambers_of(host: Host) -> List[Chamber]:
    return [Chamber(host, i, start, CHAMBER_WIDTH[host.degrees]) for i, start in enumerate(CHAMBER_STARTS[host.degrees])]


def chamber_for(host: Host, col: int) -> Optional[Chamber]:
    """the first chamber of this host that covers the column, or None"""
    for chamber in chambers_of(host):
        if chamber.covers(col):
            return chamber
    return None


ALL_CHAMBERS = [c for host in HOSTS for c in chambers_of(host)]
