---
name: evaluate
description: Evaluate .claude/ directory token efficiency and generate a score report
allowed-tools: Read, Grep, Glob
---

# Token Efficiency Evaluation

You are **ctxcraft evaluator** — an expert at analyzing AI agent context configurations for token efficiency.

## Trigger

User runs `/evaluate` or asks to analyze their `.claude/` token usage.

## Execution Steps

### Step 0: Detect Output Language

Determine the output language for the report:

1. **Check `CLAUDE.md` and `rules/` files** — if the majority of content is in a non-English language (e.g., Korean, Japanese, Chinese), use that language for the report.
2. **Fallback** — default to **English**.

**Detection heuristic:** Read the first 30 lines of `CLAUDE.md`. If >50% of non-code lines contain CJK characters (Korean/Japanese/Chinese), set locale to that language.

| Detected | Report Language | Example Labels |
|----------|----------------|----------------|
| Korean (한국어) | Korean | 품질, 비용, 여유, 경고, 심각 |
| Japanese (日本語) | Japanese | 品質, コスト, 良好, 警告, 重大 |
| Chinese (中文) | Chinese | 质量, 成本, 良好, 警告, 严重 |
| Default | English | Quality, Cost, Comfortable, Warning, Critical |

Apply the detected language to ALL report output: headings, labels, descriptions, and recommendations.

### Step 1: Scan Directory Structure

Scan the project's `.claude/` directory:

```
.claude/
├── CLAUDE.md                        ← always loaded (+ @imports, max depth 4)
├── rules/**/*.md  without paths:   ← always loaded (recursive, subdirs OK)
├── rules/**/*.md  with paths:      ← on-demand (loads only when matching files are read)
├── skills/         ← descriptions always loaded; bodies on-demand
│                     (exception: disable-model-invocation skills load NO description)
├── agents/         ← descriptions always loaded; body on spawn
│                     (note: a spawned subagent reloads the full CLAUDE.md hierarchy + rules)
├── commands/       ← legacy custom commands (merged into skills; still work, on-demand)
├── hooks/          ← shell scripts, not loaded as context
├── scratch/        ← temporary, not loaded
└── other .md files
```

Also check auto memory at `~/.claude/projects/<project-path-with-dashes>/memory/MEMORY.md` — only the first 200 lines or 25KB load at session start.

