# Deliverables

Produce these only when asked. Save files where the project keeps them (look for an existing comments
or findings folder) and show the text in the reply as well.

In every deliverable meant for the tracker or the report, reference other findings as
`[issue-N](<url of that issue>)`, never a bare `#N` (see `finding-best-practices.md`).

## Introductory paragraph

For readers new to the bug. Markdown, ready to paste above the finding's Description.
- Open with a declarative topic sentence that states the main point; no run-in bold headings (see
  `skills/finding/references/finding-best-practices.md`).
- Explain the normal behaviour first, then the case that breaks it.
- Use one small table or worked example with numbers from the PoC.
- End with the consequence in one sentence.
- No unexplained symbols; spell out what each variable means.

## Comment (downgrade, Informational, recovery runbook)

One paragraph, small and concise, starting with a bold verdict ("**Suggest Informational.**").
Include only the decisive arguments: preconditions, recovery path and its cost, bound, scope. If the
user may close the report with it, phrase the recovery as a runbook step.

## Full rewrite

Follow the format of the finding the user names (or the project's submitted findings):
- front matter (`title`, `severity`, `type`, `context` with `file:line` ranges) if the project uses it;
- Description that explains the mechanism before the bug, in paragraphs that each open with a
  declarative topic sentence (no run-in bold headings);
- Preconditions and attacker class, Impact bullets, a Severity paragraph;
- a worked example with a table;
- an embedded or `@`-referenced PoC that is standalone and passes, with the run command;
- a verified mitigation diff, labelled as guidance if that is the project's convention, with the
  invariant it relies on and the variants that need it;
- References.

Remove the source issue link only if the user asks (for example when submitting it as a new finding),
and warn if the rewrite is a duplicate of the source issue.

## Co-assignee note

Two to four sentences: "Adding myself as co-assignee." Then what the user added that the original
lacks (a new impact, a PoC, a verified fix), with one concrete number. If the user found it
independently, mention the draft date. Focus on the strongest addition when asked.

## Session marker

A block that a later search can find (use the template in `examples/session-marker-template.md`):
finding number and title, author, role of this session, verdict, the artifacts created (paths),
open items, date. Write a corrected marker if a later turn changes the verdict.

## Pending-reviews tome entry

For parked findings and new leads (template in `examples/pending-tome-template.md`): status, mechanism
with `file:line`, what is already proven (PoC paths and figures), related findings, and numbered leads
from most to least promising. New leads go at the top when the user says they'll start there.

## Mitigation diff

Show the verified diff with clean paths. Say what was verified (PoC results, regression comparison),
what the other variants need, and any invariant or caveat. If the user asks for a design without
implementation, label it a sketch and compare it with the tested option.
