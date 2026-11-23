#!/usr/bin/env node
// gen.js — generator for the chatweb fixture set (chat_01..chat_08, web_01..web_05).
// Plain Node (no npm). Emits one self-contained HTML page per fixture into the served dir.
//
//   node gen.js [outdir]        default outdir: /tmp/redactprobe/chatweb
//
// Inputs: the content below (FIXTURES) and collector.html (§5.1 of the contract, verbatim).
// Markup (§4): [[rule|text]] -> <span data-rule="rule">text</span>
//              [[shadow:kind|text]] -> <span data-shadow="kind">text</span>
//              [[code:qr|payload|size]] -> <span class="qr" data-code="qr" data-payload="payload" style="width:size;height:size">
// Each page: <div id="shot"> at CSS size W/3 x H/3 scaled x3, plus the collector script verbatim.
'use strict';
const fs = require('fs');
const path = require('path');
const OUT = process.argv[2] || '/tmp/redactprobe/chatweb';
const COLLECTOR = fs.readFileSync(path.join(__dirname, 'collector.html'), 'utf8');

const QR_LIB = '<script src="https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.min.js"></script>\n';
const BC_LIB = '<script src="https://cdn.jsdelivr.net/npm/jsbarcode@3.12.1/dist/JsBarcode.all.min.js"></script>\n';

// ---------------------------------------------------------------- content ----
// L = {l:'text', from:'nick'}  R = {r:'text'}  {t:'timestamp'}  {lqr:{payload,size}, from}
// {limg:'landscape', from}
const FIXTURES = [
  {
    id: 'chat_01_order', kind: 'chat', px: [1170, 2532], theme: 'light', im: 'wechat',
    title: '李娜', titleShadow: 'name', sb: '14:18', otherColor: '#c98b6b', meColor: '#4f78c9',
    msgs: [
      { t: '下午 2:18' },
      { l: '你好，我上周买的打印机到现在还没到' },
      { r: '抱歉，我查一下订单' },
      { r: '订单号是 [[bank|2026111500045678]]，今天下午发出' },
      { l: '好的。收件人 [[shadow:name|李娜]]，电话 [[phone|139 0012 8867]]' },
      { l: '地址是上海市浦东新区张江路 88 弄 3 号 502 室' },
      { r: '运费 ¥12.00 到付，预计明天 15:00 前送到' },
      { l: '好的，谢谢' },
    ],
  },
  {
    id: 'chat_02_group', kind: 'chat', px: [1170, 2532], theme: 'light', im: 'wechat-android', group: true, tight: true, wide: true,
    title: '周末爬山群（6）', sb: '14:20', meColor: '#4f78c9',
    colors: { 王芳: '#5b8fd6', 刘强: '#d59a5b', 陈静: '#b86fc4' },
    msgs: [
      { t: '14:20' },
      { l: '服务器地址 [[ipv4|192.168.1.23]]:8080，账号发我邮箱 [[email|wangfang@example.com]]', from: '王芳' },
      { l: '收到。先垫付一下，卡号 [[bank|6222 0210 0110 8867 123]]', from: '刘强' },
      { l: '开户行浦东支行，谢谢', from: '刘强' },
      { l: '攻略文档在这 [[url|https://docs.example.com/hike/2026.pdf]]', from: '陈静' },
      { l: '顺丰单号 [[ref|SF1398867001234]]，到了放前台', from: '王芳' },
      { l: '周五 14:30 老地方集合，别迟到', from: '刘强' },
      { l: '好，我带两瓶水', from: '陈静' },
      { t: '14:31' },
      { l: '那个 IP 是家里的，[[ipv4|192.168.1.23]]，端口 8080', from: '王芳' },
    ],
  },
  {
    id: 'chat_03_id', kind: 'chat', px: [1170, 2532], theme: 'light', im: 'wechat',
    title: '张伟', titleShadow: 'name', sb: '16:02', otherColor: '#6fae7c', meColor: '#4f78c9',
    msgs: [
      { t: '下午 4:02' },
      { l: '身份证号 [[id|310115199203084216]]，你记一下' },
      { l: '姓名张伟，手机 [[phone|186 0013 2266]]' },
      { r: '好。QQ 多少' },
      { l: '987654321，微信同号' },
      { l: '发票抬头和税号发你 [[ref|91110108MA01AB2C3X]]' },
      { r: '行，微信转你 ¥860.50' },
      // deliberately narrow bubble: the second ID number breaks across two lines (two boxes)
      { l: '另外这个也麻烦登记一下，身份证号是 [[id|110101198807154417]]', narrow: 246 },
    ],
  },
  {
    id: 'chat_04_compressed', kind: 'chat', px: [1170, 2532], theme: 'light', im: 'imessage', lang: 'en',
    title: 'Daniel Park', titleShadow: 'name', sb: '9:41',
    msgs: [
      { t: 'Today 9:41 AM' },
      { l: 'Can you send me the invoice for the printer?' },
      { r: 'Sure. Order [[ref|A8821304567]], total $1,245.00' },
      { r: "I'll email it to [[email|daniel.park@example.com]]" },
      { l: 'Thanks. Does it ship today?' },
      { r: 'Yes. Tracking number [[ref|1Z999AA10123456784]], ETA Thursday' },
      { l: 'Perfect. Call me at [[shadow:intl_phone|+1 (415) 555-0132]] if anything is missing' },
      { r: 'Will do' },
    ],
  },
  {
    id: 'chat_05_small', kind: 'chat', px: [1170, 2532], theme: 'light', im: 'wechat-android', group: true,
    title: '3 号楼业主群（42）', sb: '10:02', meColor: '#4f78c9',
    colors: { 小周: '#5b8fd6', 老赵: '#d59a5b', 楼长: '#b86fc4' },
    msgs: [
      { t: '10:02' },
      { l: '发票号码 [[ref|03300210021112345678]]', from: '小周' },
      { l: '有问题打座机 [[shadow:landline|021-6888 1234]]', from: '小周' },
      { l: '网银打款到 [[bank|6217 8500 1234 5678]]', from: '老赵' },
      { l: '汇款备注写 PO-2026-1188', from: '老赵' },
      { l: '收到，下午去办', from: '小周' },
      { l: '明天 9 点查水表，大家留人在家', from: '楼长' },
      { l: '2 号楼去年也查过一次', from: '老赵' },
      { l: '@所有人 收到请回复', from: '楼长' },
    ],
  },
  {
    id: 'chat_06_dark', kind: 'chat', px: [1170, 2532], theme: 'dark', im: 'wechat-android', group: true, lang: 'tc',
    title: '週末爬山團（5）', sb: '20:05', meColor: '#4f78c9',
    colors: { 阿傑: '#5b8fd6', 小美: '#d58bb0' },
    msgs: [
      { t: '下午 8:05' },
      { l: '手機 [[phone|137 0013 2266]]', from: '阿傑' },
      { l: 'Email [[email|chenwei@example.com]]', from: '小美' },
      { l: '網址 [[url|https://shop.example.com/orders/88213045]]', from: '小美' },
      { l: '卡號 [[bank|6226 0211 0033 8867]]', from: '阿傑' },
      { l: '統一編號 52368847，發票要開公司戶', from: '阿傑' },
      { l: '好，收到', from: '小美' },
      { l: '集合時間週六早上 6:30，捷運出口 2', from: '阿傑' },
    ],
  },
  {
    id: 'chat_07_qr', kind: 'chat', px: [1170, 2532], theme: 'light', im: 'wechat',
    title: '王芳', titleShadow: 'name', sb: '15:12', otherColor: '#5b8fd6', meColor: '#4f78c9',
    msgs: [
      { t: '下午 3:12' },
      { l: '麻烦转我 85，扫码就行' },
      { lqr: { payload: 'wxp://quickcover-test-sample-only/0001', size: 164 } },
      { r: '转了' },
      { l: '收到。手机号 [[phone|13900128867]]，微信同号' },
      { r: '好的' },
    ],
  },
  {
    id: 'chat_08_long', kind: 'chat', px: [1170, 4800], theme: 'light', im: 'wechat-android', group: true, spread: true, wide: true,
    title: '11 月日本行（8）', sb: '21:10', meColor: '#4f78c9',
    colors: { 领队: '#d59a5b', 小林: '#5b8fd6', 阿凯: '#7fae6f' },
    msgs: [
      { t: '11 月 20 日 21:10' },
      { l: '航班 MU5137，11 月 25 日 07:55 起飞', from: '领队' },
      { l: '订单号 [[bank|2026112300045678]]，护照号 [[shadow:passport|EF1234567]]', from: '领队' },
      { l: '酒店地址发我一下', from: '小林' },
      { l: '[[url|https://www.example-hotel.jp/reserve/88213045]]', from: '领队' },
      { l: '联系人电话 [[phone|138 0013 9921]]，到了打这个', from: '领队' },
      { l: '我的邮箱 [[email|xiaolin@example.com]]', from: '小林' },
      { t: '11 月 20 日 21:48' },
      { l: '保险单号 [[ref|PC2026112300188]]', from: '阿凯' },
      { l: '集合时间 11 月 25 日 06:30，T2 航站楼', from: '领队' },
      { l: '收到', from: '小林' },
      { t: '11 月 21 日 08:20' },
      { l: 'VPN 地址 [[ipv4|10.8.0.12]]，端口 1194', from: '阿凯' },
      { l: '群二维码过期了，重新发一个', from: '领队' },
      { lqr: { payload: 'https://example.com/join/quickcover-sample', size: 150.33 }, from: '领队' },
      { l: '谢谢', from: '小林' },
      { t: '11 月 21 日 12:36' },
      { l: '微信支付给谁', from: '阿凯' },
      { l: '给我就行，备注姓名', from: '领队' },
      { l: '保险 [[shadow:name|王小雨]] 那份我自己买', from: '小林' },
    ],
  },
];

