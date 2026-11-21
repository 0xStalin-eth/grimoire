# Invariant entry format, statuses and verdicts

## The entry

```markdown
#### INV-<AREA>-<n>: <short title: the property, not the bug>
- **Statement:** <one plain-English claim a reader can check against the code; every protocol symbol
  explained in parentheses where first used>
- **Where it applies:** <per currency / per swap / whole protocol / between core and vault ...>
- **Exceptions / tolerances:** <rounding, stated design exceptions, known caveats; "none" if none>
- **Enforcement:** <the check or construction that keeps it, with `file:line`; "none found" if none>
- **Source:** <protocol-claimed (§ / ID) | research: tome § / hypothesis / delve lead / model / test>
- **Status:** <see statuses below, with the evidence linked>
- **Caveat:** <only after verification: an edge or exception the statement does not mention>
- **Why it takes research:** <only in "From our research": what reading the code alone would miss>
```

Rules for the statement:
- It names what must hold, not what is wrong. "No round trip returns more USDC than it paid in", not
  "round trips are profitable".
- It is checkable without knowing the cause of any bug.
- An equality that is really an inequality is written as the inequality.
- Model-derived claims say so in the status ("model-only") until a test confirms them.

## Statuses

| Status | When | How it is written |
|---|---|---|
| **broken** | a finding, peer issue, known issue or test shows a reachable violation | starts with **BROKEN — known: <finding / issue / known issue>**; an unreported WIP draft says "(not yet reported)" |
| **held** | a closed hypothesis, a test, or a trace of every path that could break it shows it holds | `held`, plus the reason or the test name and figures where it is not obvious; never "verified" |
| **untested** | an open hypothesis in `WIP/` covers it | `untested: <hypothesis path>` |
| **claimed-unverified** | stated by the protocol or a tome; nothing has tested it yet | `claimed-unverified` |

Counting for the summary table: an entry with a held part and its own broken part counts as broken; an
entry that only points to another entry's break counts as held.

## Verification verdicts (step 5)

| Verdict | Meaning | What step 6 does |
|---|---|---|
| **Stands** | the code keeps the invariant as written | status becomes `held` |
| **Stands with caveat** | it holds, but with an exception or edge the statement does not mention | status `held` + a **Caveat:** line |
| **Broken** | a reachable state violates it | status starts **BROKEN — known: …** (after searching findings) |
| **Mis-stated** | the invariant as written is wrong: a tautology, an equality that is an inequality, a claim the evidence contradicts | statement rewritten, marked "(corrected <date>)", evidence in the status |
| **Inconclusive** | cannot be settled with the evidence at hand | stays `claimed-unverified`, with what is missing |

Each verdict in the notes file carries: why (2–5 lines with `file:line` actually opened), the
counterexample with numbers if broken or mis-stated, the test path and result or "code reading", and
whether it is already known.

## Additions file (after the list exists)

```markdown
# <Protocol> invariants: additions and flags (<date>)

<one paragraph: what research this comes from; the list itself is unchanged>

| ID | Title | Status |            <- new entries and flags at a glance

## New invariants
<entries in the format above, next free ID per area, subsection noted>

## Flags on existing invariants
### INV-<AREA>-<n>: <title as in the list>
- **What the new research shows:** ...
- **Evidence:** `file:line`, test, model (say which)
- **Proposed change:** <rewording or added exception>; the list entry itself is not edited

## Not included
<results that conflict with existing evidence, with the conflict stated>
```
