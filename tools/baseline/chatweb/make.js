#!/usr/bin/env node
// make.js — build the final chatweb fixture files (variants per §6), write the ground-truth JSON (§3.4),
// and run the §7 self-check (tag check, leak check, box-check images, code crops, size check).
//
//   node make.js            build + checks        (run gen.js and capture.sh for every fixture first)
//
// Reads /tmp/redactprobe/chatweb/<id>.png + <id>.gt.json (+ <id>.html for the leak check),
// writes /projects/.../QuickCoverTests/Fixtures/<id>.png|jpg + <id>.json,
// check images into /tmp/redactprobe/chatweb/check/ (look at them, then delete them).
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const B = '/tmp/redactprobe/chatweb';
const FIXDIR = '/projects/2ac5bd59-8729-421b-a7f8-43ca37aea5c4/QuickCoverTests/Fixtures';
const CHECK = path.join(B, 'check');
const only = process.argv.slice(2).filter(a => !a.startsWith('--'));

// id -> category, variant, output size, notes
const META = {
  chat_01_order: { cat: 'chat', variant: 'original', px: [1170, 2532], notes: 'One-on-one WeChat-like chat, light theme. Title 李娜 and the bubble 李娜 are shadow:name. Order number 2026111500045678 is tagged bank, not ref: it is 16 digits and the section 3.1 order puts bank before ref. The address line is untagged (as in the brief).' },
  chat_02_group: { cat: 'chat', variant: 'original', px: [1170, 2532], notes: 'Group chat, light theme, Android-style WeChat layout (16 CSS px text, 300 px bubbles; the content does not fit 844 px at 17 px). The URL breaks across two lines inside the bubble, so the url entry has two boxes. Nicknames are grey lines above left bubbles.' },
  chat_03_id: { cat: 'chat', variant: 'original', px: [1170, 2532], notes: 'One-on-one chat with ID numbers. The last left bubble is deliberately narrow; its second ID number (110101198807154417) breaks across two lines (15 digits, then 417), so that id entry has two boxes. The bubble is 246 px wide; the exact line break aimed at in the brief is impossible at 17 px (the aimed line 2 alone is 264 px wide), so line 1 ends with 身. Title 张伟 is shadow:name; the QQ number 987654321 (9 digits) is untagged and matches no rule.' },
  chat_04_compressed: { cat: 'chat', variant: 'compressed', px: [739, 1600], notes: 'iMessage-like English chat rendered clean at 1170x2532, then ffmpeg scale=-1:1600 + gblur=sigma=0.5, JPEG q=9 (forwarded-compressed look). Boxes scaled by 739/1170 and 1600/2532. Title Daniel Park is shadow:name; +1 (415) 555-0132 is shadow:intl_phone.' },
  chat_05_small: { cat: 'chat', variant: 'small', px: [720, 1558], notes: 'Group chat (Android-style WeChat layout, 16 CSS px text; the content does not fit at 17 px) rendered clean at 1170x2532, then downscaled to 720 wide (scale=720:-2), JPEG q=6. Boxes scaled by 720/1170 and 1558/2532. The URL breaks across two lines (two boxes). 021-6888 1234 is shadow:landline.' },
  chat_06_dark: { cat: 'chat', variant: 'original', px: [1170, 2532], notes: 'DARK theme (black background, dark grey left bubbles, green right bubbles), Traditional Chinese group chat, Android-style WeChat layout (16 CSS px text). The URL breaks across two lines in its bubble (two boxes). 統一編號 52368847 is untagged (8 digits).' },
  chat_07_qr: { cat: 'chat', variant: 'original', px: [1170, 2532], notes: 'One-on-one chat with a payment QR as a left image message (white padded card; the 164 CSS px QR box includes its 4-module quiet zone). Title 王芳 is shadow:name.' },
  chat_08_long: { cat: 'chat', variant: 'original', px: [1170, 4800], notes: 'Long group-chat screenshot (CSS 390x1600), Android-style WeChat layout (16 CSS px text, 300 px bubbles). Messages spread over the full height with two extra timestamp lines (three in total); no image message. The hotel URL breaks across two lines in its bubble (two boxes). Order number 2026112300045678 is tagged bank, not ref: it is 16 digits and the section 3.1 order puts bank before ref. Passport EF1234567 is shadow:passport.' },
  web_01_log: { cat: 'web', variant: 'original', px: [1170, 2532], notes: 'Dark log viewer, 10.5px monospace, line-height 1.75. tail -f view: the three oldest rows of the brief scrolled off the top so the newest 22 rows (44 wrapped lines) fill the screen; they held no unique tagged item. Each tagged span sits on one line.' },
  web_02_invoice: { cat: 'web', variant: 'original', px: [1170, 3948], notes: 'Mobile order-detail page, light. EAN-13 6901234567892 as an SVG barcode (box includes the quiet zone) with the digits in their own ref element; QR 164 CSS px for sharing (box includes the 4-module quiet zone). Order number 2026111500045678 is tagged bank, not ref: it is 16 digits and the section 3.1 order puts bank before ref.' },
  web_03_contact: { cat: 'web', variant: 'original', px: [1170, 2532], notes: 'Contact-us page. qc_support_2026 is deliberately untagged (underscore breaks the ref rule). QR 136.7 CSS px beside the WeChat id (box includes the 4-module quiet zone). CSS map placeholder without text.' },
  web_04_article: { cat: 'web', variant: 'original', px: [1170, 3562], notes: 'Long Chinese magazine article, 16px/1.9 justified. Only reader@example.com is in scope; 010-6888 1234 is shadow:landline. All other numbers (years, comma-grouped counts, footnote markers, dates) are negatives.' },
  web_05_lowres: { cat: 'web', variant: 'lowres', px: [720, 1558], notes: 'Logistics page rendered clean at 1170x2532, then downscaled to 720 wide (scale=720:-2), JPEG q=11 (rough). Boxes scaled by 720/1170 and 1558/2532. Masked 139****8867 and 李娜 are untagged per the brief; 021-6888 1234 is shadow:landline.' },
};

