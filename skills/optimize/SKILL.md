---
name: optimize
description: Apply token optimization improvements based on evaluation results
user_invocable: true
command: /optimize
tools: [Read, Write, Edit, Grep, Glob, Agent]
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
## Error Handling
- We use a custom Result wrapper for all API calls
- All repositories must return Result<T> type
- Errors should be mapped to domain-specific types
- The UI layer observes error states reactively
- Always log errors with structured metadata
```

**After:**
```markdown
## Error Handling
`Result<T>` wrapper for all API calls / domain-specific error mapping / reactive UI error states / structured logging
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
- Framework-specific deep dives (React hooks, SwiftUI, Spring Boot, etc.)
- Testing patterns
- Migration guides
- Reference material

**Action:** Extract verbose sections from rules/ into new skills, leave a one-line reference.

**Before (rules/api-design.md — 120 lines always loaded):**
```markdown
## Error Responses
- Use standard HTTP status codes for all endpoints...
[60 lines of examples and explanations]
```

**After (rules/api-design.md — 20 lines always loaded):**
```markdown
## Error Responses
- Use standard HTTP status codes (4xx client, 5xx server)
- Return structured error body with code + message + details
- Log server errors with correlation ID
> Deep dive: /api-error-handling
```

### Strategy 6: Extract Skills References

When a SKILL.md exceeds 250 lines, split verbose content into a `references/` subdirectory:

**What to extract:**
- Long code examples and templates
- Deep-dive explanations and Best Practice lists
- Configuration option references

**Action:** Keep only the core instructions in SKILL.md, move detailed content to `references/*.md`, and add a reference link at the bottom of SKILL.md.

**Before (skills/state-management/SKILL.md — 258 lines):**
```markdown
## Advanced Patterns
[150 lines of detailed examples and deep-dive content]
```

**After (skills/state-management/SKILL.md — 80 lines):**
```markdown
## Advanced Patterns
- 3-line summary of core rules
> Deep dive: references/state-advanced.md
```

**After (skills/state-management/references/state-advanced.md — 180 lines):**
```markdown
# State Management Deep Dive
[original detailed content]
```

**When to apply:**
- SKILL.md > 250 lines, AND
- The file contains independently separable sections

### Strategy 5: Rule Consolidation

Merge granular rules files that cover related topics:

- If 2+ rules files share >30% similar content → merge
- If a rules file is <20 lines → consider merging into a related file
- Target: 5-8 rules files total (not 15+)

## Execution Flow

```
1. Read .claude/scratch/ctxcraft-before.json for before state
2. Present optimization plan with estimated savings
3. Ask user: "Apply all? Select specific? Preview only?"
4. For --dry flag: show diffs without applying
5. Apply changes with user confirmation per strategy
6. Re-run /evaluate to get after state
7. Show before/after comparison report
8. Clean up scratch files (ctxcraft-report.md, ctxcraft-backup/)
```

## Output Format

```
┌───────────────────────────────────────────────────┐
│  ctxcraft — 최적화 계획                             │
│                                                    │
│  현재 점수: 64/100                                 │
│  예상 점수: 85/100                                 │
│  절감 토큰: ~2,100 토큰/대화                        │
│                                                    │
│  📋 변경 사항                                       │
│  1. CLAUDE.md 압축 (320→148줄)                     │
│     절감: ~1,200 토큰                               │
│  2. 중복 rules 3개 병합                             │
│     절감: ~500 토큰                                 │
│  3. 예제를 skills로 이동                            │
│     절감: ~400 토큰                                 │
│  4. 미사용 skills 2개 제거                          │
│     확보: ~800 토큰 온디맨드 예산                    │
│                                                    │
│  변경 적용? [전체 / 선택 / 미리보기]                 │
└───────────────────────────────────────────────────┘
```

## Before/After Comparison Report

After all changes are applied, you MUST re-run `/evaluate` and display the comparison in this format:

```
┌─────────────────────────────────────────────────────────┐
│  ctxcraft — Optimization Complete                       │
│                                                         │
│            Before      After      Savings               │
│  Score      75/100  →  91/100   (+16 pts)               │
│  Always-on  16,848  →   9,200   (-7,648 tokens/conv)   │
│  Grade      B       →  A                                │
│                                                         │
│  PASS 9 → 13   WARN 3 → 1   FAIL 2 → 0                │
└─────────────────────────────────────────────────────────┘
```

Before data is read from `.claude/scratch/ctxcraft-before.json`.

## Cleanup After Optimization

After optimization is complete, clean up temporary scratch files only:

```
1. Delete .claude/scratch/ctxcraft-report.md (if exists)
2. Delete .claude/scratch/ctxcraft-backup/ (if exists)
3. Delete .claude/scratch/ctxcraft-before.json (if exists)
```

> **Note:** Do NOT delete ctxcraft skills/agents — they may be installed globally via plugin system (`~/.claude/plugins/`) or locally for reuse. Only clean up temporary working files.

## Important Rules

- NEVER auto-apply without user confirmation
- ALWAYS show before/after diff for each change
- NEVER delete files without explicit approval
- Preserve the user's intent — compress, don't remove meaning
- After optimization, run evaluation again to show improvement
- Save backup of original files to `.claude/scratch/ctxcraft-backup/` before changes
- ALWAYS clean up scratch files after optimization is done (NOT the plugin itself)
