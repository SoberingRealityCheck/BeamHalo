"""where each host sits in the detector, in meters, read off the CMS endcap muon drawing (python/assets/cms_endcap_muon.png).

z is along the beam from the collision point. r is the distance from the beam. both are estimates measured by eye from the
drawing, good to about 0.2 m. the RPC and GEM stations (RE, GE) are not drawn, so they are placed just in front of the
cathode strip chamber (ME) station they sit with. the ring (inner x1 or outer x2) sets r.
"""

import math
import os
from typing import Dict, Tuple

IMAGE = os.path.join(os.path.dirname(__file__), "..", "assets", "cms_endcap_muon.png")

# where the drawing's axes are, in pixels of the image. found from the labeled ticks (z 10.86 m at x 426, 9.77 m at x 514,
# r 4.0 m at y 411, r 6.0 m at y 253, r 7.1 m at y 163). z grows to the left and the collision point is on the right edge.
IP_X = 1295           # pixel column of z = 0
AXIS_Y = 738          # pixel row of r = 0
PX_PER_M_Z = 80.0
PX_PER_M_R = 81.0

INNER, OUTER, MIDDLE = 2.4, 5.25, 3.5     # r of the x1 ring, the x2 ring, and the single ring of station 1
# host number -> (z, r)
HOST_POSITION: Dict[int, Tuple[float, float]] = {
    3: (6.94, MIDDLE),                                     # ME12
    4: (6.75, MIDDLE),                                     # RE12
    5: (8.10, INNER), 6: (8.10, OUTER),                    # GE21, RE22
    7: (8.25, INNER), 8: (8.25, OUTER),                    # ME21, ME22
    9: (9.50, INNER), 10: (9.50, OUTER),                   # ME31, ME32
    11: (9.35, INNER), 12: (9.35, OUTER),                  # RE31, RE32
    13: (10.44, INNER), 14: (10.44, OUTER),                # ME41, ME42
    15: (10.30, INNER), 16: (10.30, OUTER),                # RE41, RE42
}

# host number -> (lowest r, highest r) of its chambers, read off the drawing. a track outside it misses the host.
HOST_R_RANGE: Dict[int, Tuple[float, float]] = {
    **{n: (2.8, 4.2) for n in (3, 4)},                         # station 1, one ring
    **{n: (1.3, 3.5) for n in (5, 7, 9, 11, 13, 15)},          # the x1 rings
    **{n: (3.6, 6.9) for n in (6, 8, 10, 12, 14, 16)},         # the x2 rings
}


def image_extent(width_px: int, height_px: int) -> Tuple[float, float, float, float]:
    """(left, right, bottom, top) of the image in z and r meters, for imshow(extent=...)"""
    return ((IP_X - 0) / PX_PER_M_Z, (IP_X - width_px) / PX_PER_M_Z,
            (AXIS_Y - height_px) / PX_PER_M_R, AXIS_Y / PX_PER_M_R)


# theta is how a hit says how far from the beam it is. the hit file holds it as an 8 bit number (theta1).
# HACK: the real scale is not known here. this guess spreads 0 to 45 degrees over 0 to 255. beam halo does not read theta.
THETA_UNIT_DEG = 45 / 256
R_NOISE_M = 0.1       # how far a measured r is off the true r (m). a guess, not a detector resolution


def theta_from_r(r: float, z: float) -> int:
    """the 8 bit theta of a hit at radius r (m) on a station at z (m)"""
    return max(0, min(255, round(math.degrees(math.atan2(r, z)) / THETA_UNIT_DEG)))


def r_from_theta(theta: int, z: float) -> float:
    return z * math.tan(math.radians(theta * THETA_UNIT_DEG))

