# ctxcraft 개선 계획 (v4 — 최종 수렴본)

> 2026-07-27. 1차: 공식 문서 원문 대조 / 2차: ctxcraft 핵심 소스 직접 재확인 / 3차(최종): 나머지 전 파일(install.sh, plugin.json, marketplace.json, examples/) + plugins-reference 문서 확인, 기존 전 항목 근거 재감사 — **정정 0건, 신규 1건(#26)으로 수렴**.
> 검증 커버리지: 저장소 14개 파일 전부 직접 읽음. 문서 측 주장 전부 원문 인용 확보.
> 근거: [memory.md](https://code.claude.com/docs/en/memory.md) · [skills.md](https://code.claude.com/docs/en/skills.md) · [sub-agents.md](https://code.claude.com/docs/en/sub-agents.md) · [best-practices.md](https://code.claude.com/docs/en/best-practices.md) · [settings.md](https://code.claude.com/docs/en/settings.md) · [agentskills.io](https://agentskills.io)

## 검증 결과 요약

| 주장 | 판정 | 근거 (원문) |
|---|---|---|
| CLAUDE.md 200줄 권장 | ✅ 사실 | "**Size**: target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence." (memory.md) |
| path-scoped rules (`paths:` frontmatter) | ✅ 사실 | "Rules can be scoped to specific files using YAML frontmatter with the `paths` field" (memory.md) |
| rules 하위 디렉토리 | ✅ **공식 지원** | "All `.md` files are discovered recursively, so you can organize rules into subdirectories" (memory.md) |
| `@path` import는 시작 시 로드 (lazy 아님), depth 4 | ✅ 사실 | "imported files still load and enter the context window at launch" / "maximum depth of four hops" |
| auto memory: MEMORY.md 첫 200줄/25KB 로드, 기본 on | ✅ 사실 | memory.md#auto-memory |
| `/doctor`가 CLAUDE.md 트리밍 제안 | ✅ 사실 (v2.1.206+) | memory.md#my-claude-md-is-too-large |
| `claudeMdExcludes`, `autoMemoryEnabled`, `autoCompactEnabled` | ✅ 사실 | settings.md |
| Agent Skills 오픈 표준 + Cursor/Copilot/Gemini CLI/Codex 채택 | ✅ 사실 | agentskills.io (Client Showcase에 Cursor, VS Code, Codex 등 다수) |
| SKILL.md 크기 공식 권장 | ⚠️ **500줄** | "Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files." (skills.md) — ctxcraft의 150/250은 공식보다 엄격 |
| `.claudeignore` | ❌ **공식 문서에 없음** | 파일 접근 차단은 `permissions.deny`의 `Read(...)` 규칙 사용 (settings.md 재확인 완료) |
| agent `memory: true` | ❌ 형식 다름 | 실제: `memory: user \| project \| local` (스코프별 저장 경로 상이) |
| agent `permission-mode` | ❌ 필드명 다름 | 실제: `permissionMode` (camelCase) |
| `autoCompactEnabled` | ✅ 사실 | "Default: `true`. Automatically compact the conversation when context approaches the limit" (settings.md) |
| 플러그인의 `rules/` 지원 | ❌ **미지원** | plugins-reference의 컴포넌트 목록은 skills/agents/hooks/MCP/LSP/monitors/themes뿐 — rules는 플러그인 컴포넌트가 아님 |
| ctxcraft plugin.json 유효성 | ✅ 문제없음 | name/description/version/author/homepage/repository/license/keywords 모두 공식 스키마에 존재. 매니페스트는 선택 사항이며 skills/·agents/ 루트 자동 탐색으로 로드됨 |

**저장소 쪽 재검증 (2차):** 체크리스트가 인용한 모든 라인 근거를 소스에서 직접 확인 — check 14(`evaluate.sh:545-565`), check 16(`:587-602`), check 21 항상 PASS(`:761-767`), haiku 1x 버그(`:859`), 등급 S/A/B/C/D(`:967-987`), action.yml `\([A-D]\)` regex(`action.yml:38`), before.json은 evaluate.sh만 생성(`:1037`) 모두 사실. 정밀 검토에서 추가 발견 3건은 아래 반영(19번 문구 수정, 24·25번 신설).

---

## Phase 1 — 🔴 공식 문서와 정면 충돌 (평가 결과가 틀리는 항목) — ✅ 완료 (2026-07-27)

- [x] **1. check 14 반전: rules frontmatter FAIL → `paths` 권장**
  - 현재 `evaluate.sh:545-564`는 rules에 YAML frontmatter가 있으면 FAIL
  - `paths` frontmatter는 공식 lazy-load 메커니즘. 큰 rules 파일에 `paths` **추가를 권장**하는 체크로 교체

- [x] **2. check 16 제거: rules 하위 디렉토리 FAIL → 공식 지원**
  - 문서: "organize rules into subdirectories like `frontend/` or `backend/`" + 심볼릭 링크도 공식 지원
  - 하위 디렉토리·심링크를 오류로 처리하지 않도록 수정

- [x] **3. always-on 토큰 모델 재설계** (check 2/3/4/6/8의 기반)
  - `paths` 있는 rule → on-demand로 분류
  - `disable-model-invocation: true` 스킬 → **description조차 컨텍스트에 없음** (always-on 비용 0)
  - `user-invocable: false` 스킬 → description은 always-on
  - CLAUDE.md의 `@path` import 체인(최대 4 depth)을 always-on에 합산
  - 블록 레벨 HTML 주석은 주입 전 제거됨 → 줄 수/토큰 계산에서 제외
  - 하위 디렉토리의 CLAUDE.md·nested skills는 on-demand

- [x] **4. 자체 스킬 3개 + 검증 로직의 frontmatter를 공식 스펙으로**
  - `user_invocable` → `user-invocable` (공식은 kebab-case)
  - `command: /evaluate` → 스펙에 없는 필드 (명령어는 디렉토리명에서 나옴). 제거
  - `tools: [...]` → 스킬 필드 아님. 권한 사전승인은 `allowed-tools`, 도구 차단은 `disallowed-tools`
  - 공식 스킬 필드: `name`(표시명), `description`, `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`, `effort`, `context: fork`, `agent`, `background`, `hooks`, `paths`, `shell`
  - check 9의 "name/description/command 추가하라" 안내문(`evaluate.sh:486`)도 수정

- [x] **5. agent frontmatter 검증을 공식 스펙으로 (check 10, 22)**
  - 필수는 `name`, `description` **둘뿐**. `tools`는 선택(생략 시 전체 상속) — 누락을 오류로 보지 말고 least-privilege 관점의 WARN으로 재정의
  - 공식 필드: `tools`, `disallowedTools`, `model`(sonnet/opus/haiku/fable/전체 모델 ID/`inherit`, 기본 `inherit`), `permissionMode`, `maxTurns`, `skills`(전체 내용 preload), `mcpServers`, `hooks`, `memory: user|project|local`, `background`, `effort`, `isolation: worktree`, `color`, `initialPrompt`
  - check 24: `inherit`/`fable`/전체 모델 ID 인식 (현재 미인식 모델은 전부 sonnet 취급)
  - agents/ 디렉토리도 재귀 탐색 공식 지원 → 하위 폴더를 오류 처리하지 않기

## Phase 2 — 🟡 새 기능·정확한 수치 반영 — ✅ 완료 (2026-07-27)

- [x] **6. 서브에이전트 비용 모델에 CLAUDE.md 상속 반영** ★새 발견
  - 문서: 서브에이전트는 시작 시 **CLAUDE.md 계층 전체 + rules + CLAUDE.local.md를 로드** (Explore/Plan 제외)
  - 즉, 무거운 always-on 설정은 서브에이전트를 띄울 때마다 반복 과금 → 비용 축(2-axis)에 "에이전트 스폰당 배수 비용" 반영. 이것이 ctxcraft의 200줄 권장에 가장 강한 정량 근거

- [x] **7. SKILL.md 임계값을 공식 500줄에 정렬** (strict 150 / official 500 2단계)
  - 공식: "Keep SKILL.md under 500 lines" + 상세 자료는 별도 파일로
  - 현재 150(WARN)/250(FAIL)은 공식보다 엄격 — 500으로 맞추거나 "공식 500 / ctxcraft strict 150" 2단계로 명시
  - Strategy 6의 `references/` 분리는 표준(agentskills.io)의 `scripts/`·`references/`·`assets/` 규약과 일치 — 표준 인용 추가

- [x] **8. 스킬 description 1,536자 상한 체크 신설** — check 16 교체로 구현 완료
  - 공식: `description` + `when_to_use` 합산이 스킬 목록에서 1,536자에서 잘림 → 초과분은 낭비이자 손실. 정확히 측정 가능한 새 체크

- [x] **9. CLAUDE.md 임계값 통일 (내부 4벌 → 200)** (200 WARN / 500 FAIL 3단계, rules 150·budget 8K/12K도 통일)
  - evaluate.sh 500 / SKILL 200-500 / optimize 150 / rules·auditor 200 → 공식 기준 200으로 통일, 출처 URL 병기

- [x] **10. `.claude/commands/` 스캔 추가** (온디맨드 집계 + 마이그레이션 안내)
  - 커스텀 커맨드는 스킬에 병합됐지만 기존 파일도 계속 동작 — 현재 ctxcraft는 아예 안 봄
  - legacy commands 감지 → skills/ 마이그레이션 제안 (supporting files, 자동 로드 등 이점)

- [x] **11. optimize 전략 확장** (Strategy 7: Environment-Level Savings)
  - `claudeMdExcludes` (모노레포에서 무관한 CLAUDE.md 제외)
  - `AGENTS.md`가 있으면 `@AGENTS.md` import 또는 심링크로 중복 제거 (공식 권장 패턴)
  - 민감/대용량 파일 차단은 `permissions.deny`의 `Read(...)` 규칙 (~~`.claudeignore`~~는 공식 기능 아님)
  - HTML 주석 활용: 사람용 메모는 `<!-- -->`로 두면 토큰 0

- [x] **12. auto memory 감사 체크 신설** (check 21 교체 — 20번 동시 해결)
  - `~/.claude/projects/<project>/memory/MEMORY.md` — 200줄/25KB 초과분은 로드 안 됨. 인덱스+토픽 파일 구조 검사

- [x] **13. "official recommendation" 주장에 출처 명기** (+README /doctor 포지셔닝)
  - `rules/token-efficiency.md:4`, `evaluate/SKILL.md:69` → memory.md#write-effective-instructions 링크
  - `/doctor`(공식 CLAUDE.md 트리밍) 대비 차별점(rules/skills/agents 전체 + 비용 축)을 README에 명시

- [x] **14. README 크로스플랫폼 항목 갱신**
  - Cursor·Copilot·Gemini CLI·Codex 등이 Agent Skills 표준 채택 완료 — "(planned)" 문구 수정. 단 rules/agents 평가 로직은 Claude Code 전용임을 구분

## Phase 3 — 🟢 내부 일관성 (문서와 무관, 저장소 분석에서 발견) — ✅ 완료

- [x] **15. 등급 체계 3벌 통일** (7단계 A~F로 통일, action.yml regex `[A-F][+-]?`) — SKILL.md `A/A-/B+/B/C/D/F` ↔ evaluate.sh `S/A/B/C/D` ↔ action.yml regex `[A-D]`(그 외 전부 D로 오인)
- [x] **16. 두 엔진 점수 공식 통일** (정규화 공식으로 통일, N/A 제외 명시) — `100−FAIL×3−WARN×1` vs `PASS=10/WARN=5/FAIL=0 정규화`
- [x] **17. haiku 가중치 버그** (0.2x = tokens/5 정수 연산으로 수정) — 문서 0.2x, 구현 1x (`evaluate.sh:859`)
- [x] **18. plugin 경로 before/after 데이터 누락** (/evaluate Step 7이 before.json도 저장) — `ctxcraft-before.json`은 evaluate.sh만 생성
- [x] **19. 하드코딩 한국어 정리** (token-auditor 템플릿 언어중립화; evaluate.sh/action.yml 셸 UI는 한국어 유지 결정) — token-auditor 템플릿·evaluate.sh·action.yml이 locale detection 우회
- [x] **20. check 21(auto-learning) 정리** (auto memory 검사로 교체) — 항상 PASS + 비공식 `learning-log/` 의존 → 제거하거나 실제 auto memory 검사로 교체
- [x] **21. evaluate.sh의 self-clone + `claude "/optimize"` 실행 재설계** (clone/자동실행 전면 제거 → 안내문으로 대체) (`evaluate.sh:1085-1114`)
  - 재확인 결과 y/n 확인은 있으나(`:1081`), 동의 문구가 "자동 최적화 실행"뿐 — 실제로는 사용자 프로젝트 `.claude/`에 git clone 후 스킬·에이전트 복사 + `claude "/optimize"` 실행. 범위를 정확히 고지하거나 플러그인 설치 안내로 대체
- [x] **22. README 모순** — "read-only tools only"(`README.md:74`) vs optimize의 `Write, Edit` 선언
- [x] **23. check 22 완화** (참고 수준 PASS로 강등) — "reviewer는 opus" 하드 룰 → 공식 문서도 opus reviewer 예시는 있으나 규칙은 아님. INFO 수준 제안으로 강등
- [x] **24. check 20 오탐 버그** (하이픈 필수 조건 추가 — check 25와 동일) (`evaluate.sh:714`) ★2차 검증에서 발견
  - CLAUDE.md의 백틱 감싼 소문자 단어 전부를 스킬 참조로 간주 (`npm`, `pnpm`, `git` 등도 매칭) → "존재하지 않는 skill" WARN 오탐. check 25처럼 하이픈 포함 조건(`:910`) 추가 필요
- [x] **25. 사소한 정리** (AGENTS_MAX 제거, check 10 표 정합, action.yml 뱃지 확장) ★2차 검증에서 발견
  - `AGENTS_MAX=150`(`evaluate.sh:32`) 선언만 되고 어디서도 미사용
  - check 10: SKILL.md 표는 FAIL(`evaluate/SKILL.md:109`), 구현은 WARN(`evaluate.sh:456`) — 엔진 불일치 사례 추가
  - action.yml 등급 뱃지 case문(`:56-62`)도 A-D만 처리 — S/A-/B+/F는 빈 상태 메시지
- [x] **26. 플러그인 배포 시 `rules/token-efficiency.md`가 로드되지 않음** (README에 경로별 차이 명시) ★3차(최종) 검증에서 발견
  - 플러그인 컴포넌트에 rules는 없음(plugins-reference) → `claude plugin install ctxcraft@tools` 경로에서는 rules 파일이 죽은 파일 (install.sh 경로만 `~/.claude/rules/`로 복사해 로드됨 — 현재 세션에서 실증 확인)
  - 해결: README에 두 설치 경로의 차이 명시, 또는 rules 내용을 skill(`user-invocable: false`)로 이전, 또는 플러그인 설치 후 안내 메시지 추가
