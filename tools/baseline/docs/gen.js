#!/usr/bin/env node
'use strict';
// Generator for the five `doc_*` baseline fixtures (tools/baseline/FIXTURES.md §2, §4, §5).
// Plain Node, no npm. Emits one self-contained HTML page per fixture into the served dir
// (default /tmp/redactprobe/docs, override with DOCS_SERVED). Each page has <div id="shot">
// at CSS size W/3 x H/3 scaled x3, the content with [[rule|text]] / [[shadow:kind|text]] /
// [[code:kind|payload|size]] expanded into data-* elements, and the §5.1 collector verbatim.
// The portrait is portrait.jpg next to this script; it is copied into the served dir and
// referenced by a relative URL (the cloud browser refuses file:/data: URLs).

const fs = require('fs');
const path = require('path');

const SERVED = process.env.DOCS_SERVED || '/tmp/redactprobe/docs';
const PORTRAIT = path.join(__dirname, 'portrait.jpg');
const SCALE = 3;

const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// §4 inline markup -> elements. Codes become placeholder elements; the page script renders them.
function md(s) {
  return s
    .replace(/\[\[code:(\w+)\|([^|\]]*)\|([\dx]+)\]\]/g, (m, kind, payload, size) => {
      const tag = (kind === 'code128' || kind === 'ean13') ? 'svg' : 'canvas';
      return `<${tag} class="code" data-code="${kind}" data-payload="${esc(payload)}" data-size="${size}"></${tag}>`;
    })
    .replace(/\[\[shadow:([a-z_]+)\|([^\]]*)\]\]/g, '<span data-shadow="$1">$2</span>')
    .replace(/\[\[([a-z0-9]+)\|([^\]]*)\]\]/g, '<span data-rule="$1">$2</span>');
}

const QR_LIB = '<script src="https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.min.js"></script>\n';
const BAR_LIB = '<script src="https://cdn.jsdelivr.net/npm/jsbarcode@3.12.1/dist/JsBarcode.all.min.js"></script>\n';

// Draws the QR codes on canvases at capture resolution (3x) so modules stay crisp, and the
// Code128 barcodes into SVGs with a 10-module quiet zone left and right.
const RENDER = `(function(){
  var S = ${SCALE};
  document.querySelectorAll('canvas[data-code="qr"]').forEach(function(cv){
    var payload = cv.getAttribute('data-payload'), size = parseFloat(cv.getAttribute('data-size'));
    var qr = qrcode(0, 'M'); qr.addData(payload); qr.make();
    var n = qr.getModuleCount(), q = 4, total = n + 2*q, px = Math.round(size*S);
    cv.width = px; cv.height = px; cv.style.width = size + 'px'; cv.style.height = size + 'px';
    var ctx = cv.getContext('2d'); ctx.fillStyle = '#fff'; ctx.fillRect(0,0,px,px); ctx.fillStyle = '#000';
    var cell = px/total;
    for (var r=0;r<n;r++) for (var c=0;c<n;c++) if (qr.isDark(r,c)) {
      var x0=Math.round((c+q)*cell), x1=Math.round((c+q+1)*cell), y0=Math.round((r+q)*cell), y1=Math.round((r+q+1)*cell);
      ctx.fillRect(x0,y0,x1-x0,y1-y0);
    }
    cv.setAttribute('data-modules', n);
    // Hand the pixels to an <img> (as in the §5 recipe) at the same CSS size; the PNG is 3x so it maps 1:1 to device pixels.
    var im = new Image(); im.className = cv.className; im.style.width = size + 'px'; im.style.height = size + 'px';
    im.setAttribute('width', size); im.setAttribute('height', size);
    for (const k of ['data-code', 'data-payload', 'data-size', 'data-modules']) if (cv.hasAttribute(k)) im.setAttribute(k, cv.getAttribute(k));
    im.src = cv.toDataURL('image/png'); cv.replaceWith(im);
  });
  document.querySelectorAll('svg[data-code="code128"]').forEach(function(svg){
    var sz = (svg.getAttribute('data-size') || '800x110').split('x');
    var w = (parseFloat(sz[0]) / S) / 132;           // 112 modules (14 digits, CODE128-C) + 2x10 quiet zone
    var h = parseFloat(sz[1]) / S;
    JsBarcode(svg, svg.getAttribute('data-payload'), { format: 'CODE128', width: w, height: h,
      displayValue: false, marginTop: 0, marginBottom: 0, marginLeft: 10*w, marginRight: 10*w, background: '#ffffff' });
    // JsBarcode ignores marginTop/Bottom = 0 (falsy) and adds 10px above and below; crop the viewBox to the bars.
    var vb = (svg.getAttribute('viewBox') || '0 0 0 0').split(' ').map(parseFloat), W = vb[2], H = vb[3];
    svg.setAttribute('viewBox', '0 ' + ((H - h) / 2) + ' ' + W + ' ' + h);
    svg.setAttribute('height', h + 'px');
  });
})();`;

