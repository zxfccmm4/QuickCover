#!/bin/bash
# run_all.sh — regenerate and re-capture every chatweb fixture (FIXTURES.md §5), then build the final files.
#
#   ./run_all.sh              all 13 fixtures (about 9 minutes: one browser session per fixture)
#   ./run_all.sh chat_03_id   only the listed ids (also runs make.js for them)
#
# Needs: node, ffmpeg/ffprobe, the static server on 127.0.0.1:8765 serving /tmp/redactprobe, the tunnel
# (FIXTURES.md §1) and the `browser` CLI. Writes the served pages to /tmp/redactprobe/chatweb and the final
# files to QuickCoverTests/Fixtures. Check images land in /tmp/redactprobe/chatweb/check/ (delete after looking).
set -u
D=$(cd "$(dirname "$0")" && pwd)
B=/tmp/redactprobe/chatweb
FIX=/projects/2ac5bd59-8729-421b-a7f8-43ca37aea5c4/QuickCoverTests/Fixtures
SIZES="chat_01_order:1170:2532 chat_02_group:1170:2532 chat_03_id:1170:2532 chat_04_compressed:1170:2532
chat_05_small:1170:2532 chat_06_dark:1170:2532 chat_07_qr:1170:2532 chat_08_long:1170:4800
web_01_log:1170:2532 web_02_invoice:1170:3948 web_03_contact:1170:2532 web_04_article:1170:3562 web_05_lowres:1170:2532"
mkdir -p "$B" "$FIX"
node "$D/gen.js" "$B" || exit 1
ids=""
for spec in $SIZES; do
  id=${spec%%:*}; rest=${spec#*:}; W=${rest%%:*}; H=${rest#*:}
  if [ $# -eq 0 ] || [[ " $* " == *" $id "* ]]; then
    "$D/capture.sh" "$id" "$W" "$H" || exit 1
    ids="$ids $id"
  fi
done
[ -n "$ids" ] || { echo "no such id"; exit 1; }
node "$D/make.js" $ids
