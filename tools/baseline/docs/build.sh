#!/bin/sh
# Regenerate all five doc_* fixtures end to end:
#   node gen.js      -> /tmp/redactprobe/docs/<id>.html (+ portrait.jpg)
#   ./capture.sh     -> cloud-browser screenshots + collector output (one session per fixture)
#   node check.js    -> §7 self-check, writes QuickCoverTests/Fixtures/<id>.json + <id>.png,
#                       box-check images in /tmp/redactprobe/docs/work/<id>.check.png
set -e
cd "$(dirname "$0")"
node gen.js
./capture.sh
node check.js