// Extra measurement for the self-check (not part of the ground truth): the rotated watermark
// quads in output pixels, and any element that sticks out of #shot (clipping).
const WM = `window.__wm = () => {
  const s = document.getElementById('shot').getBoundingClientRect();
  const f = v => Math.round(v * 10) / 10;
  const quads = [...document.querySelectorAll('[data-wm]')].map(e => {
    const r = e.getBoundingClientRect();
    const cx = r.x + r.width/2 - s.x, cy = r.y + r.height/2 - s.y;
    const m = new DOMMatrix(getComputedStyle(e).transform);
    const k = s.width / document.getElementById('shot').offsetWidth;   // capture scale (3)
    const a = Math.atan2(m.b, m.a), w = e.offsetWidth*k/2, h = e.offsetHeight*k/2;
    return [[-w,-h],[w,-h],[w,h],[-w,h]].map(([x,y]) => [cx + x*Math.cos(a) - y*Math.sin(a), cy + x*Math.sin(a) + y*Math.cos(a)].map(f));
  });
  const over = [];
  document.getElementById('shot').querySelectorAll('*').forEach(e => {
    const r = e.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) return;
    if (r.right > s.right + 0.6 || r.bottom > s.bottom + 0.6 || r.left < s.left - 0.6 || r.top < s.top - 0.6)
      over.push([e.tagName + '.' + e.className, (r.left - s.x), (r.top - s.y), r.width, r.height].map(v => typeof v === 'number' ? Math.round(v*10)/10 : v));
  });
  return { quads, overflow: over };
};`;

// §5.1 collector, verbatim.
const COLLECTOR = `<script>
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
</script>`;

const WM_CSS = `.wm{position:absolute;transform-origin:50% 50%;white-space:nowrap;pointer-events:none;font-weight:700;line-height:1.2;font-family:"Noto Sans CJK SC","PingFang SC",sans-serif}`;
const CJK = `"Noto Sans CJK SC","PingFang SC","Source Han Sans SC",sans-serif`;
const MONO = `"DejaVu Sans Mono","Liberation Mono",monospace`;

// ---------------------------------------------------------------- fixtures (CSS px = output px / 3)

