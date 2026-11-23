"""two ways to look at the detector: from the side (z against r) and down the beam (a wedge of rings).
each view draws a background, a particle and a hit, so the plot can show the same three phases in either one."""

import math

import numpy as np
from matplotlib.patches import Wedge
from PIL import Image

from .patterns import CENTER, START, STOP
from .detector import HOST_POSITION, IMAGE, image_extent, r_from_theta
from .events import Hit, Particle
from .geometry import COLS_PER_DEGREE, HITMAP_OFFSET, HOST_BY_NUMBER, HOSTS_BY_ROW, NUM_COLS, NUM_ROWS, ROW_NAMES

Z_COLLISION_END = 11.5                  # collision tracks are drawn from the collision point out to this z (m)
Z_COSMIC_FROM, Z_COSMIC_TO = 6.0, 11.0  # a cosmic is drawn across the stations
Z_HALO_FROM, Z_HALO_TO = 16.0, -1.0     # a halo muon comes in from the far end and passes the whole picture


def in_sector(particle: Particle, z: float) -> bool:
    """is the particle inside our sector (hitmap columns 0 to NUM_COLS) at z? we only collect data from that wedge, so
    that is the only part of a cosmic worth drawing. its path is a straight line in x-y and the wedge is convex, so
    this is true over one stretch of z."""
    return 0 <= particle.col_at(z) < NUM_COLS


class SideView:
    """the CMS endcap drawing in grayscale, z along the beam (growing to the left) and r up"""
    name = "side"
    title = "Side view (along the beam)"
    figsize = (10, 17)
    panels = (3, 1)                     # rows, columns of subplots

    def draw_background(self, ax):
        picture = Image.open(IMAGE).convert("L")
        ax.imshow(picture, cmap="gray", alpha=0.45, extent=image_extent(*picture.size), aspect="equal")
        ax.set_autoscale_on(False)          # keep the picture whole. a cosmic runs far off it
        ax.set_xlabel("z (m)")
        ax.set_ylabel("r (m)")

    def draw_particle(self, ax, particle: Particle, color: str):
        """a halo muon flies along the beam, toward the collision point. a collision particle starts at the collision point.
        a cosmic is drawn only where it is inside our sector (r is its distance from the beam, so it is a V near the axis)."""
        if particle.kind == "halo":
            zs = [Z_HALO_FROM, Z_HALO_TO]
        elif particle.kind == "collision":
            zs = [0.0, Z_COLLISION_END]
        else:
            zs = [z for z in np.linspace(Z_COSMIC_FROM, Z_COSMIC_TO, 400) if in_sector(particle, z)]
        if len(zs) < 2:
            return                      # a cosmic that never enters our sector (or only between two samples)
        points = [(z, particle.r_at(z)) for z in zs]
        ax.plot(*zip(*points), color=color, lw=2)
        ax.annotate("", xy=points[-1], xytext=points[-2], arrowprops=dict(arrowstyle="->", color=color, lw=2))

    def draw_hit(self, ax, hit: Hit, color: str = "black"):
        z, _ = HOST_POSITION[hit.host]
        ax.plot(z, r_from_theta(hit.theta1, z), "o", color=color, ms=6)


