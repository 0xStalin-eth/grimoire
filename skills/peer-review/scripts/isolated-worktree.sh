#!/usr/bin/env bash
# isolated-worktree.sh — a private, throwaway checkout for patching and testing while other sessions share the repo.
#
# The checkout is a detached `git worktree` at a commit (HEAD by default) plus the repo's UNTRACKED,
# non-ignored files (PoCs, helpers, lock files). Uncommitted edits to tracked files in the shared checkout
# are deliberately NOT copied: they are usually another session's temporary patch. Heavy dependency folders
# are symlinked, not copied.
#
# Usage (run from the shared repo root):
#   isolated-worktree.sh create <dir> [--ref <commit>] [--link <path>]... [--untracked <pathspec>]...
#   isolated-worktree.sh sync   <dir> [--untracked <pathspec>]...   # re-copy untracked files (new/edited PoCs)
#   isolated-worktree.sh remove <dir>
#
#   --ref        commit to check out (default HEAD)
#   --link       folder to symlink from the shared repo (default: lib and node_modules, when present)
#   --untracked  pathspec whose untracked files are copied (default: the whole repo except grimoire/)
#
# Put <dir> in the session scratchpad. Never `git stash` in a shared repo: the stash stack is shared.
set -euo pipefail

cmd="${1:?usage: isolated-worktree.sh create|sync|remove <dir> [options]}"
dir="${2:?missing <dir>}"
shift 2
root="$(git rev-parse --show-toplevel)"
ref="HEAD"; links=(); specs=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --link) links+=("$2"); shift 2 ;;
    --untracked) specs+=("$2"); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ ${#links[@]} -gt 0 ]] || for d in lib node_modules; do [[ -e "$root/$d" ]] && links+=("$d"); done
[[ ${#specs[@]} -gt 0 ]] || specs=("." ":(exclude)grimoire")

copy_untracked() {
  (cd "$root" && git ls-files --others --exclude-standard -z -- "${specs[@]}") \
    | rsync -a --from0 --files-from=- "$root/" "$dir/"
}

case "$cmd" in
  create)
    [[ -e "$dir" ]] && { echo "$dir already exists; remove it first or use sync" >&2; exit 1; }
    git -C "$root" worktree add --detach "$dir" "$ref" >/dev/null
    for l in ${links[@]+"${links[@]}"}; do
      rm -rf "${dir:?}/$l"
      ln -s "$root/$l" "$dir/$l"
    done
    copy_untracked
    echo "isolated worktree at $dir ($(git -C "$dir" rev-parse --short HEAD)); linked: ${links[*]:-none}"
    echo "first build compiles from scratch, so expect it to be slower"
    ;;
  sync)
    copy_untracked
    echo "synced untracked files into $dir"
    ;;
  remove)
    git -C "$root" worktree remove --force "$dir"
    git -C "$root" worktree prune
    echo "removed $dir"
    ;;
  *) echo "unknown command: $cmd" >&2; exit 2 ;;
esac