function idcard() {
  const W = 1560, H = 1000;
  const cw = (W / 3) * 0.92, ch = cw * 54 / 85.6;          // card 92% of the width, ID-1 ratio
  const cl = ((W / 3) - cw) / 2, ct = ((H / 3) - ch) / 2;
  const css = `
.idcard{background:radial-gradient(ellipse at 50% 40%, #e8eaec 0%, #d5d8db 65%, #c9ccd0 100%)}
.idcard .card{position:absolute;left:${cl}px;top:${ct}px;width:${cw}px;height:${ch}px;border-radius:14px;overflow:hidden;
  box-shadow:0 6px 18px rgba(0,0,0,.38),0 1px 3px rgba(0,0,0,.3);
  background:linear-gradient(160deg,#f8fcfd 0%,#eff7fa 50%,#fdf5f9 100%);color:#111;font-family:${CJK}}
.idcard .pattern{position:absolute;left:0;top:0;right:0;bottom:0;background:
  radial-gradient(ellipse 130px 80px at 12% 18%, rgba(110,200,230,.42), transparent 70%),
  radial-gradient(ellipse 170px 90px at 88% 12%, rgba(245,165,200,.38), transparent 70%),
  radial-gradient(ellipse 220px 110px at 62% 78%, rgba(130,210,235,.30), transparent 70%),
  radial-gradient(ellipse 160px 90px at 28% 92%, rgba(250,185,210,.32), transparent 70%),
  radial-gradient(ellipse 90px 60px at 70% 45%, rgba(160,225,240,.22), transparent 70%)}
.idcard .portrait{position:absolute;left:26px;top:84px;width:112px;height:132px;display:block;object-fit:cover;border-radius:2px;box-shadow:0 0 0 1px rgba(0,0,0,.1)}
.idcard .fields{position:absolute;left:158px;top:34px;width:302px}
.idcard .row{display:flex;align-items:baseline;margin-bottom:11px;white-space:nowrap}
.idcard .row.triple{gap:16px}
.idcard .cell{display:flex;align-items:baseline}
.idcard .lbl{font-size:8.5px;color:#333;letter-spacing:.5px;margin-right:6px}
.idcard .val{font-size:12.5px;font-weight:500}
.idcard .name{font-size:14px;font-weight:600}
.idcard .numline{position:absolute;left:26px;top:246px;height:30px;display:flex;align-items:baseline;white-space:nowrap}
.idcard .numline .lbl{font-size:10px;letter-spacing:1px;color:#222;margin-right:10px}
.idcard .num{font-family:${MONO};font-size:17px;letter-spacing:3px;color:#0b1c2b;font-weight:500}
.idcard .wm{left:309px;top:188px;transform:translate(-50%,-50%) rotate(-14deg);font-size:24px;color:rgba(30,90,140,.13)}`;
  const body = `
<div class="card">
  <div class="pattern"></div>
  <img class="portrait" src="portrait.jpg" alt="" data-face="1">
  <div class="fields">
    <div class="row"><span class="lbl">姓名</span><span class="val name">[[shadow:name|李明]]</span></div>
    <div class="row triple">
      <span class="cell"><span class="lbl">性别</span><span class="val">男</span></span>
      <span class="cell"><span class="lbl">民族</span><span class="val">汉</span></span>
      <span class="cell"><span class="lbl">出生</span><span class="val">1992 年 3 月 8 日</span></span>
    </div>
    <div class="row"><span class="lbl">住址</span><span class="val">[[shadow:address|上海市浦东新区张江路 88 弄 3 号 502 室]]</span></div>
  </div>
  <div class="numline"><span class="lbl">公民身份号码</span><span class="num">[[id|310115199203084216]]</span></div>
  <div class="wm" data-wm>测试样本 · 假数据</div>
</div>`;
  return { cls: 'idcard', W, H, css, body, qr: false, bar: false, portrait: true };
}

