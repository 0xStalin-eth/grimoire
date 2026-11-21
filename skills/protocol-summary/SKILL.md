---
name: protocol-summary
description: >-
  This skill should be used when the user says "protocol summary", "/protocol-summary", "write the
  protocol summary", "build the protocol summary", "add this to the protocol summary", "put this in
  the protocol-summary", "add a section to the protocol summary", "update the protocol summary",
  "is the protocol summary up to date", "check the protocol summary", or wants
  grimoire/report-deliverables/protocol-summary.md written, extended or re-checked. It condenses
  what the research learned (tomes, closed hypotheses, delves, client answers, findings) into a
  plain-language description of how the protocol works, checks every claim against the code, and
  records which research each section came from. Not for writing tomes (use /tome), recording a
  suspicion (use /write-hypothesis) or drafting a finding (use /finding-draft).
user_invocable: true
---

# Protocol Summary

Write `grimoire/report-deliverables/protocol-summary.md`: the report's description of how the protocol
works, for a reader who has not seen the code or the research.

## Philosophy

- **The summary is the research, condensed.** Tomes, hypotheses, delves and client answers hold
  what the engagement learned the hard way: which quantity moves when, which role can do what, which
  behavior looked like a bug and is by design. The summary keeps that understanding and drops the
  process that produced it. A reader should come away knowing the quirks that made the code easier
  to understand, stated as facts.
- **Expected behavior is the best material.** A hypothesis closed as expected behavior is a behavior
  a careful reader would suspect, plus the reason it is intended. Each one is a sentence the summary
  owes its reader.
