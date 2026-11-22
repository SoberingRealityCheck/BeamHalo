# makes fpga/sim_data/hit_data_bh.txt: test events for the beam halo testbench, in his hit_data.txt format
#
#   14 ints per hit:  endcap sector host ch seg phi theta1 theta2 bend qual1 qual2 zones emtf_time valid
#   each event ends with a line holding 12345.   the testbench reads 19 events, 30 hits max each.
#
# a "halo" here is one hit in each beam halo row at (nearly) the same hitmap column, which is what the road looks for.
# hits only go where a chamber actually covers that column, so a halo near the edge loses the rows whose chambers don't reach it.
#
# usage: python3 python/make_hits.py

import random
from bh_model import BH_ROW_HOSTS, PH_INIT, COVER, HITMAP_OFFSET, chamber_for, kind_of

OUT = "fpga/sim_data/hit_data_bh.txt"
N_EVENTS = 19
rng = random.Random(1)       # fixed seed so the file is the same every run
ALL_HOSTS = [h for hosts in BH_ROW_HOSTS for h in hosts]


def hit(host, ch, phi, seg=0):
    # theta1, bend, qual1 are filler. beam halo hitmap building only looks at valid + phi
    return [1, 1, host, ch, seg, phi, 30, 0, 0, 6, 0, 1, 0, 1]


def hit_at_column(host, hm_col):
    """a hit on this host at hitmap column hm_col, or None if no chamber covers it"""
    phi_col = hm_col + HITMAP_OFFSET
    ch = chamber_for(host, phi_col)
    if ch is None:
        return None
    return hit(host, ch, phi_col * 16 + rng.randrange(16))


def halo(col, rows=range(8), jitter=0):
    hits = []
    for r in rows:
        host = rng.choice(BH_ROW_HOSTS[r])
        c = col + rng.randint(-jitter, jitter)
        h = hit_at_column(host, c)
        if h is None:                      # try the row's other host
            for other in BH_ROW_HOSTS[r]:
                h = hit_at_column(other, c)
                if h:
                    break
        if h:
            hits.append(h)
    return hits


def noise(n):
    hits = []
    for _ in range(n):
        host = rng.choice(ALL_HOSTS)
        kind = kind_of(host)
        ch = rng.randrange(len(PH_INIT[kind]))
        phi_col = PH_INIT[kind][ch] + rng.randrange(COVER[kind])
        hits.append(hit(host, ch, phi_col * 16 + rng.randrange(16)))
    return hits


events = [
    halo(120),                          # 0  clean halo, all 8 rows
    halo(60, jitter=2),                 # 1  all rows, each off by up to 2 columns
    [],                                 # 2  empty
    halo(200, rows=range(0, 6)),        # 3  rows 0 to 5 only
    noise(12),                          # 4  random hits
    halo(20),                           # 5  near the left edge
    halo(270),                          # 6  near the right edge
    halo(100, rows=[0]),                # 7  a single hit
    halo(150, rows=range(4, 8)),        # 8  late rows only
    halo(120) + noise(6),               # 9  halo plus noise
    [],                                 # 10 empty
    halo(80) + halo(220),               # 11 two halos
    halo(31),                           # 12 on a fold boundary (folds are 32 columns)
    halo(32),                           # 13 the other side of it
    halo(287),                          # 14 last column
    halo(0),                            # 15 first column
]
events += [[] for _ in range(N_EVENTS - len(events))]   # pad with empty events

def assign_seg_slots(ev):
    """the testbench stores hits in emtf_segs[host][ch][seg]. two hits with the same slot overwrite each other.
    so give each hit in a chamber its own slot. a chamber holds 2 segments (kChamberSegments), drop any extra."""
    used = {}
    kept = []
    for h in ev:
        n = used.get((h[2], h[3]), 0)
        if n < 2:
            h[4] = n
            used[(h[2], h[3])] = n + 1
            kept.append(h)
    return kept


events = [assign_seg_slots(ev) for ev in events]

with open(OUT, "w") as f:
    for ev in events:
        assert len(ev) <= 30, "testbench reads 30 hits per event at most"
        for h in ev:
            f.write(" ".join(str(x) for x in h) + "\n")
        f.write("12345\n")
print("wrote", OUT, "-", len(events), "events,", sum(len(e) for e in events), "hits")
