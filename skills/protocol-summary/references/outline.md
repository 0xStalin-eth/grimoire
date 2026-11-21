# Outline and Sources Map

## Default outline

A starting order for a build. Adapt it: drop what doesn't apply, rename sections after the protocol's
own concepts, and add sections for its own mechanisms. Order sections so each depends only on earlier
ones: what the system is, then what it holds, then how value moves, then what can go wrong, then who
controls it.

| # | Section | What it answers |
|---|---|---|
| 0 | (untitled opening paragraph) | What the protocol does, for whom, and where its capital and revenue come from |
| 1 | Architecture | The deployable contracts, one line each: what each holds and does; the framework it builds on |
| 2 | Tokens and assets | Each token: who mints it, who holds it, what it is a claim on |
| 3 | Pricing | How each price or rate is formed, its unit, and what moves it |
| 4 | Core flows | The user-facing operations (deposit, swap, borrow, redeem…) end to end, including slippage protection |
| 5 | Actors | Each class of participant (liquidity providers, keepers, issuers…): what they put in, earn and how they leave |
| 6 | Books and ownership | Whose money sits where; how pooled balances are split between owners |
| 7 | Regimes | How the system behaves in each market state (price up / down, high / low utilization), with an example each |
| 8 | Yield and revenue | Where returns come from, who receives them, and how they turn into withdrawable funds |
| 9 | Fees | Every fee: payer, base, bound, launch value, recipient; and which charges are prices, not fees |
| 10 | Losses | How a loss is detected and booked, the order of who absorbs it, and what happens when it exceeds every buffer |
| 11 | Seniority | The claims ranked by who bears a loss first, and how gains flow back (or don't) |
| 12 | End of life | Termination, shutdown, wind-down or migration: triggers, who can call them, and how the remaining funds split |
| 13 | External dependencies | Oracles, bridges, yield venues, issuers: what is trusted and what happens when each fails or goes stale |
| 14 | Governance | Each role, what it can do, its delays and vetoes, and what is immutable |

## Sources map

`grimoire/report-deliverables/protocol-summary.sources.md` records where each section's claims came
from and where they were verified, so a later check knows which sections a changed note affects. It is
an audit working file and is never copied into the report.

```markdown
# Protocol summary sources

| Section | Research | Verified in code | Checked |
|---|---|---|---|
| <section heading> | tomes/active/<tome>.md#<section>; hypotheses/invalid/<name>.md; client-communication/<file>.md Q<n> | `<path>:<line>` (<claim>); `<path>:<line>` (<claim>) | <YYYY-MM-DD> |
```

- One row per `###` section; `####` subsections share their parent's row unless they have their own
  sources.
- **Research** lists every note a claim came from: a tome section, a hypothesis file, a delve lead, a
  client answer, a finding.
- **Verified in code** lists each code location checked, with the claim it supports in a few words.
- **Checked** is the date the section was last verified. Update it whenever the section is written or
  re-checked.
