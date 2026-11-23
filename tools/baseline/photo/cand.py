#!/usr/bin/env python3
"""Candidate / inspection pages (capture them with shoot.sh):
   cand.py plate <id> [zoom]           crop around the plate of fixture <id> with the plate rendered
   cand.py final <id> ...              the final full-size page(s) of fixture id(s) (plates only)
   cand.py grid <img> x y w h zoom [step] [minor]   grid crop of src/<img>
   cand.py boxes <id> [zoom]           crop pages per face of photo fixture <id> with its boxes
   cand.py all <id> [zoom]             whole photo with its boxes (zoom default 0.5)
   cand.py tile <img> cols rows [zoom] grid tiles of the whole photo
Prints "<WxH:name>" args for shoot.sh.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import page, fixtures as F

out = []


def emit(r):
    out.append('%dx%d:%s' % (r[1], r[2], os.path.basename(r[0])[:-5]))


def plate(id_, zoom=2.0):
    s = F.PLATES[id_]
    p = s['plate']
    cx, cy = p['x'] + p['w'] / 2, p['y'] + p['h'] / 2
    cw, ch = p['w'] * 1.5, p['h'] * 2.4
    emit(page.build('c_' + id_, s['img'], F.W, F.H, crop=(cx - cw / 2, cy - ch / 2, cw, ch), zoom=zoom, plates=[p],
                    grid=dict(step=20, minor=10, font=11), overlay_top=True))


def final(ids):
    for id_ in ids:
        s = F.PLATES[id_]
        emit(page.build(id_, s['img'], F.W, F.H, plates=[s['plate']]))


def grid(img, x, y, w, h, zoom, step=20, minor=10):
    emit(page.build('g_%s_%s_%s' % (img[:-4], x, y), img, F.W, F.H, crop=(float(x), float(y), float(w), float(h)),
                    zoom=float(zoom), grid=dict(step=float(step), minor=float(minor), font=11)))


def boxes(id_, zoom=None):
    """one page per face: source crop = 1.6x the box, zoom chosen so the long side is ~900 output px"""
    s = F.PHOTOS[id_]
    for i, b in enumerate(s['faces']):
        x, y, w, h = b
        cw, ch = w * 1.6, h * 1.6
        z = zoom or min(3.0, 900.0 / max(cw, ch))
        cx, cy = x + w / 2, y + h / 2
        crop = (max(0, min(F.W - cw, cx - cw / 2)), max(0, min(F.H - ch, cy - ch / 2)), cw, ch)
        emit(page.build('b_%s_%d' % (id_, i), s['img'], F.W, F.H, crop=crop, zoom=z,
                        boxes=[tuple(b) + ('lime', str(i))], grid=dict(step=20, minor=10, font=11)))


def allp(id_, zoom=0.5):
    s = F.PHOTOS[id_]
    emit(page.build('a_' + id_, s['img'], F.W, F.H, zoom=zoom,
                    boxes=[tuple(b) + ('lime', str(i)) for i, b in enumerate(s['faces'])],
                    grid=dict(step=100, font=14)))


def tile(img, cols, rows, zoom=1.0, step=50, minor=25):
    W, H = F.W, F.H
    tw, th = W / float(cols), H / float(rows)
    for r in range(rows):
        for c in range(cols):
            emit(page.build('t_%s_%d%d' % (img[:-4], r, c), img, W, H, crop=(c * tw, r * th, tw, th), zoom=zoom,
                            grid=dict(step=step, minor=minor, font=11)))


if __name__ == '__main__':
    a = sys.argv[1:]
    cmd, a = a[0], a[1:]
    if cmd == 'plate':
        plate(a[0], float(a[1]) if len(a) > 1 else 2.0)
    elif cmd == 'final':
        final(a)
    elif cmd == 'grid':
        grid(a[0], *a[1:])
    elif cmd == 'boxes':
        boxes(a[0], float(a[1]) if len(a) > 1 else 2.0)
    elif cmd == 'all':
        allp(a[0], float(a[1]) if len(a) > 1 else 0.5)
    elif cmd == 'tile':
        tile(a[0], int(a[1]), int(a[2]), *[float(v) for v in a[3:]])
    print(' '.join(out))
