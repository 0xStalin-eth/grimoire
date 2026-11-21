# Ranking the next work

`/audit-status` ranks every open item into one ordered list. The order puts cheap, context-hot work
first and broad new exploration last. Tune it here; the skill reads this file.

| Rank | Bucket | Why it goes here | Typical skill |
|---|---|---|---|
| 1 | **Verdicts owed** — WIP hypotheses whose PoC and triage are done and only need the user's call; bookkeeping drift (`DRIFT`, `GHOST`, `ORPHAN`, `DUP`) | Minutes each. Until closed they inflate the open queue and hide what is really open | user verdict; `session-status.sh` |
| 2 | **Fresh spin-offs** — untested risks, residual doubts and spin-off candidates recorded in hypotheses closed in the last few days | The closing session still holds the harness and the reasoning; the cost to resume grows every day | `/write-hypothesis`, then `/validate-hypothesis` |
| 3 | **Open WIP outcomes** — hypotheses with open outcome rows, stalest claim first | Already framed; a stale claim usually means a blocked or forgotten session | `/validate-hypothesis` |
| 4 | **Uncovered leads** — tome leads, idea-list entries, delve leads and kickoff questions with no hypothesis, finding or known issue | New ground; rank inside the bucket by the asset at risk (user funds > protocol funds > liveness > accounting hygiene) | `/write-hypothesis` |
| 5 | **Loose ends on valid findings** — unexplained figures, open outcomes, unfinished severity arguments in findings that will ship | A wrong number in a shipped finding costs credibility; do before reporting | `/finding-review`, `/write-poc` |
| 6 | **Thin areas** — in-scope components with few or no hypotheses or findings | Signals code nobody has attacked; suggest a delve group or a sigil, not a single hypothesis | `/delve` groups, sigils, `/checks` |
| 7 | **Undrafted informationals** — observations recorded as Informational but with no draft | Low value each; batch them | `/finding-draft` |
| 8 | **Wrap-up** — dedup and tome sync, once ranks 1–3 are empty | Keeps the report and the tomes coherent | `/finding-dedup`, `/tome-sync` |

## Tie-breakers inside a bucket

1. Higher expected severity first (use the hypothesis's own "Severity expectation", never a new guess).
2. Items that unblock others (a spin-off two other leads depend on) first.
3. Older claims first in rank 3; newer closures first in rank 2.

## Phase of the audit

- **Early** (few hypotheses, tomes still growing): ranks 4 and 6 dominate; say so and suggest delve groups.
- **Middle**: ranks 2–4.
- **Late** (report due): ranks 1, 5, 7, 8 first; say which open items can be dropped with least risk.
