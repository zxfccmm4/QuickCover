#!/usr/bin/env python3
"""Measure the generated blank plate (solid blue/green rectangle) in a photo: corners in source px.
usage: blank.py img.png x y w h [blue|green]
Pure ffmpeg + python (no PIL): the crop is decoded to raw rgb24 and thresholded; per column/row the
longest contiguous mask run gives the edge samples; the four edges are least-squares lines through the
samples of the "full" columns/rows (>= 90% of the longest run), the corners are their intersections."""
import sys, subprocess, math

def main(img, x, y, w, h, color='blue'):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', img, '-vf', 'crop=%d:%d:%d:%d' % (w, h, x, y),
                                   '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'])
    def px(i, j):
        o = (j * w + i) * 3
        return raw[o], raw[o + 1], raw[o + 2]
    if color == 'blue':
        hit = lambda p: p[2] > p[0] + 60 and p[2] > p[1] + 25 and p[2] > 90
    else:
        hit = lambda p: p[1] > p[0] + 30 and p[1] > p[2] + 30 and p[1] > 70

    def longest(seq):   # longest contiguous run of True in seq -> (start, end) or None
        best, cur = None, None
        for k, v in enumerate(seq + [False]):
            if v:
                cur = (k, k) if cur is None else (cur[0], k)
            elif cur is not None:
                if best is None or cur[1] - cur[0] > best[1] - best[0]:
                    best = cur
                cur = None
        return best
    cols = {i: longest([hit(px(i, j)) for j in range(h)]) for i in range(w)}
    rows = {j: longest([hit(px(i, j)) for i in range(w)]) for j in range(h)}
    cols = {i: r for i, r in cols.items() if r}; rows = {j: r for j, r in rows.items() if r}
    if not cols:
        print('no blank found'); return
    cmax = max(r[1] - r[0] for r in cols.values()); rmax = max(r[1] - r[0] for r in rows.values())
    fc = [i for i, r in cols.items() if r[1] - r[0] >= 0.9 * cmax]
    fr = [j for j, r in rows.items() if r[1] - r[0] >= 0.9 * rmax]

    def fit(pts):
        n = len(pts); sx = sum(p[0] for p in pts); sy = sum(p[1] for p in pts)
        sxx = sum(p[0] * p[0] for p in pts); sxy = sum(p[0] * p[1] for p in pts)
        a = (n * sxy - sx * sy) / (n * sxx - sx * sx); b = (sy - a * sx) / n
        return a, b

    def rfit(pts):   # + trimming of the rounded-corner samples
        for _ in range(4):
            a, b = fit(pts)
            pts = [p for p in pts if abs(p[1] - (a * p[0] + b)) <= 2.0]
        return fit(pts)
    top = rfit([(i, cols[i][0]) for i in fc]); bot = rfit([(i, cols[i][1]) for i in fc])      # y = a x + b
    lef = rfit([(j, rows[j][0]) for j in fr]); rig = rfit([(j, rows[j][1]) for j in fr])      # x = a y + b

    def inter(hl, vl):
        xx = (vl[0] * hl[1] + vl[1]) / (1 - vl[0] * hl[0]); return xx, hl[0] * xx + hl[1]
    TL = inter(top, lef); TR = inter(top, rig); BL = inter(bot, lef); BR = inter(bot, rig)

    def A(p, q): return math.hypot(p[0] - q[0], p[1] - q[1])
    def s(p): return '(%d,%.1f)' % (p[0] + x, p[1] + y)
    print('%s: TL %s TR %s BR %s BL %s | top %.1f bottom %.1f left %.1f right %.1f | tilt %.1f/%.1f deg '
          '| centre (%.1f, %.1f) | bbox x %.0f-%.0f y %.0f-%.0f' % (
              img.split('/')[-1], s(TL), s(TR), s(BR), s(BL), A(TL, TR), A(BL, BR), A(TL, BL), A(TR, BR),
              -math.degrees(math.atan2(TR[1] - TL[1], TR[0] - TL[0])),
              -math.degrees(math.atan2(BR[1] - BL[1], BR[0] - BL[0])),
              (TL[0] + TR[0] + BR[0] + BL[0]) / 4 + x, (TL[1] + TR[1] + BR[1] + BL[1]) / 4 + y,
              min(TL[0], TR[0], BR[0], BL[0]) + x, max(TL[0], TR[0], BR[0], BL[0]) + x,
              min(TL[1], TR[1], BR[1], BL[1]) + y, max(TL[1], TR[1], BR[1], BL[1]) + y))

if __name__ == '__main__':
    a = sys.argv[1:]
    main(a[0], int(a[1]), int(a[2]), int(a[3]), int(a[4]), a[5] if len(a) > 5 else 'blue')
