#!/usr/bin/env node
// normgt.js — normalise the raw `browser eval` output of the collector into <id>.gt.json and print a summary.
// usage: node normgt.js /tmp/redactprobe/chatweb/<id>.gt.json
'use strict';
const fs = require('fs');
const file = process.argv[2];
let raw = fs.readFileSync(file, 'utf8').trim();
let gt;
try { gt = JSON.parse(raw); if (typeof gt === 'string') gt = JSON.parse(gt); }
catch (e) { console.error('collector output is not JSON:', raw.slice(0, 300)); process.exit(1); }
if (!gt || !Array.isArray(gt.text)) { console.error('unexpected collector output', JSON.stringify(gt).slice(0, 300)); process.exit(1); }
fs.writeFileSync(file, JSON.stringify(gt, null, 1));
const cnt = {};
for (const t of gt.text) cnt[t.rule] = (cnt[t.rule] || 0) + 1;
const multi = gt.text.filter(t => t.boxes.length !== 1).map(t => `${t.rule}:${t.text}=${t.boxes.length}boxes`);
console.log(`  rules ${JSON.stringify(cnt)} shadow ${gt.shadow.length} codes ${gt.codes.length} faces ${gt.faces.length}` +
  (multi.length ? `  multi-box: ${multi.join(', ')}` : '  all rule strings on one line'));
