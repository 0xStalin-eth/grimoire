#!/usr/bin/env bash
# isolated-worktree.sh — a private, throwaway checkout for patching and testing, proven identical to the shared one.
#
# The checkout is a detached `git worktree` at HEAD plus a copy of the repo's untracked, non-ignored files
# (PoCs, helpers, lock files, notes). Dependency folders (lib, node_modules) are symlinks to the shared ones.
# After every create and sync, `verify` compares the two trees byte for byte: every tracked and untracked,
# non-ignored file, plus the symlink targets. If anything differs, create removes the new worktree and fails.
#
# Uncommitted edits to TRACKED files in the shared checkout make the trees differ. They may be your own
# intended changes, or another session's temporary patch. The script never guesses: it stops and lists them.
# Re-run create with --with-modified only after confirming they are code you want to test against.
#
# Usage (run from the shared repo root):
#   isolated-worktree.sh create <dir> [--with-modified] [--ref <commit>] [--link <path>]...
#   isolated-worktree.sh sync   <dir>          # mirror the shared checkout again (DISCARDS edits made in <dir>), verify
#   isolated-worktree.sh verify <dir> [--except <path>]...   # byte-for-byte comparison; exit 1 on any difference
#   isolated-worktree.sh remove <dir>
#
#   --with-modified  also copy tracked files that differ from HEAD in the shared checkout (deleted ones are deleted)
#   --ref            check out another commit (mitigation reviews); the comparison is skipped and says so
#   --link           folder to symlink from the shared repo (default: lib and node_modules, when present)
#   --except         path to leave out of the comparison (e.g. a file you patched on purpose)
#
# Put <dir> in the session scratchpad. Never `git stash` in a shared repo: the stash stack is shared.
set -euo pipefail