- **Describe, never judge.** Findings show where the reader needs an explanation, not what to report.
  The mechanism a finding relies on is described neutrally; the bug, its severity and its number stay
  in the findings section of the report. Trade-offs are stated as consequences ("the model therefore
  depends on…"), not as weaknesses.
- **The code is the authority.** Every claim is checked in the code before it is written. Research
  notes drift; when a note and the code disagree, the code wins and the note is reported to the user.
- **One concept, one home.** Each concept is explained in one section. Other sections point to it
  instead of repeating it, so a correction is made once.
- **Readable cold.** No audit vocabulary, no code symbols without a plain name, no file or line
  references. The reader is the report's audience, not the auditor.

## Inputs

| Input | Where it comes from |
|---|---|
| Existing summary | `grimoire/report-deliverables/protocol-summary.md` (may be empty) |
| Sources map | `grimoire/report-deliverables/protocol-summary.sources.md` (created by this skill) |
| Context | `GRIMOIRE.md` (scope, actors, roles, trust assumptions) |
| Research | `grimoire/tomes/active/` (never `tomes/archived/`), `grimoire/hypotheses/invalid/` and `valid/`, `grimoire/delves/*/board*.md` and `leads/`, `grimoire/client-communication/`, `grimoire/findings/` |
| The conversation | In section mode, the part of the conversation the user points at |
| Code | The in-scope source, to verify each claim |

If `GRIMOIRE.md` or `grimoire/report-deliverables/` doesn't exist, run `/summon` first.

Read `references/writing-rules.md` before writing anything, and `references/outline.md` before a
build.

## Modes

| Mode | When | Steps |
|---|---|---|
| **Build** | The summary is empty, or the user asks for a full (re)write | 1-8 |
| **Section** | The user asks to add or change one topic ("put this in the protocol summary"), often after a conversation that explored it | 1, 3 (that topic only), 5-8 |
| **Check** | The user asks whether the summary is up to date, or after `/tome-sync` or a batch of closed hypotheses | 1, then 9 |

Pick the mode from the request; say which one you picked in one line.

---

## Workflow

Create a todo list from the steps of the chosen mode. Steps marked **[confirm]** pause for the user.

### 1. Load

Read the whole summary and the sources map, if they exist. Note which section owns each concept
already explained (`references/writing-rules.md`, "One concept, one home"). Read `GRIMOIRE.md`.

### 2. Gather the research (Build)

Read the research in this order, and for each source write candidate claims into a scratch ledger in
`grimoire/tmp/protocol-summary-ledger.md` (claim, source, status):

1. `GRIMOIRE.md` and the tomes in `tomes/active/`: the system model, flows, glossary, quirks.
   Follow `tomes/LINKS.md`: take a shared topic from its **owner** section.
2. Hypotheses closed as **expected behavior**: each `outcome:` reason is a by-design behavior to
   state. Hypotheses closed as **invalid**: the check that stops the attack is often a guard worth
   naming.
3. Delve boards and leads: odd mechanisms, near misses, fragile assumptions. Keep the mechanism,
   drop the suspicion.
4. Client answers in `client-communication/`, including `kickoff-questions.md`: stated intent.
5. Findings (`valid/`, `WIP/`, and the findings-repo mirror): the mechanisms the reader must
   understand to follow the findings section. Never the bug itself.

Skip anything a later answer, verdict or correction overturned.

### 3. Gather the topic (Section)

Take the claims from the conversation the user points at; if the scope is unclear, use the most
recent thread on the topic and say which part you used. Then search the tomes, hypotheses and client
answers for the same topic: a closed hypothesis or client answer often adds the "why". Use the
corrected version of any claim the conversation retracted.

### 4. Plan the outline [confirm] (Build)

Start from `references/outline.md` and adapt it to the protocol: drop sections that don't apply, add
sections for the protocol's own mechanisms, and order them so each section only depends on earlier
ones. For each section, list its claims from the ledger. Present the outline and wait for the user.

### 5. Verify

Check every claim against the code before it is written:
- the role or caller of each function named, and whether it is permissionless;
- every cap, bound, default and launch value, and whether it is fixed or can change (and by whom);
- the direction and unit of every rate, ratio and price;
- the order of every sequence (loss stages, settlement order, who is paid first).

Mark each ledger claim `verified (path:line)`, `corrected`, or `dropped (why)`. The `path:line` goes in
the ledger and the sources map, never in the summary. When a tome, hypothesis or delve note disagrees
with the code, tell the user which note is wrong; don't edit it (that is `/tome` or `/tome-sync`).

### 6. Write

Write the summary (Build) or the section (Section) following `references/writing-rules.md`.

In Section mode:
- Put the text in the section that owns the concept. If no section does, add one where the outline
  order puts it, or split an existing one into `####` subsections when it now covers two cases.
- If the new text overlaps another section, keep the explanation in one place and turn the other
  into a pointer ("…subject to the limits described under <Section>").
- Adding text, or a section the user asked for, needs no confirmation. Rewriting or removing text that
  is already there does: show the old and new text and wait **[confirm]**.

Before rewriting more than one section, copy the current file to the session scratchpad (or
`grimoire/tmp/`) as `protocol-summary.bak.md`.

### 7. Self-check

Re-read every changed section against the checklist at the end of `references/writing-rules.md`, then
grep it for leaks:

```bash
grep -nE 'hypothes|delve|finding|PoC|severity|issue #|#[0-9]+|\.[a-z]{1,5}:[0-9]+|test_|TODO|K[0-9]+' \
  grimoire/report-deliverables/protocol-summary.md
```

Also grep for the engagement's code symbols listed in its glossary tome (the short math names and
variable names): each hit must sit in parentheses after its plain name, or be removed. Fix every hit
before going on.

### 8. Record the sources and report

Update `grimoire/report-deliverables/protocol-summary.sources.md` (format in `references/outline.md`):
one row per section, with the research it came from and the code locations checked, dated. Delete the
scratch ledger once its claims are in the sources map.

Reply briefly: what was added or changed and where; any claim corrected against the code; any
research note found wrong (with the file); the backup path if one was made. Nothing is committed.

### 9. Check (Check mode)

For each row of the sources map, see whether a source changed after the row's date (a tome section
edited, a hypothesis moved or re-closed, a client answer added) and whether any newly closed
hypothesis or new client answer touches a section's topic. Re-verify the claims of every affected
section in the code (step 5). Report a table: section, what changed, whether the summary is still
right, proposed fix. Fix only what the user approves, then run steps 6-8 for those sections.
