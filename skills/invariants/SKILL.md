---
name: invariants
description: >-
  This skill should be used when the user says "build the invariant list", "invariant list",
  "/invariants", "list the invariants", "what invariants does this protocol have", "write the
  invariants for formal verification", "invariants for the FV engineer", "verify the invariants",
  "add invariants from this tome", "are there new invariants in this research", or wants a
  plain-English list of the properties a protocol must always keep, built from the engagement's
  research and checked against the code. Runs one pipeline: gather every research source, draft,
  gap-check every tome in full, split each area into baseline and research-derived invariants,
  verify the unverified ones, apply the results, and publish the list as a tome plus a shareable
  markdown file. After the list exists, new research is added through a separate additions file
  that never edits the list. Not for writing formal-verification specs or test suites, for exploring
  one suspected bug (use /validate-hypothesis), or for drafting findings (use /finding-draft).
user_invocable: true
---

# Invariants

Build the list of properties a protocol must always keep, in plain English, from everything the
engagement has learned: tomes, hypotheses, findings, delves and the protocol's own claims. Each
invariant says what must hold, where, with which exceptions, how the code enforces it, where it came
from, and whether the audit has shown it holds or breaks. The list is written for a reader who will
turn it into properties (a formal-verification engineer, a fuzzing campaign, the client), so it never
uses formal-verification notation: that reader does the conversion.

## Philosophy

- **Plain English, not a spec language.** Each invariant is a sentence a reader can check against the
  code without knowing the cause of any bug. No formulas in FV syntax, no type signatures, no lists of
  "preserving functions".
- **The research is the source, not the code alone.** Anyone can derive "only the owner can withdraw"
  from the code. The value of this list is the properties the audit found the hard way: a tome quirk,
  a cross-component interaction, a closed hypothesis, a model. Keep those visibly apart from the
  baseline, and say for each one why it took research.
- **Read everything in full.** A keyword search for "never", "always" or "invariant" misses most of
  what the tomes say in other words. On the engagement this skill came from, a keyword pass missed 23
  invariants and 12 corrections that a full read found.
- **Status comes from evidence.** An invariant is broken only when a finding or a test shows it, held
  only when a hypothesis, a test or a trace of every path that could break it shows it, and otherwise
  claimed-unverified or untested. Never present a guess as a status.
- **Known before new.** Before calling anything broken, untested or new, search the findings, the
  mirrored peer issues and the known-issues list for the same mechanism. A break someone already
  reported is "BROKEN — known: <it>", not a discovery.
- **Models and fork tests never merge silently.** When an off-chain model and a fork test disagree,
  flag the conflict; do not pick one.
- **The user decides what becomes a finding.** This skill records breaks; it never creates findings or
  hypotheses. Mis-stated invariants are corrected in the list; whether a break deserves a finding is
  the user's call.
- **The list is never rewritten by later research.** Once published, new invariants and doubts about
  existing ones go to a separate, dated additions file. The list changes only when the user says so.

## Inputs

| Input | Where it comes from |
|---|---|
| Context | `GRIMOIRE.md` (scope, actors, trust assumptions, crown jewels) |
| Research notes | every file in `grimoire/tomes/active/` (never `archived/`), read in full |
| Hypotheses | `grimoire/hypotheses/` `valid/`, `invalid/`, `WIP/`: each file's **At risk** line, its `outcome:` and its folder |
| Findings | `grimoire/findings/` (all folders), the mirrored peer issues in `original-findings/`, and `known-issues.md` |
| Delves | the lead tables of every board in `grimoire/delves/` (their asset or invariant column) |
| Protocol claims | the spec, the docs, the audit-readiness document's invariant section, the client's answers in `grimoire/client-communication/` |
| Code | the in-scope source, for every enforcement `file:line` |

If GRIMOIRE.md or the tomes don't exist, run `/summon` first. The entry format, the status values and
the verification verdicts are in `references/entry-format.md`; read it before step 2.

---

## Workflow

Create a todo list from these steps. Steps marked **[confirm]** pause for the user.

```
- [ ] 1. Gather
- [ ] 2. Draft
- [ ] 3. Gap check
- [ ] 4. Split
- [ ] 5. Verify                [confirm]
- [ ] 6. Apply                 [confirm]
- [ ] 7. Publish
```

If the list already exists (`grimoire/tomes/active/invariants.md`), skip to **Adding new research**
below unless the user asks to rebuild it.

### 1. Gather

Collect every candidate property, with where it came from:
- **Protocol claims:** each invariant the spec or audit-readiness document states (keep its own ID,
  e.g. "§9 I3"), each "never / always / must" in the design notes.
- **Hypotheses:** the **At risk** line of every hypothesis is an invariant. Its folder and outcome give
  the status: `valid/` or a promoted outcome = broken (link the finding); `invalid/` = held (one-line
  reason from the outcome); `WIP/` = untested.
