---
name: token-guide
description: Reference guide for token-efficient .claude/ directory design patterns
user_invocable: false
tools: [Read]
---

# Token Efficiency Guide

## How Claude Code Loads Context

```
Every conversation starts by loading:
1. CLAUDE.md (project root)           ← ALWAYS loaded
2. CLAUDE.md (.claude/ directory)      ← ALWAYS loaded
3. rules/*.md                          ← ALWAYS loaded
4. Skill/agent descriptions (names)    ← ALWAYS loaded (just the index)

Loaded on-demand (only when triggered):
5. skills/*/SKILL.md                   ← when /command is invoked
6. agents/*.md                         ← when Agent tool selects it
7. Memory files                        ← when relevant context detected
```

## Cost Model

| Category | When Loaded | Cost per Conversation |
|----------|-------------|----------------------|
| CLAUDE.md | Always | Every single conversation |
| rules/*.md | Always | Every single conversation |
| Skill index | Always | Minimal (name + description only) |
| SKILL.md body | On trigger | Only when /command runs |
| Agent .md body | On delegation | Only when agent is spawned |
| Memory files | On relevance | Only when memory system activates |

## Token Estimation

- 1 line of markdown ≈ 10-15 tokens (average)
- 1 line of code block ≈ 12-18 tokens
- 1 empty line ≈ 1 token
- 1 table row ≈ 15-25 tokens

### Budget Guidelines

| Always-loaded | Rating |
|---------------|--------|
| < 2,000 tokens | Excellent |
| 2,000 - 4,000 | Good |
| 4,000 - 6,000 | Needs optimization |
| > 6,000 | Critical — actively wasting tokens |

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
