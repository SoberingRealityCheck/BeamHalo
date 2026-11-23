"""the hitmap the firmware dumps: 8 rows by 288 columns of hit or no hit."""

from dataclasses import dataclass, field
from typing import Dict

from .geometry import NUM_COLS, NUM_ROWS


@dataclass
class Hitmap:
    rows: Dict[int, int] = field(default_factory=dict)      # row -> int, bit c = column c. rows with no hit are left out

    def has(self, row: int, col: int) -> bool:
        return bool((self.rows.get(row, 0) >> col) & 1)

    def as_grid(self):
        """NUM_ROWS lists of NUM_COLS 0/1 values, row 0 first"""
        return [[int(self.has(r, c)) for c in range(NUM_COLS)] for r in range(NUM_ROWS)]


def read_hitmap(path: str, bx: int) -> Hitmap:
    """the hitmap stamped bx in a stage1_hitmaps.txt dump. lines are 'bx zone row hex'. an unknown bx gives an empty hitmap."""
    hitmap = Hitmap()
    for line in open(path):
        line_bx, _zone, row, hex_row = line.split()
        if int(line_bx) == bx:
            hitmap.rows[int(row)] = int(hex_row, 16)
    return hitmap
