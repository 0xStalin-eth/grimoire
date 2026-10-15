#!/usr/bin/env bash
# isolated-workspace.sh — a private copy of the workspace for patching and testing, proven byte-for-byte identical.
#
# Everything stays INSIDE the git workspace this runs from: the copy lives in <workspace>/.isolated/<name>/, which a
# `.gitignore` of `*` keeps out of `git status` and out of other sessions' copies. Nothing is written above the
# workspace root (no system temp dir, no `git worktree` metadata in a shared git dir); git is only read.
#
# The copy holds every tracked and untracked, non-ignored file of the workspace; dependency folders (lib,
# node_modules) are symlinks to the workspace's own. After every create and sync, `verify` compares the two byte for
# byte (sha256 of every file, plus the symlink targets) and exits 1 on any difference.
#
# Uncommitted edits to TRACKED files in the workspace may be your own intended changes or another session's
# temporary patch. The script never guesses: create/sync refuse and list them. Pass --with-modified only after
# confirming they are code you want to test against.
#
# Usage (run from inside the workspace):
#   isolated-workspace.sh create <name> [--with-modified] [--ref <commit>] [--link <path>]...
#   isolated-workspace.sh sync   <name>     # mirror the workspace again (DISCARDS edits made in the copy), verify
#   isolated-workspace.sh verify <name> [--except <path>]...
#   isolated-workspace.sh path   <name>     # print the copy's absolute path
#   isolated-workspace.sh remove <name>
#
#   --with-modified  accept uncommitted edits to tracked files and copy them as they are
#   --ref            build the copy from another commit (mitigation reviews); the comparison is skipped and says so
#   --link           folder to symlink to the workspace's own (default: lib and node_modules, when present)
#   --except         path to leave out of the comparison (e.g. a file you patched on purpose)
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
exec python3 -I - "$root" "$@" <<'PY'
import hashlib, os, shutil, subprocess, sys, json

root, args = os.path.realpath(sys.argv[1]), sys.argv[2:]
if len(args) < 2:
    sys.exit("usage: isolated-workspace.sh create|sync|verify|path|remove <name> [options]")
cmd, name, rest = args[0], args[1], args[2:]
if not name or "/" in name or name.startswith(".") or name == "work":
    sys.exit(f"invalid name {name!r}: use a plain folder name, e.g. i68 ('work' is reserved for patched copies)")
base = os.path.join(root, ".isolated")
iso = os.path.join(base, name)
STATE = ".isolated-state.json"

def inside(path):
    p = os.path.realpath(path)
    return p == root or p.startswith(root + os.sep)
assert inside(iso) and os.path.realpath(iso) != root, "the copy must live inside the workspace"

opts = {"links": [], "excepts": [], "with_modified": False, "ref": "HEAD"}
i = 0
while i < len(rest):
    a = rest[i]
    if a == "--with-modified": opts["with_modified"] = True; i += 1
    elif a in ("--ref", "--link", "--except") and i + 1 < len(rest):
        if a == "--ref": opts["ref"] = rest[i + 1]
        elif a == "--link": opts["links"].append(rest[i + 1].strip("/"))
        else: opts["excepts"].append(rest[i + 1].strip("/"))
        i += 2
    else: sys.exit(f"unknown argument: {a}")

def git(*a, inp=None):
    return subprocess.run(["git", "-C", root, *a], input=inp, capture_output=True, check=True).stdout

def under(p, prefixes):
    return any(p == x or p.startswith(x + "/") for x in prefixes)

def load_state():
    with open(os.path.join(iso, STATE)) as f:
        return json.load(f)

def workspace_files(links):
    out = git("ls-files", "-z", "--cached", "--others", "--exclude-standard")
    return sorted({p.decode() for p in out.split(b"\0") if p and not under(p.decode(), links + [".isolated"])})

def copy_files(files):
    for p in files:
        src, dst = os.path.join(root, p), os.path.join(iso, p)
        if os.path.isdir(src) and not os.path.islink(src):
            continue                      # submodule outside the linked folders; reported by verify
        if not os.path.lexists(src):
            continue                      # deleted in the workspace
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.lexists(dst) or os.path.islink(dst):
            os.remove(dst)
        shutil.copy2(src, dst, follow_symlinks=False)

def modified():
    return [l for l in git("status", "--porcelain", "--untracked-files=no").decode().splitlines()
            if not under(l[3:].strip(), [".isolated"])]

def iso_files(links, excepts):
    found = []
    for d, dirs, files in os.walk(iso):
        rel_d = os.path.relpath(d, iso)
        rel_d = "" if rel_d == "." else rel_d + "/"
        dirs[:] = [x for x in dirs if not os.path.islink(os.path.join(d, x))]
        found += [rel_d + f for f in files]
        found += [rel_d + x for x in os.listdir(d) if os.path.islink(os.path.join(d, x)) and os.path.isdir(os.path.join(d, x))]
    found = [p for p in found if p != STATE and not under(p, links)]
    if found:   # drop what the workspace's ignore rules ignore (build output, caches)
        ign = subprocess.run(["git", "-C", root, "check-ignore", "--no-index", "-z", "--stdin"],
                             input="\0".join(found).encode() + b"\0", capture_output=True).stdout
        ignored = {p.decode() for p in ign.split(b"\0") if p}
        found = [p for p in found if p not in ignored]
    return set(found)

