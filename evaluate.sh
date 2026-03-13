#!/usr/bin/env bash
# ctxcraft — AI 에이전트 컨텍스트 토큰 효율 평가
# Usage: curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/evaluate.sh | bash

set -euo pipefail

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

CHECK_IDX=0

add_result() {
    local name="$1"
    local status="$2"
    local detail="$3"
    local tokens="${4:-0}"
    CHECK_NAMES[$CHECK_IDX]="$name"
    CHECK_STATUS[$CHECK_IDX]="$status"
    CHECK_DETAIL[$CHECK_IDX]="$detail"
    CHECK_TOKENS[$CHECK_IDX]="$tokens"
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
    local detail="$4"
    printf "${BOLD}[%2d] %s${RESET}\n" "$num" "$name"
    case "$status" in
        PASS) echo -e "     ${GREEN}PASS${RESET} $detail" ;;
        WARN) echo -e "     ${YELLOW}WARN${RESET} $detail" ;;
        FAIL) echo -e "     ${RED}FAIL${RESET} $detail" ;;
    esac
    echo ""
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
elif [ ! -d "$CLAUDE_DIR/rules" ] && [ ! -d "$CLAUDE_DIR/skills" ]; then
    no_agent_system=true
elif [ ! -d "$CLAUDE_DIR/rules" ] && [ ! -d "$CLAUDE_DIR/skills" ]; then
    no_agent_system=true
else
    # rules, skills 디렉토리가 있어도 파일이 없으면
    rules_md_count=$(find "$CLAUDE_DIR/rules" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    skills_md_count=$(find "$CLAUDE_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$rules_md_count" -eq 0 ] && [ "$skills_md_count" -eq 0 ]; then
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
    echo ""
    echo -e "  Claude Code 에이전트 시스템을 시작하고 싶다면:"
    echo -e "  ${DIM}https://github.com/warrenth/ctxcraft${RESET}"
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
    add_result "CLAUDE.md 크기" "WARN" "CLAUDE.md 파일 없음" 0
elif [ "$claude_md_lines" -le "$CLAUDE_MD_MAX" ]; then
    add_result "CLAUDE.md 크기" "PASS" "${claude_md_lines}줄 (기준: ${CLAUDE_MD_MAX}줄 이하)" 0
else
    save=$((claude_md_lines - 150))
    add_result "CLAUDE.md 크기" "FAIL" "${claude_md_lines}줄 → ${CLAUDE_MD_MAX}줄 이하로 압축 필요" $((save * TOKENS_PER_LINE))
fi
print_check 1 "${CHECK_NAMES[0]}" "${CHECK_STATUS[0]}" "${CHECK_DETAIL[0]}"

# [2] 상시 로드 총량
if [ "$always_tokens" -le "$ALWAYS_LOADED_WARN" ]; then
    add_result "상시 로드 토큰" "PASS" "~${always_tokens} 토큰 (${always_files}개 파일) — 기준: ${ALWAYS_LOADED_WARN} 이하" 0
elif [ "$always_tokens" -le "$ALWAYS_LOADED_CRITICAL" ]; then
    add_result "상시 로드 토큰" "WARN" "~${always_tokens} 토큰 — 기준 ${ALWAYS_LOADED_WARN} 초과" $((always_tokens - ALWAYS_LOADED_WARN))
else
    add_result "상시 로드 토큰" "FAIL" "~${always_tokens} 토큰 — 기준 ${ALWAYS_LOADED_CRITICAL} 크게 초과" $((always_tokens - ALWAYS_LOADED_WARN))
fi
print_check 2 "${CHECK_NAMES[1]}" "${CHECK_STATUS[1]}" "${CHECK_DETAIL[1]}"

# [3] Rules 파일 크기
if [ "$rules_count" -eq 0 ]; then
    add_result "Rules 파일 크기" "WARN" "rules/ 디렉토리 없음" 0
elif [ ${#OVERSIZED_RULES[@]} -eq 0 ]; then
    add_result "Rules 파일 크기" "PASS" "모든 rules 파일 ${RULES_MAX}줄 이하 (${rules_count}개, 권장 ${RULES_MIN}~${RULES_MAX}줄)" 0
else
    detail="기준(${RULES_MAX}줄) 초과 ${#OVERSIZED_RULES[@]}개:"
    save_tokens=0
    for entry in "${OVERSIZED_RULES[@]}"; do
        name="${entry%%:*}"
        lines="${entry##*:}"
        detail="${detail} ${name}(${lines}줄)"
        excess=$((lines - RULES_MAX))
        save_tokens=$((save_tokens + excess * TOKENS_PER_LINE))
    done
    add_result "Rules 파일 크기" "FAIL" "$detail" "$save_tokens"
fi
print_check 3 "${CHECK_NAMES[2]}" "${CHECK_STATUS[2]}" "${CHECK_DETAIL[2]}"

# [4] Rules 파일 수
if [ "$rules_count" -le "$RULES_COUNT_MAX" ]; then
    add_result "Rules 파일 수" "PASS" "${rules_count}개 (기준: ${RULES_COUNT_MAX}개 이하)" 0
else
    add_result "Rules 파일 수" "WARN" "${rules_count}개 → 5~8개로 통합 권장" 0
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
    add_result "중복 섹션" "WARN" "중복 제목 ${dup_count}개 감지: $(echo "$dup_headings" | tr '\n' ', ')" $((dup_count * 200))
else
    add_result "중복 섹션" "FAIL" "중복 제목 ${dup_count}개 감지: $(echo "$dup_headings" | tr '\n' ', ')" $((dup_count * 200))
fi
print_check 5 "${CHECK_NAMES[4]}" "${CHECK_STATUS[4]}" "${CHECK_DETAIL[4]}"

# [6] 단계적 공개 (Progressive Disclosure)
if [ "$ondemand_files" -gt 0 ] && [ "$always_files" -gt 0 ]; then
    ratio=$((ondemand_files * 100 / (always_files + ondemand_files)))
    if [ "$ratio" -ge 50 ]; then
        add_result "단계적 공개" "PASS" "온디맨드 ${ratio}% (${ondemand_files}개) / 상시 $((100 - ratio))% (${always_files}개)" 0
    else
        add_result "단계적 공개" "WARN" "온디맨드 ${ratio}% — 상시 로드 비중이 높음" 0
    fi
elif [ "$ondemand_files" -eq 0 ] && [ "$always_files" -gt 3 ]; then
    add_result "단계적 공개" "FAIL" "skills/agents 없음 — 모든 콘텐츠가 상시 로드" 0
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
    for entry in "${OVERSIZED_SKILLS[@]}"; do
        name="${entry%%:*}"
        lines="${entry##*:}"
        detail="${detail} ${name}(${lines}줄)"
    done
    add_result "Skills 파일 크기" "WARN" "$detail" 0
fi
print_check 7 "${CHECK_NAMES[6]}" "${CHECK_STATUS[6]}" "${CHECK_DETAIL[6]}"

# [8] 상시 vs 온디맨드 비율
if [ "$total_tokens" -gt 0 ]; then
    always_pct=$((always_tokens * 100 / total_tokens))
    if [ "$always_pct" -le 30 ]; then
        add_result "토큰 배분 비율" "PASS" "상시 ${always_pct}% / 온디맨드 $((100 - always_pct))% — 이상적" 0
    elif [ "$always_pct" -le 50 ]; then
        add_result "토큰 배분 비율" "WARN" "상시 ${always_pct}% / 온디맨드 $((100 - always_pct))% — 상시 비중 높음" 0
    else
        add_result "토큰 배분 비율" "FAIL" "상시 ${always_pct}% / 온디맨드 $((100 - always_pct))% — 상시 비중 과다" 0
    fi
else
    add_result "토큰 배분 비율" "WARN" "분석할 파일 없음" 0
fi
print_check 8 "${CHECK_NAMES[7]}" "${CHECK_STATUS[7]}" "${CHECK_DETAIL[7]}"

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

# 검증 결과 테이블
echo -e "  ${BOLD}📋 검증 결과${RESET}"
for i in $(seq 0 $((CHECK_IDX - 1))); do
    num=$((i + 1))
    name="${CHECK_NAMES[$i]}"
    status="${CHECK_STATUS[$i]}"
    case "$status" in
        PASS) status_display="${GREEN}PASS${RESET}" ;;
        WARN) status_display="${YELLOW}WARN${RESET}" ;;
        FAIL) status_display="${RED}FAIL${RESET}" ;;
    esac
    printf "  %b  [%d] %s\n" "$status_display" "$num" "$name"