function bankcard() {
  const W = 1587, H = 1002;
  const cw = 500, ch = cw * 54 / 85.6;
  const cl = ((W / 3) - cw) / 2, ct = ((H / 3) - ch) / 2;
  const css = `
.bankcard{background:radial-gradient(ellipse at 50% 35%, #3b3f47 0%, #272a30 68%, #1d1f23 100%)}
.bankcard .card{position:absolute;left:${cl}px;top:${ct}px;width:${cw}px;height:${ch}px;border-radius:16px;overflow:hidden;color:#fff;
  background:linear-gradient(125deg,#0a2472 0%,#143a9e 40%,#4b2a8f 78%,#6d2c93 100%);
  box-shadow:0 10px 24px rgba(0,0,0,.55),0 2px 4px rgba(0,0,0,.4);font-family:${CJK}}
.bankcard .sheen{position:absolute;left:0;top:0;right:0;bottom:0;background:linear-gradient(115deg,rgba(255,255,255,.14) 0%,rgba(255,255,255,0) 38%,rgba(255,255,255,0) 62%,rgba(255,255,255,.07) 100%)}
.bankcard .chip{position:absolute;left:34px;top:74px;width:46px;height:34px;border-radius:6px;
  background:linear-gradient(135deg,#f8dc78 0%,#d9a520 40%,#f5d870 55%,#c9950f 100%);
  box-shadow:inset 0 0 0 1px rgba(120,80,0,.5),0 1px 2px rgba(0,0,0,.4)}
.bankcard .chip::before{content:"";position:absolute;left:0;right:0;top:11px;height:1px;background:rgba(120,80,0,.55);box-shadow:0 11px 0 rgba(120,80,0,.55)}
.bankcard .chip::after{content:"";position:absolute;top:0;bottom:0;left:15px;width:1px;background:rgba(120,80,0,.55);box-shadow:15px 0 0 rgba(120,80,0,.55)}
.bankcard .nfc{position:absolute;left:90px;top:82px;width:30px;height:30px}
.bankcard .brand{position:absolute;left:34px;top:24px}
.bankcard .brand .cn{font-size:17px;font-weight:700;letter-spacing:1px}
.bankcard .brand .en{font-size:8.5px;letter-spacing:2.2px;margin-top:2px;color:rgba(255,255,255,.78)}
.bankcard .circles{position:absolute;left:414px;top:20px;width:80px;height:46px}
.bankcard .circles i{position:absolute;top:0;width:46px;height:46px;border-radius:50%;border:1.5px solid rgba(255,255,255,.82);box-sizing:border-box}
.bankcard .circles i:first-child{left:0}
.bankcard .circles i:last-child{left:30px}
.bankcard .holo{position:absolute;left:300px;top:248px;width:38px;height:38px;border-radius:50%;
  background:radial-gradient(circle at 35% 35%,rgba(255,255,255,.75),rgba(255,255,255,.15) 45%,rgba(255,255,255,.35) 100%),
  conic-gradient(from 200deg,rgba(255,170,200,.55),rgba(170,220,255,.55),rgba(200,255,220,.5),rgba(255,240,180,.55),rgba(200,180,255,.55),rgba(255,170,200,.55));
  box-shadow:0 0 6px rgba(255,255,255,.25)}
.bankcard .num{position:absolute;left:0;right:0;top:192px;line-height:32px;text-align:center;white-space:nowrap;
  font-family:${MONO};font-size:26px;letter-spacing:2px;color:#e3e6ec}
.emb{text-shadow:0 -2px 2px rgba(0,0,0,.6),0 2px 1px rgba(255,255,255,.38)}
.bankcard .holder{position:absolute;left:34px;top:250px}
.bankcard .exp{position:absolute;right:34px;top:250px;text-align:right}
.bankcard .lbl{font-size:7px;letter-spacing:1.6px;color:rgba(255,255,255,.72);margin-bottom:3px}
.bankcard .val{font-size:14px;letter-spacing:1.5px;color:#e3e6ec;font-family:${MONO}}
.bankcard .wm{left:264px;top:152px;transform:translate(-50%,-50%) rotate(-12deg);font-size:23px;color:rgba(255,255,255,.14)}`;
  const body = `
<div class="card">
  <div class="sheen"></div>
  <div class="brand"><div class="cn">示例银行</div><div class="en">SAMPLE BANK</div></div>
  <div class="circles"><i></i><i></i></div>
  <div class="chip"></div>
  <svg class="nfc" viewBox="0 0 30 30" aria-hidden="true"><g fill="none" stroke="rgba(255,255,255,.88)" stroke-width="2.2" stroke-linecap="round">
    <path d="M7 11.5 A5 5 0 0 1 7 18.5"/><path d="M7 7.5 A9 9 0 0 1 7 22.5"/><path d="M7 3.5 A13 13 0 0 1 7 26.5"/></g></svg>
  <div class="holo"></div>
  <div class="num emb">[[bank|6226 0211 0033 8867]]</div>
  <div class="holder"><div class="lbl">CARD HOLDER</div><div class="val emb">[[shadow:name|ZHANG WEI]]</div></div>
  <div class="exp"><div class="lbl">VALID THRU</div><div class="val emb">12/29</div></div>
  <div class="wm" data-wm>测试样本 · 假数据</div>
</div>`;
  return { cls: 'bankcard', W, H, css, body, qr: false, bar: false, portrait: false };
}

