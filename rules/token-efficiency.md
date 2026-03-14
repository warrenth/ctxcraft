# Token Efficiency Rules

## Always-on Budget
- CLAUDE.md + rules/ combined must stay under 4,000 tokens (~300 lines)
- Each rules/ file should be 80 lines or fewer — extract excess into skills
- Write CLAUDE.md as an index, not a manual

## Progressive Disclosure
- Rules = constraints (do / don't) — always loaded, keep short
- Skills = knowledge (how to) — on-demand, can be detailed
- Agents = execution (do it for me) — on-demand, can be comprehensive

## Compression Techniques
- Tables over prose: convert 3-line explanations → 1 table row
- Bullet points over paragraphs
- Code patterns over verbal descriptions
- Cross-references over duplication: `> See: /skill-name`
