---
name: peer-review
description: >-
  This skill should be used when the user says "peer review #<N>", "peer-review issue <N>", "let's review
  <N>", "review this finding from my peers", "is this finding valid", "is this a dupe", "check the severity
  of <N>", "/peer-review", or points at a finding written by another auditor or an AI agent and wants it
  validated before it goes into the report. Reproduces the finding with a PoC, checks validity, scope,
  severity and duplicates, verifies the proposed mitigation against the code, and produces the review
  verdict plus any follow-up artifact the user asks for (intro paragraph, downgrade comment, rewrite,
  co-assignee note, session marker, pending-work tome). Not for reviewing the user's own draft for
  writing quality (use /finding-review), drafting new findings (use /finding-draft), or reviewing a
  client's fix after the audit (use /mitigation-review).
user_invocable: true
---

# Peer Review

Validate a finding someone else wrote (a peer auditor or an AI agent) the way a careful second auditor
would: reproduce it, measure it, place it in scope, compare it with the other findings, test the fix,
and give a verdict the user can act on.

## Philosophy

- **Reproduce before you opine.** A finding is not reviewed until its claim has run as a test. Run the
  finding's own PoC; if it has none, write a minimal one. Numbers in the verdict come from test output,
  not from arithmetic in your head.
- **Validity and severity are separate questions.** "The code does this" can be true while "this matters"
  is weak. Answer both, separately.
- **Severity follows realism.** Ask who triggers it, what they control, what must line up, what it costs
  to recover, and how much value moves. Privileged mistakes, dust, and self-healing states pull severity
  down; supported flows, cross-component blast radius, and expensive or absent recovery push it up.
- **Name the root cause, then group.** Many findings are symptoms of one cause. Say so, and say which
  single fix closes the group.
- **Verify the fix, not just the bug.** A recommendation is checked by applying it to a scratch copy,
  watching the PoC's bug assertions flip, and diffing the whole test suite before and after.
- **Never leave the codebase changed.** Every patch is temporary. Restore it and prove it (`git status`
  on the touched paths) before reporting.
- **Correct yourself in the open.** When a later check contradicts an earlier statement (a wrong
  variant, a mis-scoped claim, a flawed fix), say so plainly and update the verdict.

## Inputs

| Input | Where it comes from |
|---|---|
| Finding | Issue number in the findings repo, or a local mirror file (`<mirror>/issue<N>-*.md`) |
| Findings repo | GRIMOIRE.md header, or ask once |
| Local mirror of findings | e.g. `grimoire/findings/original-repo-findings/` (with its `DUPLICATES.md` if present) |
| Baseline and audited commits | GRIMOIRE.md Scope ("delta" range), used to decide pre-existing vs new code |
| In-scope paths, trust assumptions | GRIMOIRE.md Scope / Trust assumptions |
| PoC directory | The project's existing PoC folder (e.g. `test/PoC/<Org>/`); never create a new one silently |
| Scratchpad | Session scratchpad for patched copies and backups |

If GRIMOIRE.md doesn't exist, run `/summon` first. If an input is missing, ask once and record it in
GRIMOIRE.md. Scripts live in this skill's `scripts/` directory; run them from the target repo root.

---

## Workflow (per finding)

Create a todo list from these steps. Steps marked **[confirm]** pause for the user.

```
- [ ] 1. Load the finding and its context
- [ ] 2. Reproduce
- [ ] 3. Verify the mechanism in code, across every variant
- [ ] 4. Place it in scope (delta vs pre-existing)
- [ ] 5. Calibrate severity
- [ ] 6. Duplicates and root cause
- [ ] 7. Verify the mitigation            [confirm before writing a new fix]
- [ ] 8. Present the verdict              [confirm]
- [ ] 9. Produce requested deliverables   [confirm each]
```

### 1. Load the finding and its context

```bash
bash <skill>/scripts/load-finding.sh <N> --mirror <mirror-dir> [--repo <owner/repo>]
```

