# reference model of the beam halo path: segments -> hitmap -> pattern match -> tag.
#
# honest code: values in, values out, no hardware. it mirrors what hitmap_builder_bh.sv and
# pattern_matcher_bh.sv are supposed to do, so a mismatch against the xsim dumps points at one stage.
#
# NOT modeled: his suppression and sorting (merge_neighbor_columns, merge8, find_best_tracks).
# so the "tag" here is "any column has quality > 0", the same thing the tagger computes from the best tracks.
#
# usage: python3 python/bh_model.py [fpga/sim_data/hit_data_bh.txt]
# writes fpga/sim_data/out/model_hitmaps.txt and model_roads.txt

import sys
from bh_tables import load

# ---- geometry. from common.svh, hitmap_builder_bh.sv ----
NUM_ROWS = 8
NUM_COLS = 288
HITMAP_OFFSET = 27           # hitmap_offset: chamber column 27 is hitmap column 0
PAD = 55                     # max_padding: a pattern's center value
BH_ROW_HOSTS = [[3], [4], [5, 6], [7, 8], [9, 10], [11, 12], [13, 14], [15, 16]]   # host numbers per row, hosts_by_row_bh
HOST_ROW = {h: r for r, hosts in enumerate(BH_ROW_HOSTS) for h in hosts}
TWENTY_DEG_HOSTS = {5, 7, 9, 11, 13, 15}                                            # type_by_host: everything else is ten_deg
PH_INIT = {"ten": [38, 75, 113, 150, 188, 225, 263], "twenty": [0, 75, 150, 225]}  # ph_init_bt
COVER = {"ten": 53, "twenty": 90}                                                   # max_coverage_bt
EVENT_END = 12345


def kind_of(host):
    return "twenty" if host in TWENTY_DEG_HOSTS else "ten"


def chamber_for(host, phi_col):
    """first chamber of this host whose columns cover phi_col (phi >> 4), or None"""
    kind = kind_of(host)
    for ch, start in enumerate(PH_INIT[kind]):
        if 0 <= phi_col - start < COVER[kind]:
            return ch
    return None


def build_hitmap(hits):
    """hits: list of dicts with host, ch, phi, valid. returns 8 ints, bit c of row r = hitmap column c"""
    rows = [0] * NUM_ROWS
    for h in hits:
        if not h["valid"]:
            continue
        row = HOST_ROW.get(h["host"])
        if row is None:
            continue                                  # host isn't in a beam halo row
        kind = kind_of(h["host"])
        if h["ch"] >= len(PH_INIT[kind]):
            continue                                  # no such chamber (ch_per_host_bt)
        col = (h["phi"] >> 4) & 0x1FF                 # trk_col_t is 9 bits
        idx = (col - PH_INIT[kind][h["ch"]]) & 0x1FF  # unsigned wrap, like the hardware subtract
        if idx >= COVER[kind]:
            continue                                  # outside this chamber's coverage
        c = col - HITMAP_OFFSET                       # chamber bit ph_init+idx == col, then crop 27 off the left
        if 0 <= c < NUM_COLS:
            rows[row] |= 1 << c
    return rows


def match(hitmap, pattern_rows, ql):
    """per hitmap column: (mask, quality). mask bit r = row r has a hit inside its window"""
    out = []
    for c in range(NUM_COLS):
        mask = 0
        for r, (begin, _center, end) in enumerate(pattern_rows):
            lo = max(c + begin - PAD, 0)
            hi = min(c + end - PAD, NUM_COLS - 1)
            if lo <= hi and (hitmap[r] >> lo) & ((1 << (hi - lo + 1)) - 1):
                mask |= 1 << r
        out.append((mask, ql[mask]))
    return out


# ---- reading the hit file the way his testbench does ----
def read_events(path, n_events=19, max_hits=30):
    tokens = [int(t) for t in open(path).read().split()]
    pos = 0
    events = []
    for _ in range(n_events):
        hits = []
        for _ in range(max_hits):
            if pos >= len(tokens):
                break
            if tokens[pos] == EVENT_END:
                pos += 1
                break
            f = tokens[pos:pos + 14]
            pos += 14
            hits.append(dict(endcap=f[0], sector=f[1], host=f[2], ch=f[3], seg=f[4], phi=f[5], theta1=f[6],
                             theta2=f[7], bend=f[8], qual1=f[9], qual2=f[10], zones=f[11], time=f[12], valid=f[13]))
        events.append(hits)
    return events


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "fpga/sim_data/hit_data_bh.txt"
    rows, ql = load()
    events = read_events(path)

    f_hm = open("fpga/sim_data/out/model_hitmaps.txt", "w")
    f_rd = open("fpga/sim_data/out/model_roads.txt", "w")
    print("evt  hits  rows_hit  best_qual  best_cols            tag")
    for e, hits in enumerate(events):
        hm = build_hitmap(hits)
        for r, row in enumerate(hm):
            if row:
                f_hm.write(f"{e} 0 {r} {row:072x}\n")
        res = match(hm, rows, ql)
        for c, (mask, q) in enumerate(res):
            if q:
                f_rd.write(f"{e} {c} 0 {q}\n")
        best = max(q for _, q in res)
        best_cols = [c for c, (_, q) in enumerate(res) if q == best] if best else []
        shown = f"{best_cols[0]}..{best_cols[-1]} ({len(best_cols)})" if best_cols else "-"
        print(f"{e:3d}  {len(hits):4d}  {sum(1 for r in hm if r):8d}  {best:9d}  {shown:20s} {int(best > 0)}")