const LOG_ROWS = `2026-11-23 09:41:20.004 INFO  boot     service started pid=4821 version 2.14.3
2026-11-23 09:41:20.011 INFO  config   loaded 38 rules from /etc/relay/rules.yaml
2026-11-23 09:41:21.372 INFO  gateway  [[ipv4|203.0.113.42]] GET /api/v1/orders 200 12ms
2026-11-23 09:41:21.905 WARN  gateway  [[ipv4|198.51.100.7]] POST /api/v1/login 401 3ms reason=bad-password
2026-11-23 09:41:22.315 INFO  gateway  [[ipv4|203.0.113.42]] GET /api/v1/orders/88213 304 4ms
2026-11-23 09:41:22.402 INFO  orders   order created id=[[ref|8f14e45fceea167a5a36dedd4bea2543]]
2026-11-23 09:41:22.410 INFO  notify   mail to [[email|ops@example.com]] queued q=mail-2
2026-11-23 09:41:23.001 INFO  sshd     accepted publickey for deploy from [[ipv4|192.0.2.61]] port 51234 ssh2
2026-11-23 09:41:24.118 INFO  db       user=[[email|zhang.wei@example.com]] login ok session=8h
2026-11-23 09:41:25.220 INFO  sync     pulling from [[url|https://mirror.example.com/apt/pool/main/]] every 6h
2026-11-23 09:41:26.003 INFO  cron     job invoices ran in 1.28s, 14 rows
2026-11-23 09:41:27.560 WARN  gateway  [[ipv4|198.51.100.7]] POST /api/v1/login 401 2ms reason=locked
2026-11-23 09:41:28.004 INFO  smtp     delivered to [[email|anna.li@example.com]] in 412ms
2026-11-23 09:41:29.330 INFO  pay      refund [[ref|R2026112300045678]] amount=12.50 currency=CNY
2026-11-23 09:41:30.002 INFO  health   ok uptime=99.98% mem=412/2048MB
2026-11-23 09:41:31.470 INFO  gateway  [[ipv4|203.0.113.42]] GET /api/v1/me 200 8ms
2026-11-23 09:41:32.011 INFO  audit    rule 17 matched 0 rows in last 24h
2026-11-23 09:41:33.880 INFO  backup   snapshot 2026-11-23T09:41:33 size=1.2G ok
2026-11-23 09:41:34.230 INFO  sshd     disconnected from [[ipv4|192.0.2.61]] port 51234
2026-11-23 09:41:35.001 INFO  notify   sms to [[phone|13900128867]] queued q=sms-1
2026-11-23 09:41:36.520 INFO  gateway  [[ipv4|198.51.100.7]] GET /healthz 200 1ms
2026-11-23 09:41:37.010 INFO  workers   8 busy, 24 idle, queue depth 3
2026-11-23 09:41:38.300 INFO  mail     bounce for [[email|bounce@example.com]] code=550
2026-11-23 09:41:39.004 INFO  gateway  [[ipv4|203.0.113.42]] DELETE /api/v1/keys/7 204 15ms
2026-11-23 09:41:40.480 INFO  sync     done, 0 errors, next run in 6h`;
// tail -f shows the newest lines; the three oldest rows have scrolled off the top (see report).
const LOG_SKIP = 3;

