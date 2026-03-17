# ctxcraft

> AI 에이전트 컨텍스트를 평가하고 최적화하세요. 토큰을 아끼고, 비용을 줄이세요.

**ctxcraft**는 `.claude/` 디렉토리 구조를 분석하여 기능 손실 없이 토큰 소비를 줄이는 구체적인 개선안을 제시합니다.

## 문제

AI 코딩 에이전트(Claude Code, Cursor, Windsurf)는 매 대화마다 컨텍스트 파일을 로드합니다. `.claude/` 디렉토리가 커질수록 다음과 같은 토큰 낭비가 조용히 발생합니다:

- 절반으로 줄일 수 있는 장황한 규칙 파일
- rules, skills, CLAUDE.md 간 중복 콘텐츠
- 한 번도 호출되지 않는 미사용 skills/agents
- 온디맨드로 전환 가능한 상시 로드 파일

## 빠른 시작

### 방법 1: Plugin Marketplace (권장)

Claude Code 플러그인 시스템으로 설치합니다. 업데이트 자동 관리, 활성화/비활성화가 가능합니다.

```bash
# 1. 마켓플레이스 추가 (한 번만)
claude plugin marketplace add warrenth/ctxcraft

# 2. 플러그인 설치
claude plugin install ctxcraft@tools

# 3. Claude Code에서 사용
/ctxcraft:evaluate
/ctxcraft:optimize
```

> **팀 자동 설치**: 프로젝트 `.claude/settings.json`에 추가하면 팀원이 자동으로 설치됩니다:
>
> ```json
> {
>   "extraKnownMarketplaces": {
>     "ctxcraft": {
>       "source": { "source": "github", "repo": "warrenth/ctxcraft" }
>     }
>   },
>   "enabledPlugins": { "ctxcraft@tools": true }
> }
> ```

### 방법 2: 글로벌 원라인 설치

플러그인 시스템 없이 `~/.claude/`에 직접 설치합니다. 모든 프로젝트에서 `/evaluate`, `/optimize`를 사용할 수 있습니다.

```bash
tmp=$(mktemp -d) && git clone --depth 1 https://github.com/warrenth/ctxcraft.git "$tmp/ctx" && \
mkdir -p ~/.claude/{skills,rules,agents} && \
cp -r "$tmp/ctx/skills/"* ~/.claude/skills/ && \
cp -r "$tmp/ctx/agents/"* ~/.claude/agents/ && \
cp "$tmp/ctx/rules/token-efficiency.md" ~/.claude/rules/ && \
rm -rf "$tmp" && echo "✅ ctxcraft installed globally (~/.claude/)"
```

> **프로젝트 로컬 설치**: `~/.claude/` 대신 `.claude/`에 설치하면 해당 프로젝트에서만 사용됩니다. git commit 시 팀원도 공유 가능합니다.
>
> ```bash
> curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/install.sh | bash
> ```

## 동작 방식

```
$ curl -sL .../evaluate.sh -o /tmp/ctxcraft.sh && bash /tmp/ctxcraft.sh

━━━ Phase 1: 토큰 효율 검증 ━━━

  ✓ 스캔 완료 (파일 60개)

  PASS  [ 1] CLAUDE.md 크기
  FAIL  [ 2] 상시 로드 토큰
  FAIL  [ 3] Rules 파일 크기
  PASS  [ 4] Rules 파일 수
  WARN  [ 5] 중복 섹션
  PASS  [ 6] 단계적 공개
  WARN  [ 7] Skills 파일 크기
  PASS  [ 8] 토큰 배분 비율
  PASS  [ 9] Agent Frontmatter
  PASS  [10] Agent 필수 필드
  PASS  [11] Skill Frontmatter
  PASS  [12] Skill References 링크
  WARN  [13] Rules 스킬 참조
  PASS  [14] Rules 순수 Markdown
  PASS  [15] Skills 고아 디렉토리
  PASS  [16] Rules 평면 구조
  PASS  [17] Agent Skills 참조
  PASS  [18] Agent Tools 최소권한
  PASS  [19] Rules 강제성 키워드
  PASS  [20] CLAUDE.md ↔ Skills 동기화
  PASS  [21] 자동 학습 시스템
  PASS  [22] Agent Model 명시
  PASS  [23] Context Saving
  PASS  [24] Agent 모델별 비용
  PASS  [25] Cross-reference 유효성

━━━ Phase 2: 리포트 ━━━

  📊 토큰 분석
  ┌────────────────────┬──────────────┬───────────┐
  │ 구분                │ 토큰         │ 파일 수   │
  ├────────────────────┼──────────────┼───────────┤
  │ 상시 로드 (매 대화)    │      16848   │    14     │
  │ 온디맨드 (필요 시)     │      53040   │    46     │
  ├────────────────────┼──────────────┼───────────┤
  │ 합계                │      69888   │    60     │
  └────────────────────┴──────────────┴───────────┘

  📋 개선 필요 항목
  FAIL  [ 2] 상시 로드 토큰        → rules 전체 압축 필요, 절감 가능: ~8848 토큰
  FAIL  [ 3] Rules 파일 크기       → coroutines.md — 예시/설명 제거 또는 skills로 이동
  WARN  [ 5] 중복 섹션             → 한 곳만 남기고 나머지 섹션 제거
  WARN  [ 7] Skills 파일 크기      → compose-navigation — 상세 내용을 references/ 하위 폴더로 분리
  WARN  [13] Rules 스킬 참조       → ai-behavior.md — 하단에 '> 심화: /skill-name' 한 줄 추가

  💡 절감 가능: ~9168 토큰/대화

━━━ 최종 요약 ━━━
  점수: 86/100 (A) — 훌륭합니다!
  PASS 20개  WARN 3개  FAIL 2개

━━━ Phase 3: 최적화 ━━━

  지금 최적화하시겠습니까? (y/n): y

  ✓ 설치 완료
  ✓ Claude Code 감지 — 최적화를 시작합니다.
```

