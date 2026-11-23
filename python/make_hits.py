"""makes fpga/sim_data/hit_data_bh.txt: the 19 test events for the testbench, in the hit_data.txt format.

a beam halo muon flies along the beam, so it crosses every station at the same r and about the same column.
a collision particle comes from the collision point, so its r grows with z and its column drifts.
the busy events come in pairs: one with the halo, then the same event with the halo taken out.
the hit file holds only hits. the particles that made them go in hit_truth_bh.txt for the plots.

usage: python3 python/make_hits.py
"""

from src.builder import EventBuilder
from src.events import SimEvent, assign_seg_slots, write_events, write_truth

OUT = "fpga/sim_data/hit_data_bh.txt"
TRUTH_OUT = "fpga/sim_data/hit_truth_bh.txt"
N_EVENTS = 19            # the reference testbench reads 19 events

b = EventBuilder(seed=1)
demo, second, third = b.busy_event(120), b.busy_event(200), b.busy_event(150)
events = [
    SimEvent([b.halo(120, r=3.0, wander=0)], []),                         # 0  a clean halo, same column in every row
    SimEvent([b.halo(60, r=4.5, wander=2)], []),                          # 1  the halo wanders by up to 2 columns per row
    SimEvent([], []),                                                     # 2  empty
    SimEvent([b.halo(200, r=2.5, gap=range(3, 6))], []),                  # 3  rows 3 to 5 missing
    SimEvent([], b.noise(48)),                                            # 4  random hits only
    demo,                                                                 # 5  the demo event: a halo, 3 collision tracks and noise
    demo.without("halo"),                                                 # 6  the same event with the halo taken out
    second,                                                               # 7  another busy event
    second.without("halo"),                                               # 8  and the same without its halo
    SimEvent([b.halo(20, r=3.0)], []),                                    # 9  near the left edge
    SimEvent([b.halo(270, r=3.0)], []),                                   # 10 near the right edge
    SimEvent([b.halo(31, r=3.0)], []),                                    # 11 on a fold boundary. folds are 32 columns
    SimEvent([b.halo(32, r=3.0)], []),                                    # 12 the other side of it
    third,                                                                # 13 another busy event
    third.without("halo"),                                                # 14 and the same without its halo
    SimEvent([b.cosmic()], []),                                           # 15 a cosmic ray alone
]
events += [SimEvent([], []) for _ in range(N_EVENTS - len(events))]

hit_lists = [assign_seg_slots(e.hits) for e in events]
write_events(OUT, hit_lists)
write_truth(TRUTH_OUT, events, hit_lists)
print(f"wrote {OUT}: {len(events)} events, {sum(len(h) for h in hit_lists)} hits")
