# Baseline fixtures — the contract

Owner: Pluso (@developer). Why this exists: brief §9.2 — 30 fake images, made by us, with
ground truth, to measure what the phone's built-in recognition (faces, text, QR and barcodes)
actually finds before any rule is tuned. The numbers are only worth something if the ground
truth is exact, so every rule below is about keeping it exact.

**Never tune the set to make numbers look good. Never put a real person's data in it.**

## 1. Where things live

| What | Path | Notes |
|---|---|---|
| Served site (throw-away) | `/tmp/redactprobe/<agent>/…` | static server on `127.0.0.1:8765`; the cloud browser reads it through a public tunnel |
| Public base URL | `https://dsl-brakes-fotos-asn.trycloudflare.com` | quick tunnel; it can change. Re-read it with `grep -o 'https://[a-z-]*\.trycloudflare\.com' /run/airbuild/team/state/background-services/output/894E9102-70AB-41B0-A4BF-0821C0D5CFB1.log \| tail -1`, then `curl -s -o /dev/null -w '%{http_code}' <base>/t2.html` must print `200`. If it is down, stop and report — do not restart services. |
| Your scripts | `/projects/2ac5bd59-8729-421b-a7f8-43ca37aea5c4/tools/baseline/<agent>/` | generator + capture script only (small text files) |
| Final fixtures | `/projects/2ac5bd59-8729-421b-a7f8-43ca37aea5c4/QuickCoverTests/Fixtures/` | `<id>.png` or `<id>.jpg` plus `<id>.json` |

Do not run `git` (Pluso commits). Do not post to chat channels. Do not start or stop services.
Write only under your own three directories above.

## 2. The 30 fixtures

| id | category | pixels | file | what it is |
|---|---|---|---|---|
| chat_01_order | chat | 1170×2532 | png | one-on-one chat, an order |
| chat_02_group | chat | 1170×2532 | png | group chat, server / card / URL / waybill |
| chat_03_id | chat | 1170×2532 | png | chat with ID numbers, one wraps |
| chat_04_compressed | chat | 739×1600 | jpg | English chat, forwarded-compressed |
| chat_05_small | chat | 720×1558 | jpg | group chat, downscaled |
| chat_06_dark | chat | 1170×2532 | png | dark theme, Traditional Chinese |
| chat_07_qr | chat | 1170×2532 | png | chat with a payment QR |
| chat_08_long | chat | 1170×4800 | png | long group-chat screenshot |
| doc_01_idcard | doc | 1560×1000 | png | ID-style card with a portrait |
| doc_02_bankcard | doc | 1587×1002 | png | bank card front |
| doc_03_waybill | doc | 1000×1414 | png | courier label with QR + Code128 |
| doc_04_bankapp | doc | 1170×2532 | png | bank app screen |
| doc_05_invoice | doc | 1240×1754 | png | e-invoice page |
| plate_01_clear | plate | imagegen size | jpg | car rear, plate straight-on, big |
| plate_02_angle | plate | imagegen size | jpg | plate yawed ~25° |
| plate_03_small | plate | imagegen size | jpg | plate ~120 px wide, far car |
| plate_04_glare | plate | imagegen size | jpg | plate with glare streak, slight blur |
| plate_05_green | plate | imagegen size | jpg | new-energy green plate, 8 characters |
| plate_06_night | plate | imagegen size | jpg | night, plate lamps lit |
| photo_01_friends | photo | imagegen size | jpg | five adults, frontal, daylight |
| photo_02_couple | photo | imagegen size | jpg | two people, close-up |
| photo_03_crowd | photo | imagegen size | jpg | street, 10–14 people, small faces |
| photo_04_profile | photo | imagegen size | jpg | profile, sunglasses, cap, hard side light |
| photo_05_dinner | photo | imagegen size | jpg | family dinner, tilted camera, one mask |
| photo_06_backlit | photo | imagegen size | jpg | backlit group at sunset, one mask |
| web_01_log | web | 1170×2532 | png | dark log page, small monospace text |
| web_02_invoice | web | 1170×3948 | png | mobile order-detail page |
| web_03_contact | web | 1170×2532 | png | "contact us" page |
| web_04_article | web | 1170×3562 | png | long article, almost nothing to redact |
| web_05_lowres | web | 720×1558 | jpg | logistics page, downscaled and compressed |

