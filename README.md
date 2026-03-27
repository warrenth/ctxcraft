# ctxcraft

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin-orange)](https://github.com/warrenth/ctxcraft)

> Evaluate and optimize your AI agent's context. Save tokens, cut costs.

**ctxcraft** analyzes your `.claude/` directory structure and provides actionable recommendations to reduce token consumption — without losing any functionality.

## The Problem

AI coding agents (Claude Code, Cursor, Windsurf) load context files on every conversation. As your `.claude/` directory grows, **silent token waste** accumulates:

- Verbose rule files that could be cut in half
- Duplicated content across rules, skills, and CLAUDE.md
- Unused skills/agents that are never invoked
- Always-on files that should be loaded on-demand

**ctxcraft finds and fixes all of this.**

## Quick Start

### Option 1: Plugin Marketplace (Recommended)

```bash
# Add marketplace (one-time)
claude plugin marketplace add warrenth/ctxcraft

# Install plugin
claude plugin install ctxcraft@tools
```

Then in Claude Code:

```
/ctxcraft:evaluate    # Analyze token efficiency
/ctxcraft:optimize    # Auto-fix issues
/ctxcraft:token-guide # Best practices reference
```

<details>
<summary>Team auto-install via settings.json</summary>

```json
{
  "extraKnownMarketplaces": {
    "ctxcraft": {
      "source": { "source": "github", "repo": "warrenth/ctxcraft" }
    }
  },
  "enabledPlugins": { "ctxcraft@tools": true }
}
```

</details>

### Option 2: Global Install

```bash
curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/install.sh | bash
```

Then in Claude Code: `/evaluate`, `/optimize`, `/token-guide`

<details>
<summary>Project-local install</summary>

```bash
curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/install.sh | bash -s -- --local
```

</details>

> ctxcraft uses only read-only tools (Read, Grep, Glob) — **no permission prompts** needed.

## How It Works

```
$ /ctxcraft:evaluate

━━━ Phase 1: Token Efficiency Audit ━━━

  PASS  [ 1] CLAUDE.md size
  FAIL  [ 2] Always-on tokens         → Compress rules, save ~8,848 tokens
  FAIL  [ 3] Rules file size           → Move examples to skills/
  PASS  [ 4] Rules file count
  WARN  [ 5] Duplicate sections        → Keep in one place only
  PASS  [ 6] Progressive disclosure
  ...
  PASS  [25] Cross-reference validity

━━━ Phase 2: Report ━━━

  ┌────────────────────┬────────────┬───────┐
  │ Category           │ Tokens     │ Files │
  ├────────────────────┼────────────┼───────┤
  │ Always-on (every)  │    16,848  │   14  │
  │ On-demand (lazy)   │    53,040  │   46  │
  ├────────────────────┼────────────┼───────┤
  │ Total              │    69,888  │   60  │
  └────────────────────┴────────────┴───────┘

  💡 Potential savings: ~9,168 tokens/conversation

━━━ Summary ━━━
  Quality: 86/100 (A-)
  Cost: Comfortable (Max 5x plan)
  PASS 20  WARN 3  FAIL 2
```

## Before / After

```
┌──────────────────────────────────────────────────┐
│  ctxcraft — Optimization Complete                │
│                                                  │
│              Before      After       Change      │
│  Quality     78/100  →  92/100    (+14 pts)      │
│  Grade       B+      →  A                        │
│  Always-on   16,848  →   9,200   (-7,648 tok)   │
│                                                  │
│  PASS 20 → 24   WARN 3 → 1   FAIL 2 → 0        │
└──────────────────────────────────────────────────┘
```

## What `/optimize` Does

1. **Compress** — Shrink verbose rules and CLAUDE.md while preserving meaning
2. **Deduplicate** — Merge overlapping rules into a single source of truth
3. **Clean up** — Identify and remove unused skills/agents
4. **Restructure** — Move always-on content to on-demand skills
5. **Split references** — Extract details from large SKILL.md (>250 lines) into references/
6. **Self-clean** — Remove ctxcraft files after optimization

All changes require user confirmation before applying.

### Loop Mode (inspired by [Karpathy's AutoResearch](https://github.com/karpathy/autoresearch))

```
/optimize --loop
```

Instead of applying all strategies at once, loop mode applies **one strategy per round**, measures the impact, and automatically keeps or reverts each change — the same "change one thing → measure → keep/revert" loop that [Andrej Karpathy's AutoResearch](https://github.com/karpathy/autoresearch) uses to self-improve ML experiments.

```
Round 1: Strategy 1 (Compress CLAUDE.md)
  B+ (72) → A- (81)  ✅ Keep   (+9 pts)

Round 2: Strategy 2 (Deduplicate)
  A- (81) → A- (80)  ❌ Revert (-1 pt)

Round 3: Strategy 4 (Progressive Disclosure)
  A- (81) → A  (91)  ✅ Keep   (+10 pts)

━━━ A grade × 3 consecutive — loop stopped ━━━

┌──────────────────────────────────────────┐
│  Strategy Effectiveness                  │
│                                          │
│  Strategy 1 (Compress):    +9 pts  ★    │
│  Strategy 2 (Dedup):      -1 pt  (rev)  │
│  Strategy 4 (Disclosure): +10 pts  ★    │
│                                          │
│  Total: B+ (72) → A (93)  3 rounds      │
└──────────────────────────────────────────┘
```

**Key differences from batch mode:**
- One strategy per round (isolates each strategy's impact)
- Auto-rollback on score drop (file-based, not git)
- Stops when A grade (90+) achieved 3 consecutive rounds

## 25 Checks

### Token Efficiency (1–8)

| # | Check | Threshold | What it measures |
|---|-------|-----------|------------------|
| 1 | CLAUDE.md size | ≤ 500 lines | Core file loaded every conversation |
| 2 | Always-on tokens | ≤ 8,000 | Total tokens from CLAUDE.md + rules/ |
| 3 | Rules file size | 100–130 lines | Individual rule file bloat |
| 4 | Rules file count | ≤ 15 | Too many rules → consolidate |
| 5 | Duplicate sections | 0 | Overlap between CLAUDE.md ↔ rules/ |
| 6 | Progressive disclosure | On-demand 50%+ | Always-on vs on-demand ratio |
| 7 | Skills file size | ≤ 250 lines | Individual skill file bloat |
| 8 | Token allocation ratio | Always-on ≤ 30% | Always-on share of total context |

<details>
<summary>Structural Validity (9–25)</summary>

| # | Check | What it measures |
|---|-------|------------------|
| 9 | Agent frontmatter | YAML `---` block validity |
| 10 | Agent required fields | name/description/tools presence |
| 11 | Skill frontmatter | YAML `---` block validity |
| 12 | Skill references links | references/*.md link validity |
| 13 | Rules skill references | Deep-dive `/skill-name` links |
| 14 | Rules pure Markdown | No YAML frontmatter in rules |
| 15 | Skills orphan directories | SKILL.md must exist in each dir |
| 16 | Rules flat structure | No subdirectories allowed |
| 17 | Agent skills references | skills/ directory exists |
| 18 | Agent least privilege | Read-only agents don't get Write/Edit |
| 19 | Rules enforcement keywords | MUST/SHOULD/NEVER (RFC 2119) |
| 20 | CLAUDE.md ↔ Skills sync | Referenced skills actually exist |
| 21 | Auto-learning system | memory + hooks + promotion pipeline |
| 22 | Agent model specified | Model field for cost control |
| 23 | Context saving | scratch dir + save rules |
| 24 | Agent model cost | opus ≤ 2 agents (weighted cost) |
| 25 | Cross-reference validity | No broken `/skill-name` references |

</details>

## Scoring

ctxcraft uses a **2-axis system** — quality (universal) and cost (plan-dependent).

**Quality** measures structural health:

```
Quality = 100 - (FAIL × 3) - (WARN × 1)
```

| Grade | Score | Meaning |
|-------|-------|---------|
| A | 90–100 | Excellent |
| A- | 80–89 | Great |
| B+ | 70–79 | Good |
| B | 60–69 | Fair |
| C | 50–59 | Needs work |
| D | 40–49 | Poor |
| F | 0–39 | Optimize now |

**Cost** shows token budget usage per plan:

| Plan | Comfortable | Warning | Critical |
|------|-------------|---------|----------|
| Pro | < 15K | 15K–25K | > 25K |
| Max 5x | < 20K | 20K–35K | > 35K |
| Max 20x | < 25K | 25K–40K | > 40K |
| Team | < 20K | 20K–35K | > 35K |
| Opus 1M | < 50K | 50K–80K | > 80K |

> On-demand skills/agents are NOT penalized — they load only when needed.

## Project Structure

```
ctxcraft/
├── .claude-plugin/
│   ├── plugin.json           # Plugin manifest
│   └── marketplace.json      # Marketplace catalog
├── skills/
│   ├── evaluate/SKILL.md     # /ctxcraft:evaluate
│   ├── optimize/SKILL.md     # /ctxcraft:optimize
│   └── token-guide/SKILL.md  # Token efficiency reference
├── agents/
│   └── token-auditor.md      # Dedicated analysis agent
├── rules/
│   └── token-efficiency.md   # Token efficiency rules
├── action.yml                # GitHub Actions integration
├── evaluate.sh               # One-liner evaluation script
└── install.sh                # Global/local installer
```

## Supported Environments

- [x] Claude Code
- [ ] Cursor (planned)
- [ ] Windsurf (planned)
- [ ] Cline (planned)

## Contributing

Contributions are welcome! Feel free to open issues and pull requests.

## License

MIT