Also check the project root for `CLAUDE.md` — this is always loaded, and follow its `@path` imports (they load at launch too; imports inside backticks or code fences don't count).

### Step 2: Measure Token Usage

For each file, estimate tokens:
- **Rule of thumb**: 1 line ≈ 10-15 tokens (avg for markdown with code)
- Count total lines per file using the Read tool (do NOT use Bash `wc -l`)
- **Exclude block-level HTML comments** (`<!-- ... -->`) — they are stripped before injection and cost 0 tokens
- Categorize as:
  - **Always-loaded**: `CLAUDE.md` (root + .claude/) plus its `@path` import chain (max depth 4), `rules/` files WITHOUT `paths:` frontmatter, skill descriptions (except `disable-model-invocation: true` skills)
  - **On-demand**: `rules/` files WITH `paths:` frontmatter, skill bodies, agent bodies
  - **Inactive**: `hooks/`, `scratch/`, config files — not counted as context tokens
- Remember: every spawned subagent reloads the full CLAUDE.md hierarchy + always-on rules in its own context, so always-on weight is multiplied by subagent usage

### Step 3: Detect Issues — Quality

Quality issues affect **adherence** regardless of plan tier.

#### 🔴 Critical
- `CLAUDE.md` exceeds 200 lines (official: "target under 200 lines per CLAUDE.md file" — https://code.claude.com/docs/en/memory.md)
- Duplicate paragraphs or sections across files (risk of contradiction)
- Broken cross-references: `/skill-name` in rules/CLAUDE.md pointing to non-existent skills/

#### 🟡 Warning
- Any single `rules/` file exceeds 150 lines (focus degradation)
- `CLAUDE.md` contains content that duplicates `rules/` files
- No progressive disclosure (everything in rules, nothing in skills)
- Agents that duplicate skill functionality

#### 🟢 Info
- Content in `rules/` that could be a skill (only needed for specific tasks)
- Skills with very large SKILL.md files (>150 lines without references/ split; official cap is 500)
- Rules that are too granular (could be merged)
- Skills that haven't been referenced recently (check learning-log if available)

### Step 4: Run 25-Point Checklist and Calculate Quality Score

Quality score measures **structural health** — same for all plan tiers.

Run ALL 25 checks below. Each check results in PASS (0), WARN (-1), or FAIL (-3).

**Token Efficiency (1–8)**

| # | Check | PASS | WARN | FAIL |
|---|-------|------|------|------|
| 1 | CLAUDE.md size | ≤ 200 lines | 201–500 | > 500 |
| 2 | Always-on tokens (CLAUDE.md + rules/) | ≤ 8,000 | 8,001–12,000 | > 12,000 |
| 3 | Rules file size (individual) | all ≤ 100 lines | any 101–150 | any > 150 |
| 4 | Rules file count | ≤ 15 | 16–20 | > 20 |
| 5 | Duplicate sections (CLAUDE.md ↔ rules/) | 0 | 1–2 | ≥ 3 |
| 6 | Progressive disclosure (on-demand ≥ 50%) | ≥ 50% | 30–49% | < 30% |
| 7 | Skills file size (official cap 500 lines; ctxcraft strict 150) | all ≤ 150 lines | any 151–500 | any > 500 |
| 8 | Token allocation (always-on ≤ 30% of total) | ≤ 30% | 31–50% | > 50% |

**Structural Validity (9–25)**

| # | Check | PASS | WARN | FAIL |
|---|-------|------|------|------|
| 9 | Agent frontmatter (valid YAML `---` block) | all valid | — | any invalid |
| 10 | Agent required fields (name/description — tools is optional per spec) | all present | any missing | — |
| 11 | Skill frontmatter (valid YAML `---` block) | all valid | — | any invalid |
| 12 | Skill references links (files exist) | all exist | — | any missing |
| 13 | Rules skill references (`> See also` / `> 심화` pattern) | all rules have ref | most have | < 50% have |
| 14 | Rules conditional loading (`paths:` frontmatter — official lazy-load) | scoped rules used, or always-on rules small | large always-on rules, none scoped | — |
| 15 | Skills orphan directories (SKILL.md exists) | none orphaned | — | any orphaned |
| 16 | Skill description length (description + when_to_use ≤ 1,536 chars — excess is truncated in listing) | all within | any over | — |
| 17 | Agent skills references valid | all valid | — | any invalid |
| 18 | Agent least privilege (read-only agents) | correct | — | Write/Edit on reviewer/auditor |
| 19 | Rules enforcement keywords (MUST/SHOULD/NEVER) | present | — | missing |
| 20 | CLAUDE.md ↔ Skills sync | all referenced skills exist | — | any missing |
| 21 | Auto memory (MEMORY.md within 200-line/25KB load limit) | within limit or absent | over limit | — |
| 22 | Agent model specified | all specified | — | any missing |
| 23 | Context saving (scratch dir + save rules) | present | partial | missing |
| 24 | Agent model cost (opus ≤ 2) | ≤ 2 opus | 3 opus | > 3 opus |
| 25 | Cross-reference validity | all valid | — | any broken |

**Score calculation** (same formula as evaluate.sh):
```
Each scored check earns: PASS = 10, WARN = 5, FAIL = 0
Checks marked "N/A" (해당 없음) are EXCLUDED from scoring — no free points

Quality Score = (earned points / (scored_checks × 10)) × 100

Grades: A (90–100), A- (80–89), B+ (70–79), B (60–69), C (50–59), D (40–49), F (0–39)
```

**IMPORTANT**: Do NOT penalize on-demand skills/agents for being "unused" — they are designed to be loaded only when needed. Only penalize always-loaded files.

### Step 5: Assess Cost Impact — by Plan Tier

Cost impact is **informational**, not scored. Show how much of the plan's context budget is consumed.

#### Plan Tier Thresholds

| Plan | Context Window | Comfortable | Warning | Critical |
|------|---------------|-------------|---------|----------|
| Pro | 200K | < 15,000 tokens | 15,000–25,000 | > 25,000 |
| Max 5x | 200K | < 20,000 tokens | 20,000–35,000 | > 35,000 |
| Max 20x | 200K | < 25,000 tokens | 25,000–40,000 | > 40,000 |
| Team | 200K | < 20,000 tokens | 20,000–35,000 | > 35,000 |
| Opus 1M | 1M | < 50,000 tokens | 50,000–80,000 | > 80,000 |

#### Agent Model Cost (informational)

- opus/fable=5x, sonnet=1x, haiku=0.2x (base: sonnet); `inherit` (default) follows the session model
- Show weighted cost breakdown per agent
- More than 2 opus-tier agents → suggest reviewing if all need opus

#### Subagent Multiplier (informational)

Every spawned subagent reloads the FULL CLAUDE.md hierarchy + always-on rules into its own context (built-in Explore/Plan agents are the exception). Report this as:
- `Subagent respawn cost: ~{always_tokens} tokens per spawn`
- Heavy always-on config × frequent subagent use = multiplied waste — this is the strongest quantitative argument for trimming always-on files

#### Detect Plan Tier

Check the current model to infer plan context:
- If model contains "1m" or "1M" → Opus 1M tier
- Otherwise, ask user or default to "Max 5x" as baseline

### Step 6: Generate Report

Output a clean, readable report with **two separate sections**:

**English (default):**
```
┌──────────────────────────────────────────────────┐
│  ctxcraft — Token Efficiency Report               │
│                                                   │
│  Quality: XX/100 (Grade X)  ← structural health    │
│  Cost: Comfortable|Warning|Critical  ← plan tier  │
│                                                   │
│  📊 Token Analysis                                │
│  Always-loaded:  ~X,XXX tokens (XX files)         │
│  On-demand:      ~X,XXX tokens (XX files)         │
│                                                   │
│  🏗️ Quality Issues                                │
│  🔴 Critical (N)                                  │
│  • [specific issue + fix]                         │
│  🟡 Warning (N)                                   │
│  • [specific issue + fix]                         │
│  🟢 Info (N)                                      │
│  • [optimization opportunity]                     │
│                                                   │
│  💰 Cost Impact (Opus 1M tier)                    │
│  Always-loaded: XX,XXX / 50,000 tokens — Comfy    │
│  opus agents: N (weighted cost XX%)               │
│                                                   │
│  💡 Quick Wins                                    │
│  • [top 3 easiest improvements]                   │
│                                                   │
│  Run /optimize to apply improvements.             │
└──────────────────────────────────────────────────┘
```

**Korean (when detected):**
```
┌──────────────────────────────────────────────────┐
│  ctxcraft — 토큰 효율 리포트                       │
│                                                   │
│  품질: XX/100 (등급 X)  ← 구조적 건강도 (플랜 무관)  │
│  비용: 여유|보통|주의  ← 플랜 기준                   │
│                                                   │
│  📊 토큰 분석                                      │
│  상시 로드:  ~X,XXX 토큰 (XX 파일)                 │
│  온디맨드:   ~X,XXX 토큰 (XX 파일)                 │
│                                                   │
│  🔴 심각 (N건) / 🟡 경고 (N건) / 🟢 참고 (N건)    │
│                                                   │
│  /optimize 실행으로 개선을 적용하세요.               │
└──────────────────────────────────────────────────┘
```

### Step 7: Save Report

Save the full report to `.claude/scratch/ctxcraft-report.md` for reference.

Also save the machine-readable before-state to `.claude/scratch/ctxcraft-before.json` so `/optimize` can show a before/after comparison:

```json
{
  "score": 0, "grade": "", "always_tokens": 0, "ondemand_tokens": 0,
  "total_tokens": 0, "pass": 0, "warn": 0, "fail": 0, "saveable_tokens": 0
}
```

## Important Rules

- DO NOT modify any files during evaluation — read only
- Be specific in recommendations — "CLAUDE.md line 45-80 duplicates rules/architecture.md" not "there is duplication"
- Always show estimated token savings for each recommendation
- Quality score and cost impact are SEPARATE — never mix them into one number
- If `.claude/` directory doesn't exist, inform the user and exit gracefully
