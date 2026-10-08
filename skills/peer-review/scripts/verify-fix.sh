#!/usr/bin/env bash
# verify-fix.sh — test a candidate fix without leaving the repo changed.
#
# Runs the given forge test suites on the current code, swaps in the patched files, runs them again,
# restores the originals (also on error or Ctrl-C), and prints every test whose result changed. Finally
# checks that the patched paths match their originals again.
#
# Usage: verify-fix.sh --patch <repo/File.sol>=<patched/File.sol> [--patch ...] --suite '<glob>' [--suite ...]
#   --patch  a repo file and the patched copy to swap in for the "after" run (repeatable)
#   --suite  a forge --match-path glob (repeatable), e.g. 'test/pocs/Issue12*.t.sol' 'test/unit/**'
# Env: FORGE_ARGS  extra arguments for forge test (e.g. "--no-match-path 'test/fork/**'")
# Run from the repository root.
set -euo pipefail

patches=(); suites=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --patch) patches+=("$2"); shift 2 ;;
    --suite) suites+=("$2"); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ ${#patches[@]} -gt 0 && ${#suites[@]} -gt 0 ]] || { echo "need at least one --patch and one --suite" >&2; exit 2; }

work="$(mktemp -d)"
restore() {
  for p in "${patches[@]}"; do
    target="${p%%=*}"
    [[ -f "$work/orig/$target" ]] && cp "$work/orig/$target" "$target"
  done
}
trap restore EXIT INT TERM

for p in "${patches[@]}"; do
  target="${p%%=*}"; patched="${p#*=}"
  [[ -f "$target" && -f "$patched" ]] || { echo "missing file in --patch $p" >&2; exit 2; }
  mkdir -p "$work/orig/$(dirname "$target")"
  cp "$target" "$work/orig/$target"
done

results() {
  for s in "${suites[@]}"; do
    # shellcheck disable=SC2086
    forge test --match-path "$s" ${FORGE_ARGS:-} 2>&1 \
      | grep -E '^\[(PASS|FAIL)' | sed -E 's/ \(gas: [0-9]+\)//; s/ \(runs: .*\)$//' || true
  done | sort -u
}

echo ">>> running suites on the original code"
results > "$work/before.txt"
for p in "${patches[@]}"; do cp "${p#*=}" "${p%%=*}"; done
echo ">>> running suites with the patch applied"
results > "$work/after.txt"
restore
trap - EXIT INT TERM

echo
echo "tests: before=$(wc -l < "$work/before.txt" | tr -d ' ')  after=$(wc -l < "$work/after.txt" | tr -d ' ')"
echo "=== results that changed (< original, > patched)"
diff "$work/before.txt" "$work/after.txt" || true

echo
echo "=== restore check"
ok=1
for p in "${patches[@]}"; do
  target="${p%%=*}"
  if cmp -s "$target" "$work/orig/$target"; then echo "restored: $target"; else echo "NOT RESTORED: $target"; ok=0; fi
done
[[ $ok -eq 1 ]] || exit 1
