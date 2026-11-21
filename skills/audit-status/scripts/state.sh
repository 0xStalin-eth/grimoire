#!/usr/bin/env bash
# state.sh — Deterministic snapshot of a Grimoire workspace for /audit-status (steps 1-2).
# Reads only. Prints:
#   1. counts per folder (hypotheses, findings, informationals, sigil findings, delve boards)
#   2. the latest SESSIONS.md row per hypothesis, grouped by status
#   3. reconciliation flags:
#        DRIFT      row status disagrees with the folder the file is in
#        ORPHAN     file has no SESSIONS.md row
#        GHOST      row names a file that exists in no hypotheses/ folder
#        DUP        the same file appears in more than one row
#        STALE      WIP row not updated for more than STALE_DAYS days
#        VERDICT    WIP row whose note says a verdict is pending / familiar ran (needs the user)
# Usage: state.sh [grimoire-dir] (default: ./grimoire). STALE_DAYS env var, default 3.

set -uo pipefail

g="${1:-grimoire}"
stale_days="${STALE_DAYS:-3}"
[ -d "$g/hypotheses" ] || { echo "no $g/hypotheses — run /summon first" >&2; exit 1; }
log="$g/hypotheses/SESSIONS.md"

count() { [ -d "$1" ] && find "$1" -maxdepth 1 -type f -name '*.md' ! -name 'SESSIONS.md' ! -name 'README.md' | wc -l | tr -d ' ' || echo 0; }

echo "## Counts"
for d in hypotheses/WIP hypotheses/valid hypotheses/invalid findings/WIP findings/WIP/informationals \
         findings/valid findings/invalid findings/archived sigil-findings; do
  printf '%-32s %s\n' "$d" "$(count "$g/$d")"
done
boards=$(find "$g/delves" -name 'board*.md' 2>/dev/null | wc -l | tr -d ' ')
printf '%-32s %s\n' "delve boards" "$boards"
echo

[ -f "$log" ] || { echo "no $log — skipping session reconciliation"; exit 0; }

now=$(date +%s)
to_epoch() { date -j -f '%Y-%m-%d %H:%M' "$1" +%s 2>/dev/null || date -d "$1" +%s 2>/dev/null || echo 0; }

# rows: file|status|session|updated|note  (header and divider skipped)
rows=$(awk -F'|' 'NR>2 && NF>5 { for(i=2;i<=6;i++){gsub(/^ +| +$/,"",$i)}; print $2"|"$3"|"$4"|"$5"|"$6 }' "$log")

echo "## Hypotheses by status (latest row)"
for s in WIP valid invalid; do
  echo "### $s"
  echo "$rows" | awk -F'|' -v s="$s" '$2==s { printf "- %s  [%s, %s]  %s\n", $1, substr($3,1,8), $4, substr($5,1,160) }'
done
echo

echo "## Flags"
# DUP
echo "$rows" | cut -d'|' -f1 | sort | uniq -d | sed 's/^/DUP      /'
# DRIFT + GHOST + STALE + VERDICT
echo "$rows" | while IFS='|' read -r file status sid updated note; do
  [ -n "$file" ] || continue
  where=""
  for s in WIP valid invalid; do [ -f "$g/hypotheses/$s/$file" ] && where="$s"; done
  if [ -z "$where" ]; then echo "GHOST    $file (row says $status, file not found)"
  elif [ "$where" != "$status" ]; then echo "DRIFT    $file (row says $status, file is in $where/)"; fi
  if [ "$status" = "WIP" ]; then
    t=$(to_epoch "$updated"); age=$(( (now - t) / 86400 ))
    [ "$t" -gt 0 ] && [ "$age" -gt "$stale_days" ] && echo "STALE    $file (${age}d since $updated, session ${sid:0:8})"
    echo "$note" | grep -qiE 'verdict pending|pending user|familiar|ready for|awaiting' \
      && echo "VERDICT  $file (${note:0:120})"
  fi
done
# ORPHAN
for s in WIP valid invalid; do
  for f in "$g/hypotheses/$s"/*.md; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    echo "$rows" | cut -d'|' -f1 | grep -qxF "$b" || echo "ORPHAN   $s/$b"
  done
done
exit 0
