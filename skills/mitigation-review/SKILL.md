---
name: mitigation-review
description: >-
  This skill should be used when the user says "mitigation review", "review the mitigation",
  "review the fix", "verify the fix", "fix review", "check the remediation", "/mitigation-review",
  or shares a finding (ID, title, or issue URL) and asks whether the client's fix resolves it.
  Maps an audit report to the client's fix commits and findings-repo issues, reviews each fix
  against its finding and thread, verifies it with pre-fix / post-fix / residual PoCs, records a
  verdict, and drafts the short "Cyfrin:" write-up for the report. Not for finding new bugs in
  unchanged code (use sigils / cartography) or drafting new findings (use /finding-draft).
user_invocable: true
---

# Mitigation Review

Judge whether each client fix closes its finding, prove it with PoCs, and produce a short write-up
for the report's `**Cyfrin:**` field.

## Philosophy

- **The fix is guilty until a PoC says otherwise.** Reading the diff is not verification. Every fix that
  changes behaviour gets a test that reproduces the bug before the fix and passes after it. Only renames
  and docs-only changes skip PoCs, and the review says so.
- **The thread binds the verdict.** Agreements reached in the issue thread (accepted behaviour,
  severity, design limits) are context, not something to re-litigate.
- **Realism before severity.** Before raising a residual, ask who triggers it, what they control, and
  how many uncontrollable events it needs. Unrealistic residuals become footnotes, not findings.
- **Short and plain.** Write-ups are 1–3 sentences in simple words. Detail lives in the review file.
- **Don't touch `src/`.** PoCs go in `test/mitigation/`. Pre-fix code is swapped in at test time.

## Inputs

| Input | Example | Where it's stored |
|---|---|---|
| Report | `2026-09-17-cyfrin-<client>-v0.0.md` | GRIMOIRE.md header |
| Findings repo | `Cyfrin/audit-2026-09-<client>` | GRIMOIRE.md header |
| Baseline (audited) commit | `37f06bb` | GRIMOIRE.md header |
| Mitigation commit | `be70792` | GRIMOIRE.md header |
| In-scope paths | `src/vault-v2 src/risk-engines` | GRIMOIRE.md Scope |
| Client name + git remote of the client repo | `Acme`, remote `client` | GRIMOIRE.md header |

If GRIMOIRE.md doesn't exist, run `/summon` first. If any input is missing from GRIMOIRE.md, ask
once, then record it there.

Scripts live in this skill's `scripts/` directory; run them from the repo root (`$S` below).

---

## Phase A — Setup (once per engagement; skip steps already done)

```
- [ ] A1. Confirm inputs and record them in GRIMOIRE.md
- [ ] A2. Build the findings → issue → fix index
- [ ] A3. Add the status table to GRIMOIRE.md
```

### A1. Confirm inputs

Check `git log -1 <mitigation-commit>` and `git log -1 <baseline>` resolve, `gh auth status` works,
and the report file exists. Note fork-test env vars the repo uses (`grep -r "vm.envString\|rpc_endpoints" test foundry.toml`).

### A2. Build the index

```bash
$S/index-report.sh   <report>                       # ID, line, title (IDs derived per severity section)
$S/link-issues.sh    <report> <owner/repo>          # ID → issue # by title
$S/map-fixes.sh      <baseline> <head> <scope...>   # PR → issue refs, commits, files ([*] in scope)
```

Join the three into `grimoire/tomes/findings-index.md`:

| ID | Report line | Finding (short) | Issue # | PR / commits | Mitigation type |

PRs without issue references (e.g. `fix/<client>-adapters`) are mapped by content: compare the diff
to the finding's recommendation. Mark findings with no matching PR `none found` and list them at the
bottom as "confirm with the client whether acknowledged". Also flag PRs in the range that map to no
finding: they are unreviewed changes, so skim them for regressions.

### A3. Status table

Add a `### Finding → mitigation status` table to GRIMOIRE.md (`| Finding | PR | Verdict |`, all
`pending`) and a short **Mitigation Diff Map** (one row per PR) if not already present.

---

## Phase B — Per finding (the user names the finding: ID, title, or issue URL)

```
- [ ] B1. Load finding, thread, and fix diff
- [ ] B2. Review the fix
- [ ] B3. Verify with PoCs
- [ ] B4. Decide the verdict
- [ ] B5. Record (review file + GRIMOIRE status)
- [ ] B6. Present + Cyfrin write-up
```

### B1. Load

Run these in parallel:

```bash
$S/extract-finding.sh <report> <ID | title fragment>
$S/load-issue.sh      <N> <owner/repo>                 # full thread + PR/commit links in it
$S/fix-diff.sh        <N> <baseline> <head> src        # the fix commits + their diff
```

If `fix-diff.sh` finds nothing, use the PR/commit links from the thread or the index row, then
`git show <sha>`. If the user's pasted title doesn't match the issue they linked, say so and review
the issue.

Summarise for yourself: root cause (one sentence), the recommendation, what the thread agreed, and
what the diff changes.

