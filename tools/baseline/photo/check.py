#!/usr/bin/env python3
"""§7 self-check for the photo / plate fixtures.

   check.py box <id> ...      box check (§7.3): final JPEG + every JSON box drawn with drawbox t=4
                              (text red, faces lime) -> /tmp/redactprobe/photo/chk/<id>.check.png (full size)
   check.py all <id> ...      whole fixture at zoom 0.75 with a labelled 100 px grid and the boxes
                              -> /tmp/redactprobe/photo/insp/<id>_all.png
   check.py faces <id> ...    one 2-3x crop per face box from the final JPEG (no grid, box in lime)
                              -> /tmp/redactprobe/photo/insp/<id>_f<i>.png
   check.py plate <id> ...    2x crop of the final JPEG around the plate, plate box in red
                              -> /tmp/redactprobe/photo/insp/<id>_plate<k>.png
   check.py tag <id> ...      tag + leak check (§7.1-2) on the rendered page of plate fixture <id>:
                              every data-rule text must match its rule; no other text on the page may
                              match any §3.1 rule
   check.py size <id> ...     size check (§7.6): ffprobe 1536x1024 + JSON width/height
"""
import json, os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import insp

FIX = '/projects/2ac5bd59-8729-421b-a7f8-43ca37aea5c4/QuickCoverTests/Fixtures'
CHK = '/tmp/redactprobe/photo/chk'
PROV = '京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼使领'
RULES = [
    ('phone', re.compile(r'(?<![0-9])1[0-9]{10}(?![0-9])')),
    ('id', re.compile(r'(?<![0-9X])[0-9]{17}[0-9X](?![0-9X])')),
    ('bank', re.compile(r'(?<![0-9])[0-9]{16,19}(?![0-9])')),
    ('email', re.compile(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')),
    ('url', re.compile(r'(?:https?://|www\.)[^\s<"]+|\b[a-z0-9-]+\.(?:com|cn|net|org)(?:/[^\s<"]*)?')),
    ('ipv4', re.compile(r'(?<![0-9.])(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?![0-9.])')),
    ('ref', re.compile(r'(?<![A-Za-z0-9])[A-Za-z0-9]{10,}(?![A-Za-z0-9])')),
    ('plate', re.compile('(?:' + PROV + ')[A-Z][A-Z0-9]{5,6}')),
]


def load(fid):
    jpg = os.path.join(FIX, fid + '.jpg')
    js = json.load(open(os.path.join(FIX, fid + '.json'), encoding='utf-8'))
    return jpg, js


def boxes_of(js):
    out = []
    for b in js.get('faces', []):
        out.append((b[0], b[1], b[2], b[3], 'lime'))
    for t in js.get('text', []):
        for b in t['boxes']:
            out.append((b[0], b[1], b[2], b[3], 'red'))
    return out


def box(fid):
    """§7.3 box check at 1:1 with t=4 (text red, faces lime)"""
    jpg, js = load(fid)
    os.makedirs(CHK, exist_ok=True)
    f = []
    for (x, y, w, h, col) in boxes_of(js):
        f.append('drawbox=x=%d:y=%d:w=%d:h=%d:color=%s:t=4' % (round(x), round(y), round(w), round(h), col))
    out = '%s/%s.check.png' % (CHK, fid)
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', jpg, '-vf', ','.join(f),
                    '-frames:v', '1', out], check=True)
    print(out, len(boxes_of(js)), 'boxes')


def all_(fid):
    jpg, js = load(fid)
    insp.render('%s_all' % fid, jpg, 0, 0, js['width'], js['height'], 0.75, rects=boxes_of(js),
                step_minor=0, step_major=100)


def faces(fid):
    jpg, js = load(fid)
    W, H = js['width'], js['height']
    for i, b in enumerate(js.get('faces', [])):
        x, y, w, h = b
        cw, ch = w * 1.5, h * 1.5
        z = min(3.0, 800.0 / max(cw, ch))
        x0 = max(0, min(W - cw, x + w / 2 - cw / 2)); y0 = max(0, min(H - ch, y + h / 2 - ch / 2))
        insp.render('%s_f%d' % (fid, i), jpg, x0, y0, cw, ch, z, rects=[(x, y, w, h, 'lime')],
                    labels=False, step_minor=0, step_major=0)


