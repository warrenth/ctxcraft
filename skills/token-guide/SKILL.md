---
name: token-guide
description: Reference guide for token-efficient .claude/ directory design patterns
user-invocable: false
---

# Token Efficiency Guide

## How Claude Code Loads Context

> Source: code.claude.com/docs/en/memory.md, skills.md, sub-agents.md

```
Loaded at session start (always-on):
1. CLAUDE.md — root, .claude/, ~/.claude/ — plus @path imports (max depth 4;
   imports load at launch, so splitting does NOT save tokens)
2. rules/**/*.md WITHOUT paths: frontmatter (recursive; subdirs and symlinks OK)
3. Skill descriptions (+ when_to_use, truncated at 1,536 chars)
   — except disable-model-invocation skills, which load NO description
4. Auto memory MEMORY.md — first 200 lines or 25KB, whichever comes first

Loaded on-demand:
5. rules/**/*.md WITH paths: frontmatter  ← when Claude reads matching files
6. skills/*/SKILL.md body                 ← when invoked (then stays in context)
7. agents/*.md body                       ← when the subagent is spawned
   ⚠ a spawned subagent also reloads the FULL CLAUDE.md hierarchy + rules
8. Memory topic files, nested CLAUDE.md / nested skills in subdirectories

Not context: hooks/ scripts, scratch/, settings files.
Block-level HTML comments (<!-- -->) are stripped before injection — free for humans.
```

## Cost Model

| Category | When Loaded | Cost per Conversation |
|----------|-------------|----------------------|
| CLAUDE.md + @imports | Always | Every single conversation |
| rules without `paths:` | Always | Every single conversation |
| rules with `paths:` | On file match | Only when matching files are read |
| Skill index (desc + when_to_use) | Always | ≤1,536 chars each; 0 for disable-model-invocation skills |
| SKILL.md body | On invoke | Loads once, then persists in context (official tip: keep under 500 lines) |
| Agent .md body | On spawn | Body + full CLAUDE.md/rules reload per spawn |
| Auto memory MEMORY.md | Always | First 200 lines / 25KB only |

## Token Estimation

- 1 line of markdown ≈ 10-15 tokens (average)
- 1 line of code block ≈ 12-18 tokens
- 1 empty line ≈ 1 token
- 1 table row ≈ 15-25 tokens

### Budget Guidelines

Aligned with the `/evaluate` thresholds (WARN 8,000 / CRITICAL 12,000):

| Always-loaded | Rating |
|---------------|--------|
| < 4,000 tokens | Excellent |
| 4,000 - 8,000 | Good |
| 8,001 - 12,000 | Needs optimization (WARN) |
| > 12,000 | Critical — actively wasting tokens (FAIL) |

Remember: always-on tokens are also reloaded into every spawned subagent's context, so real waste scales with subagent usage.

## Design Patterns

### Pattern 1: Thin Rules, Thick Skills

```
rules/error-handling.md (always loaded — 15 lines):
  - Key constraints only
  - One-liner per rule
  - Reference: "> Deep dive: /error-handling-guide"

skills/error-handling-guide/SKILL.md (on-demand — 200 lines):
  - Full examples
  - Anti-patterns with code
  - Detailed explanations
```

### Pattern 2: CLAUDE.md as Index

```
CLAUDE.md should be a TABLE OF CONTENTS, not a manual.

BAD (300 lines):
  ## Architecture
  [50 lines explaining Clean Architecture...]
  ## Patterns
  [80 lines of code examples...]

GOOD (80 lines):
  ## Architecture
  Clean Architecture: app → domain/data/core
  > Details: rules/architecture.md

  ## Patterns
  Service layer: dependency injection + repository pattern + reactive streams
  > Details: rules/architecture.md, /project-patterns
```

### Pattern 3: Conditional Loading via Skills

Move content that's only relevant to specific tasks into skills:

- Testing rules → `/tdd` skill
- Migration guides → `/migration` skill
- Release checklists → `/release` skill
- Dependency management → `/dep-check` skill

### Pattern 4: Agent over Rules for Complex Logic

If a rule requires >30 lines of explanation with examples, it's better as an agent:

```
rules/code-review.md (10 lines):
  - Review checklist summary
  - "Delegate detailed review to code-reviewer agent"

agents/code-reviewer.md (100 lines):
  - Full review criteria
  - Examples of good/bad patterns
  - Output format
```

## Common Waste Patterns

| Pattern | Waste | Fix |
|---------|-------|-----|
| CLAUDE.md > 200 lines | ~1,500+ tokens/conv | Compress to index |
| Duplicate content in rules + CLAUDE.md | ~500-1,000 tokens | Single source of truth |
| Examples in rules/ | ~300-800 tokens | Move to skills |
| 15+ rules files | ~2,000+ tokens | Consolidate to 5-8 |
| Verbose prose in rules | ~500+ tokens | Convert to tables/bullets |
| Unused skills with long descriptions | Minimal but noisy | Prune or shorten description |
