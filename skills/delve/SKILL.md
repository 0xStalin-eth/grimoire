---
name: delve
description: >-
  This skill should be used when the user says "delve", "/delve", "review the
  research", "what was interesting", "surface odd behavior", "what did the agents
  find odd", "show me the leads", or wants to see what autonomous security research
  turned up that deserves a human look. Delve is a report for the operator. It
  surfaces substantiated oddities, near-misses, unresolved mechanisms, and
  suspicious patterns so the operator can decide what to explore. It does not pick
  research directions, and it is not for agents to choose their next task.
user_invocable: true
---

# Delve

Review completed security research and surface interesting behavior to the operator.

## Who Delve Is For

Delve is for a human operator. It is not a planning step for autonomous research.

When an operator runs research manually, they learn the system as they go. They
notice what is odd, what almost broke, and what nobody could explain. When agents
do the research, that learning is lost. Delve recovers it. It collects the odd
behavior the agents saw and gives it back to the operator in a form they can absorb.

The operator then applies their own intuition and research taste. Bugs are often
found near delve topics, but the operator chooses which topic, and how deep.

The usual sequence:
1. Set up autonomous research and let it run.
2. Run `/delve` to see what was interesting.
3. Use `/dig-mode` to learn how the interesting behaviors fit together.

If you are an agent doing autonomous research and you reached this skill while
looking for your next task, stop. Delve does not answer that question. Use your
own research plan.

## What Delve Does Not Do

- It does not promote leads to findings.
- It does not recommend which lead to pursue.
- It does not start the investigation of a lead.
- It does not route leads to other skills.
- It does not plan or steer research.

Delve ends when the board is presented. What happens next is the operator's call.

## Philosophy

Interesting behavior is not a vulnerability. It is a signal that the system has
complexity, tension, or unexplained constraints near a security boundary.

Delve should be curious but disciplined:
- Do not bury strange behavior just because it is not yet exploitable.
- Prefer concrete observed behavior over vibes.
- Preserve why the behavior caught attention.
- Preserve what the agents did and did not verify.

## What Counts As Interesting

Look for behavior that is concrete, security-relevant, and not already resolved:

| Signal | Examples |
|--------|----------|
| Odd mechanism | Special-case accounting, unusual fallback, duplicated logic, unexplained threshold |
| Boundary tension | Trust changes, implicit authorization, offchain/onchain mismatch, admin escape hatch |
| Near miss | Exploit path blocked by one check, invariant preserved by fragile ordering |
| Inconsistency | Docs disagree with code, tests imply a different model, two modules handle the same case differently |
| Fragile assumption | "This can never happen", single trusted actor, assumed ordering, assumed external behavior |
| Impact proximity | Behavior touches funds, identity, authorization, governance, pricing, secrets, or availability |
| Research residue | Agent dismissed a path but left open questions or unverified assumptions |

Avoid leads that are only style preferences, generic complexity, or unsupported suspicion.

## Workflow

When this skill is activated, create a todo list from these steps. Mark each task
in_progress before starting it and completed when done.

```text
- [ ] 1. Gather research artifacts
- [ ] 2. Extract interesting behaviors
- [ ] 3. Separate findings, leads, dead ends, and notes
- [ ] 4. Rank leads by security promise
- [ ] 5. Present the delve board
```

### 1. Gather Research Artifacts

Read `GRIMOIRE.md` if it exists. Then inspect relevant research output:
- Current conversation or agent transcript, if available
- `grimoire/tomes/`
- `grimoire/findings/`
- `grimoire/sigil-findings/`
- `grimoire/cartography/`
- `grimoire/spells/`
- Test output, PoCs, notes, or temporary research artifacts

If the user points to a specific agent run, transcript, file, branch, or topic, focus
there first.

Completion criterion: you know what research was performed, what was proven, what was
dismissed, and what remained odd.

### 2. Extract Interesting Behaviors

For each candidate lead, capture:
- The observed behavior
- Where it appears
- Why it is interesting
- What asset, invariant, or trust boundary it might touch
- What blocked it from becoming a finding
- What evidence is missing

Keep claims calibrated. Use "observed", "suggests", "unverified", or "unknown"
instead of vulnerability language.

### 3. Separate Findings, Leads, Dead Ends, And Notes

Classify each item:

| Class | Meaning | Where it goes |
|-------|---------|---------------|
| Finding | Substantiated vulnerability or control failure | Listed under Guardrails, not on the board |
| Lead | Interesting behavior with plausible security relevance but insufficient proof | Delve board |
| Dead end | Checked path with evidence it is not exploitable | Listed under Guardrails, not on the board |
| Note | Durable context without a clear attack direction | Mentioned only if it explains a lead |

Do not dilute the delve board with confirmed findings or already-closed dead ends.

### 4. Rank Leads By Security Promise

Rank each lead on four axes:

| Axis | Values | Meaning |
|------|--------|---------|
| Impact proximity | High, Medium, Low | How close the behavior is to assets or security properties |
| Weirdness | High, Medium, Low | How surprising or unexplained it is relative to the system model |
| Evidence quality | High, Medium, Low | How concrete the current observation is |
| Next-step clarity | High, Medium, Low | Whether there is an obvious check to confirm or refute it |

Ranking orders the board. It is not a recommendation. A boring-looking edge near
money or authority often ranks above a fascinating edge in harmless code, but the
operator may disagree, and that is the point.

### 5. Present The Delve Board

Present 3-7 leads unless fewer exist. Use this format:

```markdown
## Delve Board

| Lead | Why it matters | Evidence | Missing proof | Open check | Priority |
|------|----------------|----------|---------------|------------|----------|
| [short name] | [asset/invariant/boundary] | [paths or observations] | [gap] | [what would confirm or refute] | [High/Med/Low] |
```

Where leads touch the same mechanism, asset, or actor, say so in one line. The
operator uses this to see the shape of the system, not to pick a lead.

If no good leads exist, say so directly and summarize the strongest dead ends or notes.

Then stop. Do not recommend a lead. Do not offer to investigate. Do not ask which
lead the operator wants.

## Output Format

```markdown
## Research Reviewed

- [Artifacts, transcripts, files, or agents reviewed.]

## Delve Board

| Lead | Why it matters | Evidence | Missing proof | Open check | Priority |
|------|----------------|----------|---------------|------------|----------|
| [short name] | [security relevance] | [source-backed observation] | [gap] | [what would confirm or refute] | [High/Med/Low] |

## Connections

- [Leads that share a mechanism, asset, or actor, one line each. Omit if none.]

## Guardrails

- Findings already substantiated: [list or "none"]
- Dead ends not worth re-opening: [list or "none"]
- Claims that remain unverified: [list]
```

## Key Principles

- Delve reports to a human. It does not steer agents.
- Leads are not findings.
- Every lead needs a concrete observation.
- The best leads are near assets, invariants, trust boundaries, or privileged actions.
- Odd behavior deserves preservation even when it is not yet exploitable.
- The operator chooses where to go next. Delve makes that choice informed, then stops.