cmd="${1:?usage: isolated-worktree.sh create|sync|verify|remove <dir> [options]}"
dir="${2:?missing <dir>}"
shift 2
root="$(git rev-parse --show-toplevel)"
ref="HEAD"; links=(); excepts=(); with_modified=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --link) links+=("$2"); shift 2 ;;
    --except) excepts+=("$2"); shift 2 ;;
    --with-modified) with_modified=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ ${#links[@]} -gt 0 ]] || for d in lib node_modules; do [[ -e "$root/$d" ]] && links+=("$d"); done

state_file() { echo "$(git -C "$dir" rev-parse --absolute-git-dir)/isolated-worktree.state"; }

copy_untracked() {
  (cd "$root" && git ls-files --others --exclude-standard -z) | rsync -a --from0 --files-from=- "$root/" "$dir/"
}

reset_tracked() {
  # put every tracked file that differs from HEAD in the isolated worktree back to HEAD (outside the linked folders)
  (cd "$dir" && git diff --name-only -z HEAD) | while IFS= read -r -d '' f; do
    for l in ${links[@]+"${links[@]}"}; do [[ "$f" == "$l" || "$f" == "$l/"* ]] && continue 2; done
    git -C "$dir" checkout -q HEAD -- "$f"
  done
}

copy_modified() {
  # tracked files that differ from HEAD in the shared checkout: copy changed ones, delete deleted ones
  (cd "$root" && git diff --name-only -z --diff-filter=d HEAD) | rsync -a --from0 --files-from=- "$root/" "$dir/"
  (cd "$root" && git diff --name-only -z --diff-filter=D HEAD) | while IFS= read -r -d '' f; do rm -f "$dir/$f"; done
}

verify() {
  python3 -I - "$root" "$dir" "${links[*]:-}" ${excepts[@]+"${excepts[@]}"} <<'PY'
import hashlib, os, subprocess, sys
root, wt, links, *excepts = sys.argv[1:]
links = [l for l in links.split() if l]
def listing(base):
    out = subprocess.run(["git", "-C", base, "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                         capture_output=True, check=True).stdout
    return {p.decode() for p in out.split(b"\0") if p}
def skip(p):
    return any(p == l or p.startswith(l + "/") for l in links) or any(p == e or p.startswith(e.rstrip("/") + "/") for e in excepts)
def digest(path):
    if os.path.islink(path):
        return "link:" + os.readlink(path)
    if os.path.isdir(path):
        return "dir"          # a submodule outside the linked folders
    if not os.path.exists(path):
        return None
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()
problems, compared, submodules = [], 0, []
for p in sorted(listing(root) | listing(wt)):
    if skip(p):
        continue
    a, b = digest(os.path.join(root, p)), digest(os.path.join(wt, p))
    if a == "dir" or b == "dir":
        submodules.append(p)
        continue
    compared += 1
    if a != b:
        why = "missing in isolated" if b is None else "missing in shared" if a is None else "content differs"
        problems.append(f"  {why}: {p}")
for l in links:
    s, w = os.path.join(root, l), os.path.join(wt, l)
    if not (os.path.islink(w) and os.path.realpath(w) == os.path.realpath(s)):
        problems.append(f"  not linked to the shared folder: {l}")
print(f"compared {compared} files byte for byte; linked: {', '.join(links) or 'none'}"
      + (f"; excluded: {', '.join(excepts)}" if excepts else ""))
for s in submodules:
    print(f"  NOT compared (submodule outside the linked folders): {s}")
if problems:
    print("DIFFERENT from the shared checkout:")
    print("\n".join(problems))
    sys.exit(1)
print("IDENTICAL to the shared checkout")
PY
}

case "$cmd" in
  create)
    [[ -e "$dir" ]] && { echo "$dir already exists; remove it first or use sync" >&2; exit 1; }
    git -C "$root" worktree add --detach "$dir" "$ref" >/dev/null
    for l in ${links[@]+"${links[@]}"}; do
      rm -rf "${dir:?}/$l"
      ln -s "$root/$l" "$dir/$l"
    done
    printf 'links=%q\nwith_modified=%q\nref=%q\n' "${links[*]:-}" "$with_modified" "$ref" > "$(state_file)"
    copy_untracked
    [[ $with_modified -eq 1 ]] && copy_modified
    echo "isolated worktree at $dir ($(git -C "$dir" rev-parse --short HEAD)); linked: ${links[*]:-none}"
    if [[ "$(git -C "$dir" rev-parse HEAD)" != "$(git -C "$root" rev-parse HEAD)" ]]; then
      echo "NOT compared: --ref $ref is not the shared checkout's HEAD, so the code differs on purpose"
    elif ! verify; then
      git -C "$root" worktree remove --force "$dir"; git -C "$root" worktree prune
      echo "removed the isolated worktree. Tracked files modified in the shared checkout:" >&2
      git -C "$root" status --short --untracked-files=no >&2
      echo "If these are code you want to test against, re-run create with --with-modified." >&2
      echo "If they are another session's temporary patch, wait until the shared checkout is back at HEAD." >&2
      exit 1
    fi
    echo "first build compiles from scratch, so expect it to be slower"
    ;;
  sync)
    # shellcheck disable=SC1090
    source "$(state_file)"; read -r -a links <<< "${links:-}"
    reset_tracked
    copy_untracked
    [[ "${with_modified:-0}" -eq 1 ]] && copy_modified
    echo "synced into $dir"
    if [[ "$(git -C "$dir" rev-parse HEAD)" == "$(git -C "$root" rev-parse HEAD)" ]]; then verify; fi
    ;;
  verify)
    if [[ -f "$(state_file)" ]]; then
      # shellcheck disable=SC1090
      source "$(state_file)"; read -r -a links <<< "${links:-}"
    fi
    verify
    ;;
  remove)
    git -C "$root" worktree remove --force "$dir"
    git -C "$root" worktree prune
    echo "removed $dir"
    ;;
  *) echo "unknown command: $cmd" >&2; exit 2 ;;
esac
