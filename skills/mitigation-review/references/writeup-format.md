# Write-up Format

The write-up goes in the report's `**Cyfrin:**` field. Keep it **short and in plain words**. The
review file holds the detail; the write-up only states what changed and why it closes the issue.

## Rules

- Open with the verdict word: `Verified.`, `Partially fixed.`, `Acknowledged.`, `Not fixed.`
- Paragraph 1 (1–3 sentences): what the code does now, naming the function, and the effect on the
  finding's scenario. Use `Contract::function` and backticks for identifiers.
- Paragraph 2 (optional, 1–3 sentences): residual notes or a recommendation. Only for something the
  client should act on. Use "Consider …".
- No PoC details, no line numbers, no commit hashes, no internal reasoning chains.
- No hedging adjectives ("robust", "comprehensive"). Prefer simple verbs.
- Respect the thread: if the client and Cyfrin agreed something (accepted behaviour, severity), state
  it briefly as context ("As agreed, …"), don't argue it.
- Default length: 1–3 sentences. The user often asks for "shorter" — when in doubt, start short.

## Shapes

**Fixed:**
> **Cyfrin:**
> Verified. `Router::_findAndWithdraw` now skips priority entries that are not tracked in
> `_positionIndex`, mirroring the guard in `SiblingRouter`. A donated, untracked position can no longer
> be selected, so withdrawals fall through to tracked positions.

**Fixed for part of the scope:**
> **Cyfrin:**
> Verified for `AdapterA`: `allocate` now only accepts a vault allocator. `AdapterB::allocate` still
> accepts the owner. This is documented and has no impact, since the vault only lets allocators call
> `allocate`.

**Partially fixed:**
> **Cyfrin:**
> Partially fixed. `setRewardInterval` now reverts below 1 day, so the drip can no longer be
> configured off. The interval still defaults to 0 at deployment, so a reward recorded before it is set
> is released in one block. Consider reverting in `recordReward` when the interval is 0, or setting it
> in the constructor.

**Acknowledged:**
> **Cyfrin:**
> Acknowledged. `totalAssets` intentionally remains fail-closed; `IAdapter` now documents that an
> underlying vault whose valuation reverts halts the parent vault until it recovers or the adapter is
> removed.

**Rename / trivial:**
> **Cyfrin:**
> Verified. The helpers were renamed to `_requireAllocatorOrOwner` / `_isAllocatorOrOwner`, matching
> the roles they actually admit.

## Follow-up asks that recur

- **"Shorter" / "simpler wording"** — cut to the verdict + one sentence of mechanism; replace jargon
  with plain verbs.
- **"In md format"** — give the raw markdown in a fenced block so it pastes cleanly.
- **"Write the recommendation as if it led to the mitigation"** — rewrite the report's
  `**Recommended Mitigation:**` section so it prescribes the approach the client actually shipped, in
  the same style as the report's other recommendation sections (imperative, references the functions,
  optional diff).
- **"Propose hardening to the client"** — short md with numbered proposals, each one sentence of why
  plus a minimal diff. Keep proposals non-invasive.
- **"Justify X"** — one paragraph: the gap, how it's exploited, what X changes.
