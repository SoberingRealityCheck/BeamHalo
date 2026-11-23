"""hits and events, in the file format of the reference testbench (hit_data.txt), and a builder for test events.

a hit file is a list of events. each hit is one line of 14 numbers, and each event ends with a line holding 12345.
"""

from __future__ import annotations

import copy
import math
from dataclasses import dataclass
from typing import List

from .geometry import COLS_PER_DEGREE


EVENT_END = 12345
MAX_HITS = 64           # tb_tagger_bh reads 64 hits per event at most (n_hits). the reference testbench took 30
SEGMENTS_PER_CHAMBER = 2


@dataclass
class Hit:
    """one segment. host, ch and seg say where it came from, and phi says where it is.

    beam halo only reads valid and phi. the other fields are filler so the file loads in the reference testbench."""
    host: int
    ch: int
    seg: int
    phi: int
    valid: bool = True
    endcap: int = 1
    sector: int = 1
    theta1: int = 30
    theta2: int = 0
    bend: int = 0
    qual1: int = 6
    qual2: int = 0
    zones: int = 1
    emtf_time: int = 0

    @property
    def col(self) -> int:
        """phi in hitmap column units. the hardware drops the 4 low bits."""
        return self.phi >> 4

    def to_numbers(self) -> List[int]:
        return [self.endcap, self.sector, self.host, self.ch, self.seg, self.phi, self.theta1, self.theta2,
                self.bend, self.qual1, self.qual2, self.zones, self.emtf_time, int(self.valid)]

    @classmethod
    def from_numbers(cls, n: List[int]) -> "Hit":
        return cls(host=n[2], ch=n[3], seg=n[4], phi=n[5], valid=bool(n[13]), endcap=n[0], sector=n[1],
                   theta1=n[6], theta2=n[7], bend=n[8], qual1=n[9], qual2=n[10], zones=n[11], emtf_time=n[12])


Event = List[Hit]


def read_events(path: str) -> List[Event]:
    numbers = [int(t) for t in open(path).read().split()]
    events: List[Event] = []
    pos = 0
    while pos < len(numbers):
        event: Event = []
        while pos < len(numbers) and numbers[pos] != EVENT_END:
            event.append(Hit.from_numbers(numbers[pos:pos + 14]))
            pos += 14
        pos += 1                                    # the end marker
        events.append(event)
    return events


def write_events(path: str, events: List[Event]) -> None:
    with open(path, "w") as f:
        for event in events:
            assert len(event) <= MAX_HITS, f"the reference testbench reads {MAX_HITS} hits per event at most"
            for hit in event:
                f.write(" ".join(str(n) for n in hit.to_numbers()) + "\n")
            f.write(f"{EVENT_END}\n")


def assign_seg_slots(event: Event) -> Event:
    """the reference testbench stores a hit at [host][ch][seg], so two hits with the same slot overwrite each other.
    gives each hit in a chamber its own slot. a chamber holds 2 segments, so any extra hit is dropped."""
    used = {}
    kept = []
    for hit in event:
        n = used.get((hit.host, hit.ch), 0)
        if n < SEGMENTS_PER_CHAMBER:
            hit.seg = n
            used[(hit.host, hit.ch)] = n + 1
            kept.append(hit)
    return kept


Z_REF = 8.5             # a cosmic's position is given at this z (m), the middle of the stations


@dataclass
class Particle:
    """a particle that went through the detector, and the hits it left. the hits are all the hit file knows about it.
    r_at(z) is its distance from the beam at z (m). col_at(z) is the hitmap column it crosses there. params by kind:
      halo       r, col                      flies along the beam: the same r and column everywhere
      collision  slope, col0, bend, curve    comes from the collision point: r = slope * z, and the column is
                                             col0 + bend * z + curve * z * z, so it drifts and curves as it bends
      cosmic     x, y, dx, dy                comes from the sky, nearly square to the beam. it is at transverse position (x, y)
                                             (m) at Z_REF and moves (dx, dy) m per m of z. the column is its angle round the beam"""
    kind: str                   # "halo", "collision" or "cosmic"
    params: List[float]
    hits: List[Hit]

    def r_at(self, z: float) -> float:
        if self.kind == "halo":
            return self.params[0]
        if self.kind == "collision":
            return self.params[0] * z
        x, y = self.xy_at(z)
        return math.hypot(x, y)

    def col_at(self, z: float) -> float:
        if self.kind == "halo":
            return self.params[1]
        if self.kind == "collision":
            _, col0, bend, curve = self.params
            return col0 + bend * z + curve * z * z
        x, y = self.xy_at(z)
        return math.degrees(math.atan2(y, x)) * COLS_PER_DEGREE

    def xy_at(self, z: float):
        x, y, dx, dy = self.params
        return x + dx * (z - Z_REF), y + dy * (z - Z_REF)


@dataclass
class SimEvent:
    """one event as it was made: the particles and the noise hits. the hit file keeps only the hits."""
    particles: List[Particle]
    noise: List[Hit]

    @property
    def hits(self) -> Event:
        return [h for p in self.particles for h in p.hits] + self.noise

    def without(self, kind: str) -> "SimEvent":
        """the same event with every particle of this kind taken out. the hits are copies, so the two events are independent."""
        return copy.deepcopy(SimEvent([p for p in self.particles if p.kind != kind], self.noise))


def write_truth(path: str, sim_events: List[SimEvent], events: List[Event]) -> None:
    """what made each event, one line per particle: event kind number_of_params params, then the positions of its hits in the
    event's hit list. `events` are the hit lists as written (assign_seg_slots can drop hits)."""
    with open(path, "w") as f:
        for number, (sim, event) in enumerate(zip(sim_events, events)):
            position = {id(h): i for i, h in enumerate(event)}
            for p in sim.particles:
                kept = [position[id(h)] for h in p.hits if id(h) in position]
                f.write(f"{number} {p.kind} {len(p.params)} {' '.join(map(str, p.params))} {' '.join(map(str, kept))}\n")


def read_truth(path: str, events: List[Event]) -> List[List[Particle]]:
    """the particles of every event, with their Hit objects taken from `events`"""
    particles: List[List[Particle]] = [[] for _ in events]
    for line in open(path):
        number, kind, n_params, *rest = line.split()
        params, positions = [float(x) for x in rest[:int(n_params)]], rest[int(n_params):]
        particles[int(number)].append(Particle(kind, params, [events[int(number)][int(i)] for i in positions]))
    return particles
