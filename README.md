# ctxcraft

> AI 에이전트 컨텍스트를 평가하고 최적화하세요. 토큰을 아끼고, 비용을 줄이세요.

**ctxcraft**는 `.claude/` 디렉토리 구조를 분석하여 기능 손실 없이 토큰 소비를 줄이는 구체적인 개선안을 제시합니다.

## 문제

AI 코딩 에이전트(Claude Code, Cursor, Windsurf)는 매 대화마다 컨텍스트 파일을 로드합니다. `.claude/` 디렉토리가 커질수록 다음과 같은 토큰 낭비가 조용히 발생합니다:

- 절반으로 줄일 수 있는 장황한 규칙 파일
- rules, skills, CLAUDE.md 간 중복 콘텐츠
- 한 번도 호출되지 않는 미사용 skills/agents
- 온디맨드로 전환 가능한 상시 로드 파일

## 기능

| 명령어 | 설명 |
|--------|------|
| `/evaluate` | `.claude/` 디렉토리 스캔, 토큰 사용량 추정, 효율 점수(0-100) 산출 |
| `/optimize` | 평가 결과 기반으로 개선 적용 |

## 빠른 시작

### 방법 1: 설치 스크립트 (권장)

```bash
curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/install.sh | bash
```

### 방법 2: 수동 복사

```bash
git clone https://github.com/warrenth/ctxcraft.git
cp -r ctxcraft/skills/* /path/to/your/project/.claude/skills/
cp -r ctxcraft/rules/* /path/to/your/project/.claude/rules/
```

## `/evaluate` 리포트 예시

```
┌─────────────────────────────────────────────────┐
│  ctxcraft — 토큰 효율 리포트                      │
│                                                  │
│  점수: 64/100                                    │
│                                                  │
│  📊 토큰 분석                                     │
│  상시 로드 (rules, CLAUDE.md):  ~4,200 토큰       │
│  온디맨드 (skills, agents):     ~8,500 토큰       │
│  추정 낭비:                     ~1,800 토큰       │
│                                                  │
│  🔴 심각                                         │
│  • CLAUDE.md 320줄 → 150줄로 압축 가능            │
│                                                  │
│  🟡 경고                                         │
│  • rules 파일 3개에서 내용 중복 감지               │
│  • 최근 10세션 동안 미참조 skill 4개               │
│                                                  │
│  🟢 양호                                         │
│  • 에이전트 위임 구조가 잘 설계됨                   │
│  • Skills에 단계적 공개 패턴 적용됨                │
└─────────────────────────────────────────────────┘
```

## `/optimize`가 하는 일

1. **압축** — 의미를 유지하면서 장황한 rules와 CLAUDE.md 축소
2. **중복 제거** — 겹치는 규칙을 단일 소스로 병합
3. **정리** — 미사용 skills/agents 식별 및 제거
4. **재구조화** — 상시 로드 콘텐츠를 온디맨드 skills로 이동

모든 변경은 적용 전 사용자 확인을 거칩니다.

## 프로젝트 구조

```
ctxcraft/
├── skills/
│   ├── evaluate/SKILL.md     # /evaluate 명령어
│   ├── optimize/SKILL.md     # /optimize 명령어
│   └── token-guide/SKILL.md  # 토큰 효율 레퍼런스
├── rules/
│   └── token-efficiency.md   # 상시 로드 효율 규칙
├── agents/
│   └── token-auditor.md      # 전용 분석 에이전트
└── install.sh                # 원라인 설치 스크립트
```

## 점수 산정 기준

| 항목 | 가중치 | 측정 내용 |
|------|--------|----------|
| 상시 로드 크기 | 30% | rules/ + CLAUDE.md 총 토큰 수 |
| 중복도 | 25% | 파일 간 콘텐츠 겹침 |
| 미사용 파일 | 20% | 최근 사용 기록 없는 skills/agents |
| 단계적 공개 | 15% | 온디맨드 vs 상시 로드 비율 |
| 구조 | 10% | 네이밍, 구성, 모듈화 |

## 지원 환경

- [x] Claude Code
- [ ] Cursor (예정)
- [ ] Windsurf (예정)
- [ ] Cline (예정)

## 기여

기여를 환영합니다! [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.

## 라이선스

MIT