// ------------------------------------------------------------------ rules ----
const strip = t => t.replace(/[\s-]/g, '');
const RULES = {
  phone: t => /^1\d{10}$/.test(strip(t)),
  id: t => /^\d{17}[\dX]$/.test(strip(t)),
  bank: t => /^\d{16,19}$/.test(strip(t)),
  email: t => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(t),
  url: t => /^(https?:\/\/)?[\w-]+(?:\.[\w-]+)*\.[a-z]{2,}(?::\d+)?([\/?#][^\s]*)?$/i.test(t), // scheme optional; the last label must be letters (a TLD), so 860.50 / 1.2G are not URLs
  ipv4: t => /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.test(t) && t.split('.').every(o => +o <= 255),
  ref: t => /[A-Za-z0-9]{10,}/.test(t), // §3.1: a run of >= 10 letters/digits
  plate: t => /^[京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼使领][A-Z][A-Z0-9]{4,5}[A-Z0-9挂学警港澳]$/.test(t),
};
const ORDER = ['phone', 'id', 'bank', 'email', 'url', 'ipv4', 'ref', 'plate'];
// leak patterns for free text
const LEAK = [
  ['phone', l => new RegExp('(?<![0-9])1[0-9]{10}(?![0-9])').exec(strip(l))],
  ['id', l => new RegExp('(?<![0-9X])[0-9]{17}[0-9X](?![0-9X])').exec(strip(l))],
  ['bank', l => new RegExp('(?<![0-9])[0-9]{16,19}(?![0-9])').exec(strip(l))],
  ['email', l => /[^\s@]+@[^\s@]+\.[^\s@]+/.exec(l)],
  ['url', l => /(?:https?:\/\/)?[\w-]+(?:\.[\w-]+)*\.[a-z]{2,}(?::\d+)?(?:[\/?#][^\s]*)?/i.exec(l)],
  ['ipv4', l => /(?<![0-9.])(?:\d{1,3}\.){3}\d{1,3}(?![0-9.])/.exec(l)],
  ['ref', l => /(?=[A-Za-z0-9]*[0-9])[A-Za-z0-9]{10,}/.exec(l)], // needs a digit: a pure word is not a tracking number
];
const WARN_REF = l => /[A-Za-z]{10,}/.exec(l); // pure-letter runs: would match a digit-free ref regex

const ffprobe = f => execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', f]).toString().trim().split(',').map(Number);
const ffmpeg = args => execFileSync('ffmpeg', ['-v', 'error', '-y', ...args]);
const r1 = v => Math.round(v * 10) / 10;

function variantCmd(id, src, dst) {
  if (id === 'chat_04_compressed') return ['-i', src, '-vf', 'scale=-1:1600,gblur=sigma=0.5', '-q:v', '9', dst];
  if (id === 'chat_05_small') return ['-i', src, '-vf', 'scale=720:-2', '-q:v', '6', dst];
  if (id === 'web_05_lowres') return ['-i', src, '-vf', 'scale=720:-2', '-q:v', '11', dst];
  return null;
}

function scaleGt(gt, sx, sy) {
  const sc = b => [r1(b[0] * sx), r1(b[1] * sy), r1(b[2] * sx), r1(b[3] * sy)];
  return {
    text: gt.text.map(t => ({ rule: t.rule, text: t.text, boxes: t.boxes.map(sc) })),
    shadow: gt.shadow.map(t => ({ kind: t.kind, text: t.text, boxes: t.boxes.map(sc) })),
    faces: gt.faces.map(sc),
    codes: gt.codes.map(c => ({ type: c.type, payload: c.payload, box: sc(c.box) })),
  };
}

function leakCheck(id) {
  let h = fs.readFileSync(path.join(B, `${id}.html`), 'utf8');
  h = h.replace(/<script[\s\S]*?<\/script>/g, '').replace(/<style[\s\S]*?<\/style>/g, '')
    .replace(/<span data-rule="[^"]*">[^<]*<\/span>/g, '').replace(/<svg[\s\S]*?<\/svg>/g, '')
    .replace(/<\/(div|p|h1|h2|h3|tr|td|th|li|table|blockquote|figure|figcaption|thead|tbody|span)>|<br\s*\/?>/g, '\n')
    .replace(/<[^>]+>/g, '').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
  const errs = [], warns = [];
  for (const line0 of h.split('\n')) {
    const line = line0.trim(); if (!line) continue;
    for (const [rule, fn] of LEAK) { const m = fn(line); if (m) errs.push(`${rule} "${m[0]}" in "${line.slice(0, 70)}"`); }
    const w = WARN_REF(line); if (w && !/[0-9]/.test(w[0])) warns.push(`letters-only ref run "${w[0]}" in "${line.slice(0, 60)}"`);
  }
  return { errs, warns };
}

function build(id) {
  const meta = META[id];
  const gtRaw = JSON.parse(fs.readFileSync(path.join(B, `${id}.gt.json`), 'utf8'));
  const srcPng = path.join(B, `${id}.png`);
  const srcSize = ffprobe(srcPng);
  const problems = [];
  // 1. tag check (+ precedence note)
  const precNotes = [];
  for (const t of gtRaw.text) {
    if (!RULES[t.rule](t.text)) problems.push(`TAG: ${t.rule} "${t.text}" does not match its rule`);
    const first = ORDER.find(r => RULES[r](t.text));
    if (first !== t.rule) precNotes.push(`${t.rule} "${t.text}" also fits ${first} first (§3.1 order)`);
  }
  for (const s of gtRaw.shadow) {
    const hit = ORDER.find(r => RULES[r](s.text)); if (hit) problems.push(`SHADOW: ${s.kind} "${s.text}" matches rule ${hit}`);
  }
  // 2. leak check
  const lk = leakCheck(id);
  for (const e of lk.errs) problems.push(`LEAK: ${e}`);
  // 3. output file + scaled boxes
  const outName = `${id}.${meta.variant === 'original' ? 'png' : 'jpg'}`;
  const outFile = path.join(FIXDIR, outName);
  const cmd = variantCmd(id, srcPng, outFile);
  let gt = gtRaw;
  if (cmd) {
    ffmpeg(cmd);
    const sz = ffprobe(outFile);
    if (sz[0] !== meta.px[0] || sz[1] !== meta.px[1]) problems.push(`SIZE: ${outName} is ${sz.join('x')}, expected ${meta.px.join('x')}`);
    gt = scaleGt(gtRaw, sz[0] / srcSize[0], sz[1] / srcSize[1]);
  } else {
    fs.copyFileSync(srcPng, outFile);
    if (srcSize[0] !== meta.px[0] || srcSize[1] !== meta.px[1]) problems.push(`SIZE: ${outName} is ${srcSize.join('x')}, expected ${meta.px.join('x')}`);
  }
  const sz = ffprobe(outFile);
  const json = {
    id, file: outName, category: meta.cat, variant: meta.variant, source: 'html',
    width: sz[0], height: sz[1], orientation: 1, notes: meta.notes,
    text: gt.text, shadow: gt.shadow, faces: gt.faces, codes: gt.codes,
  };
  fs.writeFileSync(path.join(FIXDIR, `${id}.json`), JSON.stringify(json, null, 1) + '\n');
  // 4. box-check image + 5. code crops
  fs.mkdirSync(CHECK, { recursive: true });
  const filters = [];
  const box = (b, color) => {
    let [x, y, w, h] = b.map(Math.round);
    x = Math.max(0, Math.min(x, sz[0] - 1)); y = Math.max(0, Math.min(y, sz[1] - 1));
    w = Math.max(1, Math.min(w, sz[0] - x)); h = Math.max(1, Math.min(h, sz[1] - y));
    filters.push(`drawbox=x=${x}:y=${y}:w=${w}:h=${h}:color=${color}@0.85:t=4`);
  };
  for (const t of json.text) t.boxes.forEach(b => box(b, 'red'));
  for (const s of json.shadow) s.boxes.forEach(b => box(b, 'yellow'));
  for (const f of json.faces) box(f, 'lime');
  json.codes.forEach((c, i) => {
    box(c.box, 'blue');
    const [x, y, w, h] = c.box.map(Math.round);
    ffmpeg(['-i', outFile, '-vf', `crop=${w}:${h}:${x}:${y}`, path.join(CHECK, `${id}.code-${i + 1}.png`)]);
  });
  if (filters.length) ffmpeg(['-i', outFile, '-vf', filters.join(','), path.join(CHECK, `${id}.check.png`)]);
  // 6. summary
  const cnt = {}; for (const t of json.text) cnt[t.rule] = (cnt[t.rule] || 0) + 1;
  const multi = json.text.filter(t => t.boxes.length !== 1).map(t => `${t.rule}:${t.text}=${t.boxes.length}`);
  const summary = `${id} | ${outName} | ${sz.join('x')} | rules ${ORDER.filter(r => cnt[r]).map(r => `${r}=${cnt[r]}`).join(' ') || 'none'} | shadow ${json.shadow.length} | codes ${json.codes.length}${multi.length ? ` | multi-box ${multi.join('; ')}` : ''}` +
    `${precNotes.length ? `\n    precedence note: ${precNotes.join('; ')}` : ''}${lk.warns.length ? `\n    letter-run warning: ${lk.warns.join('; ')}` : ''}${problems.length ? `\n    PROBLEMS: ${problems.join('; ')}` : ' | OK'}`;
  return summary;
}

fs.mkdirSync(FIXDIR, { recursive: true });
const ids = only.length ? only : Object.keys(META);
for (const id of ids) console.log(build(id));