### B2. Review

Work through `references/review-checklist.md`: root cause, every instance and path (siblings,
constructor vs setter, defaults), regressions (new reverts, params, casts, privileged powers,
layout/ABI, EIP-170), bypasses of the new defence, reliance on out-of-scope code, thread
consistency, stale docs/invariants. Cite `file:line` for every claim.

For a large or cross-contract fix, spawn a `grimoire:sigil` (variant mode) on the fixed pattern to
check for unfixed siblings, and the `grimoire:familiar` to challenge any residual before you rate it.

### B3. Verify with PoCs

Follow `references/poc-patterns.md`. The minimum is:

1. **Pre-fix reproduces.** Config fixes: the report's inputs now revert. Logic fixes:
   `$S/prefix-snapshot.sh <src-file> <fix-commit> test/mitigation`, then `deployCodeTo` it. Layout
   changes: use a separate `git worktree` at `<fix-commit>^`.
2. **Post-fix passes** with the report's own figures.
3. **Residual / bypass probes** for every concern raised in B2.
4. **The client's regression test** for the fix (from the fix commits) also passes.

When other sessions share the checkout, don't check out other commits, swap source files, or run
`prefix-snapshot.sh` output against swapped code in it. Do those steps in a private worktree:
`bash skills/peer-review/scripts/isolated-worktree.sh create <scratch>/<ID>/wt --ref <commit>`. The new
test files stay untracked in the shared checkout and are copied into the worktree, so only the source
under test changes.

Put the tests in `test/mitigation/<ID>MitigationReview.t.sol` (template:
`examples/MitigationReview.t.sol.template`), scoped with `--match-path`. If a fork test needs an RPC
the shell lacks, ask the user to export it (never echo the URL). If a PoC fails, report the failure
and its output; don't call the fix verified.

Skip PoCs only for renames and docs-only changes. For those, grep that no stale reference is left and
state "no behaviour change, no PoC".

### B4. Verdict

Pick one from `references/verdict-taxonomy.md`. Rate each residual as **new finding**, **note (Info)**,
or **footnote (not reported)**. Before calling a residual a finding, show the user the realism
reasoning; if the user disagrees, downgrade it.

### B5. Record

- Write `grimoire/findings/<ID>-mitigation-review.md` from `examples/mitigation-review-template.md`.
  Include the PoC table, the run command, the thread context, and the final write-up.
- Update the finding's row in the GRIMOIRE.md status table (format in `verdict-taxonomy.md`).
- Don't edit the report file unless the user asks.

### B6. Present

Reply in this order, briefly:

1. One sentence: the verdict and the reason.
2. **What changed** — 2–4 bullets with `file:line`.
3. **PoCs** — the table (test → result) and the pass count, or why there are none.
4. **Notes** — numbered residuals with their rating, if any.
5. The write-up, following `references/writeup-format.md`: first the client line with the fix commit links
   (`$S/commit-links.sh <client-remote> <sha | #PR | PR-URL>...`; PRs resolve to their merge commit, never link a PR), then `**Cyfrin:**` on its own line and the text as
   **one single unwrapped line**, no blockquote:

   **<Client>:**
   Fixed at commitHash [abc1234](…/commit/<full>) && [def5678](…/commit/<full>).

   **Cyfrin:**
   Verified. …

6. One line: where the review was saved and which finding is next by the index (pending, report
   order).

Expect follow-ups: "shorter", "simpler wording", "in md format", "write the recommendation as if it
led to this mitigation", "propose hardening to the client", "justify X". Their shapes are in
`references/writeup-format.md`. Update the review file's write-up section whenever the user settles
on a new version.

---

## Phase C — Wrap-up (when the user says the review is done or asks what's left)

- List the pending rows. Group docs-only acknowledgements (they can be reviewed together in one pass:
  check that the doc text is accurate and placed where the affected party will see it).
- List findings with no fix PR, with their issue numbers, for client confirmation.
- List PRs in the range that map to no finding, and whether they were skimmed for regressions.
- Offer to fill the `**Cyfrin:**` fields in the report from the saved write-ups. Do this only when
  asked.
- Offer `/scribe-distill` for any new finding a mitigation introduced.

## Guidelines

- Before the first finding, read GRIMOIRE.md's Scope and accepted-behaviour notes. Don't report
  anything listed as accepted.
- When the user corrects a claim (e.g. how a library function behaves), fix it in the review file and
  the write-up straight away, and say it was corrected.
- Keep every PoC passing. Re-run the mitigation suite before Phase C:
  `forge test --match-path 'test/mitigation/*'` (fork suites with the RPC set).
- Don't commit unless asked.
- **Parallel sessions:** several reviews may run in one checkout. Follow
  `skills/peer-review/references/parallel-sessions.md`:
  - patch and probe only in a private worktree;
  - take PoC output for write-ups from a clean run;
  - check `git status` and running `forge` processes before trusting a shared-checkout run;
  - never revert changes you didn't make;
  - message the other sessions if you touched a shared file.
