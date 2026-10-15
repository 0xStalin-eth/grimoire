# Parallel Sessions on One Repo

Several sessions often review findings side by side in the same checkout: one per issue, each
reproducing, probing and verifying fixes. A file one session swaps in for a fix run is live for every
other session's `forge test` in that window. A run that overlaps someone else's swap measures their
patch, not the original code, and a restore can wipe out their patch or put back a stale file.

## Rules

1. **The shared checkout is read-mostly.** Write only new, untracked files there: your PoCs, probes,
   write-ups. Never swap or edit tracked source files in it while another session may be running.
2. **Patch and verify in your own worktree.** `verify-fix.sh` does this by default. For manual patch
   probes, create one with `scripts/isolated-worktree.sh create <scratch>/<id>/wt`, work there, and
   remove it when done. It is HEAD plus the untracked files, so the baseline is the real code and your
   PoCs are present.
3. **Take write-up output from a clean run.** PoC output embedded in a write-up must come from a
   run on unmodified code: the isolated worktree, or the shared checkout after confirming that
   `git status` shows no tracked changes under the source folders and no other `forge` process is running.
4. **Check before you trust a shared-checkout run.** Before and after it, run `git status --short` on the
   source folders and `pgrep -fl 'forge (test|build)'`. If tracked files changed during the run, or
   another forge process overlapped it, run it again in your own worktree.
5. **Never revert what isn't yours.** If you find tracked source files modified in the shared checkout and
   you didn't change them, leave them. Say so to the user, and report your results from your own
   worktree. Restoring them can destroy another session's work in progress.
6. **Tell the other session when you touched a shared file.** If you swapped a shared file, even briefly,
   message the sessions that may have run tests in that window (`ListAgents`, then `SendMessage`).
   Say which files changed and for how long, and that the files are back at HEAD. When you receive such a
   message, check its claims (`git status`, compare with HEAD), re-run anything that overlapped, and reply
   saying what you re-ran and whether results changed.
7. **One scratch folder per finding.** Use `<scratch>/i<N>/`:
   - `a/` for the originals and `b/` for the patched copies;
   - the diff;
   - a backup of any PoC you rewrite;
   - the worktree, if you keep one.

   Probes that compile only against a patch go in the scratch folder, not the PoC folder. In the shared
   PoC folder they break every other session's build.
8. **Never use `git stash` in a shared repo.** The stash stack is shared across worktrees. To set work
   aside, use a temporary commit in your own worktree.

## Worktree setup notes

- Create it with `git worktree add --detach <dir> HEAD`. A detached HEAD keeps it from touching any branch.
- **Dependencies:** symlink `lib/` and `node_modules/` from the shared checkout. Submodules are not checked
  out in a new worktree, and copying them is slow.
- **Untracked files:** copy all untracked, non-ignored files, not only the PoC files. PoCs import helpers
  (`utils/`, mocks) that are also untracked, and a missing helper fails the whole build.
- **Do not copy tracked modifications** from the shared checkout. They are someone's temporary patch.
- **Refresh, don't recreate.** After editing a PoC in the shared checkout, `sync` it into the worktree.
  Recreating the worktree costs a full rebuild.
- **Clean up:** `git worktree remove --force <dir>`, then `git worktree prune`.

## Comparing results

- **Key every result by suite and test** (`forge test --json`). Text output repeats failing tests in a
  summary at the end. Tests with the same name in different suites also merge when you sort text lines.
- **Record the baseline failure count.** Old probes that fail on purpose show up as failures in both
  runs; only *changes* matter.
- **Separate infrastructure failures from results.** Fork suites can fail on one run and pass on the
  next ("block not found", RPC timeouts). Re-run them, or exclude fork suites, before calling a change a
  regression.
- **Spot-check one run in the shared checkout.** Run the PoC once there on clean code and compare figures
  and gas with the isolated run. If they are identical, the two environments agree.
