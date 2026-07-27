# Token Efficiency Rules

## Always-on Budget
- CLAUDE.md < 200 lines (official: "target under 200 lines" — code.claude.com/docs/en/memory.md)
- Each rules/ file < 150 lines — extract excess into skills, or add `paths:` frontmatter to lazy-load
- Write CLAUDE.md as an index, not a manual (note: `@path` imports still load at launch)

## Progressive Disclosure
- Rules = constraints (do / don't) — always loaded unless `paths:`-scoped
- Skills = knowledge (how to) — on-demand; only the description is always loaded
- Agents = execution (do it for me) — isolated context, but each spawn reloads full CLAUDE.md + rules

## Compression Techniques
- Tables over prose: convert 3-line explanations → 1 table row
- Bullet points over paragraphs
- Code patterns over verbal descriptions
- Cross-references over duplication: `> See: /skill-name`
