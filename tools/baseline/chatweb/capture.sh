#!/bin/bash
# capture.sh — render one chatweb fixture page in the cloud browser and save screenshot + collector output.
# Own session ("chatweb"), one fixture per session, browser stop after each (FIXTURES.md §5).
#
#   ./capture.sh <id> <W> <H>        e.g. ./capture.sh chat_01_order 1170 2532
#
# Output: /tmp/redactprobe/chatweb/<id>.png, <id>.gt.json (collector, unscaled), <id>.ov.json (overflow probe)
set -u
ID=$1; W=$2; H=$3
B=/tmp/redactprobe/chatweb; S=chatweb
BASE=$(grep -o 'https://[a-z-]*\.trycloudflare\.com' /run/airbuild/team/state/background-services/output/894E9102-70AB-41B0-A4BF-0821C0D5CFB1.log | tail -1)
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$BASE/t2.html"); [ "$code" = 200 ] || { echo "tunnel down ($code)"; exit 2; }
[ -f "$B/$ID.html" ] || { echo "no page $B/$ID.html (run gen.js)"; exit 2; }
browser start --session $S >/dev/null 2>&1 || { echo "browser start failed"; exit 3; }
browser set viewport "$W" "$H" --session $S >/dev/null 2>&1
browser open "$BASE/chatweb/$ID.html" --session $S >/dev/null 2>&1
browser wait --load-state networkidle --timeout 8000 --session $S >/dev/null 2>&1
browser screenshot --selector '#shot' -o "$B/$ID.png" --session $S >/dev/null 2>&1 || echo "screenshot failed"
browser eval "JSON.stringify(window.__gt())" --session $S > "$B/$ID.gt.json" 2>&1
browser eval "JSON.stringify((function(){var s=document.getElementById('shot');var sb=s.getBoundingClientRect();var m=s.querySelector('.msgs,.body');var o={shotH:(sb.bottom-sb.top)/3};if(m){var mb=m.getBoundingClientRect();var last=m.lastElementChild;var r=last?last.getBoundingClientRect():null;o.innerTop=(mb.top-sb.top)/3;o.innerLimit=(mb.bottom-sb.top)/3;o.innerScrollH=m.scrollHeight;o.innerClientH=m.clientHeight;o.lastBottom=r?(r.bottom-sb.top)/3:null;}return o;})())" --session $S > "$B/$ID.ov.json" 2>&1
browser stop --session $S >/dev/null 2>&1
node "$(dirname "$0")/normgt.js" "$B/$ID.gt.json" || exit 4
echo "$ID: $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$B/$ID.png")  overflow: $(cat "$B/$ID.ov.json")"