## 3. Ground truth: what counts

### 3.1 Rule tags (exactly these strings)

| tag | definition from the brief (§7.2) | the tagged text must |
|---|---|---|
| `phone` | 手机号：1 开头 11 位 | be 11 digits starting with 1 once spaces and hyphens are removed |
| `id` | 身份证号：18 位，末位可以是 X | be 17 digits + one digit or X |
| `bank` | 银行卡号：16–19 位 | be 16–19 digits once spaces and hyphens are removed |
| `email` | 邮箱 | contain `@` and a dotted domain |
| `url` | 网址 | be a URL, with or without the scheme |
| `ipv4` | IP | be a dotted IPv4 address (no port inside the tag) |
| `ref` | 不少于 10 位的数字或字母数字单号 | contain a run of ≥ 10 letters/digits |
| `plate` | 车牌样式 | be a mainland plate, dot removed |

A string that fits two tags gets the first of this order: `phone`, `id`, `bank`, `email`, `url`, `ipv4`, `ref`, `plate`.

Matching is done per rule, and only three rules ignore separators:

- `phone`, `id`, `bank`: remove spaces and hyphens first (a card number printed in groups
  still counts). `021-6888 1234` then becomes 11 digits starting with 0 — no rule fits, it is
  a shadow item.
- `ref`: nothing is removed. It needs a run of ≥ 10 letters/digits with no space, hyphen, comma or
  underscore inside, so `400-800-1234`, `1,234,567,890` and `qc_support_2026` are not matches.
- `email`, `url`, `ipv4`: matched as printed.

### 3.2 Shadow items: real PII the first-version rules do not cover

`shadow:<kind>` marks something a person would want hidden that **no rule above can catch**:
person name (`shadow:name`), address (`shadow:address`), landline (`shadow:landline`),
international phone (`shadow:intl_phone`), passport number (`shadow:passport`).
Shadow items are reported separately and never scored as misses. Tag them wherever they are
obvious in the content; do not go hunting.

### 3.3 Codes and faces

`code:qr`, `code:code128`, `code:ean13` on the rendered code element, with `payload` the exact
encoded string. `face` on an image element whose visible content is one face (doc_01 only).
Photo faces are annotated by eye (photos and plates brief, §7.3).

### 3.4 The JSON beside each image

Pixel coordinates, origin top-left, **in the upright image as displayed** (for a rotated file
that means after the rotation is applied). Numbers may be fractional.

```json
{
  "id": "chat_01_order",
  "file": "chat_01_order.png",
  "category": "chat",
  "variant": "original",
  "source": "html",
  "width": 1170,
  "height": 2532,
  "orientation": 1,
  "notes": "",
  "text":   [ { "rule": "phone", "text": "139 0012 8867", "boxes": [[161.8, 851.9, 334.2, 71.4]] } ],
  "shadow": [ { "kind": "name", "text": "李娜", "boxes": [[..]] } ],
  "faces":  [ [x, y, w, h] ],
  "codes":  [ { "type": "qr", "payload": "…", "box": [x, y, w, h] } ]
}
```

- `text` holds **every** in-scope thing to redact, nothing else. One entry per tagged string;
  `boxes` has one `[x, y, w, h]` per visual line the string occupies (a wrapped number has two).
- `faces` is a list of `[x, y, w, h]`, one per face that is recognisable as a face at a glance.
- `codes`: one per QR / barcode, box = the full code including its quiet zone.
- `variant`: `original`, `compressed` (JPEG after a clean render), `small` (downscaled).
- `source`: `html`, `imagegen`, or `composite` (typeset plate on a generated photo).
- `orientation`: EXIF orientation of the file; 1 when the stored pixels are already upright.

## 4. Inline markup in the content

Generators take text with this markup and turn it into elements:

- `[[phone|139 0012 8867]]` → `<span data-rule="phone">139 0012 8867</span>`
- `[[shadow:name|李娜]]` → `<span data-shadow="name">李娜</span>`
- `[[code:qr|payload|size_px]]` → the rendered code, `data-code="qr" data-payload="payload"`

Each rule string sits on **one visual line** unless the fixture says it wraps.

## 5. Rendering HTML fixtures (proven recipe)

The cloud browser refuses `file:` and `data:` URLs and captures at 1x, so pages are laid out at
CSS size `W/3 × H/3` inside `<div id="shot">` scaled ×3, served over the tunnel, and captured
as an element screenshot.