done
echo ""

# 절감 가능 토큰
if [ "$saveable_tokens" -gt 0 ]; then
    echo -e "  ${BLUE}💡 절감 가능: ~${saveable_tokens} 토큰/대화${RESET}"
    echo ""
fi

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
    echo -e "${CYAN}${BOLD}━━━ Phase 3: 최적화 ━━━${RESET}\n"
    echo -e "  ctxcraft 최적화 도구를 설치하면 Claude Code에서"
    echo -e "  ${BOLD}/optimize${RESET} 명령으로 자동 최적화를 수행할 수 있습니다."
    echo -e "  ${DIM}(압축, 중복 제거, 재구조화 — 완료 후 자동 삭제)${RESET}"
    echo ""
    printf "  설치하시겠습니까? (y/n): "
    read -r REPLY
    echo ""

    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
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
        echo -e "  ${BOLD}Claude Code에서 실행하세요:${RESET}"
        echo ""
        echo -e "    ${BOLD}/optimize${RESET}        — 자동 최적화"
        echo -e "    ${BOLD}/optimize --dry${RESET}  — 미리보기만"
        echo ""
        echo -e "  ${DIM}최적화 완료 후 ctxcraft 파일은 자동으로 삭제됩니다.${RESET}"
    else
        echo -e "  ${DIM}건너뛰었습니다.${RESET}"
        echo -e "  나중에 다시: ${DIM}curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/evaluate.sh | bash${RESET}"
    fi
else
    echo -e "  ${GREEN}✅ 이미 잘 최적화되어 있습니다!${RESET}"
fi

echo ""
NORMAL_EXIT=true
