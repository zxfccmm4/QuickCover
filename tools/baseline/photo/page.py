#!/usr/bin/env python3
"""Page builder for the photo/plate fixtures.

Every page follows the contract recipe (FIXTURES.md §5): #shot at CSS size W/3 x H/3 (zoom 1),
scaled x3, collector window.__gt embedded verbatim (§5.1).

All coordinates in the API are SOURCE pixels of the photo (origin top-left).  A crop page
shows a zoomed part of the photo: #shot is (cw*zoom) x (ch*zoom) output px, grid lines,
labels and boxes stay in source pixel coordinates.

The photo is drawn as an SVG <image> at its natural size.  (An <img> at CSS size W/3 is
rasterised from a 1/3-resolution decode by the cloud browser and comes out blurry; the SVG
image is pixel-exact — verified with ffmpeg psnr against the original.)

Usage (from other scripts):
    import page
    page.build(name, img='plate_01.png', W=1536, H=1024, grid={'step':100}, zoom=0.5)
    page.build(name, img, W, H, crop=(x,y,w,h), zoom=2, grid={'step':50}, boxes=[(x,y,w,h), ...])
    page.build(name, img, W, H, plates=[{...}], outline=True)
Pages are written to /tmp/redactprobe/photo/pages/<name>.html; photos are read from
/tmp/redactprobe/photo/src/ by relative URL.
"""
import os, html, math

B = '/tmp/redactprobe/photo'
PAGES = B + '/pages'

COLLECTOR = r"""<script>
window.__gt = () => {
  const f = v => Math.round(v * 10) / 10;
  const rect = e => { const r = e.getBoundingClientRect(); return [r.x, r.y, r.width, r.height].map(f); };
  const rects = e => [...e.getClientRects()].map(r => [r.x, r.y, r.width, r.height].map(f));
  const s = document.getElementById('shot').getBoundingClientRect();
  const shift = b => [b[0] - s.x, b[1] - s.y, b[2], b[3]].map(f);
  const out = { text: [], shadow: [], faces: [], codes: [] };
  document.querySelectorAll('[data-rule],[data-shadow],[data-face],[data-code]').forEach(e => {
    if (e.dataset.rule)  out.text.push({ rule: e.dataset.rule, text: e.textContent, boxes: rects(e).map(shift) });
    if (e.dataset.shadow) out.shadow.push({ kind: e.dataset.shadow, text: e.textContent, boxes: rects(e).map(shift) });
    if (e.dataset.face)  out.faces.push(shift(rect(e)));
    if (e.dataset.code)  out.codes.push({ type: e.dataset.code, payload: e.dataset.payload || '', box: shift(rect(e)) });
  });
  return out;
};
</script>"""

# Real plates leave a margin around the characters: condense the text (scaleX, k <= 1) so that it
# spans 86% of the plate's inner width. Layout sizes (offsetWidth/clientWidth) ignore transforms.
FIT_JS = """<script>
document.querySelectorAll('.plate').forEach(p=>{
  const tx=p.querySelector('.tx'); if(!tx) return;
  const b=parseFloat(getComputedStyle(p).borderLeftWidth)||0;
  const inner=p.clientWidth-2*b; const k=Math.min(1, 0.86*inner/tx.offsetWidth);
  tx.style.transform='scaleX('+k.toFixed(4)+')'; p.dataset.fit=k.toFixed(4);
});
</script>"""

PLATE_CSS = """.plate{position:absolute;box-sizing:border-box;display:flex;align-items:center;justify-content:center;
  overflow:hidden;font-weight:700;line-height:1;white-space:nowrap;transform-origin:50% 50%;
  font-family:"Noto Sans CJK SC","Noto Sans SC","Noto Sans",-apple-system,"Liberation Sans",Arial,sans-serif}
.plate.blue{background:linear-gradient(180deg,#0631a8,#0a3fd0);color:#fff;border-color:#fff}
.plate.green{background:linear-gradient(180deg,#0d6b3f,#13a05a);color:#000;border-color:#fff;box-shadow:inset 0 0 0 1.5px #000}
.plate .tx{display:flex;align-items:center;transform-origin:50% 50%}
.plate .prov,.plate .rest{display:inline-block;line-height:1}
.plate .dot{display:inline-block;border-radius:50%;background:#fff}
.plate.green .dot{background:#000}
.plate .glare,.pool{position:absolute;pointer-events:none;mix-blend-mode:screen}
.plate.x{outline:1px solid #ff0}
"""


def px(v):
    """source (output) pixels -> CSS px of the page (the x3 scale)"""
    return "%.5fpx" % (v / 3.0 + 0.0034)  # +0.01 output px so the last row is never clipped


