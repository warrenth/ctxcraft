# Token Efficiency Rules

## Always-on Budget
- CLAUDE.md < 200 lines (official recommendation — adherence degrades beyond this)
- Each rules/ file < 150 lines — extract excess into skills
- Write CLAUDE.md as an index, not a manual

## Progressive Disclosure
- Rules = constraints (do / don't) — always loaded, keep short
- Skills = knowledge (how to) — on-demand, can be detailed
- Agents = execution (do it for me) — isolated context, no main session impact

## Compression Techniques
- Tables over prose: convert 3-line explanations → 1 table row
- Bullet points over paragraphs
- Code patterns over verbal descriptions
- Cross-references over duplication: `> See: /skill-name`
