# Duplicate Analysis

## The test

Two findings are **duplicates** when both hold:
1. **Same root cause**: the same wrong assumption or missing step, not merely the same function.
2. **Same fix**: one change closes both.

Everything else is **related**: same function, same symptom, same theme, opposite directions of the
same tracker, or two bugs whose fixes touch the same lines. Related findings get a cross-reference,
and often a note that their fixes must land together.

## How to check

For each candidate (from the duplicates index, a grep of the mirror for the same `file:line`, and the
findings that mention the same state variables):

1. Write each root cause in one sentence. If the sentences differ in *what is wrong*, not just *where*,
   they are probably distinct.
2. Ask what each fix does to the other finding's PoC. When cheap, run it: apply fix A, run PoC B.
3. Check direction. A tracker that is wrong **too high** in one finding and **too low** in the other is
   two bugs, even on the same variable.
4. Check triggers. "Fee or loss writes down X" and "price path writes down X" are different triggers;
   if the fixes differ, they are different findings.

## Symptom vs root

A finding is a **symptom** of another when the other's fix removes it. Example pattern: a protected
bucket that never absorbs losses can show up as a revert in one state, an inflated claim in another, a
blocked price update in a third, and a failing payout in a fourth. One change (writing the bucket down
when nothing backs it) closes all four. Present those as a cluster:

| Condition | Symptom | Finding |
|---|---|---|
| state A | revert | #a |
| state B | inflated claim | #b |
| ... | ... | ... |

Then name the single fix and say which local fixes become defence in depth.

## The user's own findings

Always check whether the finding under review duplicates something the user filed, drafted, or is
about to submit:
- **The user filed later with the same root**: the user's issue will be closed as a duplicate. Move
  its extra impact (a stronger scenario, a cross-instance effect) into an additional-impact comment on
  the earlier issue, close the user's issue, and add the user as co-assignee.
- **The user has an unsubmitted draft**: don't submit it separately. Use it to rewrite or extend the
  filed finding, and justify the co-assignment by what it adds.
- **The user's rewrite of a finding**: it is a rewrite, not a new finding, even if the PoC and numbers
  differ. Keep the source link.

## When a judge might merge broader

Mention it when a broad framing could swallow several findings ("trackers don't keep a cost basis"),
and argue for or against the merge using the fix test. Keep groups the project's duplicates index
already separates unless a fix test shows otherwise.