const ARTICLE = {
  title: '城市骑行十年：从代步到生活方式',
  byline: '本刊记者 · 2026 年 11 月',
  quote: '骑车的人多了，城市才会认真对待骑车的人。',
  caption: '清晨的滨江骑行道',
  table: { head: ['年份', '骑行人次', '同比增长'], rows: [['2023', '12,345,678', '23.5%'], ['2024', '15,020,331', '21.6%'], ['2025', '18,240,775', '21.4%']] },
  notes: ['[1] 为保护受访者，文中人物为化名，通勤时间为受访者自述。', '[2] 数据来自市交通管理部门年度报告，统计口径为全市公共自行车道计数点。'],
  blocks: [
    ['p', '十年前，骑车穿过这座城市需要一点勇气；十年后，自行车道成了许多人每天的必经之路。'],
    ['h', '车道从无到有'],
    ['p', '最早的变化来自江边。几段试验路铺上绿色沥青，与机动车道用隔离墩分开。'],
    ['p', '通车头一个月，就有市民晒出通勤时间：从城东到园区，骑车比开车快了将近二十分钟。'],
    ['h', '共享单车改变习惯'],
    ['p', '共享单车出现以后，骑行的门槛几乎降到了零。'],
    ['p', '在软件园上班的小林算了一笔账：换乘要四十分钟，骑车走滨江道只要三十五分钟[1]。'],
    ['h', '通勤者的账本'],
    ['q'],
    ['p', '安全最受关注。主要路口增设了非机动车信号灯，部分路段把右转车道与自行车道分开。'],
    ['f'],
    ['h', '一项城市计划'],
    ['p', '年初，“慢行系统提升”列入年度实事项目：三年内打通十二条断头路，新增万个车位[2]。'],
    ['t'],
    ['p', '十年累计骑行 1,234,567,890 人次——这是全市公共自行车道交出的数字，而且还在逐年增长。'],
    ['p', '下个十年，骑车的人会给出答案。'],
  ],
};

// ---------------------------------------------------------------- helpers ----
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const MMRX = /\[\[(code:[a-z0-9]+|shadow:[a-z_]+|[a-z0-9]+)\|([^\]]*)\]\]/g;
// Expand §4 markup. Inner text / attributes are escaped; surrounding text is the generator's own HTML.
function expand(m, kind, arg) {
  if (kind.startsWith('code:')) {
    const [payload, size] = arg.split('|');
    return `<span class="qr" data-code="${kind.slice(5)}" data-payload="${esc(payload)}" style="width:${size}px;height:${size}px"></span>`;
  }
  if (kind.startsWith('shadow:')) return `<span data-shadow="${kind.slice(7)}">${esc(arg)}</span>`;
  return `<span data-rule="${kind}">${esc(arg)}</span>`;
}
const mm = text => String(text).replace(MMRX, expand);

const PAGE_JS = `<script>
(function(){
  function run(){
    if (window.qrcode) document.querySelectorAll('[data-code="qr"]').forEach(function(el){
      var q = qrcode(0, 'M'); q.addData(el.dataset.payload); q.make();
      el.innerHTML = q.createSvgTag({cellSize: 10, margin: 40, scalable: true}); // margin is in cellSize units: 40 = 4 modules of quiet zone inside the box
      var svg = el.firstChild; svg.setAttribute('width', '100%'); svg.setAttribute('height', '100%'); svg.setAttribute('shape-rendering', 'crispEdges'); svg.style.display = 'block';
    });
    if (window.JsBarcode) document.querySelectorAll('svg[data-code="ean13"]').forEach(function(el){
      JsBarcode(el, el.dataset.payload, { format: 'EAN13', width: 2, height: 56, displayValue: false, margin: 22, background: '#ffffff' });
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', run); else run();
})();
</script>`;

function page(id, px, cls, body, css, libs) {
  const w = px[0] / 3;
  let h = px[1] / 3;
  // keep 3 x h an integer even when H is not divisible by 3 (snap to 1/64 px above H/3)
  if (!Number.isInteger(h)) h = Math.ceil(h * 64) / 64;
  const hs = Number.isInteger(h) ? `${h}px` : `${h}px`;
  return `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>${id}</title>
${libs && libs.includes('qr') ? QR_LIB : ''}${libs && libs.includes('bc') ? BC_LIB : ''}<style>
html,body{margin:0;background:#fff}
#shot{width:${w}px;height:${hs};transform:scale(3);transform-origin:0 0;overflow:hidden;position:absolute;left:0;top:0}
*{box-sizing:border-box}
${css}
</style></head><body>
<div id="shot" class="${cls}">${body}</div>
${PAGE_JS}
${COLLECTOR}
</body></html>`;
}

