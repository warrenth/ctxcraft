#!/usr/bin/env bash
# ctxcraft — AI 에이전트 컨텍스트 토큰 효율 평가
# Usage: curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/evaluate.sh | bash
# CI:    bash /tmp/ctxcraft.sh --ci [--threshold=70]

set -euo pipefail

# ─────────────────────────────────────────────
# 인수 파싱
# ─────────────────────────────────────────────
CI_MODE=false
CI_THRESHOLD=70
for arg in "$@"; do
    case "$arg" in
        --ci)             CI_MODE=true ;;
        --threshold=*)    CI_THRESHOLD="${arg#*=}" ;;
    esac
done

# ─────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────
CLAUDE_DIR=".claude"
ROOT_CLAUDE="CLAUDE.md"
REPO_URL="https://github.com/warrenth/ctxcraft.git"
TOKENS_PER_LINE=12

CLAUDE_MD_MAX=500
RULES_MAX=130
RULES_MIN=80
SKILLS_MAX=250
AGENTS_MAX=150
ALWAYS_LOADED_WARN=8000
ALWAYS_LOADED_CRITICAL=15000
RULES_COUNT_MAX=15
DUP_HEADING_THRESHOLD=1

# ─────────────────────────────────────────────
# ANSI
# ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─────────────────────────────────────────────
# 스피너
# ─────────────────────────────────────────────
SPINNER_PID=""
NORMAL_EXIT=false

cleanup_on_exit() {
    if [[ -n "${SPINNER_PID:-}" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
        printf "\r\033[2K"
    fi
    if [[ "$NORMAL_EXIT" != "true" ]]; then
        echo -e "\n${YELLOW}중단됨.${RESET}"
    fi
}
trap cleanup_on_exit EXIT INT TERM

start_spinner() {
    local msg="${1:-처리 중...}"
    if [[ "$CI_MODE" == "true" ]]; then
        echo "  → ${msg}"
        return
    fi
    (
        local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        local i=0
        while true; do
            printf "\r  ${CYAN}${frames[$i]}${RESET} ${msg}  "
            i=$(( (i + 1) % ${#frames[@]} ))
            sleep 0.12
        done
    ) &
    SPINNER_PID=$!
    disown "$SPINNER_PID" 2>/dev/null
}

stop_spinner() {
    local result="${1:-완료}"
    if [[ "$CI_MODE" == "true" ]]; then
        echo "  ✓ ${result}"
        return
    fi
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
    fi
    SPINNER_PID=""
    printf "\r\033[2K"
    echo -e "  ${GREEN}✓${RESET} ${result}"
}

# ─────────────────────────────────────────────
# 결과 저장
# ─────────────────────────────────────────────
declare -a CHECK_NAMES
declare -a CHECK_STATUS    # PASS / WARN / FAIL
declare -a CHECK_DETAIL
declare -a CHECK_TOKENS    # 해당 항목의 토큰 절감 가능량
declare -a CHECK_HINTS     # 개선 방법 힌트

CHECK_IDX=0

add_result() {
    local name="$1"
    local status="$2"
    local detail="$3"
    local tokens="${4:-0}"
    local hint="${5:-}"
    CHECK_NAMES[$CHECK_IDX]="$name"
    CHECK_STATUS[$CHECK_IDX]="$status"
    CHECK_DETAIL[$CHECK_IDX]="$detail"
    CHECK_TOKENS[$CHECK_IDX]="$tokens"
    CHECK_HINTS[$CHECK_IDX]="$hint"
    CHECK_IDX=$((CHECK_IDX + 1))
}

# ─────────────────────────────────────────────
# 점수 계산
# ─────────────────────────────────────────────
score_for_status() {
    case "$1" in
        PASS) echo 10 ;;
        WARN) echo 5 ;;
        FAIL) echo 0 ;;
        *)    echo 0 ;;
    esac
}

# ─────────────────────────────────────────────
# 출력 헬퍼
# ─────────────────────────────────────────────
print_check() {
    local num="$1"
    local name="$2"
    local status="$3"
    case "$status" in
        PASS) printf "  ${GREEN}PASS${RESET}  [%2d] %s\n" "$num" "$name" ;;
        WARN) printf "  ${YELLOW}WARN${RESET}  [%2d] %s\n" "$num" "$name" ;;
        FAIL) printf "  ${RED}FAIL${RESET}  [%2d] %s\n" "$num" "$name" ;;
    esac
}

count_lines() {
    if [ -f "$1" ]; then
        wc -l < "$1" | tr -d ' '
    else
        echo "0"
    fi
}

# ─────────────────────────────────────────────
# 시작
# ─────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}${BOLD}  ctxcraft — 토큰 효율 평가${RESET}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  디렉토리: ${BOLD}$(pwd)/${CLAUDE_DIR}${RESET}"
echo ""

# .claude 확인
no_agent_system=false

if [ ! -d "$CLAUDE_DIR" ]; then
    no_agent_system=true
else
    rules_md_count=$({ find "$CLAUDE_DIR/rules" -name "*.md" 2>/dev/null || true; } | wc -l | tr -d ' ')
    skills_md_count=$({ find "$CLAUDE_DIR/skills" -name "SKILL.md" 2>/dev/null || true; } | wc -l | tr -d ' ')
    agents_md_count=$({ find "$CLAUDE_DIR/agents" -name "*.md" 2>/dev/null || true; } | wc -l | tr -d ' ')
    if [ "$rules_md_count" -eq 0 ] && [ "$skills_md_count" -eq 0 ] && [ "$agents_md_count" -eq 0 ]; then
        no_agent_system=true
    fi
fi

if [ "$no_agent_system" = true ]; then
    echo -e "${GREEN}${BOLD}━━━ 최종 요약 ━━━${RESET}"
    echo ""
    echo -e "  점수: ${GREEN}${BOLD}100/100 (A) — 토큰 낭비 없음${RESET}"
    echo ""
    echo -e "  ${YELLOW}아직 에이전트 시스템을 사용하고 계시지 않군요.${RESET}"
    echo -e "  ${DIM}.claude/rules, .claude/skills 가 없으면 낭비할 토큰도 없습니다.${RESET}"
    echo -e "  ${DIM}토큰이 걱정될 때 다시 실행하세요.${RESET}"
    echo ""
    NORMAL_EXIT=true
    exit 0
fi

# ─────────────────────────────────────────────
# Phase 1: 검증
# ─────────────────────────────────────────────
echo -e "${CYAN}${BOLD}━━━ Phase 1: 토큰 효율 검증 ━━━${RESET}\n"

start_spinner "파일 스캔 중..."
sleep 0.5

# 기본 수집
always_lines=0
always_files=0
ondemand_lines=0
ondemand_files=0
rules_count=0
skills_count=0
agents_count=0