function waybill() {
  const W = 1000, H = 1414;
  const css = `
.waybill{background:#fff;color:#000;font-family:"Liberation Mono","DejaVu Sans Mono","Noto Sans CJK SC",monospace;font-size:12px;line-height:16px}
.waybill .wrap{position:absolute;left:8px;top:8px;right:8px;bottom:8px}
.waybill .top{position:relative;height:150px}
.waybill .brand .cn{font-size:24px;font-weight:700;letter-spacing:1px;line-height:30px}
.waybill .brand .en{font-size:11px;letter-spacing:1.5px;line-height:14px;margin-top:2px}
.waybill .top .code{position:absolute;right:0;top:0}
.waybill .wm{left:88px;top:112px;transform:translate(-50%,-50%) rotate(-20deg);font-size:18px;color:rgba(0,0,0,.07)}
.waybill hr{border:0;border-top:1px solid #000;margin:0}
.waybill .route{font-size:26px;font-weight:700;line-height:34px;letter-spacing:2px;padding-left:2px}
.waybill .blk{padding:4px 2px;line-height:17px;white-space:nowrap}
.waybill .blk b{font-weight:700}
.waybill .ind{padding-left:42px}
.waybill .waybillno{padding:1px 2px;line-height:31px;white-space:nowrap}
.waybill .waybillno .k{font-size:11px;margin-right:12px}
.waybill .waybillno .v{font-size:24px;font-weight:700;letter-spacing:1px}
.waybill table.grid{border-collapse:collapse;width:100%;table-layout:fixed;font-size:11px}
.waybill table.grid td{border:1px solid #000;padding:1px 4px;height:19px;line-height:17px;white-space:nowrap;overflow:hidden}
.waybill .remark{padding:3px 2px;line-height:18px;white-space:nowrap}
.waybill .wrap>svg.code{display:block;margin:4px auto 0}
.waybill .digits{text-align:center;font-size:14px;letter-spacing:2px;line-height:18px;margin-top:1px}`;
  const body = `
<div class="wrap">
  <div class="top">
    <div class="brand"><div class="cn">示例快递</div><div class="en">SAMPLE EXPRESS</div></div>
    [[code:qr|https://example.com/t/SE1398867001234|150]]
    <div class="wm" data-wm>测试样本 · 假数据</div>
  </div>
  <hr>
  <div class="route">上海 → 苏州</div>
  <hr>
  <div class="blk">
    <div>寄件：<b>[[shadow:name|王芳]]</b>  [[phone|186 0013 8867]]</div>
    <div class="ind">[[shadow:address|上海市徐汇区示例路 12 号 3 楼]]</div>
  </div>
  <div class="blk">
    <div>收件：<b>[[shadow:name|李娜]]</b>  [[phone|139 0012 8867]]</div>
    <div class="ind">[[shadow:address|上海市浦东新区张江路 88 弄 3 号 502 室]]</div>
  </div>
  <hr>
  <div class="waybillno"><span class="k">运单号</span><span class="v">[[ref|SE1398867001234]]</span></div>
  <hr>
  <table class="grid">
    <colgroup><col style="width:31%"><col style="width:41%"><col></colgroup>
    <tr><td>件数 1/1</td><td>重量 2.35kg</td><td>体积 0.012m³</td></tr>
    <tr><td>付款方式 寄付</td><td>寄件日期 2026-11-23</td><td>第 1 次派送</td></tr>
  </table>
  <div class="remark">备注　易碎，轻放</div>
  <hr>
  [[code:code128|99998888001234|792x110]]   <!-- 132 modules x 6 px: integer module width, no antialiased bar edges -->
  <div class="digits">[[ref|99998888001234]]</div>
</div>`;
  return { cls: 'waybill', W, H, css, body, qr: true, bar: true, portrait: false };
}