// ------------------------------------------------------------ small parts ----
function statusBar(dark, time) {
  return `<div class="statusbar"><span class="sb-time">${esc(time || '')}</span><span class="sb-icons">
<svg width="18" height="12" viewBox="0 0 18 12"><rect x="0" y="7.5" width="3" height="4" rx="1" fill="currentColor"/><rect x="5" y="5" width="3" height="6.5" rx="1" fill="currentColor"/><rect x="10" y="2.5" width="3" height="9" rx="1" fill="currentColor"/><rect x="15" y="0" width="3" height="11.5" rx="1" fill="currentColor"/></svg>
<svg width="16" height="12" viewBox="0 0 16 12"><path d="M1.6 4.2a9.2 9.2 0 0 1 12.8 0" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M4.2 7a5.6 5.6 0 0 1 7.6 0" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><circle cx="8" cy="10" r="1.5" fill="currentColor"/></svg>
<svg width="27" height="13" viewBox="0 0 27 13"><rect x="0.6" y="0.6" width="23" height="11.2" rx="3.4" fill="none" stroke="currentColor" stroke-opacity="0.4" stroke-width="1.1"/><rect x="2.3" y="2.3" width="19.6" height="7.8" rx="2" fill="currentColor"/><path d="M25.3 4.4v4.2c1.3-0.3 1.3-3.9 0-4.2z" fill="currentColor" fill-opacity="0.5"/></svg>
</span></div>`;
}
function sb(dark, time) { return statusBar(dark, time); }
const chevron = `<svg width="13" height="21" viewBox="0 0 13 21"><path d="M11 2 L2.5 10.5 L11 19" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
const chevronSm = `<svg width="10" height="17" viewBox="0 0 13 21"><path d="M11 2 L2.5 10.5 L11 19" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
const arrowBack = `<svg width="20" height="20" viewBox="0 0 20 20"><path d="M17 10 H3.5 M9 3.5 L2.5 10 L9 16.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
const dotsVert = `<svg width="6" height="22" viewBox="0 0 6 22"><circle cx="3" cy="3" r="2.1" fill="currentColor"/><circle cx="3" cy="11" r="2.1" fill="currentColor"/><circle cx="3" cy="19" r="2.1" fill="currentColor"/></svg>`;
function dotsSvg() { return `<svg width="22" height="6" viewBox="0 0 22 6"><circle cx="3" cy="3" r="2.1" fill="currentColor"/><circle cx="11" cy="3" r="2.1" fill="currentColor"/><circle cx="19" cy="3" r="2.1" fill="currentColor"/></svg>`; }

// ------------------------------------------------------------------ chats ----
const CHAT_CSS = `
.chat{display:flex;flex-direction:column;background:#ededed;color:#000;font-family:-apple-system,"PingFang SC","Noto Sans CJK SC",sans-serif;font-size:17px;-webkit-font-smoothing:antialiased}
.chat.tc{font-family:-apple-system,"PingFang TC","Noto Sans CJK TC","Noto Sans CJK SC",sans-serif}
.chat .statusbar{height:47px;flex:none;display:flex;align-items:center;justify-content:space-between;padding:6px 22px 0 34px}
.sb-time{font-size:15px;font-weight:600;letter-spacing:-0.2px}
.sb-icons{display:flex;align-items:center;gap:5px}
.chat .nav{height:44px;flex:none;display:flex;align-items:center;justify-content:center;position:relative}
.chat .nav .back{position:absolute;left:10px;width:30px;height:20px;border-radius:11px;background:rgba(0,0,0,.07);display:flex;align-items:center;justify-content:center}
.chat .nav .title{font-size:17px;font-weight:600;max-width:220px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis}
.chat .nav .more{position:absolute;right:14px;display:flex}
.msgs{flex:1;min-height:0;padding:0 12px;display:flex;flex-direction:column}
.spread{justify-content:space-between}
.blk{display:flex;flex-direction:column;align-items:stretch}
.ts{align-self:center;margin:10px 0 16px;padding:4px 9px;border-radius:4px;background:#dadada;color:#8a8a8a;font-size:12px;line-height:1.25}
.row{display:flex;align-items:flex-start;margin-top:16px}
.ts + .row{margin-top:0}
.row.r{justify-content:flex-end}
.ava{width:40px;height:40px;border-radius:4px;flex:none}
.row.l .ava{margin-right:8px}
.row.r .ava{margin-left:8px}
.col{display:flex;flex-direction:column;align-items:flex-start;max-width:240px;min-width:0}
.row.r .col{align-items:flex-end}
.nick{font-size:12px;color:#999;line-height:1.2;margin:0 0 5px 2px}
.bub{position:relative;background:#fff;border-radius:6px;padding:9px 12px;font-size:17px;line-height:1.4;max-width:230px;word-break:break-all;overflow-wrap:normal}
.bub::before{content:"";position:absolute;top:13px;left:-4px;width:8px;height:8px;background:inherit;border-radius:1px;transform:rotate(45deg)}
.row.r .bub{background:#95ec69}
.row.r .bub::before{left:auto;right:-4px}
.bub [data-rule]{white-space:nowrap}
.bub [data-rule="url"]{white-space:normal}
.bub [data-shadow]{white-space:nowrap}
.bub.narrow{width:246px;max-width:none}
.bub.narrow [data-rule]{white-space:normal}
.imgcard{background:#fff;border-radius:6px;padding:8px;display:block}
.qr{display:block;background:#fff}
.imgmsg{display:block;width:230px;height:132px;border-radius:6px;background:linear-gradient(180deg,#a9cde9 0%,#d7e6f3 50%,#7ea56f 50%,#557f4e 100%);position:relative;overflow:hidden}
.imgmsg::before{content:"";position:absolute;left:-40px;top:40px;width:220px;height:120px;border-radius:50%;background:#6f9a62}
.imgmsg::after{content:"";position:absolute;right:-60px;top:58px;width:260px;height:120px;border-radius:50%;background:#5f8a55}
.chat .bottom{flex:none;background:#f7f7f7;border-top:1px solid #d9d9d9}
.chat .inputbar{height:56px;display:flex;align-items:center;gap:10px;padding:0 10px;color:#000}
.ib-field{flex:1;height:38px;background:#fff;border:1px solid #e0e0e0;border-radius:6px}
.ib-plus{width:30px;height:30px;border-radius:6px;background:#fff;border:1.5px solid currentColor;display:flex;align-items:center;justify-content:center}
.homebar{height:34px;display:flex;align-items:center;justify-content:center}
.homebar i{display:block;width:134px;height:5px;border-radius:3px;background:#000}
/* dark theme */
.chat.dark{background:#111;color:#fff}
.chat.dark .bub{background:#2c2c2c}
.chat.dark .row.r .bub{background:#3eb575;color:#000}
.chat.dark .ts{background:#3a3a3a;color:#b2b2b2}
.chat.dark .nick{color:#a6a6a6}
.chat.dark .nav .back{background:rgba(255,255,255,.14)}
.chat.dark .bottom{background:#1e1e1e;border-top-color:#2a2a2a;color:#fff}
.chat.dark .ib-field{background:#2c2c2c;border-color:#2c2c2c}
.chat.dark .ib-plus{background:#2c2c2c}
.chat.dark .homebar i{background:#fff}
/* iMessage */
.im{background:#fff;font-family:-apple-system,"SF Pro Text","Helvetica Neue",Roboto,"Segoe UI",sans-serif}
.im .nav{background:#f6f6f7;border-bottom:1px solid #d9d9de}
.im .nav .title{font-weight:700}
.im .nav .backlabel{position:absolute;left:10px;color:#0a84ff;font-size:16px;display:flex;align-items:center;gap:2px}
.im .nav .avatarbtn{position:absolute;right:14px;width:30px;height:30px;border-radius:50%;background:#d1d1d6;display:flex;align-items:center;justify-content:center;color:#8e8e93}
.im .msgs{justify-content:flex-end}
.im .ts{background:none;padding:0;margin:8px 0 12px;color:#8e8e93;font-size:13px}
.im .row{margin-top:2px}
.im .ts + .row{margin-top:0}
.im .bub{background:#e9e9eb;border-radius:18px;padding:8px 13px;max-width:255px;word-break:normal;overflow-wrap:break-word}
.im .row.r .bub{background:#0b84fe;color:#fff}
.im .bub::before{top:auto;bottom:3px;left:-6px;width:14px;height:14px;border-radius:2px;background:inherit;transform:rotate(45deg)}
.im .row.r .bub::before{left:auto;right:-6px}
.im .bottom{background:#f6f6f7;border-top-color:#e2e2e6}
.im .inputbar{gap:8px;padding:0 10px}
.im .ib-field{background:#f0f0f2;border:none;border-radius:18px;height:36px;display:flex;align-items:center;padding:0 12px;color:#8e8e93;font-size:16px}
.im .ib-plus{display:none}
/* Android-style WeChat (16px text, 28px status bar, 48px title bar, no home indicator, wider bubbles) */
.chat.android{font-size:16px}
.chat.android .statusbar{height:28px;padding:0 16px 0 18px}
.chat.android .sb-time{font-size:13.5px;font-weight:500}
.chat.android .nav{height:48px}
.chat.android .nav .back{position:absolute;left:8px;width:40px;height:40px;border-radius:50%;background:transparent;display:flex;align-items:center;justify-content:center}
.chat.android .nav .title{font-weight:500}
.chat.android .nav .more{right:14px}
.chat.android .bub{font-size:16px;max-width:290px;padding:7px 12px}
.chat.android .bub.narrow{width:246px}
.chat.android .row{margin-top:12px}
.chat.android.tight .row{margin-top:8px}
.chat.android.wide .col{max-width:300px}
.chat.android.wide .bub{max-width:300px}
.msgs.spread{padding-bottom:12px}
.chat.android .ts{margin:8px 0 14px}
.chat.android.tight .ts{margin:6px 0 12px}
.chat.android .nick{margin-bottom:2px}
.chat.android .homebar{display:none}
.chat.android .imgmsg{width:290px}
`;

const voiceIcon = `<svg width="27" height="27" viewBox="0 0 27 27"><circle cx="13.5" cy="13.5" r="12" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M8 11v5 M11 8.5v10 M14 10v7 M17 11v5 M20 12.5v2" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" fill="none"/></svg>`;
const emojiIcon = `<svg width="27" height="27" viewBox="0 0 27 27"><circle cx="13.5" cy="13.5" r="12" fill="none" stroke="currentColor" stroke-width="1.6"/><circle cx="9.5" cy="11" r="1.4" fill="currentColor"/><circle cx="17.5" cy="11" r="1.4" fill="currentColor"/><path d="M8.5 16c1.3 1.9 2.9 2.8 5 2.8s3.7-.9 5-2.8" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" fill="none"/></svg>`;
const plusIcon = `<svg width="16" height="16" viewBox="0 0 16 16"><path d="M8 2v12 M2 8h12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>`;
const cameraIcon = `<svg width="26" height="24" viewBox="0 0 26 24"><path d="M8 6.5 L9.5 3.5 h7 L18 6.5" fill="none" stroke="#8e8e93" stroke-width="1.6" stroke-linejoin="round"/><rect x="2" y="6.5" width="22" height="15" rx="3.5" fill="none" stroke="#8e8e93" stroke-width="1.6"/><circle cx="13" cy="14" r="4.3" fill="none" stroke="#8e8e93" stroke-width="1.6"/></svg>`;
const appstoreIcon = `<svg width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="#8e8e93"/><path d="M9.3 15.2 l4.2-7.6 M14.7 15.2 l-2.1-3.9 M7.2 15.2 h9.6" stroke="#fff" stroke-width="1.5" stroke-linecap="round" fill="none"/></svg>`;

function chatHtml(f) {
  const cls = ['chat', f.theme === 'dark' ? 'dark' : '', f.lang === 'tc' ? 'tc' : '', f.im === 'imessage' ? 'im' : '', f.im === 'wechat-android' ? 'android' : '', f.tight ? 'tight' : '', f.wide ? 'wide' : ''].join(' ');
  const im = f.im === 'imessage';
  const android = f.im === 'wechat-android';
  const title = f.titleShadow ? `<span data-shadow="${f.titleShadow}">${esc(f.title)}</span>` : esc(f.title);
  let nav;
  if (im) {
    nav = `<div class="nav"><span class="backlabel">${chevronSm}Messages</span><span class="title">${title}</span><span class="avatarbtn"><svg width="18" height="18" viewBox="0 0 18 18"><circle cx="9" cy="6.3" r="3.4" fill="#f6f6f7"/><path d="M2.5 16c0.6-3.6 3.2-5.4 6.5-5.4s5.9 1.8 6.5 5.4z" fill="#f6f6f7"/></svg></span></div>`;
  } else if (android) {
    nav = `<div class="nav"><span class="back">${arrowBack}</span><span class="title">${title}</span><span class="more">${dotsVert}</span></div>`;
  } else {
    nav = `<div class="nav"><span class="back">${chevron}</span><span class="title">${title}</span><span class="more">${dotsSvg()}</span></div>`;
  }
  // messages, grouped into blocks per timestamp (blocks are spread over the full height for the long chat)
  let blocks = [[]];
  for (const m of f.msgs) {
    if (m.t) { if (blocks[0].length) blocks.push([]); blocks[blocks.length - 1].push(`<div class="ts">${esc(m.t)}</div>`); continue; }
    let inner = '';
    if (m.lqr) inner = `<div class="imgcard"><span class="qr" data-code="qr" data-payload="${esc(m.lqr.payload)}" style="width:${m.lqr.size}px;height:${m.lqr.size}px"></span></div>`;
    else if (m.limg) inner = `<div class="imgmsg"></div>`;
    else inner = `<div class="bub${m.narrow ? ' narrow' : ''}">${mm(m.r || m.l)}</div>`;
    if (m.r) blocks[blocks.length - 1].push(`<div class="row r"><div class="col">${inner}</div><div class="ava" style="background:${f.meColor}"></div></div>`);
    else {
      const color = f.group ? (f.colors[m.from] || '#999') : f.otherColor;
      const nick = f.group ? `<div class="nick">${esc(m.from)}</div>` : '';
      blocks[blocks.length - 1].push(`<div class="row l"><div class="ava" style="background:${color}"></div><div class="col">${nick}${inner}</div></div>`);
    }
  }
  const msgsHtml = blocks.map(b => `<div class="blk">${b.join('')}</div>`).join('');
  const input = im
    ? `<span>${appstoreIcon}</span><span class="ib-field">iMessage</span><span>${cameraIcon}</span>`
    : `<span>${voiceIcon}</span><span class="ib-field"></span><span>${emojiIcon}</span><span class="ib-plus">${plusIcon}</span>`;
  const body = sb(f.theme === 'dark', f.sb) + nav + `<div class="msgs${f.spread ? ' spread' : ''}">${msgsHtml}</div>` +
    `<div class="bottom"><div class="inputbar">${input}</div><div class="homebar"><i></i></div></div>`;
  const libs = f.msgs.some(m => m.lqr) ? 'qr' : '';
  return page(f.id, f.px, cls, body, CHAT_CSS, libs);
}

// ------------------------------------------------------------------- web ----
const WEB_CSS = `
.web{display:flex;flex-direction:column;background:#f3f4f6;color:#111;font-family:-apple-system,"PingFang SC","Noto Sans CJK SC",sans-serif;font-size:15px;-webkit-font-smoothing:antialiased}
.web .statusbar{height:44px;flex:none;display:flex;align-items:center;justify-content:space-between;padding:8px 22px 0 30px}
.sb-time{font-size:15px;font-weight:600;letter-spacing:-0.2px}
.sb-icons{display:flex;align-items:center;gap:5px}
.web .nav{height:44px;flex:none;display:flex;align-items:center;justify-content:center;position:relative;background:#fff;border-bottom:1px solid #e6e6e8}
.web .nav .back{position:absolute;left:12px;display:flex;color:#111}
.web .nav .title{font-size:17px;font-weight:600}
.web .body{flex:1;min-height:0;padding:6px 12px 0}
.card{background:#fff;border-radius:10px;padding:9px 14px;margin-bottom:8px}
.card h3{margin:0;font-size:15px;font-weight:600;color:#222}
.wrow{display:flex;justify-content:space-between;align-items:center;min-height:32px;gap:10px}
.wrow .k{color:#666;flex:none}
.wrow .v{color:#111;text-align:right;min-width:0;word-break:break-all}
.btn{display:inline-block;border:1px solid #333;border-radius:4px;padding:2px 8px;font-size:12px;line-height:1.4;color:#333;margin-left:8px;vertical-align:middle}
.small{font-size:12px;color:#888;margin-top:3px}
.web [data-rule]{white-space:nowrap}
`;

function webNav(title) { return `<div class="nav"><span class="back">${chevron}</span><span class="title">${esc(title)}</span></div>`; }
const landscape = (h, extraCss) => `<div class="landscape" style="height:${h}px"></div>`;
const LANDSCAPE_CSS = `.landscape{position:relative;overflow:hidden;border-radius:8px;background:linear-gradient(180deg,#9cc4e6 0%,#d8e8f4 52%,#7fa46f 52%,#557b4c 100%)}
.landscape::before{content:"";position:absolute;left:-30px;top:6%;width:18%;height:18%;border-radius:50%;background:#fff6d6}
.landscape::after{content:"";position:absolute;left:-25%;top:46%;width:90%;height:70%;border-radius:50%;background:#6d9560}
.landscape .hill{position:absolute;right:-30%;top:52%;width:110%;height:80%;border-radius:50%;background:#5e8653}
.landscape .road{position:absolute;left:-10%;bottom:8%;width:120%;height:11%;background:#e9e2cf;transform:rotate(-4deg)}
.landscape .lane{position:absolute;left:-10%;bottom:12.5%;width:120%;height:1.5%;background:#c84b4b;transform:rotate(-4deg)}`;

// web_01_log
function web01() {
  const rows = LOG_ROWS.split('\n').slice(LOG_SKIP);
  const body = rows.map(line => {
    const m = line.match(/^(\S+ \S+) +(INFO|WARN) +(\S+) +(.*)$/);
    return `<div class="ln"><span class="ts">${m[1]}</span> <span class="lv ${m[2].toLowerCase()}">${m[2]}</span>  <span class="tg">${m[3].padEnd(8)}</span>${mm(m[4])}</div>`;
  }).join('\n');
  const css = `
.log{background:#0b0f14;color:#c9d1d9;font-family:ui-monospace,"SF Mono",Menlo,Consolas,"DejaVu Sans Mono","Liberation Mono",monospace;font-size:10.5px;line-height:1.75}
.log .hdr{height:34px;padding:9px 10px 5px;display:flex;align-items:center;gap:8px;color:#8b949e;font-size:11px}
.log .hdr .dot{width:7px;height:7px;border-radius:50%;background:#f85149}
.log .ln{white-space:pre-wrap;padding:0 10px}
.log .ts{color:#8b949e}
.log .lv{font-weight:600}
.log .lv.info{color:#3fb950}
.log .lv.warn{color:#d29922}
.log [data-rule]{white-space:nowrap;color:#e6edf3}
.log .tg{color:#d2a8ff}`;
  const html = `<div class="hdr"><span class="dot"></span><span>relay-prod · tail -f</span></div>\n${body}`;
  return page('web_01_log', [1170, 2532], 'log', html, css, '');
}

// web_02_invoice
function web02() {
  const printer = `<div class="photo"><div class="p-paper"></div><div class="p-top"></div><div class="p-body"></div><div class="p-slot"></div><div class="p-led"></div></div>`;
  const body = sb(false, '9:41') + webNav('订单详情') + `<div class="body">
<div class="card">
  <div class="wrow"><span class="k">订单编号</span><span class="v">[[bank|2026111500045678]]<span class="btn">复制</span></span></div>
  <div class="wrow"><span class="k">状态</span><span class="v">待收货</span></div>
  <div class="wrow"><span class="k">预计送达</span><span class="v">明天 15:00 前</span></div>
</div>
<div class="card">
  <div class="prod">${printer}<div class="pinfo"><div>激光打印机 Pro M404dn</div><div class="price">¥1,299.00 <span class="xq">×2</span></div></div></div>
  <div class="wrow total"><span class="k">合计</span><span class="v">¥2,598.00（含运费 ¥0.00）</span></div>
</div>
<div class="card"><h3>收货信息</h3>
  <div class="nm">[[shadow:name|李娜]]<span class="mp">139****8867</span></div>
  <div class="addr">[[shadow:address|上海市浦东新区张江路 88 弄 3 号 502 室]]</div>
</div>
<div class="card"><h3>支付方式</h3>
  <div class="wrow slim"><span class="v l">微信支付</span></div>
  <div class="wrow"><span class="k">交易单号</span><span class="v">[[ref|4200002126112098765432]]</span></div>
</div>
<div class="card"><h3>发票</h3>
  <div class="wrow slim"><span class="v l">电子普通发票（单位）</span></div>
  <div class="wrow"><span class="k">税号</span><span class="v">[[ref|91110108MA01AB2C3X]]</span></div>
</div>
<div class="card"><h3>物流</h3>
  <div class="wrow slim"><span class="v l">示例快递</span></div>
  <div class="wrow"><span class="k">运单号</span><span class="v">[[ref|SF1398867001234]]<span class="btn">查询</span></span></div>
  <div class="tl">
    <div class="ti cur"><i></i><span class="tt">11-23 14:05</span><span>已签收</span></div>
    <div class="ti"><i></i><span class="tt">11-23 08:12</span><span>派送中</span></div>
    <div class="ti"><i></i><span class="tt">11-22 21:40</span><span>运输中</span></div>
  </div>
</div>
<div class="card"><h3>商品条码</h3>
  <div class="bcwrap"><svg class="ean" data-code="ean13" data-payload="6901234567892"></svg></div>
  <div class="digits">[[ref|6901234567892]]</div>
</div>
<div class="card"><h3>分享订单</h3>
  <div class="bcwrap">[[code:qr|https://example.com/o/2026111500045678|164]]</div>
</div>
<div class="foot"><div>客服电话 [[shadow:landline|400-800-1234]]</div><div class="small" style="text-align:center">客服时间 9:00–18:00</div></div>
</div>`;
  const css = WEB_CSS + `
.prod{display:flex;gap:12px;align-items:center;padding:2px 0 6px}
.pinfo{font-size:15px;line-height:1.5}
.price{color:#111;margin-top:6px}
.xq{color:#666}
.photo{width:68px;height:68px;border-radius:6px;background:linear-gradient(160deg,#f4f6f9,#dde4ec);position:relative;flex:none;overflow:hidden}
.p-body{position:absolute;left:10px;top:28px;width:48px;height:24px;background:#2b2f36;border-radius:4px}
.p-top{position:absolute;left:14px;top:18px;width:40px;height:12px;background:#3b4049;border-radius:3px 3px 0 0}
.p-paper{position:absolute;left:19px;top:6px;width:30px;height:14px;background:#fff;border:1px solid #c9d0d8;border-radius:1px}
.p-slot{position:absolute;left:18px;top:37px;width:32px;height:3px;background:#15171b;border-radius:2px}
.p-led{position:absolute;right:14px;top:32px;width:4px;height:4px;border-radius:50%;background:#7bd389}
.total{border-top:1px solid #eee;margin-top:2px}
.nm{font-size:15px;font-weight:600;display:flex;align-items:center;gap:10px;min-height:28px}
.slim{min-height:30px}
.mp{font-weight:400;color:#111}
.addr{font-size:14px;line-height:1.5;color:#111}
.v.l{text-align:left}
.tl{margin-top:2px;padding:2px 0 0 14px;position:relative}
.tl::before{content:"";position:absolute;left:3.5px;top:11px;bottom:11px;width:1px;background:#e0e0e0}
.ti{position:relative;display:flex;gap:14px;line-height:22px;font-size:14px;color:#444}
.ti i{position:absolute;left:-14px;top:8px;width:8px;height:8px;border-radius:50%;background:#c8c8c8}
.ti.cur{color:#111;font-weight:600}
.ti.cur i{background:#1a1a1a}
.ti .tt{color:#888;width:78px;flex:none;font-weight:400}
.bcwrap{display:flex;justify-content:center;padding:4px 0 2px}
.ean{display:block}
.digits{text-align:center;font-size:15px;letter-spacing:1px}
.foot{text-align:center;font-size:13px;color:#555;padding:2px 0 12px}`;
  return page('web_02_invoice', [1170, 3948], 'web', mm(body), css, 'qr,bc');
}

// web_03_contact
function web03() {
  const map = `<div class="map"><div class="blk b1"></div><div class="blk b2"></div><div class="blk b3"></div><div class="blk b4"></div><div class="rd r1"></div><div class="rd r2"></div><div class="rd r3"></div><div class="pin"></div></div>`;
  const body = sb(false, '9:41') + webNav('联系我们') + `<div class="body">
<div class="ttl"><h1>联系我们</h1><div class="sub">示例科技有限公司</div></div>
<div class="card">
  <div class="wrow"><span class="k">客服热线</span><span class="v big">[[shadow:landline|400-800-1234]]</span></div>
  <div class="small" style="text-align:right;margin-top:0">周一至周日 9:00–18:00</div>
  <div class="wrow"><span class="k">手机</span><span class="v">[[phone|139 0012 8867]]</span></div>
  <div class="wrow"><span class="k">邮箱</span><span class="v">[[email|service@example.com]]</span></div>
  <div class="wrow"><span class="k"></span><span class="v">[[email|hr@example.com]]</span></div>
  <div class="wrow"><span class="k">官网</span><span class="v">[[url|https://www.example.com/support]]</span></div>
  <div class="wrow"><span class="k"></span><span class="v">[[url|example.com/careers]]</span></div>
  <div class="wrow"><span class="k">内网 VPN（仅员工）</span><span class="v">[[ipv4|172.16.8.4]]</span></div>
</div>
<div class="card wx"><div class="wxl"><div class="k">微信</div><div class="v">qc_support_2026</div><div class="small">扫码添加客服</div></div>[[code:qr|https://example.com/wechat/quickcover-sample|136.67]]</div>
<div class="card"><h3>地址</h3>
  <div class="addr">[[shadow:address|上海市浦东新区张江路 88 弄 3 号 502 室]]</div>
  <div class="small">地铁 2 号线张江高科站 1 号口</div>
</div>
${map}
</div>`;
  const css = WEB_CSS + `
.ttl{padding:8px 4px 12px}
.ttl h1{margin:0;font-size:24px;line-height:1.3}
.ttl .sub{color:#666;font-size:14px;margin-top:4px}
.v.big{font-size:17px;font-weight:600}
.card.wx{display:flex;align-items:center;justify-content:space-between;gap:12px}
.wxl .k{color:#666}
.wxl .v{font-size:16px;font-weight:600;margin-top:4px}
.addr{font-size:14px;line-height:1.5}
.map{position:relative;height:108px;border-radius:10px;overflow:hidden;background:#e6ece2}
.blk{position:absolute;background:#cfd9cb;border-radius:2px}
.b1{left:14px;top:10px;width:70px;height:30px}.b2{left:110px;top:16px;width:46px;height:44px}.b3{left:250px;top:12px;width:60px;height:34px;background:#c5d3c1}.b4{left:320px;top:58px;width:50px;height:26px;background:#c5d3c1}
.rd{position:absolute;background:#fff}
.r1{left:0;top:52px;width:100%;height:8px}.r2{left:92px;top:0;width:7px;height:100%}.r3{left:0;top:20px;width:100%;height:4px;background:#f6e7b8}
.pin{position:absolute;left:190px;top:28px;width:14px;height:14px;border-radius:50% 50% 50% 0;background:#e5484d;transform:rotate(-45deg);box-shadow:0 0 0 3px #fff}`;
  return page('web_03_contact', [1170, 2532], 'web', mm(body), css, 'qr');
}

// web_04_article
function web04() {
  const t = ARTICLE;
  let out = '';
  for (const b of t.blocks) {
    if (b[0] === 'p') out += `<p>${esc(b[1])}</p>`;
    else if (b[0] === 'h') out += `<h2>${esc(b[1])}</h2>`;
    else if (b[0] === 'q') out += `<blockquote>${esc(t.quote)}</blockquote>`;
    else if (b[0] === 'f') out += `<figure>${landscape(52)}<figcaption>${esc(t.caption)}</figcaption></figure>`;
    else if (b[0] === 't') {
      out += `<table><thead><tr>${t.table.head.map(h => `<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>${t.table.rows.map(r => `<tr>${r.map(c => `<td>${esc(c)}</td>`).join('')}</tr>`).join('')}</tbody></table>`;
    }
  }
  const body = sb(false, '9:41') + `<div class="body art">
<h1>${esc(t.title)}</h1>
<div class="byline">${esc(t.byline)}</div>
${out}
<div class="notes">${t.notes.map(n => `<div>${esc(n)}</div>`).join('')}</div>
<div class="foot"><div>读者来信：[[email|reader@example.com]]</div><div>编辑部电话 [[shadow:landline|010-6888 1234]]</div></div>
</div>`;
  const css = WEB_CSS.replace('.web .body{flex:1;min-height:0;padding:10px 12px 0}', '.web .body{flex:1;min-height:0;padding:0 18px 0}') + LANDSCAPE_CSS + `
.art{font-size:16px;line-height:1.9;text-align:justify}
.art h1{margin:6px 0 4px;font-size:22px;line-height:1.35;font-weight:700}
.byline{font-size:13px;color:#777;margin-bottom:10px;padding-bottom:8px;border-bottom:1px solid #e8e8e8}
.art h2{font-size:17px;font-weight:700;margin:10px 0 2px;line-height:1.3}
.art p{margin:0 0 6px}
.art blockquote{margin:6px 0 8px;padding:6px 0 6px 14px;border-left:3px solid #222;font-size:16px;font-weight:600;line-height:1.6;text-align:left;color:#222}
.art figure{margin:4px 0 8px}
.art figcaption{font-size:12px;color:#777;margin-top:5px;text-align:center}
.art table{width:100%;border-collapse:collapse;margin:2px 0 8px;font-size:14px;line-height:1.4}
.art th,.art td{padding:4px 4px;border-bottom:1px solid #e8e8e8;text-align:right;font-variant-numeric:tabular-nums}
.art th:first-child,.art td:first-child{text-align:left}
.art th{color:#666;font-weight:600}
.notes{font-size:12px;color:#777;line-height:1.6;margin-top:6px}
.foot{margin-top:10px;padding:10px 12px;border-radius:8px;background:#fff;font-size:13px;color:#555;line-height:1.7}`;
  return page('web_04_article', [1170, 3562], 'web', mm(body), css, '');
}

// web_05_lowres
function web05() {
  const body = sb(false, '9:41') + webNav('物流跟踪') + `<div class="body">
<div class="card">
  <div class="wrow big"><span class="k">运单号</span><span class="v">[[ref|SF1398867001234]]<span class="btn">复制</span></span></div>
  <div class="wrow"><span class="k">快递</span><span class="v">示例快递</span></div>
  <div class="wrow"><span class="k">状态</span><span class="v st">运输中</span></div>
</div>
<div class="card"><h3>寄件人</h3>
  <div class="nm">[[shadow:name|王芳]]<span class="mp">[[phone|186 0013 8867]]</span></div>
</div>
<div class="card"><h3>收件人</h3>
  <div class="nm">李娜<span class="mp">139****8867</span></div>
</div>
<div class="card"><h3>派件员</h3>
  <div class="nm">小刘<span class="mp">[[phone|137 0013 5566]]</span></div>
</div>
<div class="card"><h3>物流轨迹</h3>
  <div class="tl">
    <div class="ti cur"><i></i><span class="tt">11-23 08:12</span><span>快件已到达上海浦东转运中心</span></div>
    <div class="ti"><i></i><span class="tt">11-23 06:40</span><span>快件已从上海张江营业部发出</span></div>
    <div class="ti"><i></i><span class="tt">11-22 21:40</span><span>快件已到达上海转运中心</span></div>
    <div class="ti"><i></i><span class="tt">11-22 19:05</span><span>示例快递已揽收</span></div>
  </div>
</div>
<div class="foot"><div>客服电话 [[shadow:landline|021-6888 1234]]</div><div class="small" style="text-align:center">服务时间 9:00–18:00</div></div>
</div>`;
  const css = WEB_CSS + `
.wrow.big .k{font-size:15px}
.wrow.big .v{font-size:19px;font-weight:600;letter-spacing:.3px}
.wrow.big{min-height:50px}
.web5 .wrow{min-height:40px}
.web5 .card{padding:14px 14px;margin-bottom:12px}
.web5 .nm{min-height:32px}
.web5 .body{padding-top:12px}
.st{color:#1a73e8;font-weight:600}
.card h3{margin-bottom:2px}
.nm{font-size:15px;font-weight:600;display:flex;align-items:center;gap:12px;min-height:28px}
.mp{font-weight:400;color:#111}
.tl{margin-top:8px;padding-left:14px;position:relative}
.tl::before{content:"";position:absolute;left:3.5px;top:17px;bottom:17px;width:1px;background:#e0e0e0}
.ti{position:relative;display:flex;gap:12px;line-height:24px;font-size:14px;color:#555;padding:5px 0}
.ti i{position:absolute;left:-14px;top:13px;width:8px;height:8px;border-radius:50%;background:#c8c8c8}
.ti.cur{color:#111;font-weight:600}
.ti.cur i{background:#1a1a1a}
.ti .tt{color:#888;width:78px;flex:none;font-weight:400}
.foot{text-align:center;font-size:13px;color:#555;padding:4px 0 14px}`;
  return page('web_05_lowres', [1170, 2532], 'web web5', mm(body), css, '');
}

// ------------------------------------------------------------------ main ----
const pages = [];
for (const f of FIXTURES) pages.push([f.id, chatHtml(f)]);
pages.push(['web_01_log', web01()], ['web_02_invoice', web02()], ['web_03_contact', web03()], ['web_04_article', web04()], ['web_05_lowres', web05()]);
fs.mkdirSync(OUT, { recursive: true });
for (const [id, html] of pages) fs.writeFileSync(path.join(OUT, `${id}.html`), html);
console.log(`wrote ${pages.length} pages to ${OUT}`);
