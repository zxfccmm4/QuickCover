#!/bin/bash
# Capture pages with the contract recipe (FIXTURES.md §5), several pages in ONE browser session.
# usage: shoot.sh <session> <WxH:page> [<WxH:page> ...]
#   page  = /tmp/redactprobe/photo/pages/<page>.html  (built by page.py)
#   WxH   = output pixel size of that page (= size of #shot after the x3 scale)
# writes /tmp/redactprobe/photo/out/<page>.png and <page>.gt.json
# Only ever use your own session name (here: photo).
set -u
S=$1; shift
B=/tmp/redactprobe/photo
BASE=$(grep -o 'https://[a-z-]*\.trycloudflare\.com' /run/airbuild/team/state/background-services/output/894E9102-70AB-41B0-A4BF-0821C0D5CFB1.log | tail -1)
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$BASE/t2.html")
[ "$code" = 200 ] || { echo "tunnel down ($code) $BASE" >&2; exit 2; }
browser start --session "$S" >&2 || exit 3
trap 'browser stop --session "$S" >/dev/null 2>&1' EXIT
for spec in "$@"; do
  size=${spec%%:*}; name=${spec##*:}; W=${size%x*}; H=${size#*x}
  browser set viewport "$W" "$H" --session "$S" >&2
  browser open "$BASE/photo/pages/$name.html" --session "$S" >&2
  browser wait --load-state networkidle --timeout 8000 --session "$S" >&2
  browser screenshot --selector '#shot' -o "$B/out/$name.png" --session "$S" >&2
  browser eval "JSON.stringify(window.__gt())" --session "$S" > "$B/out/$name.gt.raw" 2>/dev/null
  # the CLI may print the JSON string quoted: unwrap it
  python3 - "$B/out/$name" <<'EOF'
import json, sys, os
p = sys.argv[1]
raw = open(p + '.gt.raw').read().strip() if os.path.exists(p + '.gt.raw') else ''
try:
    v = json.loads(raw)
    if isinstance(v, str):
        v = json.loads(v)
    if isinstance(v, dict) and 'text' in v:
        json.dump(v, open(p + '.gt.json', 'w'), ensure_ascii=False, indent=1)
    else:
        open(p + '.gt.json', 'w').write(raw)
except Exception as e:
    open(p + '.gt.json', 'w').write(raw)
EOF
  rm -f "$B/out/$name.gt.raw"
  echo "$name: $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$B/out/$name.png" 2>/dev/null | tr ',' 'x')"
done