## 최적화 결과 (Before/After)

최적화 완료 후 자동으로 비교 리포트를 출력합니다:

```
┌─────────────────────────────────────────────────────┐
│  ctxcraft — 최적화 완료                                │
│                                                     │
│           Before      After      절감                │
│  점수      78/100  →  92/100   (+14점)                │
│  상시토큰  16,848  →   9,200   (-7,648 토큰/대화)        │
│  등급      B       →  A                              │
│                                                     │
│  PASS 20개 → 24개   WARN 3개 → 1개   FAIL 2개 → 0개    │
└─────────────────────────────────────────────────────┘

✅ 최적화 완료! ctxcraft 파일을 모두 정리했습니다.
```

## Checks

### Token Efficiency (1–8)

| # | Check | Threshold | What it measures |
|---|-------|-----------|------------------|
| 1 | CLAUDE.md size | ≤ 500 lines | Core file loaded every conversation |
| 2 | Always-on tokens | ≤ 8,000 | Total tokens from CLAUDE.md + rules/ |
| 3 | Rules file size | 100–130 lines | Individual rule file size |
| 4 | Rules file count | ≤ 15 | Too many → consolidate |
| 5 | Duplicate sections | 0 | Overlap between CLAUDE.md ↔ rules/ |
| 6 | Progressive disclosure | On-demand 50%+ | Always-on vs on-demand ratio |
| 7 | Skills file size | ≤ 250 lines | Individual skill file size |
| 8 | Token allocation ratio | Always-on ≤ 30% | Always-on share of total context |

### Structural Validity (9–25)

| # | Check | Threshold | What it measures |
|---|-------|-----------|------------------|
| 9 | Agent frontmatter | Complete YAML `---` block | Agent file frontmatter validity |
| 10 | Agent required fields | name/description/tools | Agent metadata presence |
| 11 | Skill frontmatter | Complete YAML `---` block | SKILL.md frontmatter validity |
| 12 | Skill references links | Files actually exist | references/*.md link validity |
| 13 | Rules skill references | `>` reference pattern | Deep-dive skill links in rules |
| 14 | Rules pure Markdown | No YAML frontmatter | Rules don't need frontmatter |
| 15 | Skills orphan directories | SKILL.md must exist | skills/xxx/ without SKILL.md won't work |
| 16 | Rules flat structure | No subdirectories | rules/ allows only flat .md files |
| 17 | Agent skills references | skills/ directory exists | Agent frontmatter skills field validity |
| 18 | Agent least privilege | No Write/Edit for reviewer/auditor/architect/planner | Read-only agents principle |
| 19 | Rules enforcement keywords | MUST/SHOULD/NEVER | RFC 2119 style rule writing |
| 20 | CLAUDE.md ↔ Skills sync | Referenced skills exist | Backtick skill names match skills/ directories |
| 21 | Auto-learning system | memory + hooks + promotion | Pattern promotion to rules → long-term token savings |
| 22 | Agent model specified | model field present | Cost optimization via model selection |
| 23 | Context saving | scratch dir + save rules | Save large outputs outside conversation to reduce tokens |
| 24 | Agent model cost | opus ≤ 2 agents | Weighted cost analysis: opus=5x, sonnet=1x, haiku=0.2x |
| 25 | Cross-reference validity | All `/skill-name` refs exist | Broken skill references in rules/ and CLAUDE.md |

## Scoring

| Grade | Score | Meaning |
|-------|-------|---------|
| S | 95+ | Perfect — You are a Context Master! |
| A | 85–94 | Excellent |
| B | 70–84 | Good |
| C | 50–69 | Needs improvement |
| D | 0–49 | Optimize immediately |

## `/optimize`가 하는 일

1. **압축** — 의미를 유지하면서 장황한 rules와 CLAUDE.md 축소
2. **중복 제거** — 겹치는 규칙을 단일 소스로 병합
3. **정리** — 미사용 skills/agents 식별 및 제거
4. **재구조화** — 상시 로드 콘텐츠를 온디맨드 skills로 이동
5. **references 분리** — SKILL.md 250줄 초과 시 상세 내용을 references/로 이동
6. **자동 삭제** — 최적화 완료 후 ctxcraft 파일 자동 정리

모든 변경은 적용 전 사용자 확인을 거칩니다.

## 프로젝트 구조

```
ctxcraft/
├── .claude-plugin/
│   ├── plugin.json             # 플러그인 매니페스트
│   └── marketplace.json        # 마켓플레이스 카탈로그
├── evaluate.sh                 # 원라인 평가 스크립트
├── skills/
│   ├── evaluate/SKILL.md       # /ctxcraft:evaluate 명령어
│   ├── optimize/SKILL.md       # /ctxcraft:optimize 명령어
│   └── token-guide/SKILL.md    # 토큰 효율 레퍼런스
├── agents/
│   └── token-auditor.md        # 전용 분석 에이전트
├── rules/
│   └── token-efficiency.md     # 토큰 효율 규칙
├── action.yml                  # GitHub Actions 통합
└── examples/
    └── ctxcraft-check.yml      # GitHub Actions 워크플로우 예시
```

## 지원 환경

- [x] Claude Code
- [ ] Cursor (예정)
- [ ] Windsurf (예정)
- [ ] Cline (예정)

## 기여

기여를 환영합니다!

## 라이선스

MIT
