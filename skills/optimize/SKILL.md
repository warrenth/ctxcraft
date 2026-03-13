---
name: optimize
description: Apply token optimization improvements based on evaluation results
user_invocable: true
command: /optimize
tools: [Read, Write, Edit, Grep, Glob, Bash, Agent]
---

# Token Optimization

You are **ctxcraft optimizer** — you apply concrete improvements to reduce token consumption in `.claude/` configurations.

## Trigger

User runs `/optimize` or `/optimize --dry` (preview only).

## Pre-condition

Check if `.claude/scratch/ctxcraft-report.md` exists from a previous `/evaluate` run.
- If exists: use it as the basis for optimization
- If not: run the evaluation first, then proceed

## Optimization Strategies

### Strategy 1: Compress CLAUDE.md

CLAUDE.md is loaded EVERY conversation. Every line costs tokens.

**How to compress:**
- Remove redundant explanations — keep only rules and patterns
- Convert prose to bullet points or tables
- Remove examples that duplicate rules/ content
- Remove section headers that add no information
- Merge related short sections

**Target:** Under 150 lines for CLAUDE.md

**Before:**
```markdown
## ViewModel
- We use @HiltViewModel annotation for all ViewModels
- All ViewModels must extend BaseViewModel
- We expose state using StateFlow
- For events we use SharedFlow
- Always use viewModelScope for coroutines
```

**After:**
```markdown
## ViewModel
`@HiltViewModel` + `BaseViewModel()` / `StateFlow`(state) + `SharedFlow`(event) / `viewModelScope`
```

### Strategy 2: Deduplicate

Find and merge overlapping content:

1. Grep for similar headings across rules/ files
2. Grep for repeated code snippets
3. Check if CLAUDE.md repeats rules/ content

**Action:** Keep the most detailed version, remove duplicates, add cross-reference.

### Strategy 3: Prune Unused

Identify skills/agents that are never or rarely used:

1. Check `.claude/learning-log/` for usage data (if exists)
2. Check if skill names appear in any rules or CLAUDE.md references
3. Ask user to confirm removal of candidates

**Action:** Remove with user confirmation. Never auto-delete.

### Strategy 4: Progressive Disclosure

Move always-loaded content to on-demand skills:

**Should be in rules/ (always loaded):**
- Critical patterns that apply to EVERY code change
- Architecture constraints (module boundaries, dependency direction)
- Security rules
- Naming conventions

**Should be in skills/ (on-demand):**
- Detailed examples and templates
- Framework-specific deep dives (Compose, Coroutines, etc.)
- Testing patterns
- Migration guides
- Reference material

**Action:** Extract verbose sections from rules/ into new skills, leave a one-line reference.

**Before (rules/compose.md — 120 lines always loaded):**
```markdown
## Recomposition
- Use @Stable/@Immutable annotations...
[60 lines of examples and explanations]
```

**After (rules/compose.md — 20 lines always loaded):**
```markdown
## Recomposition
- Use @Stable/@Immutable for custom types passed to Composables
- Use derivedStateOf for frequently changing state
- Use key() in LazyColumn/LazyRow
> Deep dive: /compose-performance-audit
```

### Strategy 5: Rule Consolidation

Merge granular rules files that cover related topics:

- If 2+ rules files share >30% similar content → merge
- If a rules file is <20 lines → consider merging into a related file
- Target: 5-8 rules files total (not 15+)

## Execution Flow

```
1. Read evaluation report (or run /evaluate)
2. Present optimization plan with estimated savings
3. Ask user: "Apply all? Select specific? Preview only?"
4. For --dry flag: show diffs without applying
5. Apply changes with user confirmation per strategy
6. Re-run evaluation to show before/after score
```

## Output Format

```
┌─────────────────────────────────────────────┐
│  ctxcraft — Optimization Plan               │
│                                             │
│  Current Score: 64/100                      │
│  Estimated After: 85/100                    │
│  Token Savings: ~2,100 tokens/conversation  │
│                                             │
│  📋 Changes                                 │
│  1. Compress CLAUDE.md (320→148 lines)      │
│     Saves: ~1,200 tokens                    │
│  2. Merge 3 overlapping rules               │
│     Saves: ~500 tokens                      │
│  3. Move examples to skills                 │
│     Saves: ~400 tokens                      │
│  4. Remove 2 unused skills                  │
│     Frees: ~800 tokens on-demand budget     │
│                                             │
│  Apply changes? [all / select / preview]    │
└─────────────────────────────────────────────┘
```

## Important Rules

- NEVER auto-apply without user confirmation
- ALWAYS show before/after diff for each change
- NEVER delete files without explicit approval
- Preserve the user's intent — compress, don't remove meaning
- After optimization, run evaluation again to show improvement
- Save backup of original files to `.claude/scratch/ctxcraft-backup/` before changes