class CrossSectionView:
    """looking down the beam at one sector. one ring per hitmap row, evenly spaced (NOT the real radii), ME12 innermost.
    the angle is the position around the sector, from its first hitmap column. a halo muon is a radial line.
    a collision particle's angle drifts from ring to ring. the sector's real angle in CMS is not known here."""
    name = "cross"
    title = "Cross-section (down the beam)"
    figsize = (19, 7)
    panels = (1, 3)
    SECTOR_DEGREES = NUM_COLS / COLS_PER_DEGREE

    @staticmethod
    def xy(ring: float, degrees: float):
        return ring * math.cos(math.radians(degrees)), ring * math.sin(math.radians(degrees))

    def draw_background(self, ax):
        angles = np.linspace(0, self.SECTOR_DEGREES, 100)
        for row in range(NUM_ROWS):
            ax.plot(*zip(*[self.xy(row + 1, a) for a in angles]), color="lightgray", lw=1)
            ax.text(row + 1, -0.15, ROW_NAMES[row], rotation=90, ha="center", va="top", fontsize=7)
        for a in (0, self.SECTOR_DEGREES):
            ax.plot(*zip(self.xy(0.4, a), self.xy(NUM_ROWS + 0.5, a)), color="lightgray", lw=1)
        # hitmap column ticks around the outer arc, so a spot in the wedge can be matched to the panels on the left
        for col in [*range(0, NUM_COLS, 50), NUM_COLS]:
            a = col / COLS_PER_DEGREE
            ax.plot(*zip(self.xy(NUM_ROWS + 0.5, a), self.xy(NUM_ROWS + 0.65, a)), color="gray", lw=1)
            ax.text(*self.xy(NUM_ROWS + 0.9, a), str(col), ha="center", va="center", fontsize=7, color="gray")
        ax.set_aspect("equal")
        ax.set_anchor("W")                  # the wedge is narrow. keep it against the left of its cell, next to the side view
        ax.set_xlim(-0.5, NUM_ROWS + 2.2)
        ax.set_ylim(-3.2, NUM_ROWS + 1.3)   # room above the arc for the column ticks
        ax.axis("off")

    def draw_particle(self, ax, particle: Particle, color: str):
        """a line out through every ring, at the column the particle crosses that ring's station"""
        rings, angles = [], []
        for row in range(NUM_ROWS):
            z, _ = HOST_POSITION[HOSTS_BY_ROW[row][0].number]
            if particle.kind == "cosmic" and not in_sector(particle, z):
                continue                # outside our wedge at this station. skip the ring
            rings.append(row + 1)
            angles.append(particle.col_at(z) / COLS_PER_DEGREE)
        if not rings:
            return
        if particle.kind != "cosmic":   # halo and collision lines run the full length of the wedge. a cosmic only where it is in it
            rings, angles = [0.4] + rings + [NUM_ROWS + 0.5], [angles[0]] + angles + [angles[-1]]
        elif len(rings) == 1:
            # HACK: a cosmic in our wedge at one station only is a one-point line, and matplotlib draws nothing.
            # draw a short radial tick across that ring so it shows up. the tick's direction means nothing.
            rings, angles = [rings[0] - 0.4, rings[0] + 0.4], angles * 2
        ax.plot(*zip(*[self.xy(r, a) for r, a in zip(rings, angles)]), color=color, lw=2)

    def draw_hit(self, ax, hit: Hit, color: str = "black", alpha: float = 1.0, outline: str = None):
        """outline puts a ring around the dot. the roads panel uses it for hits inside a road."""
        ring = HOST_BY_NUMBER[hit.host].row + 1
        ax.plot(*self.xy(ring, (hit.col - HITMAP_OFFSET) / COLS_PER_DEGREE), "o", color=color, alpha=alpha, ms=5 if outline is None else 7,
                markeredgecolor=outline or color, markeredgewidth=1.5 if outline else 1)

    def draw_road(self, ax, col: int, color: str):
        """a road the way the firmware reads it. in each ring, a block of columns around the road. a hit inside the block
        counts for the road. the blocks are wide in the inner rings and narrow in the outer ones. a thin line marks the
        road's own column."""
        for row in range(NUM_ROWS):
            first = max(col + START[row] - CENTER - 0.5, 0)               # a block never runs past the edge of the hitmap
            last = min(col + STOP[row] - CENTER + 0.5, NUM_COLS)
            ax.add_patch(Wedge((0, 0), row + 1.38, first / COLS_PER_DEGREE, last / COLS_PER_DEGREE, width=0.76, color=color, alpha=0.3, lw=0))
        a = col / COLS_PER_DEGREE
        ax.plot(*zip(self.xy(0.4, a), self.xy(NUM_ROWS + 0.5, a)), color=color, lw=1)