def digest(path):
    if os.path.islink(path):
        return "link:" + os.readlink(path)
    if os.path.isdir(path):
        return "dir"
    if not os.path.exists(path):
        return None
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def verify(links, excepts):
    problems, submodules, compared = [], [], 0
    for p in sorted(set(workspace_files(links)) | iso_files(links, excepts)):
        if under(p, excepts):
            continue
        a, b = digest(os.path.join(root, p)), digest(os.path.join(iso, p))
        if a == "dir" or b == "dir":
            submodules.append(p); continue
        compared += 1
        if a != b:
            why = "missing in the copy" if b is None else "missing in the workspace" if a is None else "content differs"
            problems.append(f"  {why}: {p}")
    for l in links:
        w = os.path.join(iso, l)
        if not (os.path.islink(w) and os.path.realpath(w) == os.path.realpath(os.path.join(root, l))):
            problems.append(f"  not linked to the workspace folder: {l}")
    print(f"compared {compared} files byte for byte; linked: {', '.join(links) or 'none'}"
          + (f"; excluded: {', '.join(excepts)}" if excepts else ""))
    for s in submodules:
        print(f"  NOT compared (submodule outside the linked folders): {s}")
    if problems:
        print("DIFFERENT from the workspace:\n" + "\n".join(problems))
        return False
    print("IDENTICAL to the workspace")
    return True

def refuse_if_modified(with_modified):
    mods = modified()
    if mods and not with_modified:
        print("REFUSED: tracked files have uncommitted changes in the workspace:", file=sys.stderr)
        print("\n".join("  " + m for m in mods), file=sys.stderr)
        print("If they are code you want to test against, re-run with --with-modified.\n"
              "If they are another session's temporary patch, wait until the workspace is back at HEAD.", file=sys.stderr)
        sys.exit(1)

def ensure_base():
    os.makedirs(base, exist_ok=True)
    gi = os.path.join(base, ".gitignore")
    if not os.path.exists(gi):
        with open(gi, "w") as f:
            f.write("*\n")

def make_links(links):
    for l in links:
        dst = os.path.join(iso, l)
        if os.path.islink(dst) or os.path.isfile(dst): os.remove(dst)
        elif os.path.isdir(dst): shutil.rmtree(dst)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        os.symlink(os.path.join(root, l), dst)

if cmd == "create":
    if os.path.lexists(iso):
        sys.exit(f"{iso} already exists; remove it first or use sync")
    links = opts["links"] or [d for d in ("lib", "node_modules") if os.path.exists(os.path.join(root, d))]
    head = git("rev-parse", "HEAD").decode().strip()
    ref = git("rev-parse", opts["ref"] + "^{commit}").decode().strip()
    ensure_base()
    if ref != head:
        os.makedirs(iso)
        tar = subprocess.run(["git", "-C", root, "archive", "--format=tar", ref], capture_output=True, check=True).stdout
        subprocess.run(["tar", "-x", "-C", iso], input=tar, check=True)
        others = git("ls-files", "-z", "--others", "--exclude-standard")
        copy_files([p.decode() for p in others.split(b"\0") if p and not under(p.decode(), links + [".isolated"])])
    else:
        refuse_if_modified(opts["with_modified"])
        os.makedirs(iso)
        copy_files(workspace_files(links))
    make_links(links)
    with open(os.path.join(iso, STATE), "w") as f:
        json.dump({"links": links, "with_modified": opts["with_modified"], "ref": ref}, f)
    print(f"isolated copy at {iso} ({ref[:7]}); linked: {', '.join(links) or 'none'}")
    if ref != head:
        print(f"NOT compared: --ref {opts['ref']} is not the workspace's HEAD, so the code differs on purpose")
    elif not verify(links, []):
        shutil.rmtree(iso)
        sys.exit("removed the copy because it does not match the workspace")
    print("first build compiles from scratch, so expect it to be slower")

elif cmd == "sync":
    st = load_state()
    links = st["links"]
    head = git("rev-parse", "HEAD").decode().strip()
    if st["ref"] != head:
        others = git("ls-files", "-z", "--others", "--exclude-standard")
        copy_files([p.decode() for p in others.split(b"\0") if p and not under(p.decode(), links + [".isolated"])])
        print(f"synced untracked files; NOT compared (copy built from {st['ref'][:7]}, workspace HEAD is {head[:7]})")
        sys.exit(0)
    refuse_if_modified(st["with_modified"])
    want = workspace_files(links)
    for p in sorted(iso_files(links, []) - set(want)):
        os.remove(os.path.join(iso, p))
    copy_files(want)
    make_links(links)
    print(f"synced {iso}")
    sys.exit(0 if verify(links, []) else 1)

elif cmd == "verify":
    links = load_state()["links"] if os.path.exists(os.path.join(iso, STATE)) else \
        [d for d in ("lib", "node_modules") if os.path.exists(os.path.join(root, d))]
    sys.exit(0 if verify(links, opts["excepts"]) else 1)

elif cmd == "path":
    print(iso)

elif cmd == "remove":
    if os.path.lexists(iso):
        shutil.rmtree(iso)
    print(f"removed {iso}")

else:
    sys.exit(f"unknown command: {cmd}")
PY
