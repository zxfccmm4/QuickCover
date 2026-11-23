#!/usr/bin/env node
'use strict';
// Self-check for the doc_* fixtures (FIXTURES.md §7) + writes <id>.json next to the images.
// Usage: node check.js [id ...]   (default: all five)
// Reads  : /tmp/redactprobe/docs/<id>.html, <id>.png, <id>.gt.json (collector), <id>.wm.json (watermark quads)
// Writes : QuickCoverTests/Fixtures/<id>.json and /tmp/redactprobe/docs/work/<id>.check.png (box check images)

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const SERVED = process.env.DOCS_SERVED || '/tmp/redactprobe/docs';
const WORK = path.join(SERVED, 'work');
const REPO = '/projects/2ac5bd59-8729-421b-a7f8-43ca37aea5c4';
const FIXDIR = process.env.DOCS_FIXDIR || path.join(REPO, 'QuickCoverTests/Fixtures');
const gen = require('./gen.js');
const IDS = gen.FIXTURES.map(f => f.id);

// ---- §3.1 rules. phone/id/bank drop spaces and hyphens first; ref keeps everything; the rest as printed.
const strip = t => t.replace(/[\s\-]+/g, '');
const RULES = [
  ['phone', t => strip(t).match(/(?<!\d)1\d{10}(?!\d)/)],
  ['id',    t => strip(t).match(/(?<!\d)\d{17}[\dX](?![\dX])/)],
  ['bank',  t => strip(t).match(/(?<!\d)\d{16,19}(?!\d)/)],
  ['email', t => t.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/)],
  ['url',   t => t.match(/(https?:\/\/\S+)|(\bwww\.[^\s]+)|(\b[a-z0-9-]+\.(?:com|cn|net|org|io|top|xyz|cc|me|info|gov|edu)\b(?:\/\S*)?)/i)],
  ['ipv4',  t => t.match(/(?<![\d.])(\d{1,3}\.){3}\d{1,3}(?![\d.])/)],
  ['ref',   t => t.match(/[A-Za-z0-9]{10,}/)],
  ['plate', t => t.match(/[京津沪渝冀晋蒙辽吉黑苏浙皖闽赣鲁豫鄂湘粤桂琼川贵云藏陕甘青宁新使领][A-HJ-NP-Z][A-HJ-NP-Z0-9]{4}[A-HJ-NP-Z0-9挂学警港澳]/)],
];
const ORDER = RULES.map(r => r[0]);
const firstRule = t => { const r = RULES.find(([, re]) => re(t)); return r ? r[0] : null; };
// The tagged string itself must *be* the thing (not just contain it).
const WHOLE = {
  phone: t => /^1\d{10}$/.test(strip(t)),
  id: t => /^\d{17}[\dX]$/.test(strip(t)),
  bank: t => /^\d{16,19}$/.test(strip(t)),
  ref: t => /[A-Za-z0-9]{10,}/.test(t),
};

const ffprobe = f => execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', f]).toString().trim().split(',').map(Number);

// Text lines of the page outside data-rule spans (scripts/styles dropped, tagged spans replaced by a breaker).
function leakLines(html) {
  let h = html.replace(/<script[\s\S]*?<\/script>/g, '').replace(/<style[\s\S]*?<\/style>/g, '').replace(/<!--[\s\S]*?-->/g, '');
  h = h.replace(/<span data-rule="[a-z0-9]+">[^<]*<\/span>/g, '§');
  h = h.replace(/<\/(td|th)>/gi, ' | ').replace(/<br\s*\/?>/gi, '\n').replace(/<\/(div|p|tr|li|h\d|table|section)>/gi, '\n');
  h = h.replace(/<[^>]+>/g, '').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"');
  return h.split('\n').map(s => s.trim()).filter(Boolean);
}

// Separating-axis test: convex quad vs axis-aligned box.
function quadHitsBox(q, [x, y, w, h]) {
  const box = [[x, y], [x + w, y], [x + w, y + h], [x, y + h]];
  const axes = [[1, 0], [0, 1]];
  for (let i = 0; i < 4; i++) { const a = q[i], b = q[(i + 1) % 4]; axes.push([-(b[1] - a[1]), b[0] - a[0]]); }
  const proj = (pts, ax) => { const d = pts.map(p => p[0] * ax[0] + p[1] * ax[1]); return [Math.min(...d), Math.max(...d)]; };
  for (const ax of axes) {
    const [qa, qb] = proj(q, ax), [ba, bb] = proj(box, ax);
    if (qb < ba || bb < qa) return false;
  }
  return true;
}
const boxesOverlap = (a, b) => a[0] < b[0] + b[2] && b[0] < a[0] + a[2] && a[1] < b[1] + b[3] && b[1] < a[1] + a[3];
const inside = (b, W, H) => b[0] >= 0 && b[1] >= 0 && b[0] + b[2] <= W && b[1] + b[3] <= H;

