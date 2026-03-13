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

프로젝트 루트에서 한 줄로 실행:

```bash
curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/evaluate.sh -o /tmp/ctxcraft.sh && bash /tmp/ctxcraft.sh
```

프로젝트에 아무것도 설치되지 않습니다. 평가 후 개선을 원할 때만 도구가 설치됩니다.

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

━━━ Phase 2: 리포트 ━━━

  📊 토큰 분석
  ┌────────────────────┬──────────────┬───────────┐
  │ 구분               │ 토큰         │ 파일 수   │
  ├────────────────────┼──────────────┼───────────┤
  │ 상시 로드 (매 대화) │      16848   │    14     │
  │ 온디맨드 (필요 시)  │      53040   │    46     │
  ├────────────────────┼──────────────┼───────────┤
  │ 합계               │      69888   │    60     │
  └────────────────────┴──────────────┴───────────┘

  📋 개선 필요 항목
  FAIL  [ 2] 상시 로드 토큰        → rules 전체 압축 필요, 절감 가능: ~8848 토큰
  FAIL  [ 3] Rules 파일 크기       → coroutines.md — 예시/설명 제거 또는 skills로 이동
  WARN  [ 5] 중복 섹션             → 한 곳만 남기고 나머지 섹션 제거
  WARN  [ 7] Skills 파일 크기      → compose-navigation — 상세 내용을 references/ 하위 폴더로 분리
  WARN  [13] Rules 스킬 참조       → ai-behavior.md — 하단에 '> 심화: /skill-name' 한 줄 추가

  💡 절감 가능: ~9168 토큰/대화

━━━ 최종 요약 ━━━
  점수: 78/100 (B) — 양호합니다
  PASS 11개  WARN 3개  FAIL 2개

━━━ Phase 3: 최적화 ━━━

  지금 최적화하시겠습니까? (y/n): y

  ✓ 설치 완료
  ✓ Claude Code 감지 — 최적화를 시작합니다.
```

## 최적화 결과 (Before/After)

최적화 완료 후 자동으로 비교 리포트를 출력합니다:

```
┌─────────────────────────────────────────────────────┐
│  ctxcraft — 최적화 완료                               │
│                                                      │
│           Before      After      절감                │
│  점수      78/100  →  92/100   (+14점)               │
│  상시토큰  16,848  →   9,200   (-7,648 토큰/대화)    │
│  등급      B       →  A                              │
│                                                      │
│  PASS 11개 → 15개   WARN 3개 → 1개   FAIL 2개 → 0개 │
└─────────────────────────────────────────────────────┘

✅ 최적화 완료! ctxcraft 파일을 모두 정리했습니다.
```

## 검증 항목

### 토큰 효율 (1~8)

| # | 항목 | 기준 | 측정 내용 |
|---|------|------|----------|
| 1 | CLAUDE.md 크기 | 500줄 이하 | 매 대화 로드되는 핵심 파일 |
| 2 | 상시 로드 토큰 | 8,000 이하 | CLAUDE.md + rules/ 총 토큰 |
| 3 | Rules 파일 크기 | 100~130줄 | 개별 규칙 파일 적정 크기 |
| 4 | Rules 파일 수 | 15개 이하 | 너무 많으면 통합 필요 |
| 5 | 중복 섹션 | 0개 | CLAUDE.md ↔ rules/ 간 겹침 |
| 6 | 단계적 공개 | 온디맨드 50%+ | 상시 vs 온디맨드 비율 |
| 7 | Skills 파일 크기 | 250줄 이하 | 개별 스킬 적정 크기 |
| 8 | 토큰 배분 비율 | 상시 30% 이하 | 전체 대비 상시 로드 비중 |

### 구조 유효성 (9~20)

| # | 항목 | 기준 | 측정 내용 |
|---|------|------|----------|
| 9 | Agent Frontmatter | YAML `---` 블록 완전 | agent 파일 frontmatter 유효성 |
| 10 | Agent 필수 필드 | name/description/tools | agent 필수 메타데이터 존재 여부 |
| 11 | Skill Frontmatter | YAML `---` 블록 완전 | SKILL.md frontmatter 유효성 |
| 12 | Skill References 링크 | 파일 실제 존재 | references/*.md 링크 유효성 |
| 13 | Rules 스킬 참조 | `>` 참조 패턴 포함 | rules 하단 심화 skills 참조 여부 |
| 14 | Rules 순수 Markdown | YAML frontmatter 없음 | rules는 frontmatter 불필요 |
| 15 | Skills 고아 디렉토리 | SKILL.md 반드시 존재 | skills/xxx/ 있는데 SKILL.md 없으면 미작동 |
| 16 | Rules 평면 구조 | 하위 디렉토리 없음 | rules/는 flat .md 파일만 허용 |
| 17 | Agent Skills 참조 | skills/ 디렉토리 실존 | agent frontmatter skills 필드의 실존 여부 |
| 18 | Agent Tools 최소권한 | reviewer/auditor/architect/planner에 Write/Edit 금지 | 분석 전용 에이전트 최소 권한 원칙 |
| 19 | Rules 강제성 키워드 | MUST/SHOULD/NEVER 구조 | RFC 2119 스타일 규칙 작성 여부 |
| 20 | CLAUDE.md ↔ Skills 동기화 | 언급된 skill 실존 | CLAUDE.md backtick 스킬명과 skills/ 디렉토리 일치 여부 |

## 점수 등급

| 등급 | 점수 | 의미 |
|------|------|------|
| A | 85+ | 훌륭합니다! |
| B | 70~84 | 양호합니다 |
| C | 50~69 | 개선이 필요합니다 |
| D | 0~49 | 즉시 최적화를 권장합니다 |

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
├── evaluate.sh                 # 원라인 평가 스크립트 (핵심)
├── action.yml                  # GitHub Actions 통합
├── skills/
│   ├── evaluate/SKILL.md       # /evaluate 명령어
│   ├── optimize/SKILL.md       # /optimize 명령어
│   └── token-guide/SKILL.md    # 토큰 효율 레퍼런스
├── agents/
│   └── token-auditor.md        # 전용 분석 에이전트
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
