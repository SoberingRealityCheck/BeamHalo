# loads the testbench dumps (stage0..5) and lines them up with events. shared by compare_bh.py and plot_stages_bh.py.
#
# the dumps are stamped with bx and clk360 ticks, not event numbers. the output lags the input by a fixed amount,
# so we find that amount by matching against the python model (bh_model.py), then label everything by event.

from collections import defaultdict

FOLDS, FOLD_COLS, NCOLS = 9, 32, 288
HITMAP_OFFSET = 27


def lines(path):
    return [l.split() for l in open(path) if l.strip()]


def load_stage0(d):
    """-> list of (bx, phase, host, ch, phi_col) where phi_col = phi >> 4"""
    return [(int(l[0]), int(l[1]), int(l[2]), int(l[3]), int(l[4]) >> 4) for l in lines(f"{d}/stage0_segs.txt")]


def load_stage1(d):
    """-> {bx: {row: int}}  (each row is a 288 bit hitmap row, bit c = column c)"""
    out = defaultdict(dict)
    for l in lines(f"{d}/stage1_hitmaps.txt"):
        out[int(l[0])][int(l[2])] = int(l[3], 16)
    return out


def load_stage2(d):
    """-> list of (bx, fold, zone, col, patt, qual, cyc)"""
    return [tuple(int(x) for x in l) for l in lines(f"{d}/stage2_matches.txt")]


def load_stage4(d):
    """-> list of (bx, trk, patt, qual, col, zone)"""
    return [tuple(int(x) for x in l) for l in lines(f"{d}/stage4_tracks.txt")]


def load_stage5(d):
    """-> list of (bx, tag)"""
    return [tuple(int(x) for x in l) for l in lines(f"{d}/stage5_tag.txt")]


def load_model_hitmaps(d):
    """-> {event: {row: int}}"""
    out = defaultdict(dict)
    for l in lines(f"{d}/model_hitmaps.txt"):
        out[int(l[0])][int(l[2])] = int(l[3], 16)
    return out


def load_model_roads(d):
    """-> {event: {col: qual}}"""
    out = defaultdict(dict)
    for l in lines(f"{d}/model_roads.txt"):
        out[int(l[0])][int(l[1])] = int(l[3])
    return out


def group_stage2(rows2, K, D, S):
    """-> ({event: {col: qual}}, number of columns the DUT reported with two different qualities)
    K = clk360 tick a burst of 9 folds starts on, D = how early the printed fold number is, S = BX the output lags the input
    absolute hitmap column = 32 * fold + col - 1  (32 columns per fold, one extra column each side)"""
    out = defaultdict(dict)
    clash = 0
    for bx, fold, zone, col, patt, qual, cyc in rows2:
        ev = (cyc - K) // FOLDS - S
        c = FOLD_COLS * ((fold - D) % FOLDS) + col - 1
        if not 0 <= c < NCOLS:
            continue
        if c in out[ev] and out[ev][c] != qual:
            clash += 1
        out[ev][c] = qual
    return out, clash


def align_stage2(rows2, model_roads, n_events):
    """try every (K, D, S), keep the one where the most events match the model. -> (K, D, S, score, clash)"""
    best = None
    for K in range(FOLDS):
        for D in range(FOLDS):
            for S in range(0, 14):
                g, clash = group_stage2(rows2, K, D, S)
                score = sum(1 for e in range(n_events) if g.get(e, {}) == model_roads.get(e, {}))
                if best is None or (score, -clash) > (best[3], -best[4]):
                    best = (K, D, S, score, clash)
    return best


def stage0_by_event(segs, events):
    """which bx does event 0 land on? try a few. -> {event: [(host, ch, phi_col)]}"""
    want = [sorted((h["host"], h["ch"], h["phi"] >> 4) for h in ev if h["valid"]) for ev in events]
    by_bx = defaultdict(list)
    for bx, phase, host, ch, phi_col in segs:
        by_bx[bx].append((host, ch, phi_col))
    for offset in range(0, 4):
        if all(sorted(by_bx.get(e + offset, [])) == want[e] for e in range(len(events))):
            return {e: by_bx.get(e + offset, []) for e in range(len(events))}
    return {e: by_bx.get(e, []) for e in range(len(events))}   # no clean match. best effort. compare_bh.py will say so


def check_tracks(tracks, tags, model_roads, n_events, max_lag=16):
    """checks stage4 (best tracks) and stage5 (tag) against the model's per-column road qualities.
    the model has no sorting, so it only predicts the best road: its quality, and which columns share it.
    the tag should be 1 exactly when some column has quality > 0.
    returns a dict, or None if the run has no stage4/5 data"""
    if not tracks and not any(t for _, t in tags):
        return None
    best_q = {e: max(model_roads.get(e, {}).values(), default=0) for e in range(n_events)}
    best_cols = {e: sorted(c for c, q in model_roads.get(e, {}).items() if q == best_q[e]) for e in range(n_events)}
    tag_by_bx = dict(tags)
    n_bx = max(tag_by_bx) + 1 if tag_by_bx else 0
    # lag = how many bx the output trails the input. pick the one where the tag matches best
    best = None
    for lag in range(max_lag):
        score = sum(1 for b in range(n_bx) if tag_by_bx.get(b, 0) == int(best_q.get(b - lag, 0) > 0))
        if best is None or score > best[1]:
            best = (lag, score)
    lag, tag_score = best
    # the top track per bx = the one with the highest quality (track 0 should be it)
    top = {}
    for bx, trk, patt, qual, col, zone in tracks:
        if bx not in top or qual > top[bx][0]:
            top[bx] = (qual, col)
    q_ok, col_ok, col_leftmost, bad = 0, 0, 0, []
    for e in range(n_events):
        b = e + lag
        got_q, got_col = top.get(b, (0, None))
        if got_q == best_q[e]:
            q_ok += 1
            if best_q[e]:
                col_ok += got_col in best_cols[e]
                col_leftmost += got_col == best_cols[e][0]
        else:
            bad.append((e, got_q, best_q[e]))
    return dict(lag=lag, tag_score=tag_score, n_bx=n_bx, q_ok=q_ok, col_ok=col_ok, col_leftmost=col_leftmost,
                n_with_road=sum(1 for e in range(n_events) if best_q[e]), bad=bad)
