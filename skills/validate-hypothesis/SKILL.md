---
name: validate-hypothesis
description: >-
  This skill should be used when the user says "validate hypothesis", "validate this hypothesis",
  "/validate-hypothesis", "is this lead real", "explore this lead", "prove or disprove this", "check
  this hypothesis", "work on hypothesis <name>", "promote this hypothesis", or points at a file in
  grimoire/hypotheses/WIP/ (created by hand or by /delve) and wants it explored and settled. Also when
  the user says "validate all the hypotheses of this delve", "validate this delve's hypotheses", "run
  the delve hypotheses" or "/validate-hypothesis --delve": batch mode runs every open hypothesis of the
  session's newest delve board without pausing and returns one digest, a shortlist plus closings to
  approve in bulk. Traces the
  mechanism in code, checks whether the behavior is intended, proves it with a PoC, gets an independent
  triage, and records the outcome: promoted to a finding draft in findings/WIP/, reframed around what
  actually breaks, or closed in hypotheses/invalid/ as invalid or expected behavior once every measured
  value transfer has a home. Not for only writing a hypothesis down (use
  /write-hypothesis), surfacing leads (use /delve), building
  context through questions (use /dig-mode), reviewing someone else's finding (use /peer-review), or
  writing up an already-proven bug (use /finding-draft).
user_invocable: true
---

# Validate Hypothesis

Take one hypothesis from `grimoire/hypotheses/WIP/` and settle it: explore it, prove or disprove it,
and file the result where the rest of Grimoire can see it. A hypothesis comes from the user's own
reading or from `/delve`; both use the hypothesis format from `/summon` Step 2.

## Philosophy

- **Prove, don't argue.** A hypothesis is valid only when a test shows it. Numbers in the verdict come
  from test output, not from reasoning about the code.
- **Disproving is a result.** A hypothesis closed as `invalid` or `expected behavior`, with the reason,
  keeps the next delve and the next session from re-opening it. Write the reason so it convinces a
  reader who was not here.
- **Validity, intent and severity are separate questions.** The code can do what the hypothesis says
  and still be working as designed. Answer each one on its own.
- **The claim and the impact are separate questions too.** Whether the hypothesis is true as worded is
  one answer; whether any explored path moves value, from whom and how much, is another. A wrong
  suspected cause disproves the claim, not the bug: the same invariant can still break through another
  door, actor or parameter value. Answer both, every time.
- **A measured loss never closes as Invalid.** If any test in this validation shows value moving where
  the invariant says it must not, the hypothesis cannot be closed as Invalid or Expected behavior until
  that loss has its own home: the hypothesis is reframed around it, a new hypothesis is opened for it,
  or it is promoted (step 6).
- **Sweep, don't sample.** A parameter the outcome depends on is tested across its allowed range and
  past its break-even, not at one realistic value. One value can sit exactly where the bug vanishes.
- **Write as you go.** Every check goes into the hypothesis file's `## Notes` with the date, so a
  hypothesis left in `WIP/` can be resumed from the file alone.
- **The user moves the file.** Nothing leaves `WIP/` without the user confirming the verdict.

## Inputs

| Input | Where it comes from |
|---|---|
| Hypothesis | A file in `grimoire/hypotheses/WIP/`, or an idea the user states (step 1 records it) |
| Source leads | The file's `source:` lines (`grimoire/delves/<session-id>/leads/<lead>.md`) |
| Context | `GRIMOIRE.md` (scope, trust assumptions, crown jewels), `grimoire/tomes/active/` (never `tomes/archived/`) |
| PoC directory | The project's existing PoC folder; never create a new one silently |

If GRIMOIRE.md doesn't exist, run `/summon` first. The peer-review skill's `scripts/` directory is `$P`
below (`isolated-workspace.sh`, `verify-fix.sh`); its `references/severity-calibration.md` and
`references/parallel-sessions.md` apply here too.