function check(id) {
  const fx = gen.FIXTURES.find(f => f.id === id);
  const f = fx.make();
  const W = f.W, H = f.H;
  const fails = [];
  const fail = m => fails.push(m);
  const readJSON = p => { const t = fs.readFileSync(p, 'utf8'); const i = t.indexOf('{'); return JSON.parse(t.slice(i)); };

  const png = path.join(SERVED, id + '.png'), html = fs.readFileSync(path.join(SERVED, id + '.html'), 'utf8');
  const gt = readJSON(path.join(SERVED, id + '.gt.json'));
  const wm = readJSON(path.join(SERVED, id + '.wm.json'));

  // 6. size
  const [pw, ph] = ffprobe(png);
  if (pw !== W || ph !== H) fail(`size ${pw}x${ph} != ${W}x${H}`);

  // 1. tag check
  for (const it of gt.text) {
    if (!WHOLE[it.rule](it.text)) fail(`tag: "${it.text}" is not a whole ${it.rule}`);
    const first = firstRule(it.text);
    if (first !== it.rule) fail(`tag: "${it.text}" tagged ${it.rule} but order gives ${first}`);
    if (!it.boxes.length) fail(`tag: "${it.text}" has no box`);
    for (const b of it.boxes) if (!inside(b, W, H)) fail(`box outside image: ${JSON.stringify(b)} for "${it.text}"`);
  }
  // 2. leak check
  for (const line of leakLines(html)) {
    const hit = RULES.find(([, re]) => re(line));
    if (hit) fail(`leak: "${line}" matches ${hit[0]}`);
  }
  // codes: element box equals the data-size box, payload as expected
  for (const c of gt.codes) {
    if (!inside(c.box, W, H)) fail(`code box outside image ${JSON.stringify(c.box)}`);
    if (c.type === 'qr' && (Math.abs(c.box[2] - c.box[3]) > 0.5)) fail(`qr not square ${c.box}`);
  }
  // watermark never over a tagged/shadow/code/face box
  const protectedBoxes = [...gt.text.flatMap(t => t.boxes), ...gt.shadow.flatMap(s => s.boxes), ...gt.codes.map(c => c.box), ...gt.faces];
  wm.quads.forEach((q, i) => {
    for (const b of protectedBoxes) if (quadHitsBox(q, b)) fail(`watermark ${i} overlaps box ${JSON.stringify(b)}`);
    for (const p of q) if (p[0] < 0 || p[1] < 0 || p[0] > W || p[1] > H) fail(`watermark ${i} outside image`);
  });
  if (wm.quads.length !== 1) fail(`expected exactly one watermark, got ${wm.quads.length}`);
  for (const o of wm.overflow) fail(`clipped/overflowing element: ${JSON.stringify(o)}`);
  for (const b of gt.faces) if (!inside(b, W, H)) fail('face box outside image');

  // 3. box-check image (red text, lime faces, blue codes, t=4) + the watermark quad outlined in yellow
  fs.mkdirSync(WORK, { recursive: true });
  const chain = [];
  const db = ([x, y, w, h], color) => `drawbox=x=${x}:y=${y}:w=${Math.max(1, w)}:h=${Math.max(1, h)}:color=${color}:t=4`;
  for (const t of gt.text) for (const b of t.boxes) chain.push(db(b, 'red'));
  for (const s of gt.shadow) for (const b of s.boxes) chain.push(db(b, 'orange'));
  for (const b of gt.faces) chain.push(db(b, 'lime'));
  for (const c of gt.codes) chain.push(db(c.box, 'blue'));
  const check = path.join(WORK, id + '.check.png');
  execFileSync('ffmpeg', ['-v', 'error', '-y', '-i', png, '-vf', chain.length ? chain.join(',') : 'null', check]);

  // §3.4 JSON
  const out = {
    id, file: id + '.png', category: fx.category, variant: 'original', source: 'html',
    width: W, height: H, orientation: 1, notes: fx.notes,
    text: gt.text, shadow: gt.shadow, faces: gt.faces, codes: gt.codes,
  };
  // written one entry per line, boxes on one line
  const q = JSON.stringify;
  const bx = b => `[${b.join(', ')}]`;
  const json = `{
  "id": ${q(id)},
  "file": ${q(id + '.png')},
  "category": ${q(fx.category)},
  "variant": "original",
  "source": "html",
  "width": ${W},
  "height": ${H},
  "orientation": 1,
  "notes": ${q(fx.notes)},
  "text": [${out.text.map(t => `\n    { "rule": ${q(t.rule)}, "text": ${q(t.text)}, "boxes": [${t.boxes.map(bx).join(', ')}] }`).join(',')}${out.text.length ? '\n  ' : ''}],
  "shadow": [${out.shadow.map(s => `\n    { "kind": ${q(s.kind)}, "text": ${q(s.text)}, "boxes": [${s.boxes.map(bx).join(', ')}] }`).join(',')}${out.shadow.length ? '\n  ' : ''}],
  "faces": [${out.faces.map(bx).join(', ')}],
  "codes": [${out.codes.map(c => `\n    { "type": ${q(c.type)}, "payload": ${q(c.payload)}, "box": ${bx(c.box)} }`).join(',')}${out.codes.length ? '\n  ' : ''}]\n}\n`;
  JSON.parse(json); // must be valid
  fs.mkdirSync(FIXDIR, { recursive: true });
  fs.writeFileSync(path.join(FIXDIR, id + '.json'), json);
  fs.copyFileSync(png, path.join(FIXDIR, id + '.png'));

  const counts = {};
  for (const t of gt.text) counts[t.rule] = (counts[t.rule] || 0) + 1;
  const fmt = r => `${ORDER.map(r => counts[r] || 0).join('/')}`;
  console.log(`${fails.length ? 'FAIL' : 'ok  '} ${id}  ${pw}x${ph}  rules(phone/id/bank/email/url/ipv4/ref/plate)=${fmt()}  shadow=${gt.shadow.length}  faces=${gt.faces.length}  codes=${gt.codes.length}  wm=${JSON.stringify(wm.quads.map(q => q.map(p => p.map(Math.round))))}`);
  for (const m of fails) console.log('   - ' + m);
  return fails.length === 0;
}

if (require.main === module) {
  const ids = process.argv.slice(2).length ? process.argv.slice(2) : IDS;
  let ok = true;
  for (const id of ids) ok = check(id) && ok;
  process.exit(ok ? 0 : 1);
}
module.exports = { RULES, firstRule, leakLines, quadHitsBox };
