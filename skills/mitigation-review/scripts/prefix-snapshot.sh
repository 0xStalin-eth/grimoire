#!/usr/bin/env bash
# prefix-snapshot.sh — copy a contract as it was BEFORE a fix, renamed and with imports
# re-pointed, so a PoC can swap it in with `deployCodeTo` and reproduce the original bug.
#
# Usage: prefix-snapshot.sh <src-file> <fix-commit> <out-dir>
#   e.g. prefix-snapshot.sh src/Router.sol a1b2c3d test/mitigation
#
# Produces <out-dir>/<Name>PreFix.sol where contract <Name> is renamed <Name>PreFix and every
# relative import is rewritten relative to <out-dir>. The PoC must IMPORT this file so the
# artifact exists for `deployCodeTo("<Name>PreFix.sol:<Name>PreFix", args, address(target))`.
#
# Caveat: only valid when the pre-fix contract keeps the same storage layout and constructor as the
# deployed one (immutables are re-created from the constructor args). Diff it before relying on it.
set -euo pipefail

src="${1:?usage: prefix-snapshot.sh <src-file> <fix-commit> <out-dir>}"
commit="${2:?}"
out="${3:?}"

# Writes only inside the git workspace this runs from: refuse a destination above its root.
inside_workspace() {
  python3 -I -c 'import os, sys; r = os.path.realpath(sys.argv[1]); p = os.path.realpath(sys.argv[2]); sys.exit(0 if p == r or p.startswith(r + os.sep) else 1)' \
    "$(git rev-parse --show-toplevel)" "$1"
}
inside_workspace "$out" || { echo "refusing to write outside the workspace: $out" >&2; exit 2; }

name="$(basename "$src" .sol)"
dest="$out/${name}PreFix.sol"
mkdir -p "$out"

git show "$commit^:$src" > "$dest.tmp"

python3 -I - "$dest.tmp" "$dest" "$src" "$out" "$name" <<'PY'
import os, re, sys
tmp, dest, src, out, name = sys.argv[1:]
code = open(tmp).read()
src_dir = os.path.dirname(src)

def fix(m):
    path = m.group(2)
    if not path.startswith("."):
        return m.group(0)  # remapped import (lib/, @openzeppelin/...), leave it
    target = os.path.normpath(os.path.join(src_dir, path))
    rel = os.path.relpath(target, out)
    if not rel.startswith("."):
        rel = "./" + rel
    return f'{m.group(1)}"{rel}"'

code = re.sub(r'(import\s+(?:[^"\']*?\s+from\s+)?)"([^"]+)"', fix, code)
code = re.sub(rf'\b(contract|abstract contract)\s+{name}\b', rf'\1 {name}PreFix', code, count=1)
open(dest, "w").write(code)
os.remove(tmp)
PY

echo "wrote $dest (contract ${name}PreFix, from $commit^)"
echo "diff vs head:"
git diff --no-index --stat "$src" "$dest" || true