It prints the finding (labels, author, state, body, comments) and every local artifact that already
mentions it: the duplicates index, other findings citing `#<N>`, local drafts and submissions, and PoC
files named after it. Read the hits. Flag immediately if:
- **the user already has work on it**: a draft, a submission, an additional-impact comment, a PoC;
- **one of the user's own submissions duplicates it** (same root, same line, same fix). The usual
  resolution is to post the user's extra impact as a comment on the earlier issue and close their own.

If the finding is very short, has no PoC, or uses jargon, restate it in two sentences before going on.

### 2. Reproduce

**If the finding embeds a PoC**, extract and run it:

```bash
bash <skill>/scripts/extract-poc.sh <finding.md> <poc-dir>/Issue<N><ShortName>.t.sol
forge test --match-path <poc-dir>/Issue<N><ShortName>.t.sol -vv
```

`extract-poc.sh` re-roots relative imports from the PoC's original location (read from its run command,
or `--src-dir`) to the destination. If it fails to compile, fix only paths and fixture wiring; never
change what the test asserts.

**If it has no PoC**, write the smallest test that shows the claim, preferring (in order):
1. the finding's own scenario on the **full stack** reused from an existing PoC or fixture in the repo;
2. a unit harness on the real component with the test contract standing in for its caller.

Rules learned the hard way:
- Compute "before" and "after" from **one deployment** with `vm.snapshotState` / `vm.revertToState`.
  Redeploying the stack several times in one test leaves stale state and garbage numbers.
- An argument that is itself an external call consumes a pending `vm.prank`. Read values into locals
  first, then prank.
- Fork suites fail without RPC env vars; use local fixtures, or note the requirement.
- Some contracts underflow at `block.timestamp` near 0; warp to a realistic timestamp first.
- Accrual that happens over time reads the rate stored **at the start** of the period; set rates
  before seeding, not at the end.

Record the exact figures the test logs. Every number in the verdict should trace back to a test.

### 3. Verify the mechanism in code, across every variant

Quote the exact lines responsible (`file:line`) and check every sibling implementation (other
variants of the same engine, other adapters, other strategies) with one grep. State which are
affected and which are not, and why the others are immune (often: they never take the code path).
If the finding says "all N variants" or "only X", confirm it.

When behaviour depends on another component (a strategy, an oracle, a keeper), survey all concrete
implementations; the finding is often real for one family and harmless for the rest.

### 4. Place it in scope

```bash
bash <skill>/scripts/delta-check.sh <baseline> <audited> <file> [<symbol> ...]
```

Answer: is the responsible code **new in the delta**, **pre-existing and copied** into a new file, or
**pre-existing and untouched**? A pre-existing bug can still matter if the delta changes its impact,
for example by adding a new victim, a new revert surface, or a wider trigger. Say which. Check the
in-scope file list; out-of-scope components can still be the trigger, but the root must be in scope.

### 5. Calibrate severity

Walk `references/severity-calibration.md`. Always cover:
- **Preconditions and minimum actor.** Is a privileged role needed? Is it timelocked? Is the "privileged"
  step actually a supported flow? Check the project's own tests and docs before calling it misuse.
- **Magnitude.** Quantify it with a quick script or a parameter sweep when the finding is size-dependent
  (rounding, overflow thresholds, fee size, price paths). Give real ranges, not adjectives.
- **Recovery.** Who can undo it, how fast (timelocks), and at what cost. A cheap permissionless recovery
  pulls severity down; a missing or slow one pushes it up.
- **Persistence.** Self-healing, sticky until an upgrade, or permanent only when acted on
  (effective-value transfers that reset unless someone exits during the window).
- **Configuration.** Default values (features shipped disabled), reference deployment, number of
  markets sharing a component.

Give a rating and the strongest argument on each side. When it hinges on a fact you can't verify
(deployment owner, a feature flag, an off-chain data source), say what to ask the project.

### 6. Duplicates and root cause

Follow `references/duplicate-analysis.md`. Two findings are duplicates when they share the root cause
**and** one fix closes both. A shared code site, symptom, or theme is not enough. For every candidate:
- state each root in one line;
- check whether each fix closes the other finding (test it if cheap);
- say whether the finding under review is a **symptom** of a broader root already filed.