def plate_html(p):
    """p: dict(text, x, y, w, h)  + optional: color='blue'|'green', prov_len=2, rot=deg, yaw=deg, pitch=deg,
    persp=px, blur=px(output), glare=dict(inset='0', bg='linear-gradient(..)'), pool=dict(inset, bg),
    font=0.62, sx=0.9, dot=0.15, gap=0.12, border=px, radius=px, outline=bool, css='extra style'
    The element carries data-rule="plate"; its textContent is exactly the GT text (the dot is an empty <i>)."""
    text = p['text']
    pl = p.get('prov_len', 2)
    prov, rest = text[:pl], text[pl:]
    x, y, w, h = p['x'], p['y'], p['w'], p['h']
    color = p.get('color', 'blue')
    fs = h * p.get('font', 0.62)
    radius = p.get('radius', h * 0.055)
    bw = p.get('border', max(1.2, w / 440 * 5))
    tf = []
    if p.get('yaw') or p.get('pitch'):
        tf.append('perspective(%s)' % px(p.get('persp', 900)))
        if p.get('pitch'):
            tf.append('rotateX(%gdeg)' % p['pitch'])
        if p.get('yaw'):
            tf.append('rotateY(%gdeg)' % p['yaw'])
    if p.get('rot'):
        tf.append('rotate(%gdeg)' % p['rot'])
    st = 'left:%s;top:%s;width:%s;height:%s;border-radius:%s;border:%s solid currentColor;font-size:%s' % (
        px(x), px(y), px(w), px(h), px(radius), px(bw), px(fs))
    if tf:
        st += ';transform:' + ' '.join(tf)
    if p.get('blur'):
        st += ';filter:blur(%s)' % px(p['blur'])
    if p.get('css'):
        st += ';' + p['css']
    dot = '<i class="dot" style="width:%gem;height:%gem;margin:0 %gem 0 %gem"></i>' % (
        p.get('dot', 0.15), p.get('dot', 0.15), p.get('gap', 0.12), p.get('gap', 0.12))
    # no whitespace between the spans, so textContent == GT text
    inner = ('<span class="tx"><span class="prov">%s</span>%s'
             '<span class="rest">%s</span></span>') % (
        html.escape(prov), dot, html.escape(rest))
    over = ''
    g = p.get('glare')
    if g:
        over += '<span class="glare" style="inset:%s;background:%s"></span>' % (g.get('inset', '0'), g['bg'])
    return ('<div class="plate %s%s" data-rule="plate" style="%s">' % (color, ' x' if p.get('outline') else '', st)
            + inner + over + '</div>')


def pool_html(p):
    """soft light pool around the plate (sibling element, screen-blended, drawn over the plate):
    dict(inset='l t r b' in plate-relative px (negative = outside), bg='radial-gradient(..), ..')"""
    q = p.get('pool')
    if not q:
        return ''
    ins = [float(v) for v in q.get('inset', '-40 -40 -40 -40').split()]
    st = 'left:%s;top:%s;width:%s;height:%s;background:%s' % (
        px(p['x'] - ins[0]), px(p['y'] - ins[1]), px(p['w'] + ins[0] + ins[2]), px(p['h'] + ins[1] + ins[3]), q['bg'])
    if p.get('blur'):
        st += ';filter:blur(%s)' % px(p['blur'])
    return '<div class="pool" style="%s"></div>' % st


