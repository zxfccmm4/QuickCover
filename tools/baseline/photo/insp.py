#!/usr/bin/env python3
"""Offline inspection crops (ffmpeg only, no browser): source photo + grid + boxes.
   insp.py faces <id> [long]      per-face crop of photo fixture <id>, 10/50 px grid, its box in lime
   insp.py all <id> [zoom]        whole photo with every box (grid 100 px)
   insp.py grid <img> x y w h zoom    grid crop of src/<img> (10/50 px grid, labels)
   insp.py rect <img> x y w h zoom color   grid crop with one extra rectangle (x y w h source px)
Grid lines fall on multiples of 10 (thin, white) and 50 (thick, yellow) source px; labels give
source coordinates.  Writes /tmp/redactprobe/photo/insp/<name>.png and prints name  x0 y0 zoom.
"""
import os, sys, subprocess, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fixtures as F

B = '/tmp/redactprobe/photo'
O = B + '/insp'
FONT = '/var/airbuild-runtime/da0d841afc56289499583a86cf9b40a1e7f16c48586e42e7c9830daa7d5d8592/launch/bin/Inter-Black.ttf'


def render(name, img, x0, y0, cw, ch, z, rects=(), labels=True, step_minor=10, step_major=50):
    os.makedirs(O, exist_ok=True)
    x0 = int(x0); y0 = int(y0)
    cw = int(cw); ch = int(ch)
    src = img if img.startswith('/') else '%s/src/%s' % (B, img)
    W, H = F.W, F.H
    x0 = max(0, min(W - cw, x0)); y0 = max(0, min(H - ch, y0))
    src = img if img.startswith('/') else '%s/src/%s' % (B, img)
    f = ['crop=%d:%d:%d:%d' % (cw, ch, x0, y0), 'scale=%d:%d:flags=neighbor' % (cw * z, ch * z),
         'format=rgb24']
    if step_minor:
        f.append('drawgrid=w=%d:h=%d:t=1:c=white@0.30' % (step_minor * z, step_minor * z))
    if step_major:
        ox = ((step_major - x0 % step_major) % step_major) * z
        oy = ((step_major - y0 % step_major) % step_major) * z
        f.append('drawgrid=w=%d:h=%d:x=%d:y=%d:t=2:c=yellow@0.85' % (step_major * z, step_major * z, ox, oy))
    for (x, y, w, h, col) in rects:
        f.append('drawbox=x=%d:y=%d:w=%d:h=%d:color=%s:t=%d' % (
            round((x - x0) * z) + 1, round((y - y0) * z) + 1, round(w * z) - 2, round(h * z) - 2, col, 3 if z >= 2 else 2))
    if labels and step_major:
        fs = 14 if z * step_major < 110 else 16
        gx = x0 - x0 % step_major
        while gx <= x0 + cw:
            if gx >= x0:
                X = round((gx - x0) * z) + 3
                f.append("drawtext=fontfile=%s:text='%d':x=%d:y=3:fontsize=%d:fontcolor=yellow:box=1:boxcolor=black@0.6"
                         % (FONT, gx, X, fs))
                f.append("drawtext=fontfile=%s:text='%d':x=%d:y=h-%d:fontsize=%d:fontcolor=yellow:box=1:boxcolor=black@0.6"
                         % (FONT, gx, X, fs + 5, fs))
            gx += step_major
        gy = y0 - y0 % step_major
        while gy <= y0 + ch:
            if gy >= y0:
                Y = round((gy - y0) * z) + 3
                f.append("drawtext=fontfile=%s:text='%d':x=3:y=%d:fontsize=%d:fontcolor=yellow:box=1:boxcolor=black@0.6"
                         % (FONT, gy, Y, fs))
                f.append("drawtext=fontfile=%s:text='%d':x=w-%d:y=%d:fontsize=%d:fontcolor=yellow:box=1:boxcolor=black@0.6"
                         % (FONT, gy, 14 + 7 * len(str(gy)), Y, fs))
            gy += step_major
    out = '%s/%s.png' % (O, name)
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', src, '-vf', ','.join(f),
                    '-frames:v', '1', out], check=True)
    print('%s x0=%d y0=%d crop=%dx%d zoom=%g out=%dx%d' % (name, x0, y0, cw, ch, z, cw * z, ch * z))


def snap(v, m=10):
    return int(round(v / float(m))) * m


def faces(id_, long=1000):
    s = F.PHOTOS[id_]
    for i, b in enumerate(s['faces']):
        x, y, w, h = b
        cw, ch = snap(w * 1.7 + 20), snap(h * 1.5 + 20)
        z = max(1.0, min(6.0, long / float(max(cw, ch))))
        z = round(z * 4) / 4.0 or 0.25
        cx, cy = x + w / 2.0, y + h / 2.0
        render('i_%s_%d' % (id_, i), s['img'], snap(cx - cw / 2.0), snap(cy - ch / 2.0), cw, ch, z,
               [tuple(float(v) for v in b) + ('lime',)])