# CLAUDE.md 줄 수
claude_md_lines=0
if [ -f "$ROOT_CLAUDE" ]; then
    claude_md_lines=$(count_lines "$ROOT_CLAUDE")
    always_lines=$((always_lines + claude_md_lines))
    always_files=$((always_files + 1))
fi
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    lines=$(count_lines "$CLAUDE_DIR/CLAUDE.md")
    always_lines=$((always_lines + lines))
    always_files=$((always_files + 1))
    claude_md_lines=$((claude_md_lines + lines))
fi

# rules 수집
declare -a OVERSIZED_RULES
rules_lines=0
if [ -d "$CLAUDE_DIR/rules" ]; then
    for f in "$CLAUDE_DIR/rules/"*.md; do
        [ -f "$f" ] || continue
        lines=$(count_lines "$f")
        rules_count=$((rules_count + 1))
        rules_lines=$((rules_lines + lines))
        always_lines=$((always_lines + lines))
        always_files=$((always_files + 1))
        if [ "$lines" -gt "$RULES_MAX" ]; then
            OVERSIZED_RULES+=("$(basename "$f"):${lines}")
        fi
    done
fi

# skills 수집
declare -a OVERSIZED_SKILLS
if [ -d "$CLAUDE_DIR/skills" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        lines=$(count_lines "$f")
        skills_count=$((skills_count + 1))
        ondemand_lines=$((ondemand_lines + lines))
        ondemand_files=$((ondemand_files + 1))
        if [ "$lines" -gt "$SKILLS_MAX" ]; then
            skill_name=$(echo "$f" | sed "s|$CLAUDE_DIR/skills/||" | sed 's|/SKILL.md||')
            OVERSIZED_SKILLS+=("${skill_name}:${lines}")
        fi
    done < <(find "$CLAUDE_DIR/skills" -name "SKILL.md" 2>/dev/null)
fi

# agents 수집
if [ -d "$CLAUDE_DIR/agents" ]; then
    for f in "$CLAUDE_DIR/agents/"*.md; do
        [ -f "$f" ] || continue
        lines=$(count_lines "$f")
        agents_count=$((agents_count + 1))
        ondemand_lines=$((ondemand_lines + lines))
        ondemand_files=$((ondemand_files + 1))
    done
    # 하위 디렉토리
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        lines=$(count_lines "$f")
        agents_count=$((agents_count + 1))
        ondemand_lines=$((ondemand_lines + lines))
        ondemand_files=$((ondemand_files + 1))
    done < <(find "$CLAUDE_DIR/agents" -mindepth 2 -name "*.md" 2>/dev/null)
fi

always_tokens=$((always_lines * TOKENS_PER_LINE))
ondemand_tokens=$((ondemand_lines * TOKENS_PER_LINE))
total_tokens=$((always_tokens + ondemand_tokens))

stop_spinner "스캔 완료 (파일 $((always_files + ondemand_files))개)"
echo ""

# ─── 검증 항목 ───

# [1] CLAUDE.md 크기
if [ "$claude_md_lines" -eq 0 ]; then
    add_result "CLAUDE.md 크기" "WARN" "CLAUDE.md 파일 없음" 0 "CLAUDE.md 생성 권장"
elif [ "$claude_md_lines" -le "$CLAUDE_MD_MAX" ]; then
    add_result "CLAUDE.md 크기" "PASS" "${claude_md_lines}줄 (기준: ${CLAUDE_MD_MAX}줄 이하)" 0
else
    save=$((claude_md_lines - 150))
    add_result "CLAUDE.md 크기" "FAIL" "${claude_md_lines}줄 → ${CLAUDE_MD_MAX}줄 이하로 압축 필요" $((save * TOKENS_PER_LINE)) "중복 설명 제거, 불릿/테이블로 압축"
fi
print_check 1 "${CHECK_NAMES[0]}" "${CHECK_STATUS[0]}" "${CHECK_DETAIL[0]}"

# [2] 상시 로드 총량
if [ "$always_tokens" -le "$ALWAYS_LOADED_WARN" ]; then
    add_result "상시 로드 토큰" "PASS" "~${always_tokens} 토큰 (${always_files}개 파일) — 기준: ${ALWAYS_LOADED_WARN} 이하" 0
elif [ "$always_tokens" -le "$ALWAYS_LOADED_CRITICAL" ]; then
    add_result "상시 로드 토큰" "WARN" "~${always_tokens} 토큰 — 기준 ${ALWAYS_LOADED_WARN} 초과" $((always_tokens - ALWAYS_LOADED_WARN)) "rules 파일 압축 또는 skills로 이동"
else
    add_result "상시 로드 토큰" "FAIL" "~${always_tokens} 토큰 — 기준 ${ALWAYS_LOADED_CRITICAL} 크게 초과" $((always_tokens - ALWAYS_LOADED_WARN)) "rules 전체 압축 필요, 절감 가능: ~$((always_tokens - ALWAYS_LOADED_WARN)) 토큰"
fi
print_check 2 "${CHECK_NAMES[1]}" "${CHECK_STATUS[1]}" "${CHECK_DETAIL[1]}"

# [3] Rules 파일 크기
if [ "$rules_count" -eq 0 ]; then
    add_result "Rules 파일 크기" "WARN" "rules/ 디렉토리 없음" 0 "rules/ 디렉토리 및 규칙 파일 생성 권장"
elif [ ${#OVERSIZED_RULES[@]} -eq 0 ]; then
    add_result "Rules 파일 크기" "PASS" "모든 rules 파일 ${RULES_MAX}줄 이하 (${rules_count}개, 권장 ${RULES_MIN}~${RULES_MAX}줄)" 0
else
    detail="기준(${RULES_MAX}줄) 초과 ${#OVERSIZED_RULES[@]}개:"
    hint_files=""
    save_tokens=0
    for entry in "${OVERSIZED_RULES[@]}"; do
        name="${entry%%:*}"
        lines="${entry##*:}"
        detail="${detail} ${name}(${lines}줄)"
        hint_files="${hint_files}${name} "
        excess=$((lines - RULES_MAX))
        save_tokens=$((save_tokens + excess * TOKENS_PER_LINE))
    done
    add_result "Rules 파일 크기" "FAIL" "$detail" "$save_tokens" "${hint_files% }— 예시/설명 제거 또는 skills로 이동"
fi
print_check 3 "${CHECK_NAMES[2]}" "${CHECK_STATUS[2]}" "${CHECK_DETAIL[2]}"

# [4] Rules 파일 수
if [ "$rules_count" -le "$RULES_COUNT_MAX" ]; then
    add_result "Rules 파일 수" "PASS" "${rules_count}개 (기준: ${RULES_COUNT_MAX}개 이하)" 0
else
    add_result "Rules 파일 수" "WARN" "${rules_count}개 → 5~8개로 통합 권장" 0 "주제 유사한 rules 파일 병합"
fi
print_check 4 "${CHECK_NAMES[3]}" "${CHECK_STATUS[3]}" "${CHECK_DETAIL[3]}"

# [5] 중복 섹션 감지
dup_count=0
dup_headings=""
if [ -d "$CLAUDE_DIR/rules" ] && [ -f "$ROOT_CLAUDE" ]; then
    dup_headings=$(grep -rh "^## " "$CLAUDE_DIR/rules/" "$ROOT_CLAUDE" 2>/dev/null | sort | uniq -d | head -5 || true)
    if [ -n "$dup_headings" ]; then
        dup_count=$(echo "$dup_headings" | wc -l | tr -d ' ')
    fi
fi
if [ "$dup_count" -eq 0 ]; then
    add_result "중복 섹션" "PASS" "CLAUDE.md ↔ rules/ 간 중복 섹션 없음" 0
elif [ "$dup_count" -le 2 ]; then
    add_result "중복 섹션" "WARN" "중복 제목 ${dup_count}개 감지: $(echo "$dup_headings" | tr '\n' ', ')" $((dup_count * 200)) "한 곳만 남기고 나머지 섹션 제거"
else
    add_result "중복 섹션" "FAIL" "중복 제목 ${dup_count}개 감지: $(echo "$dup_headings" | tr '\n' ', ')" $((dup_count * 200)) "한 곳만 남기고 나머지 섹션 제거"
fi
print_check 5 "${CHECK_NAMES[4]}" "${CHECK_STATUS[4]}" "${CHECK_DETAIL[4]}"

# [6] 단계적 공개 (Progressive Disclosure)
if [ "$ondemand_files" -gt 0 ] && [ "$always_files" -gt 0 ]; then
    ratio=$((ondemand_files * 100 / (always_files + ondemand_files)))
    if [ "$ratio" -ge 50 ]; then
        add_result "단계적 공개" "PASS" "온디맨드 ${ratio}% (${ondemand_files}개) / 상시 $((100 - ratio))% (${always_files}개)" 0
    else
        add_result "단계적 공개" "WARN" "온디맨드 ${ratio}% — 상시 로드 비중이 높음" 0 "rules 일부를 skills로 이동하여 온디맨드 비율 높이기"
    fi
elif [ "$ondemand_files" -eq 0 ] && [ "$always_files" -gt 3 ]; then
    add_result "단계적 공개" "FAIL" "skills/agents 없음 — 모든 콘텐츠가 상시 로드" 0 "skills/ 생성 후 framework별 심화 내용 이동"
else
    add_result "단계적 공개" "PASS" "구조 적절" 0
fi
print_check 6 "${CHECK_NAMES[5]}" "${CHECK_STATUS[5]}" "${CHECK_DETAIL[5]}"

# [7] Skills 파일 크기
if [ "$skills_count" -eq 0 ]; then
    add_result "Skills 파일 크기" "PASS" "skills 없음 (해당 없음)" 0
elif [ ${#OVERSIZED_SKILLS[@]} -eq 0 ]; then
    add_result "Skills 파일 크기" "PASS" "모든 SKILL.md ${SKILLS_MAX}줄 이하 (${skills_count}개)" 0
else
    detail="기준(${SKILLS_MAX}줄) 초과 ${#OVERSIZED_SKILLS[@]}개:"
    hint_files=""
    for entry in "${OVERSIZED_SKILLS[@]}"; do
        name="${entry%%:*}"
        lines="${entry##*:}"
        detail="${detail} ${name}(${lines}줄)"
        hint_files="${hint_files}${name} "
    done
    add_result "Skills 파일 크기" "WARN" "$detail" 0 "${hint_files% }— 상세 내용을 references/ 하위 폴더로 분리"
fi
print_check 7 "${CHECK_NAMES[6]}" "${CHECK_STATUS[6]}" "${CHECK_DETAIL[6]}"

# [8] 상시 vs 온디맨드 비율
if [ "$total_tokens" -gt 0 ]; then
    always_pct=$((always_tokens * 100 / total_tokens))
    if [ "$always_pct" -le 30 ]; then
        add_result "토큰 배분 비율" "PASS" "상시 ${always_pct}% / 온디맨드 $((100 - always_pct))% — 이상적" 0
    elif [ "$always_pct" -le 50 ]; then
        add_result "토큰 배분 비율" "WARN" "상시 ${always_pct}% / 온디맨드 $((100 - always_pct))% — 상시 비중 높음" 0 "rules 내 심화 내용을 skills로 이동"
    else
        add_result "토큰 배분 비율" "FAIL" "상시 ${always_pct}% / 온디맨드 $((100 - always_pct))% — 상시 비중 과다" 0 "상시 로드 파일 전면 축소 필요"
    fi
else
    add_result "토큰 배분 비율" "WARN" "분석할 파일 없음" 0 "rules/ 또는 CLAUDE.md 추가 필요"
fi
print_check 8 "${CHECK_NAMES[7]}" "${CHECK_STATUS[7]}" "${CHECK_DETAIL[7]}"

# [9] Agent YAML Frontmatter 유효성
agent_bad=0
agent_bad_list=""
if [ -d "$CLAUDE_DIR/agents" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        # frontmatter: 첫 줄이 --- 이고 닫는 --- 존재해야 함
        first_line=$(head -1 "$f" 2>/dev/null | tr -d '\r')
        if [ "$first_line" = "---" ]; then
            close_count=$(grep -c "^---$" "$f" 2>/dev/null || true)
            if [ "$close_count" -lt 2 ]; then
                agent_bad=$((agent_bad + 1))
                agent_bad_list="${agent_bad_list} $(basename "$f")"
            fi
        else
            agent_bad=$((agent_bad + 1))
            agent_bad_list="${agent_bad_list} $(basename "$f")"
        fi
    done < <(find "$CLAUDE_DIR/agents" -name "*.md" 2>/dev/null)
fi
if [ "$agents_count" -eq 0 ]; then
    add_result "Agent Frontmatter" "PASS" "agents 없음 (해당 없음)" 0
elif [ "$agent_bad" -eq 0 ]; then
    add_result "Agent Frontmatter" "PASS" "모든 agent 파일 YAML frontmatter 유효 (${agents_count}개)" 0
else
    add_result "Agent Frontmatter" "WARN" "frontmatter 누락/불완전 ${agent_bad}개:${agent_bad_list}" 0 "파일 최상단에 ---...--- YAML 블록 추가"
fi
print_check 9 "${CHECK_NAMES[8]}" "${CHECK_STATUS[8]}" "${CHECK_DETAIL[8]}"

# [10] Agent 필수 필드 검증 (name, description, tools)
agent_missing_fields=0
agent_missing_list=""
if [ -d "$CLAUDE_DIR/agents" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        missing=""
        grep -q "^name:" "$f" 2>/dev/null || missing="${missing}name "
        grep -q "^description:" "$f" 2>/dev/null || missing="${missing}description "
        grep -q "^tools:" "$f" 2>/dev/null || missing="${missing}tools "
        if [ -n "$missing" ]; then
            agent_missing_fields=$((agent_missing_fields + 1))
            agent_missing_list="${agent_missing_list} $(basename "$f")[${missing% }]"
        fi
    done < <(find "$CLAUDE_DIR/agents" -name "*.md" 2>/dev/null)
fi
if [ "$agents_count" -eq 0 ]; then
    add_result "Agent 필수 필드" "PASS" "agents 없음 (해당 없음)" 0
elif [ "$agent_missing_fields" -eq 0 ]; then
    add_result "Agent 필수 필드" "PASS" "모든 agent 파일 필수 필드(name/description/tools) 존재 (${agents_count}개)" 0
else
    add_result "Agent 필수 필드" "WARN" "필수 필드 누락 ${agent_missing_fields}개:${agent_missing_list}" 0 "frontmatter에 name:/description:/tools: 필드 추가"
fi
print_check 10 "${CHECK_NAMES[9]}" "${CHECK_STATUS[9]}" "${CHECK_DETAIL[9]}"

# [11] Skill Frontmatter 유효성
skill_bad=0
skill_bad_list=""
if [ -d "$CLAUDE_DIR/skills" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        first_line=$(head -1 "$f" 2>/dev/null | tr -d '\r')
        if [ "$first_line" = "---" ]; then
            close_count=$(grep -c "^---$" "$f" 2>/dev/null || true)
            if [ "$close_count" -lt 2 ]; then
                skill_bad=$((skill_bad + 1))
                skill_dir=$(echo "$f" | sed "s|$CLAUDE_DIR/skills/||" | sed 's|/SKILL.md||')
                skill_bad_list="${skill_bad_list} ${skill_dir}"
            fi
        else
            skill_bad=$((skill_bad + 1))
            skill_dir=$(echo "$f" | sed "s|$CLAUDE_DIR/skills/||" | sed 's|/SKILL.md||')
            skill_bad_list="${skill_bad_list} ${skill_dir}"
        fi
    done < <(find "$CLAUDE_DIR/skills" -name "SKILL.md" 2>/dev/null)
fi
if [ "$skills_count" -eq 0 ]; then
    add_result "Skill Frontmatter" "PASS" "skills 없음 (해당 없음)" 0
elif [ "$skill_bad" -eq 0 ]; then
    add_result "Skill Frontmatter" "PASS" "모든 SKILL.md frontmatter 유효 (${skills_count}개)" 0
else
    add_result "Skill Frontmatter" "WARN" "frontmatter 누락/불완전 ${skill_bad}개:${skill_bad_list}" 0 "SKILL.md 최상단에 name:/description:/command: YAML 블록 추가"
fi
print_check 11 "${CHECK_NAMES[10]}" "${CHECK_STATUS[10]}" "${CHECK_DETAIL[10]}"

# [12] Skill References 링크 유효성
skill_ref_broken=0
skill_ref_list=""
if [ -d "$CLAUDE_DIR/skills" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        skill_dir=$(dirname "$f")
        # references/ 링크 패턴 찾기
        while IFS= read -r ref_path; do
            # 상대 경로로 파일 존재 여부 확인
            full_path="${skill_dir}/${ref_path}"
            if [ ! -f "$full_path" ]; then
                skill_ref_broken=$((skill_ref_broken + 1))
                skill_name=$(echo "$f" | sed "s|$CLAUDE_DIR/skills/||" | sed 's|/SKILL.md||')
                skill_ref_list="${skill_ref_list} ${skill_name}:${ref_path}"
            fi
        done < <(grep -oE 'references/[a-zA-Z0-9_./-]+\.md' "$f" 2>/dev/null || true)
    done < <(find "$CLAUDE_DIR/skills" -name "SKILL.md" 2>/dev/null)
fi
if [ "$skills_count" -eq 0 ]; then
    add_result "Skill References 링크" "PASS" "skills 없음 (해당 없음)" 0
elif [ "$skill_ref_broken" -eq 0 ]; then
    add_result "Skill References 링크" "PASS" "모든 references 링크 유효" 0
else
    add_result "Skill References 링크" "WARN" "존재하지 않는 references ${skill_ref_broken}개:${skill_ref_list}" 0 "references/ 파일 생성 또는 SKILL.md 링크 경로 수정"
fi
print_check 12 "${CHECK_NAMES[11]}" "${CHECK_STATUS[11]}" "${CHECK_DETAIL[11]}"

# [13] Rules 하단 스킬 참조 (> 패턴)
rules_with_ref=0
rules_without_ref=0
rules_without_list=""
if [ -d "$CLAUDE_DIR/rules" ] && [ "$rules_count" -gt 0 ]; then
    for f in "$CLAUDE_DIR/rules/"*.md; do
        [ -f "$f" ] || continue
        # > 로 시작하는 참조 패턴 (심화, 참조, See, deep dive 등)
        if grep -qE "^>\s*(심화|참조|See|deep dive|자세히|더 보기)" "$f" 2>/dev/null; then
            rules_with_ref=$((rules_with_ref + 1))
        else
            rules_without_ref=$((rules_without_ref + 1))
            rules_without_list="${rules_without_list} $(basename "$f")"
        fi
    done
fi
if [ "$rules_count" -eq 0 ]; then
    add_result "Rules 스킬 참조" "PASS" "rules 없음 (해당 없음)" 0
elif [ "$rules_without_ref" -eq 0 ]; then
    add_result "Rules 스킬 참조" "PASS" "모든 rules 파일에 skills 참조 포함 (${rules_with_ref}개)" 0
elif [ "$rules_without_ref" -le $((rules_count / 2)) ]; then
    add_result "Rules 스킬 참조" "WARN" "skills 참조 없는 rules ${rules_without_ref}개:${rules_without_list}" 0 "${rules_without_list% }— 하단에 '> 심화: /skill-name' 한 줄 추가"
else
    add_result "Rules 스킬 참조" "WARN" "절반 이상의 rules에 skills 참조 없음 (${rules_without_ref}/${rules_count}개)" 0 "각 rules 파일 하단에 '> 심화: /관련-skill' 참조 추가"
fi
print_check 13 "${CHECK_NAMES[12]}" "${CHECK_STATUS[12]}" "${CHECK_DETAIL[12]}"

# [14] Rules 순수 Markdown (YAML frontmatter 없음)
rules_with_yaml=0
rules_yaml_list=""
if [ -d "$CLAUDE_DIR/rules" ]; then
    for f in "$CLAUDE_DIR/rules/"*.md; do
        [ -f "$f" ] || continue
        first_line=$(head -1 "$f" 2>/dev/null | tr -d '\r')
        if [ "$first_line" = "---" ]; then
            rules_with_yaml=$((rules_with_yaml + 1))
            rules_yaml_list="${rules_yaml_list} $(basename "$f")"
        fi
    done
fi
if [ "$rules_count" -eq 0 ]; then
    add_result "Rules 순수 Markdown" "PASS" "rules 없음 (해당 없음)" 0
elif [ "$rules_with_yaml" -eq 0 ]; then
    add_result "Rules 순수 Markdown" "PASS" "모든 rules 파일 순수 Markdown (YAML frontmatter 없음)" 0
else
    add_result "Rules 순수 Markdown" "FAIL" "YAML frontmatter 있는 rules ${rules_with_yaml}개:${rules_yaml_list} — rules는 frontmatter 불필요" 0 "${rules_yaml_list% }— 파일 상단의 ---...--- 블록 제거"
fi
print_check 14 "${CHECK_NAMES[13]}" "${CHECK_STATUS[13]}" "${CHECK_DETAIL[13]}"

# [15] Skills 고아 디렉토리 (SKILL.md 없는 skills/ 하위 폴더)
orphan_skills=0
orphan_list=""
if [ -d "$CLAUDE_DIR/skills" ]; then
    for skill_dir in "$CLAUDE_DIR/skills/"*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        if [ ! -f "${skill_dir}SKILL.md" ]; then
            orphan_skills=$((orphan_skills + 1))
            orphan_list="${orphan_list} ${skill_name}"
        fi
    done
fi
if [ "$orphan_skills" -eq 0 ]; then
    add_result "Skills 고아 디렉토리" "PASS" "모든 skills/ 하위 폴더에 SKILL.md 존재" 0
else
    add_result "Skills 고아 디렉토리" "WARN" "SKILL.md 없는 폴더 ${orphan_skills}개:${orphan_list} — 미작동 skill" 0 "${orphan_list% }— SKILL.md 생성 또는 폴더 삭제"
fi
print_check 15 "${CHECK_NAMES[14]}" "${CHECK_STATUS[14]}" "${CHECK_DETAIL[14]}"

# [16] Rules 평면 구조 (하위 디렉토리 없어야 함)
rules_subdir=0
rules_subdir_list=""
if [ -d "$CLAUDE_DIR/rules" ]; then
    for d in "$CLAUDE_DIR/rules/"*/; do
        [ -d "$d" ] || continue
        rules_subdir=$((rules_subdir + 1))
        rules_subdir_list="${rules_subdir_list} $(basename "$d")"
    done
fi
if [ "$rules_subdir" -eq 0 ]; then
    add_result "Rules 평면 구조" "PASS" "rules/ 하위 디렉토리 없음 — 올바른 구조" 0
else
    add_result "Rules 평면 구조" "FAIL" "rules/ 안에 하위 디렉토리 ${rules_subdir}개:${rules_subdir_list} — rules는 flat .md 파일만 허용" 0 "${rules_subdir_list% }— 하위 폴더 제거 후 .md 파일을 rules/ 루트로 이동"
fi
print_check 16 "${CHECK_NAMES[15]}" "${CHECK_STATUS[15]}" "${CHECK_DETAIL[15]}"

# [17] Agent Skills 참조 유효성 (agent frontmatter skills: 필드 → skills/ 실제 존재)
agent_skill_broken=0
agent_skill_list=""
if [ -d "$CLAUDE_DIR/agents" ] && [ -d "$CLAUDE_DIR/skills" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        agent_base=$(basename "$f")
        # frontmatter 내 skills: 리스트 파싱 (- item 형식)
        in_fm=false
        in_skills=false
        while IFS= read -r line; do
            line=$(echo "$line" | tr -d '\r')
            if [ "$line" = "---" ]; then
                if [ "$in_fm" = false ]; then in_fm=true; continue
                else break; fi
            fi
            [ "$in_fm" = false ] && continue
            if echo "$line" | grep -q "^skills:"; then
                in_skills=true; continue
            fi
            if [ "$in_skills" = true ]; then
                if echo "$line" | grep -qE "^  - "; then
                    skill_ref=$(echo "$line" | sed 's/^  - //' | tr -d ' ')
                    if [ ! -d "$CLAUDE_DIR/skills/$skill_ref" ]; then
                        agent_skill_broken=$((agent_skill_broken + 1))
                        agent_skill_list="${agent_skill_list} ${agent_base}:${skill_ref}"
                    fi
                elif echo "$line" | grep -qE "^[a-zA-Z]"; then
                    in_skills=false
                fi
            fi
        done < "$f"
    done < <(find "$CLAUDE_DIR/agents" -name "*.md" 2>/dev/null)
fi
if [ "$agents_count" -eq 0 ]; then
    add_result "Agent Skills 참조" "PASS" "agents 없음 (해당 없음)" 0
elif [ "$agent_skill_broken" -eq 0 ]; then
    add_result "Agent Skills 참조" "PASS" "모든 agent skills 참조 유효" 0
else
    add_result "Agent Skills 참조" "WARN" "존재하지 않는 skill 참조 ${agent_skill_broken}개:${agent_skill_list}" 0 "skills/ 디렉토리 생성 또는 agent frontmatter skills 필드 수정"
fi
print_check 17 "${CHECK_NAMES[16]}" "${CHECK_STATUS[16]}" "${CHECK_DETAIL[16]}"

# [18] Agent Tools 최소권한 (분석 전용 에이전트에 Write/Edit 없어야)
readonly_patterns="reviewer auditor architect planner"
agent_perm_bad=0
agent_perm_list=""
if [ -d "$CLAUDE_DIR/agents" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        agent_base=$(basename "$f" .md)
        # 이름에 읽기 전용 패턴이 있는지
        is_readonly=false
        for pat in $readonly_patterns; do
            echo "$agent_base" | grep -qi "$pat" && is_readonly=true && break
        done
        [ "$is_readonly" = false ] && continue
        # tools 필드에 Write 또는 Edit 있는지 (frontmatter 내)
        tools_line=$(grep "^tools:" "$f" 2>/dev/null | head -1 || true)
        if echo "$tools_line" | grep -qE "\bWrite\b|\bEdit\b"; then
            agent_perm_bad=$((agent_perm_bad + 1))
            agent_perm_list="${agent_perm_list} $(basename "$f")"
        fi
    done < <(find "$CLAUDE_DIR/agents" -name "*.md" 2>/dev/null)
fi
if [ "$agents_count" -eq 0 ]; then
    add_result "Agent Tools 최소권한" "PASS" "agents 없음 (해당 없음)" 0
elif [ "$agent_perm_bad" -eq 0 ]; then
    add_result "Agent Tools 최소권한" "PASS" "분석 전용 에이전트 모두 최소 권한 준수" 0
else
    add_result "Agent Tools 최소권한" "WARN" "reviewer/auditor/architect/planner에 Write/Edit 권한 ${agent_perm_bad}개:${agent_perm_list}" 0 "${agent_perm_list% }— tools에서 Write/Edit 제거 (Read,Grep,Glob만 유지)"
fi
print_check 18 "${CHECK_NAMES[17]}" "${CHECK_STATUS[17]}" "${CHECK_DETAIL[17]}"

# [19] Rules MUST/SHOULD/NEVER 구조 (RFC 2119 강제성 키워드)
rules_no_keywords=0
rules_no_kw_list=""
if [ -d "$CLAUDE_DIR/rules" ] && [ "$rules_count" -gt 0 ]; then
    for f in "$CLAUDE_DIR/rules/"*.md; do
        [ -f "$f" ] || continue
        missing_kw=""
        grep -q "MUST\|반드시" "$f" 2>/dev/null || missing_kw="${missing_kw}MUST "
        grep -q "SHOULD\|권장" "$f" 2>/dev/null || missing_kw="${missing_kw}SHOULD "
        grep -q "NEVER\|절대\|금지" "$f" 2>/dev/null || missing_kw="${missing_kw}NEVER "
        if [ -n "$missing_kw" ]; then
            rules_no_keywords=$((rules_no_keywords + 1))
            rules_no_kw_list="${rules_no_kw_list} $(basename "$f")[${missing_kw% }]"
        fi
    done
fi
if [ "$rules_count" -eq 0 ]; then
    add_result "Rules 강제성 키워드" "PASS" "rules 없음 (해당 없음)" 0
elif [ "$rules_no_keywords" -eq 0 ]; then
    add_result "Rules 강제성 키워드" "PASS" "모든 rules 파일에 MUST/SHOULD/NEVER 구조 존재" 0
else
    add_result "Rules 강제성 키워드" "WARN" "강제성 키워드 부족 ${rules_no_keywords}개:${rules_no_kw_list}" 0 "규칙을 '반드시 ~한다 / 권장한다 / 절대 ~금지' 형식으로 작성"
fi
print_check 19 "${CHECK_NAMES[18]}" "${CHECK_STATUS[18]}" "${CHECK_DETAIL[18]}"

# [20] CLAUDE.md ↔ skills/ 동기화 (CLAUDE.md에 언급된 스킬명이 실제 존재하는지)
claude_skill_missing=0
claude_skill_list=""
if [ -f "$ROOT_CLAUDE" ] && [ -d "$CLAUDE_DIR/skills" ]; then
    # CLAUDE.md에서 backtick으로 감싼 소문자-하이픈 패턴 추출
    while IFS= read -r skill_ref; do
        [ -z "$skill_ref" ] && continue
        if [ ! -d "$CLAUDE_DIR/skills/$skill_ref" ]; then
            claude_skill_missing=$((claude_skill_missing + 1))
            claude_skill_list="${claude_skill_list} ${skill_ref}"
        fi
    done < <(grep -oE '\`[a-z][a-z0-9-]+\`' "$ROOT_CLAUDE" 2>/dev/null | tr -d '`' | sort -u || true)
fi
if [ ! -f "$ROOT_CLAUDE" ] || [ ! -d "$CLAUDE_DIR/skills" ]; then
    add_result "CLAUDE.md ↔ Skills 동기화" "PASS" "CLAUDE.md 또는 skills/ 없음 (해당 없음)" 0
elif [ "$claude_skill_missing" -eq 0 ]; then
    add_result "CLAUDE.md ↔ Skills 동기화" "PASS" "CLAUDE.md에 언급된 모든 skill이 skills/에 존재" 0
else
    add_result "CLAUDE.md ↔ Skills 동기화" "WARN" "CLAUDE.md에 언급됐지만 skills/ 없는 항목 ${claude_skill_missing}개:${claude_skill_list}" 0 "skills/ 디렉토리 생성 또는 CLAUDE.md에서 언급 제거"
fi
print_check 20 "${CHECK_NAMES[19]}" "${CHECK_STATUS[19]}" "${CHECK_DETAIL[19]}"

# [21] 자동 학습 시스템 (Memory / Auto-trigger / 승격 시스템)

# ① Memory — 파일/디렉토리에 memory·lessons·learned 패턴 (느슨하게)
has_memory=false
_mem_files=$(find "$CLAUDE_DIR" -name "*.md" 2>/dev/null)
if [ -n "$_mem_files" ]; then
    echo "$_mem_files" | while IFS= read -r _f; do
        grep -qiE "Learned Patterns|lessons-learned|^# Memory|^## Memory" "$_f" 2>/dev/null && echo found && break
    done | grep -q found && has_memory=true || true
fi
{ find "$CLAUDE_DIR" -type d 2>/dev/null | grep -qiE "memory|memo"; } && has_memory=true || true

# ② Auto-trigger — hooks/에 .sh 파일 1개 이상
has_hooks=false
{ [ -d "$CLAUDE_DIR/hooks" ] && find "$CLAUDE_DIR/hooks" -name "*.sh" 2>/dev/null | grep -q .; } && has_hooks=true || true

# ③ 승격/학습 시스템 — promote·loop·detect·learn 이름의 skill 디렉토리 또는 agent 내용
has_promotion=false
{ find "$CLAUDE_DIR/skills" -type d 2>/dev/null | grep -qiE "promote|loop|detect|learn"; } && has_promotion=true || true
if [ "$has_promotion" = false ] && [ -d "$CLAUDE_DIR/agents" ]; then
    _agt_files=$(find "$CLAUDE_DIR/agents" -name "*.md" 2>/dev/null)
    if [ -n "$_agt_files" ]; then
        echo "$_agt_files" | while IFS= read -r _f; do
            grep -qiE "promote|learning.loop|자동 학습|auto.learn" "$_f" 2>/dev/null && echo found && break
        done | grep -q found && has_promotion=true || true
    fi
fi

# 점수 집계 — 없어도 패널티 없음(항상 PASS), 있으면 더 좋은 메시지
learn_score=0
learn_found=""
learn_missing=""
[ "$has_memory"    = true ] && { learn_score=$((learn_score + 1)); learn_found="${learn_found} Memory✓"; }    || learn_missing="${learn_missing} Memory"
[ "$has_hooks"     = true ] && { learn_score=$((learn_score + 1)); learn_found="${learn_found} Hooks✓"; }     || learn_missing="${learn_missing} Hooks"
[ "$has_promotion" = true ] && { learn_score=$((learn_score + 1)); learn_found="${learn_found} Promote✓"; }   || learn_missing="${learn_missing} Promote"

if [ "$learn_score" -eq 3 ]; then
    add_result "자동 학습 시스템" "PASS" "완전 구축됨 —${learn_found} — 반복 패턴 자동 승격으로 장기 토큰 절감 활성화" 0
elif [ "$learn_score" -ge 1 ]; then
    add_result "자동 학습 시스템" "PASS" "부분 구축됨 (${learn_score}/3) —${learn_found} / 미감지:${learn_missing}" 0
else
    add_result "자동 학습 시스템" "PASS" "미구축 (선택사항) — 구축 시 반복 패턴이 rules로 승격 → 장기 토큰 절감 가능" 0
fi
print_check 21 "${CHECK_NAMES[20]}" "${CHECK_STATUS[20]}" "${CHECK_DETAIL[20]}"

# [22] Agent Model 명시 (model 필드 없으면 비용 최적화 기회 손실)
agent_no_model=0
agent_no_model_list=""
agent_reviewer_not_opus=""
if [ -d "$CLAUDE_DIR/agents" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        agent_base=$(basename "$f" .md)
        model_val=$(grep "^model:" "$f" 2>/dev/null | head -1 | sed 's/^model:[[:space:]]*//' | tr -d ' ' || true)
        if [ -z "$model_val" ]; then
            agent_no_model=$((agent_no_model + 1))
            agent_no_model_list="${agent_no_model_list} ${agent_base}"
        else
            # reviewer 패턴인데 opus 아니면 별도 경고
            if echo "$agent_base" | grep -qi "reviewer" && [ "$model_val" != "opus" ]; then
                agent_reviewer_not_opus="${agent_base}(${model_val})"
            fi
        fi
    done < <(find "$CLAUDE_DIR/agents" -name "*.md" 2>/dev/null)
fi
if [ "$agents_count" -eq 0 ]; then
    add_result "Agent Model 명시" "PASS" "agents 없음 (해당 없음)" 0
elif [ "$agent_no_model" -eq 0 ] && [ -z "$agent_reviewer_not_opus" ]; then
    add_result "Agent Model 명시" "PASS" "모든 agent에 model 필드 명시됨 — 비용 최적화 활성화" 0
elif [ -n "$agent_reviewer_not_opus" ]; then
    add_result "Agent Model 명시" "WARN" "code-reviewer model이 opus가 아님: ${agent_reviewer_not_opus}" 0 "reviewer는 model: opus 권장 (복잡한 추론), 단순 에이전트는 haiku로 절감"
else
    add_result "Agent Model 명시" "WARN" "model 미명시 ${agent_no_model}개:${agent_no_model_list}" 0 "reviewer→opus, 단순 작업→haiku 지정 시 비용 절감 가능"
fi
print_check 22 "${CHECK_NAMES[21]}" "${CHECK_STATUS[21]}" "${CHECK_DETAIL[21]}"

# [23] Context Saving (scratch 디렉토리 + 대용량 출력 저장 규칙)

# ① scratch/temp/tmp/workspace 디렉토리 존재?
has_scratch=false
{ find "$CLAUDE_DIR" -maxdepth 1 -type d 2>/dev/null | grep -qiE "scratch|temp|tmp|workspace"; } && has_scratch=true || true

# ② rules/ 또는 CLAUDE.md에 대용량 출력 저장 관련 키워드?
has_save_rule=false
_save_targets=""
[ -f "$ROOT_CLAUDE" ] && _save_targets="$ROOT_CLAUDE"
if [ -d "$CLAUDE_DIR/rules" ]; then
    _rule_files=$(find "$CLAUDE_DIR/rules" -name "*.md" 2>/dev/null || true)
    [ -n "$_rule_files" ] && _save_targets="${_save_targets} ${_rule_files}"
fi
for _sf in $_save_targets; do
    [ -f "$_sf" ] || continue
    grep -qiE "scratch|save.*(output|log)|large.*(output|result)|임시.*저장|대용량.*저장|sub.?agent|서브.*에이전트" "$_sf" 2>/dev/null && { has_save_rule=true; break; }
done

# 점수 집계 — 없어도 패널티 없음(항상 PASS)
ctx_score=0
ctx_found=""
ctx_missing=""
[ "$has_scratch"   = true ] && { ctx_score=$((ctx_score + 1)); ctx_found="${ctx_found} ScratchDir✓"; }   || ctx_missing="${ctx_missing} ScratchDir"
[ "$has_save_rule" = true ] && { ctx_score=$((ctx_score + 1)); ctx_found="${ctx_found} SaveRule✓"; }     || ctx_missing="${ctx_missing} SaveRule"

if [ "$ctx_score" -eq 2 ]; then
    add_result "Context Saving" "PASS" "구축됨 —${ctx_found} — 대용량 출력을 대화 밖에 저장하여 토큰 절감 활성화" 0
elif [ "$ctx_score" -eq 1 ]; then
    add_result "Context Saving" "PASS" "부분 구축됨 (${ctx_score}/2) —${ctx_found} / 미감지:${ctx_missing}" 0
else
    add_result "Context Saving" "PASS" "미구축 (선택사항) — scratch 디렉토리 + 저장 규칙 추가 시 대화당 50-200K 토큰 절감 가능" 0
fi
print_check 23 "${CHECK_NAMES[22]}" "${CHECK_STATUS[22]}" "${CHECK_DETAIL[22]}"

# ─────────────────────────────────────────────
# Phase 2: 리포트 요약
# ─────────────────────────────────────────────
echo -e "${CYAN}${BOLD}━━━ Phase 2: 리포트 ━━━${RESET}\n"

# 점수 계산
total_score=0
max_score=$((CHECK_IDX * 10))
pass_count=0
warn_count=0
fail_count=0
saveable_tokens=0

for i in $(seq 0 $((CHECK_IDX - 1))); do
    total_score=$((total_score + $(score_for_status "${CHECK_STATUS[$i]}")))
    saveable_tokens=$((saveable_tokens + CHECK_TOKENS[$i]))
    case "${CHECK_STATUS[$i]}" in
        PASS) pass_count=$((pass_count + 1)) ;;
        WARN) warn_count=$((warn_count + 1)) ;;
        FAIL) fail_count=$((fail_count + 1)) ;;
    esac
done

# 100점 환산
if [ "$max_score" -gt 0 ]; then
    score_100=$((total_score * 100 / max_score))
else
    score_100=0
fi

# 등급
if [ "$score_100" -ge 85 ]; then
    grade="A"
    grade_color="$GREEN"
    grade_msg="훌륭합니다!"
elif [ "$score_100" -ge 70 ]; then
    grade="B"
    grade_color="$GREEN"
    grade_msg="양호합니다"
elif [ "$score_100" -ge 50 ]; then
    grade="C"
    grade_color="$YELLOW"
    grade_msg="개선이 필요합니다"
else
    grade="D"
    grade_color="$RED"
    grade_msg="즉시 최적화를 권장합니다"
fi

# 토큰 분석 테이블
echo -e "  ${BOLD}📊 토큰 분석${RESET}"
echo -e "  ┌────────────────────┬──────────────┬───────────┐"
echo -e "  │ 구분               │ 토큰         │ 파일 수   │"
echo -e "  ├────────────────────┼──────────────┼───────────┤"
printf "  │ 상시 로드 (매 대화) │ ${RED}%10d${RESET}   │ %5d     │\n" "$always_tokens" "$always_files"
printf "  │ 온디맨드 (필요 시)  │ ${GREEN}%10d${RESET}   │ %5d     │\n" "$ondemand_tokens" "$ondemand_files"
echo -e "  ├────────────────────┼──────────────┼───────────┤"
printf "  │ 합계               │ %10d   │ %5d     │\n" "$total_tokens" "$((always_files + ondemand_files))"
echo -e "  └────────────────────┴──────────────┴───────────┘"
echo ""

# 개선 필요 항목 (FAIL/WARN만 표시)
has_issues=false
for i in $(seq 0 $((CHECK_IDX - 1))); do
    [[ "${CHECK_STATUS[$i]}" == "PASS" ]] && continue
    has_issues=true
    break
done

if [ "$has_issues" = true ]; then
    echo -e "  ${BOLD}📋 개선 필요 항목${RESET}"
    for i in $(seq 0 $((CHECK_IDX - 1))); do
        status="${CHECK_STATUS[$i]}"
        [[ "$status" == "PASS" ]] && continue
        num=$((i + 1))
        name="${CHECK_NAMES[$i]}"
        hint="${CHECK_HINTS[$i]}"
        hint_str=""
        [ -n "$hint" ] && hint_str="  ${DIM}→ ${hint}${RESET}"
        case "$status" in
            WARN) printf "  ${YELLOW}WARN${RESET}  [%2d] %-22s%b\n" "$num" "$name" "$hint_str" ;;
            FAIL) printf "  ${RED}FAIL${RESET}  [%2d] %-22s%b\n" "$num" "$name" "$hint_str" ;;
        esac
    done
    echo ""
fi

# 절감 가능 토큰
if [ "$saveable_tokens" -gt 0 ]; then
    echo -e "  ${BLUE}💡 절감 가능: ~${saveable_tokens} 토큰/대화${RESET}"
    echo ""
fi

# ─────────────────────────────────────────────
# Before 상태 저장 (optimize 후 비교용)
# ─────────────────────────────────────────────
mkdir -p "$CLAUDE_DIR/scratch"
cat > "$CLAUDE_DIR/scratch/ctxcraft-before.json" << EOF
{
  "score": ${score_100},
  "grade": "${grade}",
  "always_tokens": ${always_tokens},
  "ondemand_tokens": ${ondemand_tokens},
  "total_tokens": ${total_tokens},
  "pass": ${pass_count},
  "warn": ${warn_count},
  "fail": ${fail_count},
  "saveable_tokens": ${saveable_tokens}
}
EOF

# ─────────────────────────────────────────────
# 최종 요약
# ─────────────────────────────────────────────
echo -e "${CYAN}${BOLD}━━━ 최종 요약 ━━━${RESET}"
echo -e "  점수: ${BOLD}${grade_color}${score_100}/100 (${grade})${RESET} — ${grade_color}${grade_msg}${RESET}"
echo -e "  ${GREEN}PASS${RESET} ${pass_count}개  ${YELLOW}WARN${RESET} ${warn_count}개  ${RED}FAIL${RESET} ${fail_count}개"
echo ""

# ─────────────────────────────────────────────
# Phase 3: 최적화 제안
# ─────────────────────────────────────────────
if [ "$score_100" -lt 85 ]; then
    # CI 모드: Phase 3 건너뛰고 종료 코드로 결과 반환
    if [[ "$CI_MODE" == "true" ]]; then
        echo ""
        if [ "$score_100" -lt "$CI_THRESHOLD" ]; then
            echo "::error::ctxcraft 점수 ${score_100}/100 — 기준 ${CI_THRESHOLD}점 미달"
            NORMAL_EXIT=true
            exit 1
        else
            echo "::notice::ctxcraft 점수 ${score_100}/100 (${grade}) — 기준 통과"
            NORMAL_EXIT=true
            exit 0
        fi
    fi

    echo -e "${CYAN}${BOLD}━━━ Phase 3: 최적화 ━━━${RESET}\n"
    echo -e "  평가 결과를 바탕으로 자동 최적화를 실행합니다."
    echo -e "  ${DIM}(압축, 중복 제거, 재구조화 — 완료 후 자동 삭제)${RESET}"
    echo ""
    printf "  지금 최적화하시겠습니까? (y/n): "
    read -r REPLY
    echo ""

    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        # 1. 스킬 설치
        start_spinner "ctxcraft 최적화 도구 설치 중..."
        TEMP_DIR=$(mktemp -d)
        git clone --quiet --depth 1 "$REPO_URL" "$TEMP_DIR/ctxcraft"

        mkdir -p "$CLAUDE_DIR/skills"
        for skill_dir in "$TEMP_DIR/ctxcraft/skills/"*; do
            [ -d "$skill_dir" ] || continue
            skill_name=$(basename "$skill_dir")
            cp -r "$skill_dir" "$CLAUDE_DIR/skills/$skill_name"
        done

        mkdir -p "$CLAUDE_DIR/agents"
        for agent_file in "$TEMP_DIR/ctxcraft/agents/"*; do
            [ -f "$agent_file" ] || continue
            cp "$agent_file" "$CLAUDE_DIR/agents/"
        done

        rm -rf "$TEMP_DIR"
        stop_spinner "설치 완료"
        echo ""

        # 2. claude CLI로 /optimize 자동 실행
        if command -v claude &>/dev/null; then
            echo -e "  ${GREEN}✓${RESET} Claude Code 감지 — 최적화를 시작합니다."
            echo -e "  ${DIM}완료 후 ctxcraft 파일은 자동으로 삭제됩니다.${RESET}"
            echo ""
            NORMAL_EXIT=true
            claude "/optimize"
        else
            echo -e "  ${YELLOW}⚠${RESET}  claude CLI를 찾을 수 없습니다."
            echo -e "  Claude Code에서 직접 실행하세요:"
            echo ""
            echo -e "    ${BOLD}/optimize${RESET}        — 자동 최적화"
            echo -e "    ${BOLD}/optimize --dry${RESET}  — 미리보기만"
            echo ""
            echo -e "  ${DIM}최적화 완료 후 ctxcraft 파일은 자동으로 삭제됩니다.${RESET}"
        fi
    else
        echo -e "  ${DIM}건너뛰었습니다.${RESET}"
        echo -e "  나중에 다시: ${DIM}curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/evaluate.sh | bash${RESET}"
    fi
else
    echo -e "  ${GREEN}✅ 이미 잘 최적화되어 있습니다!${RESET}"
fi

echo ""
NORMAL_EXIT=true