def build(name, img, W, H, crop=None, zoom=1.0, grid=None, boxes=(), plates=(), extra_css='', extra_html='',
          bg='#000', hide_photo=False, overlay_top=False):
    """grid: None or dict(step=100, minor=0, labels=True, font=14, color=.., minor_color=..)
       boxes: iterable of (x,y,w,h[,color[,label]]) in source px
       plates: iterable of plate dicts (see plate_html)
       returns (page path, output W, output H)"""
    z = zoom
    cx, cy, cw, ch = crop if crop else (0, 0, W, H)
    ow, oh = cw * z, ch * z                      # output px of the page
    out = []
    out.append('<!doctype html><html><head><meta charset="utf-8"><title>%s</title><style>' % name)
    out.append('html,body{margin:0;background:#fff}')
    # the browser snaps #shot to whole CSS px: round the height UP so the last output row is painted
    # (build.py crops the capture back to H rows, lossless)
    out.append('#shot{width:%s;height:%s;transform:scale(3);transform-origin:0 0;overflow:hidden;position:absolute;left:0;top:0;background:%s}'
               % (px(ow), px(math.ceil(oh / 3.0 - 1e-6) * 3), bg))
    out.append('#shot svg{position:absolute;left:0;top:0;width:100%;height:100%;overflow:visible;display:block}')
    out.append(PLATE_CSS)
    out.append(extra_css)
    out.append('</style></head><body><div id="shot">')
    # vector overlay in SOURCE pixel units: viewBox = the crop
    vb = '<svg viewBox="%g %g %g %g" preserveAspectRatio="none">' % (cx, cy, cw, ch)
    ph = []
    if not hide_photo:
        ph.append(vb + '<image href="../src/%s" x="0" y="0" width="%g" height="%g"/></svg>' % (img, W, H))
    out.append(''.join(ph))
    sv = [vb]
    if grid:
        step = int(grid.get('step', 100))
        minor = int(grid.get('minor', 0))
        col = grid.get('color', 'rgba(0,255,255,.9)')
        mcol = grid.get('minor_color', 'rgba(0,255,255,.4)')
        lw = 1.0 / z
        xs = [v for v in range(0, W + 1, step) if cx <= v <= cx + cw]
        ys = [v for v in range(0, H + 1, step) if cy <= v <= cy + ch]
        if minor:
            mxs = [v for v in range(0, W + 1, minor) if cx <= v <= cx + cw and v % step]
            mys = [v for v in range(0, H + 1, minor) if cy <= v <= cy + ch and v % step]
            for gx in mxs:
                sv.append('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="%s" stroke-width="%g"/>' % (gx, cy, gx, cy + ch, mcol, lw))
            for gy in mys:
                sv.append('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="%s" stroke-width="%g"/>' % (cx, gy, cx + cw, gy, mcol, lw))
        for gx in xs:
            sv.append('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="%s" stroke-width="%g"/>' % (gx, cy, gx, cy + ch, col, lw))
        for gy in ys:
            sv.append('<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="%s" stroke-width="%g"/>' % (cx, gy, cx + cw, gy, col, lw))
        if grid.get('labels', True):
            fs = grid.get('font', 14) / z
            for gx in xs:
                if gx == 0 and cx == 0:
                    continue
                sv.append('<text x="%g" y="%g" font-size="%g" font-family="Arial,sans-serif" font-weight="700" fill="#00ffff" stroke="#000" stroke-width="%g" paint-order="stroke" text-anchor="%s">%d</text>' % (
                    gx, cy + fs * 1.1, fs, 0.5 / z, 'end' if gx == W and cx + cw == W else 'start', gx))
            for gy in ys:
                if gy == 0 and cy == 0:
                    continue
                sv.append('<text x="%g" y="%g" font-size="%g" font-family="Arial,sans-serif" font-weight="700" fill="#ffff00" stroke="#000" stroke-width="%g" paint-order="stroke">%d</text>' % (
                    cx, gy - 2.0 / z, fs, 0.5 / z, gy))
    for b in boxes:
        bx, by, bw, bh = b[:4]
        col = b[4] if len(b) > 4 else 'red'
        lab = b[5] if len(b) > 5 else None
        sv.append('<rect x="%g" y="%g" width="%g" height="%g" fill="none" stroke="%s" stroke-width="%g"/>' % (
            bx, by, bw, bh, col, 2.0 / z))
        if lab:
            fs = (grid.get('font', 14) if grid else 14.0) / z
            sv.append('<text x="%g" y="%g" font-size="%g" font-family="Arial,sans-serif" font-weight="700" fill="%s" stroke="#000" stroke-width="%g" paint-order="stroke">%s</text>' % (
                bx, by - 2.0 / z, fs, col, 0.5 / z, html.escape(str(lab))))
    sv.append('</svg>')
    svg = ''.join(sv)
    if not overlay_top:
        out.append(svg)
    for p in plates:
        # the plate is an HTML element positioned in CSS px of the page; shift it by the crop origin and zoom
        q = dict(p)
        if 'h' not in q:   # plate aspect 440:140 (blue) / 480:140 (green)
            q['h'] = p['w'] * 140.0 / (480 if p.get('color') == 'green' else 440)
        # source px -> CSS px of this page = v * zoom / 3 (plate_html_zoom patches px())
        q['x'] = p['x'] - cx
        q['y'] = p['y'] - cy
        q['_z'] = z
        out.append(plate_html_zoom(q, z))
        out.append(pool_html_zoom(q))
    if overlay_top:          # grid/boxes drawn OVER the plates (candidate pages)
        out.append(svg)
    out.append(extra_html)
    out.append('</div>')
    if plates:
        out.append(FIT_JS)
    out.append(COLLECTOR)
    out.append('</body></html>')
    os.makedirs(PAGES, exist_ok=True)
    path = os.path.join(PAGES, name + '.html')
    page_html = '\n'.join(out)
    # rewrite only when the page changed, so an existing capture stays "fresh" (build.py compares mtimes)
    if not (os.path.exists(path) and open(path, encoding='utf-8').read() == page_html):
        with open(path, 'w', encoding='utf-8') as f:
            f.write(page_html)
    return path, int(round(ow)), int(math.ceil(oh / 3.0 - 1e-6) * 3)


def pool_html_zoom(q):
    global px
    orig = px
    z = q.get('_z', 1.0)
    px = lambda v: '%.5fpx' % (v * z / 3.0)
    try:
        return pool_html(q)
    finally:
        px = orig


def plate_html_zoom(q, z):
    """plate_html() for a page of zoom z (CSS px = source px * z / 3): monkey-patch px() temporarily"""
    global px
    orig = px
    px = lambda v: '%.4fpx' % (v * z / 3.0)
    try:
        return plate_html(q)
    finally:
        px = orig


if __name__ == '__main__':
    import sys, json
    spec = json.load(open(sys.argv[1]))
    for name, kw in spec.items():
        print(build(name, **kw))