def allp(id_, zoom=1.0):
    s = F.PHOTOS[id_]
    render('i_%s_all' % id_, s['img'], 0, 0, F.W, F.H, zoom,
           [tuple(float(v) for v in b) + ('lime',) for b in s['faces']], labels=False, step_minor=0, step_major=100)


def sheet(img, name, cells):
    """cells = [(x, y, w, h), ...]: one crop per cell (box + 12 % margin, red box), max 3 cells per
    image, hstacked at a common height -> insp/<name>_<n>.png (no grid)"""
    src = '%s/src/%s' % (B, img)
    outs = []
    for n in range(0, len(cells), 3):
        part = cells[n:n + 3]
        tiles = []
        for i, (x, y, w, h) in enumerate(part):
            mx, my = max(8.0, w * 0.12), max(8.0, h * 0.12)
            x0 = int(max(0, math.floor(x - mx))); y0 = int(max(0, math.floor(y - my)))
            x1 = int(min(F.W, math.ceil(x + w + mx))); y1 = int(min(F.H, math.ceil(y + h + my)))
            cw, ch = max(1, x1 - x0), max(1, y1 - y0)
            z = min(3.0, 700.0 / ch, 600.0 / cw)
            t = '%s/s_%s_%d_%d.png' % (O, name, n // 3, i)
            f = ['crop=%d:%d:%d:%d' % (cw, ch, x0, y0), 'scale=%d:%d:flags=lanczos' % (round(cw * z), round(ch * z)),
                 'format=rgb24', 'pad=iw+4:ih+4:2:2:black',
                 'drawbox=x=%d:y=%d:w=%d:h=%d:color=red@0.9:t=2' % (
                     round((x - x0) * z) + 3, round((y - y0) * z) + 3, round(w * z) - 1, round(h * z) - 1),
                 "drawtext=fontfile=%s:text='%d (%d,%d,%d,%d)':x=4:y=4:fontsize=15:fontcolor=yellow:box=1:boxcolor=black@0.6"
                 % (FONT, n + i, x, y, w, h)]
            subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', src, '-vf', ','.join(f),
                            '-frames:v', '1', t], check=True)
            tiles.append(t)
        out = '%s/s_%s_%d.png' % (O, name, n // 3)
        # all tiles are <= 704 px tall (700 + 4 pad); scale the shorter ones to the tallest
        if len(tiles) == 1:
            os.replace(tiles[0], out)
            outs.append(out)
            continue
        hs = []
        for t in tiles:
            r = subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
                                         'stream=height', '-of', 'csv=p=0', t]).decode().strip()
            hs.append(int(r))
        H = max(hs)
        fc = ''.join('[%d]scale=-2:%d[p%d];' % (k, H, k) for k in range(len(tiles)))
        fc += ''.join('[p%d]' % k for k in range(len(tiles))) + 'hstack=inputs=%d' % len(tiles)
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y'] +
                        sum([['-i', t] for t in tiles], []) + ['-filter_complex', fc, '-frames:v', '1', out], check=True)
        for t in tiles:
            os.remove(t)
        outs.append(out)
    print(' '.join(outs))


if __name__ == '__main__':
    a = sys.argv[1:]
    c = a[0]
    if c == 'faces':
        faces(a[1], int(a[2]) if len(a) > 2 else 1000)
    elif c == 'all':
        allp(a[1], float(a[2]) if len(a) > 2 else 1.0)
    elif c == 'grid':
        x, y, w, h, z = [float(v) for v in a[2:7]]
        nm = a[8] if len(a) > 8 else 'g_%s_%d_%d_%d' % (a[1][:-4], x, y, w)
        render(nm, a[1], snap(x), snap(y), snap(w), snap(h), z, [])
    elif c == 'rect':
        x, y, w, h, z = [float(v) for v in a[2:7]]
        rx, ry, rw, rh = [float(v) for v in a[8:12]]
        render('r_%s' % a[7], a[1], snap(x), snap(y), snap(w), snap(h), z, [(rx, ry, rw, rh, a[12] if len(a) > 12 else 'lime')])
    elif c == 'plain':   # plain <img> x y w h zoom name [x y w h color]...  no grid, optional rects
        x, y, w, h, z = [float(v) for v in a[2:7]]
        rects = []
        r = a[8:]
        while len(r) >= 5:   # x y w h color
            rects.append(tuple(float(v) for v in r[:4]) + (r[4],))
            r = r[5:]
        render('p_%s' % a[7], a[1], x, y, w, h, z, rects, labels=False, step_minor=0, step_major=0)
    elif c == 'sheet':   # sheet <img> <name> x y w h [x y w h ...]
        v = [float(q) for q in a[3:]]
        sheet(a[1], a[2], [tuple(v[i:i + 4]) for i in range(0, len(v) - 3, 4)])