When several findings share a root, list them as a cluster with one row per symptom, and point to the
single fix that closes the cluster.

### 7. Verify the mitigation

Judge the finding's recommendation first: is it correct, specific, complete, and safe? Then, when a
concrete fix is needed, **ask before writing it**, and verify it:

```bash
bash <skill>/scripts/verify-fix.sh \
  --patch <repo/path/File.sol>=<scratch/patched/File.sol> \
  --suite '<poc-dir>/Issue<N>*.t.sol' --suite '<regression glob>'
```

The script runs the suites on the original code, applies the patches, runs them again, restores the
originals, prints every test whose result changed, and checks the touched paths are clean. Expected
outcome: the PoC's **bug assertions** fail (the bug is gone), and nothing else changes. Investigate every
other change. A failing test that only fails through a mock path the real code can't reach is not a
regression, but it shows an **invariant** the fix relies on, and the write-up must state it.

See `references/fix-verification.md` for patterns (non-destructive caps, tracking state separately from
in-flight counters, checkpoint-before-mutate, re-quoting dependent amounts).

### 8. Present the verdict **[confirm]**

Use `examples/verdict-template.md`. Lead with one line: **valid / partly valid / invalid**, the
rating, and the filed rating if different. Then: the bug in plain terms, the reproduction figures,
scope, severity reasoning, duplicates and cluster, mitigation assessment, and open questions. Keep it
scannable; the user will often ask follow-ups.

### 9. Produce requested deliverables **[confirm each]**

Only on request. Formats are in `references/deliverables.md`:

| Request | Output |
|---|---|
| "intro paragraph", "explain it simply" | Plain-English section to paste above the finding's Description |
| "argument to downgrade", "save as a comment" | One-paragraph comment, saved under the comments folder |
| "rewrite it", "follow the format of <issue>" | Full rewrite in the project's finding format, with PoC and verified diff |
| "justify adding me as assignee" | Short co-assignee note citing what the user added |
| "add a marker" | Session marker block (finding, verdict, artifacts, date) |
| "come back later", "park it" | Entry in the pending-reviews tome with the leads to explore |
| "diff for the mitigation" | Verified diff, with notes on the other variants |

---

## Conventions

- **PoCs** go in the project's existing PoC folder, standalone (no imports from other PoC files).
  Prefer one full-stack PoC per finding, and delete superseded scratch PoCs once the user agrees.
  Probe tests (exploring an idea, a new impact or a fix's side effects) live in their own
  `*Probe.t.sol` files and never enter a write-up's PoC unless the user asks to add a claim the
  probe validated. Probe files may stay, but no write-up may reference or embed tests for ideas that
  were ruled out or left out; do not delete probe files unless asked.
  Ask before creating a new folder; a mistyped path usually means the existing one.
- **Plain language in write-ups:** spell out what symbols mean (`exchangeRate`, not `r`), give
  numbers from the PoC, prefer a small table to a paragraph of figures, and avoid jargon the user
  hasn't used.
- **Patched copies** live in the scratchpad (`<scratch>/<id>/a` original, `.../b` patched). The repo's
  contract files are only ever swapped in by `verify-fix.sh` and are always restored.
- **Track the queue** in a pending-reviews tome (`examples/pending-tome-template.md`) so parked
  findings and open leads survive across sessions.
- **Grimoire hand-offs:** `/write-poc` for complex exploit PoCs, `/finding-review` for polishing the
  user's own rewrite, `/finding-dedup` across a batch, the familiar agent for a second-opinion triage,
  `/cartography` when a parked finding needs a flow mapped first.

## References

- `references/severity-calibration.md`: severity checklist and common up/down arguments
- `references/duplicate-analysis.md`: root-cause test, symptom vs root, clusters, own-dup handling
- `references/fix-verification.md`: patch-verify-restore loop and recurring fix patterns
- `references/deliverables.md`: formats for every follow-up artifact
- `examples/verdict-template.md`, `examples/pending-tome-template.md`, `examples/session-marker-template.md`
