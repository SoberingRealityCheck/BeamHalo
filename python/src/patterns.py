"""the beam halo road: for each hitmap row, which columns around the road center must hold a hit.

copied by hand from bh_zone_pd in the CMSSW emulator's EMTFModel.cc (cpp_check/cmssw_src/.../EMTFModel.cc).
a road at column c looks in row r at hitmap columns c + START[r] - CENTER to c + STOP[r] - CENTER.
"""

START = [35, 30, 40, 44, 51, 52, 54, 53]
STOP = [75, 80, 70, 66, 59, 58, 56, 57]
CENTER = 55
MIN_TAG_QUALITY = 10        # a road at least this good tags the event. same cut as tagger_bh.sv


def road_covers(road_col: int, row: int, hitmap_col: int) -> bool:
    """is a hit at this hitmap column, in this row, inside the window of the road at road_col?"""
    return road_col + START[row] - CENTER <= hitmap_col <= road_col + STOP[row] - CENTER


# quality of a road, by which rows its windows found a hit in. index = 8 bit mask, bit r = row r has a hit.
# copied from bh_ql in EMTFModel.cc. it matches pattern_activations_bh zone 0 in patterns_bh.svh (checked 2026-11-23).
# HACK: main's python/make_patterns_bh.py holds its own copy of this list. if one changes, change the other.
QUALITY = [
    0, 3, 0, 3, 0, 3, 0, 3, 4, 8, 4, 8, 5, 8, 5, 8, 6, 10, 6, 10, 6, 10, 6, 10, 12, 14, 12, 14, 12, 14, 12, 14,
    0, 3, 0, 4, 1, 4, 1, 4, 5, 9, 5, 9, 5, 9, 6, 9, 7, 11, 7, 11, 7, 11, 7, 11, 13, 15, 13, 15, 13, 15, 13, 15,
    7, 36, 21, 36, 21, 36, 22, 36, 37, 40, 37, 40, 37, 40, 37, 40, 38, 44, 38, 44, 38, 44, 39, 44, 48, 52, 48, 52, 48, 53, 48, 54,
    23, 36, 24, 36, 25, 36, 26, 36, 37, 41, 37, 41, 37, 41, 38, 41, 39, 45, 39, 45, 39, 45, 39, 45, 49, 55, 49, 55, 49, 56, 49, 57,
    1, 16, 1, 16, 1, 32, 2, 32, 17, 32, 32, 33, 18, 33, 32, 33, 19, 34, 33, 34, 33, 34, 33, 34, 34, 35, 34, 35, 34, 35, 35, 35,
    2, 32, 2, 32, 2, 32, 2, 32, 32, 33, 32, 33, 32, 33, 32, 33, 20, 34, 33, 34, 33, 34, 34, 34, 35, 35, 35, 35, 35, 35, 35, 36,
    7, 36, 26, 36, 27, 36, 28, 37, 38, 42, 38, 42, 38, 42, 38, 42, 39, 46, 39, 46, 39, 46, 39, 46, 50, 58, 50, 59, 50, 59, 50, 60,
    29, 37, 30, 37, 31, 37, 31, 37, 38, 43, 38, 43, 38, 43, 38, 43, 39, 47, 39, 47, 39, 47, 39, 47, 51, 61, 51, 62, 51, 63, 51, 63,
]


def quality_at_offset(offset: int) -> int:
    """the quality of a road `offset` columns away from a straight track that hits every row at the same column.
    a row counts if the track is inside that row's window. narrow rows drop out first, so quality falls in steps."""
    mask = sum(1 << row for row in range(len(START)) if START[row] - CENTER <= offset <= STOP[row] - CENTER)
    return QUALITY[mask]
