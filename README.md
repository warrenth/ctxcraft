# ctxcraft

> Evaluate and optimize your AI agent context. Save tokens, save money.

**ctxcraft** analyzes your `.claude/` directory structure and provides actionable recommendations to reduce token consumption without losing functionality.

## Problem

AI coding agents (Claude Code, Cursor, Windsurf) load context files every conversation. As your `.claude/` directory grows, you silently burn tokens on:

- Overly verbose rules that could be half the size
- Duplicate content across rules, skills, and CLAUDE.md
- Unused skills and agents that never get triggered
- Always-loaded files that should be on-demand

## Features

| Command | Description |
|---------|-------------|
| `/evaluate` | Scan `.claude/` directory, estimate token usage, score efficiency (0-100) |
| `/optimize` | Apply improvements based on evaluation results |

## Quick Start

### Option 1: Install script (recommended)

```bash
curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/install.sh | bash
```

### Option 2: Manual copy

```bash
git clone https://github.com/warrenth/ctxcraft.git
cp -r ctxcraft/skills/* /path/to/your/project/.claude/skills/
cp -r ctxcraft/rules/* /path/to/your/project/.claude/rules/
```

## What `/evaluate` Reports

```
┌─────────────────────────────────────────────┐
│  ctxcraft — Token Efficiency Report         │
│                                             │
│  Score: 64/100                              │
│                                             │
│  📊 Token Breakdown                         │
│  Always-loaded (rules, CLAUDE.md): ~4,200   │
│  On-demand (skills, agents):       ~8,500   │
│  Estimated waste:                  ~1,800   │
│                                             │
│  🔴 Critical                                │
│  • CLAUDE.md is 320 lines — compress to 150 │
│                                             │
│  🟡 Warning                                 │
│  • 3 rules files have overlapping content   │
│  • 4 skills never referenced in 10 sessions │
│                                             │
│  🟢 Good                                    │
│  • Agent delegation is well structured      │
│  • Skills use progressive disclosure        │
└─────────────────────────────────────────────┘
```

## What `/optimize` Does

1. **Compress** — Reduce verbose rules and CLAUDE.md without losing meaning
2. **Deduplicate** — Merge overlapping rules into single source of truth
3. **Prune** — Identify and remove unused skills/agents
4. **Restructure** — Move always-loaded content to on-demand skills

All changes require your confirmation before applying.

## Project Structure

```
ctxcraft/
├── skills/
│   ├── evaluate/SKILL.md     # /evaluate command
│   ├── optimize/SKILL.md     # /optimize command
│   └── token-guide/SKILL.md  # Token efficiency reference
├── rules/
│   └── token-efficiency.md   # Always-loaded efficiency rules
├── agents/
│   └── token-auditor.md      # Dedicated analysis agent
└── install.sh                # One-line installer
```

## Scoring Criteria

| Category | Weight | What it measures |
|----------|--------|------------------|
| Always-loaded size | 30% | Total tokens in rules/ + CLAUDE.md |
| Duplication | 25% | Content overlap across files |
| Unused files | 20% | Skills/agents with no recent usage |
| Progressive disclosure | 15% | Ratio of on-demand vs always-loaded |
| Structure | 10% | Naming, organization, modularity |

## Supported Environments

- [x] Claude Code
- [ ] Cursor (planned)
- [ ] Windsurf (planned)
- [ ] Cline (planned)

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT
