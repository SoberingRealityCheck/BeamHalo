# reads the beam halo road (bh_zone_pd) and quality table (bh_ql) out of Osvaldo's EMTFModel.cc.
# shared by make_patterns_bh.py, plot_roads_bh.py and bh_model.py (third copy of the regex, so it moved here).

import re

CC = "../cmssw/L1Trigger/L1TMuonEndCapPhase2/src/EMTFModel.cc"
ROWS = 8


def load(cc_path=CC):
    """returns (rows, ql)
    rows: 8 tuples of (begin, center, end), one per hitmap row
    ql:   256 qualities. index = 8 bit mask of which rows hit, bit i = row i
    """
    text = open(cc_path).read()

    m = re.search(r"bh_zone_pd\s*=\s*\{(.*?)\};", text, re.S)
    rows = re.findall(r"\{\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\}", m.group(1))
    rows = [tuple(int(x) for x in r) for r in rows]
    assert len(rows) == ROWS, f"expected {ROWS} rows, got {len(rows)}"

    m = re.search(r"bh_ql\s*=\s*\{(.*?)\};", text, re.S)
    ql = [int(x) for x in re.findall(r"\d+", m.group(1))]
    assert len(ql) == 2 ** ROWS, f"expected {2 ** ROWS} quality entries, got {len(ql)}"
    assert ql[0] == 0, "no rows hit should be quality 0"

    return rows, ql