function bankapp() {
  const W = 1170, H = 2532;
  const icon = (d, extra = '') => `<svg viewBox="0 0 24 24" aria-hidden="true"><g fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${extra}<path d="${d}"/></g></svg>`;
  // Vertical budget (CSS px): status 44 + nav 42 + balance 84 + 8 + transfer 166 + 8 + qr 222 + 8 + list 169 = 751 < content height 761.
  const css = `
.bankapp{background:#f2f3f7;color:#111;font-family:"Roboto","Helvetica Neue","Liberation Sans",Arial,"Noto Sans CJK SC",sans-serif}
.bankapp .status{position:absolute;left:0;top:0;right:0;height:44px;background:#fff;display:flex;align-items:center;justify-content:space-between;padding:0 24px 0 30px;box-sizing:border-box}
.bankapp .status .time{font-size:15px;font-weight:600}
.bankapp .status .right{display:flex;align-items:center;gap:6px}
.bankapp .signal{display:flex;align-items:flex-end;gap:1.5px;height:11px}
.bankapp .signal i{display:block;width:3px;background:#000;border-radius:1px}
.bankapp .signal i:nth-child(1){height:4px}.bankapp .signal i:nth-child(2){height:6.5px}.bankapp .signal i:nth-child(3){height:9px}.bankapp .signal i:nth-child(4){height:11px}
.bankapp .net{font-size:12px;font-weight:600}
.bankapp .batt{position:relative;width:25px;height:12px;border:1px solid rgba(0,0,0,.45);border-radius:3.5px;box-sizing:border-box;padding:1.5px}
.bankapp .batt::before{content:"";display:block;width:82%;height:100%;background:#000;border-radius:1.5px}
.bankapp .batt::after{content:"";position:absolute;right:-3px;top:3.5px;width:1.5px;height:4px;background:rgba(0,0,0,.45);border-radius:0 1px 1px 0}
.bankapp .nav{position:absolute;left:0;top:44px;right:0;height:42px;background:#fff;display:flex;align-items:center;justify-content:center;font-size:17px;font-weight:600}
.bankapp .content{position:absolute;left:0;top:86px;right:0;bottom:83px;overflow:hidden}
.bankapp .card{background:#fff;border-radius:14px;margin:0 12px 8px;padding:12px 16px}
.bankapp .bal{position:relative;height:84px;box-sizing:border-box;padding-top:10px}
.bankapp .bal .sub{font-size:12px;color:#8a8f99;line-height:16px}
.bankapp .bal .big{font-size:28px;font-weight:700;line-height:32px;letter-spacing:.3px;margin-top:1px}
.bankapp .bal .masked{font-size:12px;color:#555;line-height:16px;margin-top:1px}
.bankapp .bal .wm{left:290px;top:42px;transform:translate(-50%,-50%) rotate(-32deg);font-size:14px;color:rgba(40,70,140,.11)}
.bankapp .title{font-size:15px;font-weight:600;line-height:20px;margin-bottom:2px}
.bankapp .row{display:flex;justify-content:space-between;align-items:baseline;line-height:20px;font-size:13px}
.bankapp .row .k{color:#8a8f99}
.bankapp .row .v{color:#111;letter-spacing:.2px}
.bankapp .qrc{text-align:center;padding-bottom:8px}
.bankapp .qrc .title{text-align:left}
.bankapp .qrc .code{display:inline-block;margin:0 auto}
.bankapp .tx{display:flex;align-items:baseline;line-height:25px;font-size:14px}
.bankapp .tx .d{width:64px;color:#8a8f99;font-size:13px}
.bankapp .tx .n{flex:1}
.bankapp .tx .a{font-variant-numeric:tabular-nums}
.bankapp .tx .a.plus{color:#1a9c5b}
.bankapp .tabbar{position:absolute;left:0;right:0;bottom:0;height:83px;background:#fff;border-top:1px solid #e3e5ea;display:flex;padding-top:6px;box-sizing:border-box;color:#8a8f99}
.bankapp .tab{flex:1;display:flex;flex-direction:column;align-items:center;gap:2px;font-size:10px}
.bankapp .tab svg{width:26px;height:26px}
.bankapp .tab.on{color:#1d4fd7}
.bankapp .home{position:absolute;left:50%;bottom:8px;width:134px;height:5px;margin-left:-67px;border-radius:3px;background:#111}`;
  const body = `
<div class="status"><span class="time">9:41</span>
  <span class="right"><span class="signal"><i></i><i></i><i></i><i></i></span><span class="net">5G</span><span class="batt"></span></span>
</div>
<div class="nav">账户</div>
<div class="content">
  <div class="card bal">
    <div class="sub">储蓄账户 · 尾号 8867</div>
    <div class="big">¥ 12,345.67</div>
    <div class="masked">卡号 6226 **** **** 8867</div>
    <div class="wm" data-wm>测试样本 · 假数据</div>
  </div>
  <div class="card">
    <div class="title">转账详情</div>
    <div class="row"><span class="k">收款人</span><span class="v">[[shadow:name|王芳]]</span></div>
    <div class="row"><span class="k">收款账户</span><span class="v">[[bank|6217850001234567890]]</span></div>
    <div class="row"><span class="k">转账金额</span><span class="v">¥ 8,600.00</span></div>
    <div class="row"><span class="k">附言</span><span class="v">十一月房租</span></div>
    <div class="row"><span class="k">交易时间</span><span class="v">2026-11-20 09:41</span></div>
    <div class="row"><span class="k">交易单号</span><span class="v">[[ref|C20261120094122881300]]</span></div>
  </div>
  <div class="card qrc">
    <div class="title">收款码</div>
    [[code:qr|example-bank-pay:sample-0001|170]]
  </div>
  <div class="card list">
    <div class="title">最近交易</div>
    <div class="tx"><span class="d">11-18</span><span class="n">转账</span><span class="a">-1,200.00</span></div>
    <div class="tx"><span class="d">11-15</span><span class="n">工资</span><span class="a plus">+18,500.00</span></div>
    <div class="tx"><span class="d">11-12</span><span class="n">商超</span><span class="a">-86.50</span></div>
    <div class="tx"><span class="d">11-09</span><span class="n">房租</span><span class="a">-8,600.00</span></div>
    <div class="tx"><span class="d">11-05</span><span class="n">退款</span><span class="a plus">+199.00</span></div>
  </div>
</div>
<div class="tabbar">
  <div class="tab">${icon('M3.5 11 12 4.5 20.5 11M5.5 10.2V20h13v-9.8')}<span>首页</span></div>
  <div class="tab on">${icon('M4 20V10l8-5.5L20 10v10', '<rect x="4" y="10" width="16" height="10" rx="2"/><path d="M4 14h16"/>')}<span>账户</span></div>
  <div class="tab">${icon('M4 8h14M15 4.5 18.5 8 15 11.5M20 16H6M9 12.5 5.5 16 9 19.5')}<span>转账</span></div>
  <div class="tab">${icon('M4 20c0-4.4 3.6-7 8-7s8 2.6 8 7', '<circle cx="12" cy="8" r="4"/>')}<span>我的</span></div>
  <div class="home"></div>
</div>`;
  return { cls: 'bankapp', W, H, css, body, qr: true, bar: false, portrait: false };
}

