#!/bin/bash
cd "$(dirname "$0")"
out='{\n  "_base": "https://raw.githubusercontent.com/iDump-ster/dota-strudel-samples/main/samples/"'
emit() {
  files=$(cd samples && find "$2" -type f \( -name '*.wav' -o -name '*.mp3' \) 2>/dev/null | sort)
  [ -z "$files" ] && return
  list=$(echo "$files" | sed 's/.*/"&"/' | paste -sd, -)
  out+=",\n  \"$1\": [$list]"
}
for d in samples/hero/*/; do n=$(basename "$d"); emit "dota_$n" "hero/$n"; done
emit dota_vox vox
emit dota_ui ui
emit dota_env env
emit dota_things things
out+='\n}\n'
printf '%b' "$out" > strudel.json