def plate(fid):
    jpg, js = load(fid)
    W, H = js['width'], js['height']
    for t in js.get('text', []):
        for k, b in enumerate(t['boxes']):
            x, y, w, h = b
            cw, ch = w * 1.4, h * 2.6
            x0 = max(0, min(W - cw, x + w / 2 - cw / 2)); y0 = max(0, min(H - ch, y + h / 2 - ch / 2))
            insp.render('%s_plate%d' % (fid, k), jpg, x0, y0, cw, ch, 2.0, rects=[(x, y, w, h, 'red')],
                        labels=False, step_minor=0, step_major=0)


def tag(fid):
    """§7.1-2 on the rendered page: tagged spans must match their rule, untagged text must match no rule"""
    html = open('/tmp/redactprobe/photo/pages/%s.html' % fid, encoding='utf-8').read()
    body = html[html.index('<body>'):]
    body = re.sub(r'<script.*?</script>', '', body, flags=re.S)
    body = re.sub(r'<style.*?</style>', '', body, flags=re.S)
    ok = True
    # every element carrying data-rule: <tag ...data-rule="rule">inner</tag> (no nesting of the same tag)
    tagged = []
    for m in re.finditer(r'<(\w+)([^>]*\bdata-rule="([^"]+)"[^>]*)>', body):
        close = body.index('</%s>' % m.group(1), m.end())
        tagged.append((m.group(3), m.start(), m.end(), close))
    for rule, st, open_end, close in tagged:
        en = close
        text = re.sub(r'<[^>]+>', '', body[open_end:en])
        text = re.sub(r'<!--.*?-->', '', text).strip()
        if rule == 'plate':
            good = bool(re.match('^[' + PROV + '][A-Z][A-Z0-9]{5,6}$', text.replace('·', '')))
        else:
            good = any(r.search(text) for n, r in RULES if n == rule)
        print('  tagged %-6s %-12r %s' % (rule, text, 'ok' if good else 'MISMATCH'))
        ok &= good
    rest = body
    for rule, st, open_end, close in sorted(tagged, key=lambda t: -t[1]):
        tagname = re.match(r'<(\w+)', body[st:]).group(1)
        rest = rest[:st] + ' ' + rest[close + len(tagname) + 3:]
    rest = re.sub(r'<[^>]+>', ' ', rest)
    rest = re.sub(r'<!--.*?-->', ' ', rest, flags=re.S)
    rest = insp_html_unescape(rest)
    leaks = [(n, m.group(0)) for n, r in RULES for m in r.finditer(rest)]
    rest_nohyph = re.sub(r'[ -]', '', rest)
    leaks += [(n, m.group(0)) for n, r in RULES if n in ('phone', 'id', 'bank') for m in r.finditer(rest_nohyph)]
    print('  untagged text: %r' % re.sub(r'\s+', ' ', rest).strip()[:200])
    if leaks:
        ok = False
        print('  LEAKS:', leaks)
    else:
        print('  leak check: no rule matches outside data-rule elements')
    return ok


def insp_html_unescape(s):
    import html as _h
    return _h.unescape(s)


def size(fid):
    jpg, js = load(fid)
    out = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
                          'stream=width,height,codec_name', '-of', 'csv=p=0', jpg], capture_output=True, text=True).stdout.strip()
    codec, w, h = out.split(',')[:3]
    good = (w, h, codec) == ('1536', '1024', 'mjpeg') and js['width'] == 1536 and js['height'] == 1024
    print('  %-10s %sx%s %s  json %dx%d  %s  %d bytes' % (fid, w, h, codec, js['width'], js['height'],
                                                         'ok' if good else 'BAD', os.path.getsize(jpg)))
    return good


if __name__ == '__main__':
    mode = sys.argv[1]
    allok = True
    for fid in sys.argv[2:]:
        if mode in ('tag', 'size'):
            print(fid)
            allok &= {'tag': tag, 'size': size}[mode](fid)
        else:
            {'box': box, 'all': all_, 'faces': faces, 'plate': plate}[mode](fid)
    if mode in ('tag', 'size'):
        print('ALL OK' if allok else 'FAILED')
