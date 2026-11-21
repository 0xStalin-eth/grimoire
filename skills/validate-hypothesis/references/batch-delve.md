# Batch mode: validate every hypothesis of a delve board

Run when the user asks to validate a whole delve ("validate all the hypotheses of this delve", "validate
this delve's hypotheses", "run the delve hypotheses", `/validate-hypothesis --delve [<board>]`). Every
hypothesis on the board goes through steps 1 to 5 of the single-hypothesis workflow without pausing.
The run ends with one digest: a short **shortlist** that needs the user, and a list of **proposed
closings** the user approves in bulk. The goal is that the user only spends time on hypotheses with a
real signal of being bugs.

Every rule of the single workflow still holds. Two change shape, none is relaxed:
- **The user moves the file.** The batch never moves a hypothesis. It writes `proposed-outcome:` into
  the file; the user's one reply to the digest moves the files (step B5).
- **A measured loss never closes as Invalid.** A hypothesis whose impact ledger has an entry with no
  home always lands on the shortlist, never in the proposed closings.

## B1. Pick the board

1. **Session folder:** `grimoire/delves/$CLAUDE_CODE_SESSION_ID/`. A resumed session keeps its ID, so it
   finds its own folder. If the folder does not exist (the request comes from another session), ask
   for the board path; never guess one.
2. **Which board:**
   - No board named: the board whose header (`# Delve — <YYYY-MM-DD HH:MM>`) is the newest. Use the
     header, not the file's modified time: an edit to an old board must not make it current. A header
     with a date and no time ranks as 00:00 that day; say so if it decides the pick.
   - A focus named ("…of the XXXX delve"): the board whose `Focus:` line or file name matches. Two
     matches: ask which.
   - "All delves of this session": every `board*.md` in the folder.
3. **Its hypotheses:** read them from the board's own `Hypothesis` column. Never from `leads/`, which
   every board in the session shares.
4. **Only open work:** keep a hypothesis only if it is in `hypotheses/WIP/` and its `claimed-by:` is
   empty or this session. Every other one is reported as skipped, with its folder or the session that
   holds it.
5. **Say what was picked, then go on without waiting:** one line, e.g. "Board `board-governance.md`
   (2026-11-18 14:02): 4 hypotheses, 3 open, 1 already closed". A wrong pick costs nothing, because
   the batch only proposes outcomes. If no hypothesis is open, say so and stop.

Claim every open hypothesis (step 1 of the workflow) before any work starts, so a parallel session
sees them as taken. Note `claimed, batch <board>` in each SESSIONS row.

## B2. Stage 1: desk check (no PoC)

For each hypothesis, run step 1 (the "already settled" search), step 2 only as far as the blocking
check, and step 3 (intent). Propose closing it at this stage only on a hard reason, cited:

| Reason | Proposed outcome | Evidence required |
|---|---|---|
| Duplicate of a finding, a findings-repo issue or a closed hypothesis | `invalid: duplicate of <link>` | Same mechanism at the same `path:line` |
| Documented intent for this exact behavior | `expected behavior: <why>` | A docstring, spec line, AUDIT_READINESS caveat, intent-named test or recorded client answer, quoted |
| Needs a parameter value no allowed config reaches | `invalid: <param> range <range> (<file:line>)` | The setter or constructor check that forbids it; never a "realistic value" argument |
| Needs a role the trust model trusts | `expected behavior: trusted <role>` | The GRIMOIRE.md trust assumption it rests on |

Anything else goes to stage 2. When in doubt, stage 2: a closing here skips the PoC, so it needs a
reason a reader can check in one look. Write the reason into `## Notes` (dated, `batch stage 1`).

## B3. Stage 2: proof

Every hypothesis that survives stage 1 runs steps 2 to 5 in full: the trace, every door, the
parameter bounds, the PoC with the three passes (claim, sweep, invariant), the impact ledger, and the
familiar triage, given the evidence and not the verdict.

**Running them in parallel.** Spawn one validator agent per hypothesis (general-purpose, told to
follow this skill's steps 1 to 5 for that one file, to work only in
`$P/isolated-workspace.sh work hyp-<name>`, to write everything into the hypothesis's `## Notes`, and
to stop before step 6). When a validator returns, spawn the `familiar` on that hypothesis yourself; a
subagent may not be able to spawn one. Keep the total under the session's agent guideline: run the
hypotheses in waves if the board is larger. Run it as a Workflow only if the user asked for one in
their own words; otherwise use the Agent tool, or run the hypotheses one at a time in this session.

PoC names already differ per hypothesis (`Hyp<Name>.t.sol`), and each moves into the shared PoC
folder only once it compiles, so parallel validators do not break each other's build.

## B4. Stage 3: sort

Settle each hypothesis's Claim, Impact and ledger homes exactly as in step 6, then sort it:

| Goes to | When |
|---|---|
| **Proposed closing** | All of these hold: the claim is false (or the behavior is documented intent); every ledger entry has a home; the invariant check passed; the familiar independently agrees |
| **Shortlist** | Any of these: the claim is true or partly true; a ledger entry has no home; the invariant check failed; the familiar disagrees; the verdict would be Valid, Reframed or Inconclusive |

Write the result into the file's front matter as `proposed-outcome:` (the same values `outcome:`
takes, plus `shortlist: <one-line reason>`), and add a dated `batch verdict` line to `## Notes`. Leave
`outcome:` empty and the file in `WIP/`.

Split the shortlist by severity estimate (peer-review `references/severity-calibration.md`): **Low and
above** first, **Informational** below it, so informational items do not crowd out real bugs.

## B5. The digest [confirm]

Present one reply:

```markdown
## Batch: <board> (<n> hypotheses, <k> skipped)

### Shortlist: Low and above
| Hypothesis | Why it survived | Severity estimate | PoC (test → result) | Ledger |

### Shortlist: Informational
| Hypothesis | Why it survived | PoC (test → result) |

### Proposed closings
| Hypothesis | Proposed outcome | Reason (`path:line`) | Stage | PoC |

### Skipped
| Hypothesis | Where it is / who holds it |
```

Then wait. The user may:
- **approve the closings** ("close all", or "close all but <name>"): for each approved one, run step 7
  as for a confirmed Invalid or Expected behavior (copy `proposed-outcome:` into `outcome:`, clear
  `proposed-outcome:` and `claimed-by:`, move it, update its SESSIONS row with
  `"<outcome>; batch <board>"`);
- **reopen one**: it moves to the shortlist; clear its `proposed-outcome:`;
- **take a shortlisted hypothesis**: continue it with steps 6 and 7 one at a time, as in the single
  workflow. The batch's Notes already hold the evidence, so step 6 starts from them.

Hypotheses the user has not answered keep `proposed-outcome:` and their claim, so a resumed session
can present the digest again from the files alone.
