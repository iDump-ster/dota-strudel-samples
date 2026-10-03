#!/bin/bash
cd "$(dirname "$0")"
BASE="https://raw.githubusercontent.com/iDump-ster/dota-strudel-samples/main/samples/"
out="{\n  \"_base\": \"$BASE\""
emit() {
  files=$(cd samples && find "$2" -type f \( -iname '*.wav' -o -iname '*.mp3' -o -iname '*.ogg' -o -iname '*.flac' \) | sort)
  [ -z "$files" ] && return
  list=$(echo "$files" | sed 's/.*/"&"/' | paste -sd, -)
  out+=",\n  \"$1\": [$list]"
}
# auto: one bank per hero folder
for d in samples/hero/*/; do
  [ -d "$d" ] || continue
  n=$(basename "$d"); emit "dota_$n" "hero/$n"
done
# auto: every other top-level folder is one bank, skipping _pool etc.
for d in samples/*/; do
  n=$(basename "$d")
  case "$n" in hero|dota|_*) continue;; esac
  emit "dota_$n" "$n"
done
# custom: hand-picked banks from custom.txt
if [ -f custom.txt ]; then
  rows=$(tr -d '\r' < custom.txt | grep -v '^[[:space:]]*#' | awk 'NF>=2')
  echo "$rows" | awk '{print $2}' | while read -r p; do
    [ -f "samples/$p" ] || echo "MISSING: samples/$p" >&2
  done
  for bank in $(echo "$rows" | awk '{print $1}' | sort -u); do
    list=$(echo "$rows" | awk -v b="$bank" '$1==b{print $2}' | sed 's/.*/"&"/' | paste -sd, -)
    out+=",\n  \"dota_$bank\": [$list]"
  done
fi
out+="\n}\n"
printf '%b' "$out" > strudel.json
