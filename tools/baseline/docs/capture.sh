#!/bin/sh
# Capture the five doc_* fixtures with the cloud browser (FIXTURES.md §5 recipe).
# One session per fixture, own session name on every command, browser stop after each.
# Usage: capture.sh            (all five)      capture.sh doc_03_waybill   (one)
set -u
B=/tmp/redactprobe/docs
S=docs
BASE=${BASE:-$(grep -o 'https://[a-z-]*\.trycloudflare\.com' /run/airbuild/team/state/background-services/output/894E9102-70AB-41B0-A4BF-0821C0D5CFB1.log | tail -1)}
if [ "${1:-all}" = all ]; then IDS="doc_01_idcard doc_02_bankcard doc_03_waybill doc_04_bankapp doc_05_invoice"; else IDS="$1"; fi
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/t2.html")
if [ "$code" != 200 ]; then echo "tunnel down ($code) at $BASE"; exit 1; fi
for id in $IDS; do
  case $id in
    doc_01_idcard) W=1560; H=1000;;
    doc_02_bankcard) W=1587; H=1002;;
    doc_03_waybill) W=1000; H=1414;;
    doc_04_bankapp) W=1170; H=2532;;
    doc_05_invoice) W=1240; H=1754;;
    *) echo "unknown fixture $id"; exit 1;;
  esac
  [ -f "$B/$id.html" ] || { echo "missing $B/$id.html (run gen.js first)"; exit 1; }
  browser start --session $S >/dev/null || exit 1
  browser set viewport $W $H --session $S >/dev/null
  browser open "$BASE/docs/$id.html" --session $S >/dev/null
  browser wait --load-state networkidle --timeout 8000 --session $S >/dev/null
  browser screenshot --selector '#shot' -o "$B/$id.png" --session $S >/dev/null
  browser eval "JSON.stringify(window.__gt())" --session $S > "$B/$id.gt.json"
  browser eval "JSON.stringify(window.__wm())" --session $S > "$B/$id.wm.json"
  browser stop --session $S >/dev/null
  printf '%s  ' "$id"; ffprobe -v error -show_entries stream=width,height -of csv=p=0 "$B/$id.png"
done
