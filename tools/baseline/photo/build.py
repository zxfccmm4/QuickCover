#!/usr/bin/env python3
"""Final build: composite plates, encode JPEGs (q=3) and write the ground-truth JSON (FIXTURES.md §3.4).

usage: build.py [id ...]        (no ids = all 12)
Needs the capture of every plate page in /tmp/redactprobe/photo/out/<id>.png + <id>.gt.json
(see shoot.sh; build.py builds the pages first and tells you which captures are missing/stale).

Writes QuickCoverTests/Fixtures/<id>.jpg and <id>.json.  Photos are only re-encoded (PNG -> JPEG),
never filtered; plate photos are the browser capture of the typeset plate over the generated photo.
"""
import os, sys, json, subprocess, shutil, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import page, fixtures as F

B = page.B
OUT = '/projects/2ac5bd59-8729-421b-a7f8-43ca37aea5c4/QuickCoverTests/Fixtures'


def run(cmd):
    subprocess.run(cmd, check=True)


def jpeg(src, dst, size=None):
    """JPEG q=3 (ffmpeg mjpeg scale); size=(W,H) crops the capture to the photo's pixel size
    (the page box is rounded up to whole CSS px so the last row is painted, see page.py)"""
    vf = ['-vf', 'crop=%d:%d:0:0' % size] if size else []
    run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', src] + vf + ['-q:v', '3', dst])
    w, h = subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
                                    'stream=width,height', '-of', 'csv=p=0', dst]).decode().strip().split(',')
    return int(w), int(h)


def gt_json(fid, cat, source, w, h, notes, text, faces):
    return {
        'id': fid, 'file': fid + '.jpg', 'category': cat, 'variant': 'original', 'source': source,
        'width': w, 'height': h, 'orientation': 1, 'notes': notes,
        'text': text, 'shadow': [], 'faces': faces, 'codes': [],
    }


def main(ids):
    os.makedirs(OUT, exist_ok=True)
    for fid in ids:
        if fid in F.PLATES:
            spec = F.PLATES[fid]
            path, w, h = page.build(fid, spec['img'], F.W, F.H, plates=[spec['plate']])
            cap = '%s/out/%s.png' % (B, fid)
            gtf = '%s/out/%s.gt.json' % (B, fid)
            if not (os.path.exists(cap) and os.path.exists(gtf) and os.path.getmtime(gtf) >= os.path.getmtime(path)):
                print('%s: capture missing or stale -> shoot.sh photo %dx%d:%s' % (fid, w, h, fid))
                continue
            jpg = os.path.join(OUT, fid + '.jpg')
            jw, jh = jpeg(cap, jpg, (F.W, F.H))
            assert (jw, jh) == (F.W, F.H), (jw, jh)   # the page (#shot) is up to 2 rows taller: cropped away
            gt = json.load(open(gtf, encoding='utf-8'))
            plate = spec['plate']
            # sanity: the collector saw exactly our plate text in exactly one box
            assert len(gt['text']) == 1 and gt['text'][0]['rule'] == 'plate', gt
            assert gt['text'][0]['text'] == plate['text'], (gt['text'][0]['text'], plate['text'])
            assert len(gt['text'][0]['boxes']) == 1, gt
            faces = [[round(v, 1) for v in b] for b in spec.get('faces', [])]
            js = gt_json(fid, 'plate', 'composite', jw, jh, spec.get('notes', ''), gt['text'], faces)
            json.dump(js, open(os.path.join(OUT, fid + '.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
            print('%s: %dx%d plate box %s faces %d' % (fid, jw, jh, gt['text'][0]['boxes'][0], len(faces)))
        elif fid in F.PHOTOS:
            spec = F.PHOTOS[fid]
            src = '%s/src/%s' % (B, spec['img'])
            jpg = os.path.join(OUT, fid + '.jpg')
            jw, jh = jpeg(src, jpg)
            faces = [[round(float(v), 1) for v in b] for b in spec['faces']]
            for b in faces:
                assert 0 <= b[0] and 0 <= b[1] and b[0] + b[2] <= jw and b[1] + b[3] <= jh, (fid, b)
            js = gt_json(fid, 'photo', 'imagegen', jw, jh, spec.get('notes', ''), [], faces)
            json.dump(js, open(os.path.join(OUT, fid + '.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
            print('%s: %dx%d faces %d' % (fid, jw, jh, len(faces)))
        else:
            print('unknown id', fid)


if __name__ == '__main__':
    ids = sys.argv[1:] or list(F.PLATES) + list(F.PHOTOS)
    main(ids)
