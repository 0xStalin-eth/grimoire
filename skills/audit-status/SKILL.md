---
name: audit-status
description: >-
  This skill should be used when the user says "audit status", "/audit-status", "what's next",
  "what else is worth reviewing", "where should I focus", "what's left", "what areas are worth
  re-checking", "what should I work on now", "status of the audit", "plan the next work", or wants an
  overview of where a security engagement stands and a ranked list of what to do next. It reads the
  whole Grimoire workspace (hypotheses, findings, known issues, peer findings, delve boards, tomes),
  reconciles the bookkeeping, harvests residual risks left in closed work, finds leads nobody has
  covered, ranks the open work and routes each item to a skill and a session. It reads and plans
  only. Not for surfacing leads from agent research (use /delve), exploring one lead (use
  /validate-hypothesis) or writing one down (use /write-hypothesis).
user_invocable: true
---

# Audit Status

Tell the operator where the engagement stands and what to do next, ranked, with the skill and the
session for each item. Run it at any point: after a batch of validations, at the start of a day, before
the report.

## What it does not do

- It never closes, moves, claims or edits a hypothesis or finding, and never writes `SESSIONS.md`.
- It never starts the work it recommends. It ends when the report is presented.
- It does not re-derive verdicts. A closed hypothesis stays closed; only what its Notes left open is
  surfaced.

The one file it writes is its own snapshot (step 7).

## Modes

| Invocation | Scope | Cost |
|---|---|---|
| `/audit-status` | Steps 1–3, 5–7 | A few minutes, no subagents |
| `/audit-status full` | Adds step 4 (lead coverage) | Fans out one subagent per tome group |
| `/audit-status <area>` | Any mode, filtered to one component or tome | Proportional |

## Inputs

| Input | Where |
|---|---|
| Scope, actors, components | `GRIMOIRE.md` |
| Hypotheses and their history | `grimoire/hypotheses/{WIP,valid,invalid}/`, `grimoire/hypotheses/SESSIONS.md` |
| Findings | `grimoire/findings/{WIP,valid,invalid,archived}/`, `findings/WIP/informationals/`, `grimoire/sigil-findings/` |
| Known issues and peer findings | `grimoire/findings/original-findings/` (known-issues list, mirrored peer issues) |
| Leads | `grimoire/tomes/active/*` (Leads, Ideas, Open questions sections), `grimoire/delves/*/board*.md` |
| Client questions | `grimoire/client-communication/` |
| Last snapshot | `grimoire/audit-status/` (newest file) |

Missing folders are skipped and named in the report. If `GRIMOIRE.md` or `grimoire/hypotheses/` is
missing, stop and suggest `/summon`.

---

## Workflow

Create a todo list from these steps.

```
- [ ] 1. Snapshot the state
- [ ] 2. Reconcile the bookkeeping
- [ ] 3. Harvest residuals from recent work
- [ ] 4. Lead coverage (full mode only)
- [ ] 5. Spot thin areas
- [ ] 6. Rank and route
- [ ] 7. Report and save the snapshot
```

### 1. Snapshot

Run the state script from the workspace root:

```bash
<this-skill>/scripts/state.sh grimoire
```

It prints folder counts, the latest `SESSIONS.md` row per hypothesis by status, and the flags used in
step 2. Then read the newest file in `grimoire/audit-status/`, if any, and note what changed since it:
hypotheses opened, closed (and as what), findings added.

### 2. Reconcile

From the script's flags:
- `DRIFT`, `GHOST`, `DUP`, `ORPHAN`: bookkeeping to fix. List the exact `session-status.sh` command the
  operator would run for each (`<summon>/scripts/session-status.sh`); do not run it.
- `VERDICT`: WIP hypotheses whose PoC or triage is finished and that wait only for the user. Read each
  file's last Notes entry and give the proposed verdict and its one-line reason.
- `STALE`: claims idle past the threshold. Read the last Notes entry: blocked (on what), forgotten, or
  done but not logged.

### 3. Harvest residuals

Closed work leaves new leads in its Notes. For hypotheses updated since the last snapshot (or the last
7 days on a first run), in every folder, grep the Notes and outcome tables for:

```
untested | not run | not tested | not exercised | residual | doubt | spin-off | spun off | candidate
| pending K | asked the client | open:
```

Keep an entry only if no other hypothesis, finding or known issue already covers it (check by
mechanism and `path:line`, not by title). For each kept entry record: the source file, the one-line
risk, and the session that raised it.

Also scan `findings/valid` and `findings/WIP` for loose ends that would embarrass a shipped finding: an
open outcome, an unexplained figure, a "to confirm".

### 4. Lead coverage (full mode)

Split the tomes into groups of 3–5 and spawn one read-only subagent per group (`Explore` or
`general-purpose`). Brief each with:
- its tome files, and the paths of `hypotheses/`, `findings/` and the known-issues / peer-issues files;
- the task: for every lead, idea or open question in its tomes, classify it as **covered** (link the
  hypothesis or finding), **known** (link the known issue or peer issue), **answered** (a tome or
  client answer settles it; link it), or **uncovered**;
- for each uncovered lead: the asset at risk, the suspected mechanism, the `path:line` from the tome,
  and why it may be valid, in at most four lines;
- to verify a claimed match by mechanism, not by keywords, and to report a lead as uncovered when
  unsure.

Merge the results. Drop uncovered leads that two groups reported as the same mechanism into one.

### 5. Thin areas

From `GRIMOIRE.md`'s in-scope components, count the hypotheses and findings that touch each (by the
paths in their **Code** sections). Name the components with the fewest relative to their size or risk.
For each, suggest one concrete next move: a delve group, a sigil pattern, or a check.

### 6. Rank and route

Rank every item from steps 2–5 with `references/ranking.md`. For each item give:
- what to do, in one line, with the asset at risk;
- the skill to run (`/validate-hypothesis <name>`, `/write-hypothesis`, `/finding-draft`, ...);
- the best session: the session ID from `SESSIONS.md` that last worked the same mechanism or code
  (it holds the harness and the reasoning). Report the 8-character ID prefix. Do not guess which open
  terminal tab is which session; peer-session listings show names, not IDs.
- a cost hint: minutes, one session, or a delve.

When a lead is the same mechanism as a hypothesis just closed as expected behavior, say so and state
the one difference that could make it land; otherwise drop it.

### 7. Report and save

Print the report (format below), then write the same content to
`grimoire/audit-status/<YYYY-MM-DD-HHMM>.md`. Never overwrite an earlier snapshot.

```markdown
# Audit status — <date>

**Since last status (<date>):** <closed N (as what), opened M, findings +K> | first run

## Where things stand
<counts table; one line on the phase: early / middle / late>

## Verdicts and bookkeeping owed
| Item | State | Proposed action |

## Residual risks from recent work
| Risk (asset, mechanism) | Raised in | Best session | Skill |

## Uncovered leads            (full mode)
| Lead | Asset at risk | Source | Why it may be valid |

## Thin areas
| Component | Hypotheses / findings | Suggested move |

## Next, in order
1. <item> — <skill> — session <id8> — <cost>
...

## Can be dropped if time runs out
<late phase only: the open items with the least expected value, and why>
```

Rules for the report:
- Follow any project rule about explaining terms (for example in `GRIMOIRE.md` or the user's memory):
  explain each domain symbol where it is first used.
- Every claim about a file's state cites the file. Every proposed verdict cites the Notes entry it
  rests on.
- Keep it scannable: tables and one-line items; detail lives in the linked files.