function invoice() {
  const W = 1240, H = 1754;
  const pw = 396, ph = pw * 1754 / 1240;
  const pl = ((W / 3) - pw) / 2, pt = ((H / 3) - ph) / 2;
  const SERIF = `"Noto Serif CJK SC","Songti SC","SimSun","Source Han Serif SC",serif`;
  const css = `
.invoice{background:#e9ebee;font-family:${SERIF};color:#111}
.invoice .page{position:absolute;left:${pl}px;top:${pt}px;width:${pw}px;height:${ph}px;background:#fff;box-shadow:0 4px 14px rgba(0,0,0,.18),0 1px 3px rgba(0,0,0,.12);padding:14px 10px;box-sizing:border-box}
.invoice .hdr{position:relative;height:134px}
.invoice .hdr .code{position:absolute;left:0;top:0}
.invoice .hdr .title{position:absolute;left:140px;right:0;top:14px;text-align:center;font-size:24px;font-weight:700;letter-spacing:4px;line-height:30px}
.invoice .hdr .meta{position:absolute;left:150px;right:0;top:52px;font-size:11px;line-height:17px;white-space:nowrap}
.invoice .hdr .ckcode{font-size:12.5px;letter-spacing:.6px;line-height:18px}
.invoice table{border-collapse:collapse;width:100%;table-layout:fixed;font-size:11px}
.invoice td{border:1px solid #7a7a7a;padding:3px 5px;line-height:17px;vertical-align:middle;white-space:nowrap}
.invoice table.parties td{height:40px;vertical-align:top;font-size:10px;line-height:16px;padding:4px}
.invoice table.parties .p{font-weight:700;font-size:11px;margin-bottom:3px}
.invoice table.items tr.head td{text-align:center;font-weight:700;font-size:10px;height:24px;padding:2px;line-height:14px;border-top:0}
.invoice table.items tr.head td.w{white-space:normal;text-align:left}
.invoice table.items tr.item td{height:24px}
.invoice table.items td.r{text-align:right}
.invoice table.items tr.sum td{height:22px}
.invoice table.items tr.remark td{height:64px;vertical-align:top}
.invoice table.items td.wmcell{position:relative}
.invoice .wm{left:50%;top:50%;transform:translate(-50%,-50%) rotate(-14deg);font-size:17px;color:rgba(120,40,40,.13)}
.invoice table.items tr.sign td{height:30px;border-left:0;border-right:0;border-bottom:2px solid #111}`;
  const body = `
<div class="page">
  <div class="hdr">
    [[code:qr|example-invoice:033002100211|130]]
    <div class="title">电子发票</div>
    <div class="meta">
      <div>发票号码：[[ref|033002100211]]</div>
      <div>开票日期：2026年11月20日</div>
      <div>校验码：</div>
      <div class="ckcode">[[ref|82513098760243156789]]</div>
    </div>
  </div>
  <table class="parties">
    <colgroup><col style="width:51.5%"><col></colgroup>
    <tr>
      <td><div class="p">购买方</div><div>名称：上海示例科技有限公司</div><div>纳税人识别号：[[ref|91110108MA01AB2C3X]]</div></td>
      <td><div class="p">销售方</div><div>名称：示例办公设备有限公司</div><div>纳税人识别号：[[ref|91310115MA1K2X88B4]]</div></td>
    </tr>
  </table>
  <table class="items">
    <colgroup><col style="width:74px"><col style="width:74px"><col style="width:26px"><col style="width:26px"><col style="width:38px"><col style="width:42px"><col style="width:30px"><col></colgroup>
    <tr class="head"><td class="w">货物或应税劳务、服务名称</td><td>规格型号</td><td>单位</td><td>数量</td><td>单价</td><td>金额</td><td>税率</td><td>税额</td></tr>
    <tr class="item"><td>激光打印机</td><td>LSP-M2140</td><td>台</td><td>1</td><td class="r">735.40</td><td class="r">735.40</td><td class="r">13%</td><td class="r">95.60</td></tr>
    <tr class="item"><td>USB 打印线</td><td>2 米</td><td>条</td><td>2</td><td class="r">12.39</td><td class="r">24.78</td><td class="r">13%</td><td class="r">3.22</td></tr>
    <tr class="item"><td>安装服务</td><td></td><td>次</td><td>1</td><td class="r">13.27</td><td class="r">13.27</td><td class="r">6%</td><td class="r">0.80</td></tr>
    <tr class="sum"><td colspan="5">合计</td><td class="r">¥773.45</td><td></td><td class="r">¥99.62</td></tr>
    <tr class="sum"><td colspan="2">价税合计（大写）</td><td colspan="6">捌佰柒拾叁圆零角柒分　　（小写）¥873.07</td></tr>
    <tr class="sum"><td colspan="2">开户行及账号：</td><td colspan="6">示例银行浦东支行　[[id|310022334455667788]]</td></tr>
    <tr class="remark"><td colspan="4" style="vertical-align:top">备注：无</td><td colspan="4" class="wmcell"><div class="wm" data-wm>测试样本 · 假数据</div></td></tr>
    <tr class="sign"><td colspan="8">收款人：[[shadow:name|李娜]]　　　复核：[[shadow:name|王强]]　　　开票人：[[shadow:name|陈静]]</td></tr>
  </table>
</div>`;
  return { cls: 'invoice', W, H, css, body, qr: true, bar: false, portrait: false };
}

