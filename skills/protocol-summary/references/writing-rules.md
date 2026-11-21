# Writing Rules

How the protocol summary reads. These rules apply to every section, in every mode. The examples use
placeholder names; replace them with the protocol's own.

## Audience and vocabulary

- **Write for the report reader.** They know DeFi in general, not this protocol, and they have not
  seen the code or the research.
- **No audit vocabulary.** No hypotheses, delves, leads, findings, PoCs, severities, issue numbers,
  kickoff question IDs, test names, `path:line` references or "we found". The summary describes the
  protocol, not the audit.
- **Plain names, not symbols.** Name every quantity in words ("the reserve ratio", "the vault's idle
  balance"). A code name appears only in parentheses after its plain name, and only when the reader
  may need to find it in the code: "the vault's share of each fee (`feeShareBps`)". Never a bare
  math symbol or variable.
- **Functions as `Contract::function`.** Name a function only when the reader gains from it: an entry
  point, a privileged action, a permissionless trigger. Contract names are in backticks.
- **Define each term once.** Bold it where it is first explained: "the **reserve**, the collateral
  beyond what the debt tokens claim". Use the same word everywhere after; never switch synonyms.

## One concept, one home

- Each concept is explained in exactly one section. Before adding text, find the section that owns
  the concept and write there.
- Another section that needs the concept points to it in a clause: "…which is subject to the
  withdrawal limits described under Yield". It does not restate the rules.
- When a section grows a second parallel case (two directions, two regimes, two fee families), split
  it into `####` subsections with a shared lead-in, rather than one long paragraph.

## Paragraphs

- **Open each paragraph with its point.** The first sentence states what the paragraph shows; the
  rest supports it. No run-in bold headings, no question-then-answer framing.
- **State behavior, then consequence.** "Gains are booked to the reserve, never to the idle balance.
  The share price rises at once, but withdrawals are paid only from the idle balance, so…"
- **Quirks are facts.** A behavior that surprised the research is written as a plain statement of what
  happens and, if known, why it is intended. Never "note that", "surprisingly", "be careful".
- **Trade-offs are consequences, not judgments.** "The model therefore depends on the vault's buffer
  staying large relative to the amount deployed", not "this is risky".

## Facts that must always be stated

For every mechanism the summary covers, say where it applies:

- **Who can act.** The role behind each privileged action, and "anyone" for a permissionless one.
- **Bounds.** Caps, minimums, delays, and the launch or default value when it differs from the cap
  ("at most 1%, set to 0.25% at launch").
- **Mutability.** Whether a parameter is fixed at deployment or registration, or can change, and by
  whom; whether the contracts are upgradeable.
- **Direction and unit.** For every rate, price or ratio: its unit ("quoted in tokens per dollar")
  and which way it moves for each event. When the unit makes the direction easy to misread, say so
  explicitly ("when the currency strengthens, this rate falls").
- **Order.** For any sequence (loss stages, payout order, settlement queue): the order, and what is
  never touched.
- **Liquidity versus value.** When a quantity counts toward a price or net value but cannot be paid
  out on demand, say both halves.

## Examples, tables, structure

- **One worked example per non-obvious mechanism**, with round numbers that are easy to check by hand
  ("when the price halves from 200 to 100, a 1,000 deposit mints 2,000…"). Put it in its own
  paragraph, starting "For example,".
- **Tables for comparisons**: components side by side, regimes, fees, ranks. A table row carries
  facts; the explanation stays in prose around it.
- **Headings**: `###` per section, `####` for parallel sub-cases. The file has no `#` title; the
  report adds it. An untitled opening paragraph states what the protocol does, for whom, and where
  value comes from.

## Self-check

Before finishing, check every changed section:

- [ ] No audit vocabulary, no `path:line`, no issue numbers, no test names.
- [ ] Every code name sits in parentheses after a plain name; no bare symbols.
- [ ] Every term is defined once, in bold, before it is used elsewhere; same word throughout.
- [ ] The concept lives in one section; other mentions are pointers.
- [ ] Every privileged action names its role; every permissionless one says "anyone".
- [ ] Bounds, launch values and mutability are stated for every parameter mentioned.
- [ ] Every rate or ratio has its unit and direction.
- [ ] Each paragraph opens with its point; no judgments, only consequences.
- [ ] Every claim was verified in the code in this run, or carried over unchanged from a verified row
      of the sources map.