## Parallel Sessions

Several sessions can validate different hypotheses in the same workspace at once. On top of the
peer-review rules above:
- **One session per hypothesis.** A session works only on a hypothesis it has claimed (step 1).
- **Status rows go through the script.** `hypotheses/SESSIONS.md` is a snapshot, one row per
  hypothesis with its current state. Write it only with the summon skill's
  `scripts/session-status.sh`, which replaces the row under a lock, so concurrent updates are never
  lost. `findings/SESSIONS.md` is a history log: add rows with a shell append (`>>`) only.
- **Never overwrite on create.** Before writing a new hypothesis, finding draft or PoC, check the name
  is free (`set -o noclobber` or `[ ! -e <file> ]`). On a clash, add a short suffix.

## Batch Mode

When the user asks to validate a whole delve rather than one hypothesis, follow
`references/batch-delve.md`. It picks the board (the session's newest by default), runs steps 1 to 5
on every open hypothesis without pausing, closes on a desk check only what has a hard, cited reason,
and ends with one digest: a shortlist of hypotheses with a real signal, and proposed closings the user
approves in one reply. Nothing leaves `WIP/` before that reply. A shortlisted hypothesis then
continues at step 6 below.

---

## Workflow

Create a todo list from these steps. Steps marked **[confirm]** pause for the user.

```
- [ ] 1. Load the hypothesis and check what is already known
- [ ] 2. Explore the mechanism
- [ ] 3. Check intent
- [ ] 4. Prove it
- [ ] 5. Independent triage
- [ ] 6. Present the verdict              [confirm]
- [ ] 7. File the outcome                 [confirm]
```

### 1. Load

Read the hypothesis file and every lead in its `source:`. If the user gave an idea instead of a file,
create `grimoire/hypotheses/WIP/<name>.md` in the `/summon` format (`source: manual`) and append a
row for it to `grimoire/hypotheses/SESSIONS.md` 
(`session-status.sh … <name>.md WIP "created, manual"`).

**Claim it.** If `claimed-by:` is empty, set it to this session's ID and update its row in
`grimoire/hypotheses/SESSIONS.md` (`session-status.sh … <name>.md WIP "claimed, validating"`). Re-read the file right after: if another ID won, back off. If it
already names another session, stop: tell the user which session holds it (`claude --resume
<session-id>`), and continue only if they explicitly take it over (note `taken over from <id>`
in its row).
A resumed session keeps its ID, so it finds its own claim.

Restate the hypothesis as two sentences: **what is at risk** (the invariant or asset, and whose it is)
and **the suspected mechanism** (who does what, through which path). If the file predates the
`/write-hypothesis` format and has no **At risk**, **Parameters that decide it** or **If the suspected
mechanism is wrong** section, write them into the file now (dated in `## Notes`), from the code and the
file's own text, before going on. Every later step works from these.

Then check whether it is already settled. Search `grimoire/findings/` (all folders, and the
`original-findings/` mirror) and `grimoire/hypotheses/valid/` and `invalid/` for the same mechanism at
the same `path:line`. If a match exists, stop and tell the user: it is a duplicate of a finding, or a
known dead end with its recorded reason.

### 2. Explore

Trace the path in code and quote the responsible lines (`file:line`):
- Is the vulnerable path reachable from an entry point the attacker can call? Walk it end to end.
- Which checks stand in the way, and can each one be satisfied?
- Check every sibling (other variants, adapters, implementations) with one grep. Say which are
  affected and why the others are not.
- **Walk every door to the asset, not only the suspected one.** List each way value enters and leaves
  the component at risk (pools, desks, redemption paths, fee and rent books, liquidation or termination
  payouts), and each pairing of an entry with an exit. Add any pairing missing from the outcome tree as
  a new Open row. The suspected path is one row among them.
- **Bound every deciding parameter.** For each parameter in **Parameters that decide it**, read its
  allowed range from the setter or constructor checks (`file:line`), and derive the break-even where
  the outcome flips if the mechanism allows it. Record both in the file; step 4 sweeps them.

For a wide search across the codebase, spawn a `sigil` agent (variant mode) on the pattern. When the
hypothesis rests on a spec or external protocol claim, ask the `librarian` agent; don't rely on memory.
Append each check to `## Notes` as you go.

### 3. Check intent

Look for evidence that the behavior is by design: the spec and docs, a docstring describing this exact
behavior, an intent-named test, the client's answers in `grimoire/client-communication/`. When the
reason for the code is unclear, run `/divine` on it. Land on *not by design*, *by design*, or *needs the
client* (then draft the question for `client-communication/`; don't send it).

### 4. Prove it

Use `/write-poc` to write the smallest test that shows the claim. Name it after the hypothesis
(`Hyp<Name>.t.sol`, or the project's equivalent) so parallel sessions never pick the same file. Draft
it in this session's work folder (`$P/isolated-workspace.sh work hyp-<name>`) and move it into the
project's PoC directory only once it compiles: a broken file in the shared PoC folder breaks every
other session's build. Prefer the hypothesis's own scenario on the full stack, reusing existing fixtures. Record the exact
figures the test logs. When a code change is needed to probe the behavior, make it only in this
session's isolated copy (`$P/isolated-workspace.sh`), never in the workspace.

A test that shows the attack does **not** work is also proof: keep it, and cite it in the verdict.

Run three passes, and record each in `## Notes`:

1. **The claim.** The test above: does the suspected mechanism do what the hypothesis says?
2. **The parameter sweep.** Re-run the scenario for each parameter in **Parameters that decide it**
   across its allowed range: the smallest accepted value, values below, at and above the break-even,
   and the cap. Sweep size too when the outcome depends on it. Record a table (parameter values →
   result, who gained, who paid). A result taken at one value is never enough to rule an outcome out.
3. **The invariant check.** When the hypothesis is about value leaving where it should not (round
   trips, pricing, redemptions, fees, accounting), test the invariant directly, without assuming the
   cause: a loop or fuzz test over every door pairing from step 2 and the swept parameters, asserting
   the invariant ("USDC out ≤ USDC in for every entry and exit pair", "NAV never rises after an
   unprofitable trade"). It can find the bug even when the suspected cause is wrong.

Keep an **impact ledger** in `## Notes` as you go: every value transfer any test shows, whether or not
it supports the claim. One line each: the test, who gained, who paid, the amount, the parameter
values. Step 6 reads it.

### 5. Independent triage

Spawn the `familiar` agent (Mode 1) on the hypothesis file and the PoC path. Give it what is at risk,
the suspected mechanism and the evidence, not your verdict, so its read is not anchored on yours. Ask
it to report, in its **Measured Value Transfers** section, every value movement it observes in its own
runs or in the evidence, whether or not that movement supports the claim. Where it disagrees with you,
look again before going on, and report the disagreement in the verdict.

Copy every entry of its **Measured Value Transfers** into the impact ledger. A familiar verdict that
refutes the claim does not clear these entries: each one is settled in step 6 like any other.

### 6. Present the verdict [confirm]

Answer two questions first:

| Part | Question | Answer |
|---|---|---|
| **Claim** | Is the hypothesis true as worded, through the suspected mechanism? | true / false / partly |
| **Impact** | Independent of the claim: does the impact ledger show value moving where the invariant says it must not? | none measured / the ledger entries, with amounts |

Then the verdict, one of:

| Verdict | When |
|---|---|
| **Valid** | The PoC shows the impact, the path is reachable by the stated actor, and it is not by design |
| **Reframed** | The suspected mechanism is wrong or minor, but the invariant still breaks through another door, actor or parameter value. The hypothesis is retitled around what actually breaks and validated again from step 2 |
| **Invalid** | The attack does not work; name the check or condition that stops it. Only when the Impact part is "none measured", or every ledger entry is already homed (below) |
| **Expected behavior** | It works, but as designed; cite the evidence of intent. Same condition on the Impact part as Invalid |
| **Inconclusive** | Something only the client or more work can answer; say exactly what |

**Every ledger entry needs a home before the hypothesis closes.** For each measured value transfer
the claim does not explain, record one of:
- **reframed** into this hypothesis (verdict Reframed);
- **spun off**: a new hypothesis in `hypotheses/WIP/` written with `/write-hypothesis`, linked from both
  files;
- **promoted**: proven here, so it becomes the finding (verdict Valid);
- **filed elsewhere**: an existing finding draft, findings-repo issue or recorded client answer covers
  it; link it. A tome note, an idea-list entry or an open client question is not filed: a measured loss
  parked under one still needs a spin-off or a promotion. If intent is unclear, the finding states the
  loss and the client's answer decides it later.
- **not a loss**: explain why the transfer is intended or bounded to dust, with the evidence.

Reply briefly: the Claim and Impact answers; the verdict and the reason in one sentence; the key
`file:line`; the PoC result and the sweep table's decisive rows; the familiar's verdict and its
measured value transfers; the home of each ledger entry; and for **Valid**, a severity estimate
walked through the peer-review skill's `references/severity-calibration.md`, with the strongest
argument on each side. Wait for the user to confirm or correct it.

Before confirming, the user may question the verdict with `/dig-mode`. Make sure the hypothesis
file's `## Notes` hold everything found so far before pausing; dig-mode reads them, also from
another session.

### 7. File the outcome [confirm]

On the user's confirmation (they may question the filing with `/dig-mode` first), finish the
hypothesis file's `## Notes` with the verdict and clear `claimed-by:` (an Inconclusive hypothesis keeps
it only if this session will resume it), then:

| Verdict | Hypothesis file | Also |
|---|---|---|
| **Valid** | Move to `hypotheses/valid/`, `outcome: promoted: findings/WIP/<name>.md` | Run `/finding-draft` and save the draft as `grimoire/findings/WIP/<name>.md` (not the skill's default folder), with a `hypothesis: hypotheses/valid/<name>.md` line in its front matter and the PoC in its proof section |
| **Reframed** | Stays in `WIP/`, keeps its file name; retitle it, rewrite **At risk**, **Suspected mechanism** and the outcome tree around what actually breaks, and note the reframe (dated) in `## Notes` | Validate it again from step 2 in this session, or leave the claim for a later one |
| **Invalid** | Move to `hypotheses/invalid/`, `outcome: invalid: <why>` | Every spun-off hypothesis is linked in `## Notes` |
| **Expected behavior** | Move to `hypotheses/invalid/`, `outcome: expected behavior: <why>` | Every spun-off hypothesis is linked in `## Notes` |
| **Inconclusive** | Stays in `WIP/` | Notes say what is missing; if it waits on the client, add the question to `grimoire/client-communication/<name>.md` |

Update the hypothesis's row in `grimoire/hypotheses/SESSIONS.md` to its new folder, with the verdict
as the note (`session-status.sh … <name>.md valid "Valid; promoted to findings/WIP/<name>.md"`), and
append a `created in WIP` row to `grimoire/findings/SESSIONS.md` for a new draft.

From here on, the finding and the hypothesis move together: if the finding is later rejected, its
hypothesis goes back to `invalid/` (rule in `/summon` Step 2, "Findings and hypotheses stay in sync").
When the user confirms the draft was submitted, move it to `findings/valid/` and update the
hypothesis's `outcome:` link and both logs in the same turn (rule in `/summon` Step 2, "Finding
submitted").

Never edit the delve folders. A lead's status is read from its hypothesis's folder, so moving the
hypothesis is all the sync a delve needs.

End with one line: where the hypothesis went, and the draft's path if one was created.