const FIXTURES = [
  { id: 'doc_01_idcard', category: 'doc', notes: 'ID-style card on a grey desk; portrait is the face box; faint watermark in the empty middle-right band of the card.', make: idcard },
  { id: 'doc_02_bankcard', category: 'doc', notes: 'Bank card front; embossed number is the only rule item, CARD HOLDER / VALID THRU / 12/29 are negatives; watermark sits between the chip and the number.', make: bankcard },
  { id: 'doc_03_waybill', category: 'doc', notes: 'Thermal courier label: QR top right, CODE128 at the bottom with its digits in their own element; watermark in the blank top-left area.', make: waybill },
  { id: 'doc_04_bankapp', category: 'doc', notes: 'Bank app screen; masked card number, amounts and recent-transaction list are negatives; watermark in the right half of the balance card.', make: bankapp },
  { id: 'doc_05_invoice', category: 'doc', notes: 'E-invoice page on grey; 18-digit account number tagged id per the §3.1 order; watermark in the remarks cell.', make: invoice },
];

function shell(f) {
  const libs = (f.qr ? QR_LIB : '') + (f.bar ? BAR_LIB : '');
  return `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>${f.id}</title>
${libs}<style>
html,body{margin:0;background:#fff}
#shot{width:${f.W / 3}px;height:${f.H / 3}px;transform:scale(${SCALE});transform-origin:0 0;overflow:hidden;position:absolute;left:0;top:0}
[data-rule],[data-shadow]{display:inline}
canvas.code,svg.code,img.code{display:block}
${WM_CSS}
${f.css}
</style></head>
<body>
<div id="shot" class="${f.cls}">
${md(f.body)}
</div>
<script>${RENDER}</script>
<script>${WM}</script>
${COLLECTOR}
</body></html>
`;
}

if (require.main === module) {
  fs.mkdirSync(SERVED, { recursive: true });
  for (const fx of FIXTURES) {
    const f = fx.make();
    const html = shell({ ...f, id: fx.id });
    fs.writeFileSync(path.join(SERVED, fx.id + '.html'), html);
    if (f.portrait) fs.copyFileSync(PORTRAIT, path.join(SERVED, 'portrait.jpg'));
    console.log(`${fx.id}.html  ${f.W}x${f.H}  ${html.length} bytes`);
  }
}

module.exports = { FIXTURES, md };
