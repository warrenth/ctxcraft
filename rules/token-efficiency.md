# Token Efficiency Rules

## Always-Loaded Budget
- CLAUDE.md + rules/ combined should stay under 4,000 tokens (~300 lines)
- Each rules/ file should be under 80 lines — extract excess to skills
- CLAUDE.md should be an index, not a manual

## Progressive Disclosure
- Rules = constraints (what to do/not do) — always loaded, keep short
- Skills = knowledge (how to do it) — on-demand, can be detailed
- Agents = execution (do it for me) — on-demand, can be comprehensive

## Compression Techniques
- Tables over prose: 3 lines of explanation → 1 table row
- Bullet points over paragraphs
- Code patterns over verbal descriptions
- Cross-references over duplication: `> See: /skill-name`
