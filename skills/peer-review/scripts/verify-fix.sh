#!/usr/bin/env bash
# verify-fix.sh — test a candidate fix without touching the shared checkout.
#
# The comparison always runs in a private git worktree (scripts/isolated-worktree.sh): HEAD plus the repo's
# untracked files, so other sessions' temporary patches in the shared checkout neither leak into the "before" run
# nor get overwritten by this one. The suites run on the original code, the patched files are copied in, the suites
# run again, and every test whose result changed is printed, keyed by suite. The worktree is removed at the end.
#
# Usage: verify-fix.sh --patch <repo/File.sol>=<patched/File.sol> [--patch ...] --suite '<glob>' [--suite ...]
#                      [--worktree <dir>] [--keep]
#   --patch     a repo file and the patched copy to swap in for the "after" run (repeatable)
#   --suite     a forge --match-path glob (repeatable), e.g. 'test/pocs/Issue12*.t.sol' 'test/unit/**'
#   --worktree  where to create the private worktree (default: a temp dir); reuse saves a rebuild
#   --keep      keep the worktree for reuse (remove it later with isolated-worktree.sh remove)
# Env: FORGE_ARGS  extra arguments for forge test (e.g. "--no-match-path 'test/fork/**'")
# Run from the repository root.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
patches=(); suites=(); wt=""; keep=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --patch) patches+=("$2"); shift 2 ;;
    --suite) suites+=("$2"); shift 2 ;;
    --worktree) wt="$2"; shift 2 ;;
    --keep) keep=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ ${#patches[@]} -gt 0 && ${#suites[@]} -gt 0 ]] || { echo "need at least one --patch and one --suite" >&2; exit 2; }

root="$(git rev-parse --show-toplevel)"
work="$(mktemp -d)"
for p in "${patches[@]}"; do
  target="${p%%=*}"; patched="${p#*=}"
  [[ -f "$root/$target" && -f "$patched" ]] || { echo "missing file in --patch $p" >&2; exit 2; }
  patched_abs="$(cd "$(dirname "$patched")" && pwd)/$(basename "$patched")"
  echo "$target=$patched_abs" >> "$work/patches"
done

run_dir="${wt:-$work/wt}"
if [[ -d "$run_dir" ]]; then
  bash "$here/isolated-worktree.sh" sync "$run_dir"
else
  bash "$here/isolated-worktree.sh" create "$run_dir"
fi

restore() {
  while IFS='=' read -r target _; do
    git -C "$run_dir" checkout -q HEAD -- "$target" 2>/dev/null || true
  done < "$work/patches"
  if [[ $keep -eq 0 ]]; then
    bash "$here/isolated-worktree.sh" remove "$run_dir" >/dev/null 2>&1 || true
  fi
}
trap restore EXIT INT TERM

results() {
  local out="$1" i=0
  for s in "${suites[@]}"; do
    i=$((i + 1))
    # shellcheck disable=SC2086
    (cd "$run_dir" && forge test --match-path "$s" --json ${FORGE_ARGS:-} 2>/dev/null) > "$out.$i.json" || true
  done
  python3 -I - "$out".*.json <<'PY' | sort -u > "$out"
import json, sys
for f in sys.argv[1:]:
    try:
        data = json.load(open(f))
    except Exception:
        print(f"COMPILE-OR-RUN-ERROR {f}")
        continue
    for suite, v in data.items():
        for test, r in v.get("test_results", {}).items():
            reason = (r.get("reason") or "").replace("\n", " ")[:120]
            print(f"{suite} {test} {r['status']} {reason}".rstrip())
PY
}

echo ">>> running suites on the original code (in $run_dir)"
results "$work/before"
while IFS='=' read -r target patched; do cp "$patched" "$run_dir/$target"; done < "$work/patches"
echo ">>> running suites with the patch applied"
results "$work/after"

echo
echo "tests: before=$(wc -l < "$work/before" | tr -d ' ')  after=$(wc -l < "$work/after" | tr -d ' ')"
echo "failing before: $(grep -c ' Failure' "$work/before" || true)"
echo "=== results that changed (< original, > patched)"
diff "$work/before" "$work/after" || true
grep -h 'COMPILE-OR-RUN-ERROR' "$work/before" "$work/after" && echo "(a suite produced no results; check it compiles)" || true

restore
trap - EXIT INT TERM
echo
echo "=== restore check"
ok=1
while IFS='=' read -r target _; do
  if [[ $keep -eq 1 ]]; then
    if git -C "$run_dir" diff --quiet HEAD -- "$target"; then echo "restored: $target"; else echo "NOT RESTORED: $target"; ok=0; fi
  fi
  if git -C "$root" diff --quiet HEAD -- "$target"; then echo "shared checkout untouched: $target";
  else echo "shared checkout differs from HEAD: $target (not by this run; another session's change, leave it)"; fi
done < "$work/patches"
[[ $ok -eq 1 ]] || exit 1
