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
1. Read .claude/scratch/ctxcraft-before.json for before state
2. Present optimization plan with estimated savings
3. Ask user: "Apply all? Select specific? Preview only?"
4. For --dry flag: show diffs without applying
5. Apply changes with user confirmation per strategy
6. Re-run /evaluate to get after state
7. Show before/after comparison report
8. Clean up ctxcraft files
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

## Before/After 비교 리포트

모든 변경 적용 후 반드시 `/evaluate`를 재실행하고 아래 형식으로 비교를 출력한다:

```
┌─────────────────────────────────────────────────────┐
│  ctxcraft — 최적화 완료                               │
│                                                      │
│           Before      After      절감                │
│  점수      75/100  →  91/100   (+16점)               │
│  상시토큰  16,848  →   9,200   (-7,648 토큰/대화)    │
│  등급      B       →  A                              │
│                                                      │
│  PASS 9개 → 13개   WARN 3개 → 1개   FAIL 2개 → 0개  │
└─────────────────────────────────────────────────────┘
```

Before 데이터는 `.claude/scratch/ctxcraft-before.json`에서 읽는다.

## Cleanup After Optimization

After optimization is complete, remove all ctxcraft files from the user's project:

```
1. Delete .claude/skills/evaluate/
2. Delete .claude/skills/optimize/
3. Delete .claude/skills/token-guide/
4. Delete .claude/agents/token-auditor.md
5. Delete .claude/scratch/ctxcraft-report.md (if exists)
6. Delete .claude/scratch/ctxcraft-backup/ (if exists)
```

Inform the user:
```
✅ 최적화 완료! ctxcraft 파일을 모두 정리했습니다.
다시 평가하려면: curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/evaluate.sh | bash
```

## Important Rules

- NEVER auto-apply without user confirmation
- ALWAYS show before/after diff for each change
- NEVER delete files without explicit approval
- Preserve the user's intent — compress, don't remove meaning
- After optimization, run evaluation again to show improvement
- Save backup of original files to `.claude/scratch/ctxcraft-backup/` before changes
- ALWAYS clean up ctxcraft files after optimization is done
