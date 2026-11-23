#!/bin/bash
# Generate photos with imagegen: gen.sh <name> [<name>...] -> /tmp/redactprobe/photo/src/<name>.png
# The prompt for <name> is the line "<name>|<prompt>" in prompts.txt ($P is expanded from the P= line).
D=$(dirname "$0")
O=/tmp/redactprobe/photo/src
mkdir -p "$O"
P=$(grep '^P=' "$D/prompts.txt"); P=${P#P=}
for n in "$@"; do
  line=$(grep "^$n|" "$D/prompts.txt")
  [ -n "$line" ] || { echo "no prompt for $n"; continue; }
  prompt=${line#*|}
  prompt=${prompt//"\$P"/$P}
  if imagegen --size 1536x1024 --format png --output "$O/$n.png" "$prompt" >"$O/$n.log" 2>&1; then
    echo "$n ok $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$O/$n.png")"
  else
    echo "$n FAILED: $(tail -1 "$O/$n.log")"
  fi
done
