# Grimoire: How-To-Use Manual

## What Is Grimoire?

Grimoire is a Claude Code plugin that structures your security research workflow — from initial codebase exploration through finding discovery, PoC writing, and building a personal library of reusable detection patterns.

**Install:** `claude --plugin-dir /path/to/grimoire`

---

## The Research Workflow

Grimoire's skills map directly onto the stages of a security engagement:

```
New Codebase → summon → cartography → annotation + checks
                                            ↓
                                   finding-draft → write-poc
                                            ↓
                                   scribe-distill → (reuse later)
```

---

## Stage 1: Initialize a New Codebase

### `/summon`

Run this first on any new codebase. It creates your `GRIMOIRE.md` — the living contextual map that all other skills use as their foundation.

**What it does:**
- Builds an audit directory structure
- Maps the architecture and identifies crown jewels (high-value targets)
- Writes `GRIMOIRE.md` — a structured summary of the protocol
- Surfaces automation opportunities
- Can spawn a sigil swarm for initial vulnerability hunting

**When to use:** Once per engagement, at the start.

---

## Stage 2: Map Code Flows

### `/cartography`

Explore and document specific code paths you want to understand deeply. Creates indexed YAML-frontmatter files that act as pointers to code (not explanations).

**Seeded:** Point it at a specific function/flow
**Unseeded:** Let it discover flows via subagent swarms

**Output format:** `path/to/file:symbol` notation — designed to be machine-readable for other skills.

### `/review-cartography`

Verify and update existing cartography files when code changes. Extends missing pieces, adds conditional execution paths, cross-references related flows.

### `/gc-cartography`

When you accumulate many flows, this detects overlaps (>40% component overlap triggers a flag) and merges duplicates. Keeps the flow library clean.

---

## Stage 3: Discover Vulnerabilities

### `/annotation`

Scans the codebase for `@audit` tags left by auditors or developers. Returns structured JSON with file, line, tag, content, and surrounding context.

**Use early** to catch already-flagged concerns.

### `/checks`

Create and apply vulnerability pattern checks against the codebase. Each check is a simple, targeted query.

**Philosophy:** "Many simple checks beat one complex check."

**Modes:**
- **Create** — define a new check for a pattern you've identified
- **Apply** — run existing checks against the codebase
- **Manage** — organize your check library

---

## Stage 4: Document Findings

### `/finding-draft`

When you spot a vulnerability, use this to create a properly structured finding. It handles:
- Title construction (where/how/what rule)
- Severity estimation
- Vulnerability type classification
- All standard sections (description, impact, recommendation, PoC reference)

### `/finding-review`

Review an existing finding against best practices. Invokes a familiar agent for triage and a librarian for reference validation. Use before finalizing findings.

### `/finding-dedup`

When findings pile up, this identifies duplicates and similar issues. Classifies pairs as:
- **Duplicate** → delete one
- **Similar** → merge or cross-reference
- **Distinct** → keep both

---

## Stage 5: Write Proof-of-Concept

### `/write-poc`

6-phase workflow for writing exploit code:

1. Gather vulnerability details
2. Define the exploit flow
3. Determine PoC approach
4. Write the PoC (via gnome agent)
5. Review (via familiar agent)

**Core principles:**
- **Minimum viable proof** — demonstrate the issue exists, nothing beyond that
- **Benign payloads only** — `alert(1)`, `sleep()`, `id` — never destructive
- **Parameterized targets** — localhost + variables, never hardcoded production URLs

Integrates with `forge-poc-templates` (Immunefi's Solidity PoC library, included as a submodule).

---

## Stage 6: Build Your Detection Library

### `/scribe-distill`

Transforms a finding into a reusable detection module. Extracts the generalizable vulnerability pattern so you can find the same class of bug in future codebases automatically.

**Output:** A `checks` file or knowledge artifact added to your spellbook.

### `/scribe-gc`

Deduplicates your sigil library when detection modules start overlapping.

### `/scribe-utilities`

Query your spellbook: list, describe, get stats, or search across your accumulated detection modules.

---

## Typical Engagement Flow

```
Day 1 — Orientation
  /summon                    → get GRIMOIRE.md, understand the protocol
  /annotation                → catch flagged code immediately
  /cartography               → map the core flows (e.g., deposit/withdraw, price calculation)

Day 2–N — Research
  /checks                    → run vulnerability pattern checks
  /cartography               → map flows as you discover them
  /finding-draft             → document each issue as you find it

Final Day — Polish & PoC
  /write-poc                 → for each critical/high finding
  /finding-review            → validate all findings
  /finding-dedup             → clean up duplicates

Post-Engagement
  /scribe-distill            → turn your best findings into detection modules
  /gc-cartography            → clean up flow library
  /scribe-gc                 → deduplicate your sigil library
```

---

## Key Concepts to Internalize

**Trivial verifiability** — Every finding needs a concrete artifact proving it exists. If you can't prove it, it's a hypothesis, not a finding.

**GRIMOIRE.md is your anchor** — Most skills read this file for context. Keep it updated if the codebase changes significantly mid-engagement.

**Cartography files are code pointers, not explanations** — They use `file:symbol` notation so agents can navigate precisely, not prose descriptions.

**Checks compound over time** — Each `/scribe-distill` run makes your future engagements faster. The library grows with every audit.