```html
<style>html,body{margin:0;background:#fff}
#shot{width:390px;height:844px;transform:scale(3);transform-origin:0 0;overflow:hidden;position:absolute;left:0;top:0}</style>
<div id="shot"> … </div>
<script> /* collector from §5.1 */ </script>
```

```bash
B=/tmp/redactprobe/<agent>; S=<session>; BASE=<tunnel base url>
browser start --session $S
browser set viewport 1170 2532 --session $S          # the pixel size of #shot
browser open "$BASE/<agent>/<id>.html" --session $S
browser wait --load-state networkidle --timeout 8000 --session $S
browser screenshot --selector '#shot' -o "$B/<id>.png" --session $S   # ffprobe must report W×H
browser eval "JSON.stringify(window.__gt())" --session $S > "$B/<id>.gt.json"
browser stop --session $S
```

Use your own session name on **every** browser command. A session closes after 3 quiet minutes
and 15 minutes after start; do one fixture per session and always `browser stop` it.

Libraries, loaded from the CDN inside the page (they work there):

- QR: `<script src="https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.min.js</script>`
  then `const qr = qrcode(0, 'M'); qr.addData(payload); qr.make(); img.src = qr.createDataURL(cell, 4);`
  (`cell` in CSS px; margin 4 cells is the quiet zone; set the `img` width/height to match).
- Barcodes: `<script src="https://cdn.jsdelivr.net/npm/jsbarcode@3.12.1/dist/JsBarcode.all.min.js"></script>`
  then `JsBarcode('#bc', text, { format: 'CODE128' | 'EAN13', width, height, displayValue: false, margin: 10, background: '#fff' })`.
  Put human-readable digits in their own element under the SVG.

Chinese fonts exist (Noto Sans CJK). Use `font-family: -apple-system, "PingFang SC", "Noto Sans CJK SC", sans-serif`.
Local fonts do not exist: all text is rendered by the browser, never by ffmpeg.

### 5.1 Collector (embed verbatim)

```html
<script>
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
</script>
```

`rects(e)` must return one tight box per line. Make rule spans `display: inline` (not
`inline-block`) and give each visual line its own block with `width: max-content` when a line
must not stretch.

## 6. Variants (ffmpeg)

- `compressed` (chat_04): `ffmpeg -i clean.png -vf "scale=-2:1600,gblur=sigma=0.5" -q:v 9 out.jpg`
- `small` / `lowres` (chat_05, web_05): `ffmpeg -i clean.png -vf "scale=720:-2" -q:v 6 out.jpg`
  (use `-q:v 11` for web_05 to make it rough).
Scale ground-truth boxes by the same factor (`new_w / old_w`, `new_h / old_h`), rounding the
output size with ffprobe rather than trusting the formula.

## 7. Self-check before you report — all must pass

1. **Tag check.** Every `data-rule` text matches its rule (§3.1). Automated, in the page or Node.
2. **Leak check.** No untagged text on the page matches any rule. Scan every text line with the
   rules and their separators rule (§3.1); any match outside a `data-rule` span is an error:
   tag it, or change the text.
3. **Box check.** Draw every ground-truth box on the final image with ffmpeg `drawbox`
   (text: red, faces: lime, codes: blue; `t=4`) into `<id>.check.png`, look at it with the
   `read` tool, and confirm each box hugs exactly what it names. Crop and zoom when in doubt
   (`ffmpeg -i in.png -vf "crop=w:h:x:y"`). Delete the check images afterwards.
4. **Eye check.** Look at every final image: no tofu boxes, nothing clipped, nothing
   overlapping, the page reads like a real one.
5. **Code check.** Crop each QR/barcode at 100% and confirm it is sharp and complete.
6. **Size check.** `ffprobe` reports the size in §2.

## 8. Sandbox facts

- BusyBox `grep`: no `--include`, no `--exclude-dir`. `find` and `xargs` exist.
- `python3` (no PIL, no numpy), `ffmpeg`/`ffprobe`, `node` — no `npm install` here.
- `read` shows images downscaled (about 725 px wide); zoom by cropping.
- `imagegen`: read `/run/airbuild/system-skills/imagegen/SKILL.md` first.
- Time runs while you work: batch commands, do not sleep.