- **Findings:** each finding names the property it breaks. Peer issues and known issues count.
- **Delves:** each lead's asset or invariant column.
- **Tomes:** every claim a tome states or implies must always hold: conservation of a book, where a
  token may sit, who may call a door, a rounding direction, a bound, a liveness claim ("always can
  exit", "never reverts"), a quantity that only moves one way.

Group the candidates into areas that fit this protocol (for example core ledger, pricing, losses,
vault, oracle, governance). Area names are per protocol; keep them short, they become ID prefixes.

### 2. Draft

Write one entry per invariant in the format of `references/entry-format.md`, IDs `INV-<AREA>-<n>`.
Merge duplicates; keep the strongest evidence. Every `file:line` in **Enforcement** is opened and
checked, not copied from a tome. Explain every protocol symbol in parentheses where it is used. Record
contradictions you meet (two sources disagree, a hypothesis filed in the wrong folder, a NatSpec that
promises a check the code lacks) in a **Contradictions / open questions** section instead of choosing.

Write the draft in the session scratchpad until step 7.

### 3. Gap check

Read **every** tome in full against the draft. Split the tomes across parallel agents (about six tomes
each) with a brief that gives them the draft, the entry format, and these rules: report only genuine
gaps (not rephrasings), check every candidate in code with `file:line` actually opened, search the
findings and hypotheses before choosing a status, and return (A) missing invariants in the entry
format, (B) corrections to existing entries with evidence, (C) one line per tome read. Agents read
only; they edit nothing.

Merge the results yourself: combine duplicates across agents, check any correction to an entry you
wrote before accepting it, and show the user the combined list of additions and corrections before
merging them.

### 4. Split

Inside each area, put every entry under one of two subsections (entries become `####`):
- **Baseline:** the protocol's own claims and standard properties any reader of the code or spec would
  write down (access gates, set-once wiring, fee caps, conservation of a book).
- **From our research:** properties that came out of this engagement's own work. Each gets a
  **Why it takes research** line: what an agent reading the code alone would miss.

Judge by the statement, not by the status: a broken invariant can be baseline, and a held one can be
research.

### 5. Verify [confirm]

Take every **claimed-unverified** entry and settle it. Split them by area across parallel agents with
the full entry text and these rules:
- Grep every writer of the quantities involved and look for a reachable counterexample: a sequence of
  permissionless or role actions after which the statement is false.
- Check whether the statement itself is wrong (true only with an unstated exception, a tautology, an
  equality that is really an inequality).
- Write a test only when the verdict depends on numbers or reachability, in the project's PoC folder
  with a name that marks it as an invariant check; delete it if it does not compile (other sessions
  share the folder).
- Search the findings, peer issues and known issues before calling anything broken.
- Edit nothing: no list, tome, finding or hypothesis.

Each entry gets one verdict from `references/entry-format.md` (stands, stands with caveat, broken,
mis-stated, inconclusive). Write all results to a separate notes file next to the published list
(e.g. `grimoire/report-deliverables/<protocol>-invariants-verification.md`), never into the list.
Present the summary: which break, which are mis-stated, which hold with a caveat. Wait for the user.

### 6. Apply [confirm]

On the user's instruction, write the results into the list:
- **Broken:** start the status with **BROKEN — known: <finding, peer issue or known issue>**. Do this
  for every broken entry, not only the newly verified ones. An entry broken only by an unreported
  draft says so ("WIP draft …, not yet reported").
- **Mis-stated:** rewrite the statement (and exceptions if needed), marked "(corrected <date>)", with
  the evidence in the status.
- **Stands with caveat:** add a **Caveat:** line under the status.
- **Stands:** status becomes plain **held**. Do not label entries as "verified"; keep only evidence a
  reader needs (a fork test name and its figures).
- Recount the summary: an entry with a held part and its **own** broken part counts as broken; an
  entry that only points to another entry's break stays held. Reconcile the new totals against the old
  ones (old broken + newly broken = new broken).

### 7. Publish

- **The tome** `grimoire/tomes/active/invariants.md` owns the list. Register it in
  `grimoire/tomes/LINKS.md` (an owner row, the `INV-<AREA>-<n>` ID family in the legend, and the tome
  as a copy in each topic row it restates), and log it in `grimoire/tomes/SESSIONS.md`.
- **The shareable file** `grimoire/report-deliverables/<protocol>-invariants.md` is regenerated from
  the tome, never edited by hand: a reader-facing header (what an entry holds, the status counts, what
  the BROKEN tag and the Caveat line mean, the two subsections), workspace paths kept but explained,
  wiki-links and the internal reading log removed. Every invariant stays word for word. Regenerate it
  whenever the tome changes, and tell the user to re-share it.

---

## Adding new research (after the list exists)

When a new tome, finding or result lands and the user asks whether it brings new invariants:

1. Read the new research in full, and read the **whole** existing list: new research can prove an
   existing invariant wrong, narrow it, or improve its evidence.
2. Search findings, peer issues and known issues for each candidate before calling it new or
   untested. A property a peer issue already proves is "BROKEN — known: <issue>", even if the new
   tome calls it "derived, not tested"; point that out so the tome can be corrected too.
3. Write everything to a **new, separate file**, e.g.
   `grimoire/report-deliverables/<protocol>-invariants-additions-<date>.md`. **Never edit the existing
   list or its shareable copy.** The file holds:
   - **New invariants** in the entry format, with the next free ID per area and the subsection each
     belongs in.
   - **Flags on existing invariants:** for each entry the new research may prove wrong or improve, a
     flag with the entry ID, what the research shows, the evidence, and a proposed rewording. The
     existing entry is not touched; the flag is how the user learns it may need readjusting.
   - **Not included:** anything that rests on a result that conflicts with existing evidence (a model
     against a fork test), with the conflict stated.
4. Show the user the additions and the flags. Nothing moves into the list until the user decides.

## Rules

- No formal-verification syntax anywhere in the list. Plain sentences only.
- Every protocol symbol is explained in parentheses where it is used (also in console answers).
- Check `grimoire/tomes/LINKS.md` before editing any tome; update an owner and its copies together.
- Verification notes, additions and flags live in their own files; the list changes only on the
  user's word.
- Never create a finding or a hypothesis from this skill; report the result and let the user decide.
- Never mark entries "verified"; a passing entry reads "held".
- Keep a backup of the tome in the scratchpad before any bulk edit (steps 3, 6), and say where it is.
