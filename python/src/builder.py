"""makes test events from particles. a particle is a track through the detector, and its hits are where the track crosses a station."""

import math
import random
from typing import List, Optional

from .detector import HOST_POSITION, HOST_R_RANGE, R_NOISE_M, theta_from_r
from .events import Event, Hit, Particle, SimEvent
from .geometry import HITMAP_OFFSET, HOSTS, HOSTS_BY_ROW, NUM_COLS, NUM_ROWS, Host, chamber_for, chambers_of


class EventBuilder:
    """it holds the random generator, so the same seed gives the same events."""

    def __init__(self, seed: int):
        self.rng = random.Random(seed)

    def hit_at_column(self, host: Host, hitmap_col: int, r: float) -> Optional[Hit]:
        """a hit on this host at a hitmap column and radius r (m), or None if none of its chambers reaches that column"""
        col = hitmap_col + HITMAP_OFFSET
        chamber = chamber_for(host, col)
        if chamber is None:
            return None
        z, _ = HOST_POSITION[host.number]
        return Hit(host.number, chamber.index, 0, col * 16 + self.rng.randrange(16), theta1=theta_from_r(r, z))

    def fill_hits(self, particle: Particle, rows=range(NUM_ROWS), wander: int = 0) -> Particle:
        """give a particle the hits of its track. in each row it hits the host whose ring the track is in at that station's z.
        no hit if it is between rings, or the column is outside the chambers. `wander` adds a random walk of up to
        that many columns per row (a guess, not measured)."""
        walk = 0
        for row in range(NUM_ROWS):
            walk += self.rng.randint(-wander, wander)
            for host in HOSTS_BY_ROW[row]:
                z, _ = HOST_POSITION[host.number]
                low, high = HOST_R_RANGE[host.number]
                if row in rows and low <= particle.r_at(z) <= high:
                    r = particle.r_at(z) + self.rng.gauss(0, R_NOISE_M)       # the measured r is a little off
                    hit = self.hit_at_column(host, round(particle.col_at(z) + walk), r)
                    if hit:
                        particle.hits.append(hit)
        return particle

    def halo(self, col: int, r: float, wander: int = 1, gap: range = range(0)) -> Particle:
        """a beam halo muon at radius r. it flies along the beam, so every row sees it at about the same column.
        rows in `gap` get no hit."""
        return self.fill_hits(Particle("halo", [r, col], []), rows=[row for row in range(NUM_ROWS) if row not in gap], wander=wander)

    def collision(self, col_at_z8: int, tan_theta: float, bend: float, curve: float, n_rows: int) -> Particle:
        """a particle from the collision point. its radius grows with z. its column drifts by `bend` columns per meter
        and curves by `curve` columns per meter squared. it only hits n_rows of the 8 rows, picked at random."""
        rows = self.rng.sample(range(NUM_ROWS), n_rows)
        return self.fill_hits(Particle("collision", [tan_theta, col_at_z8 - bend * 8.0 - curve * 64.0, bend, curve], []), rows=rows)

    def cosmic(self) -> Particle:
        """a cosmic ray muon from the sky. it crosses the endcap nearly square to the beam, so it sweeps across r and
        angle while it moves only a little in z. it passes through the sector's wedge at a random angle."""
        angle = math.radians(self.rng.uniform(10, 65))
        r = self.rng.uniform(2.0, 6.0)
        move = math.radians(self.rng.uniform(0, 360))             # which way it crosses, in the transverse plane
        size = self.rng.uniform(3, 7)                             # transverse meters moved per meter of z
        return self.fill_hits(Particle("cosmic", [r * math.cos(angle), r * math.sin(angle),
                                                  size * math.cos(move), size * math.sin(move)], []))

    def noise(self, n: int) -> Event:
        """n hits at random places inside random chambers"""
        hits: Event = []
        for _ in range(n):
            host = self.rng.choice(HOSTS)
            chamber = self.rng.choice(chambers_of(host))
            z, _ = HOST_POSITION[host.number]
            phi = (chamber.start + self.rng.randrange(chamber.width)) * 16 + self.rng.randrange(16)
            hits.append(Hit(host.number, chamber.index, 0, phi, theta1=theta_from_r(self.rng.uniform(*HOST_R_RANGE[host.number]), z)))
        return hits

    def busy_event(self, halo_col: int) -> SimEvent:
        """one halo with a gap, 3 collision tracks and some noise. no cosmic. at most about 43 hits, the testbench takes 64."""
        gap_start = self.rng.randrange(1, 6)
        particles = [self.halo(halo_col, r=self.rng.uniform(2.0, 6.0), wander=2, gap=range(gap_start, gap_start + self.rng.randint(0, 2)))]
        for _ in range(3):
            sign = self.rng.choice([-1, 1])          # the charge. the drift and the curve bend the same way
            particles.append(self.collision(self.rng.randrange(NUM_COLS), self.rng.uniform(0.25, 0.8),
                                            sign * self.rng.uniform(3, 8), sign * self.rng.uniform(0.3, 0.8), self.rng.randint(4, 6)))
        return SimEvent(particles, self.noise(self.rng.randint(8, 20)))
