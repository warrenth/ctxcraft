#!/bin/bash
# ctxcraft — AI 에이전트 컨텍스트 토큰 효율 평가 및 최적화
# Usage: curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/evaluate.sh | bash

set -e

# ─── 설정 ───
CLAUDE_DIR=".claude"
ROOT_CLAUDE="CLAUDE.md"
REPO_URL="https://github.com/warrenth/ctxcraft.git"
TOKENS_PER_LINE=12  # 보수적 추정: 줄당 평균 12 토큰

# ─── 색상 ───
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ─── 유틸리티 ───
count_lines() {
    if [ -f "$1" ]; then
        wc -l < "$1" | tr -d ' '
    else
        echo "0"
    fi
}

count_tokens() {
    local lines=$1
    echo $(( lines * TOKENS_PER_LINE ))
}

# ─── 시작 ───
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  ctxcraft — 토큰 효율 평가${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ─── .claude 디렉토리 확인 ───
if [ ! -d "$CLAUDE_DIR" ]; then
    echo -e "${RED}❌ .claude/ 디렉토리를 찾을 수 없습니다.${NC}"
    echo "   프로젝트 루트 디렉토리에서 실행해주세요."
    exit 1
fi

# ─── 1. 파일 스캔 ───
echo -e "${CYAN}📂 파일 스캔 중...${NC}"
echo ""

# 상시 로드 파일 (CLAUDE.md + rules/)
always_loaded_lines=0
always_loaded_files=0
always_loaded_detail=""

# 루트 CLAUDE.md
if [ -f "$ROOT_CLAUDE" ]; then
    lines=$(count_lines "$ROOT_CLAUDE")
    always_loaded_lines=$((always_loaded_lines + lines))
    always_loaded_files=$((always_loaded_files + 1))
    always_loaded_detail="${always_loaded_detail}   ${ROOT_CLAUDE}: ${lines}줄\n"
fi

# .claude/CLAUDE.md
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    lines=$(count_lines "$CLAUDE_DIR/CLAUDE.md")
    always_loaded_lines=$((always_loaded_lines + lines))
    always_loaded_files=$((always_loaded_files + 1))
    always_loaded_detail="${always_loaded_detail}   .claude/CLAUDE.md: ${lines}줄\n"
fi

# rules/*.md
rules_count=0
rules_lines=0
rules_detail=""
oversized_rules=""
if [ -d "$CLAUDE_DIR/rules" ]; then
    for f in "$CLAUDE_DIR/rules/"*.md; do
        [ -f "$f" ] || continue
        lines=$(count_lines "$f")
        name=$(basename "$f")
        rules_count=$((rules_count + 1))
        rules_lines=$((rules_lines + lines))
        rules_detail="${rules_detail}   rules/${name}: ${lines}줄\n"
        if [ "$lines" -gt 80 ]; then
            oversized_rules="${oversized_rules}   rules/${name}: ${lines}줄 (기준: 80줄)\n"
        fi
    done
fi
always_loaded_lines=$((always_loaded_lines + rules_lines))
always_loaded_files=$((always_loaded_files + rules_count))

# 온디맨드 파일 (skills/, agents/)
ondemand_lines=0
ondemand_files=0
skills_count=0
agents_count=0
oversized_skills=""

if [ -d "$CLAUDE_DIR/skills" ]; then
    for f in $(find "$CLAUDE_DIR/skills" -name "SKILL.md" 2>/dev/null); do
        lines=$(count_lines "$f")
        skills_count=$((skills_count + 1))
        ondemand_lines=$((ondemand_lines + lines))
        ondemand_files=$((ondemand_files + 1))
        if [ "$lines" -gt 150 ]; then
            skill_name=$(echo "$f" | sed "s|$CLAUDE_DIR/skills/||" | sed 's|/SKILL.md||')
            oversized_skills="${oversized_skills}   skills/${skill_name}: ${lines}줄 (기준: 150줄)\n"
        fi
    done
fi

if [ -d "$CLAUDE_DIR/agents" ]; then
    for f in "$CLAUDE_DIR/agents/"*.md; do
        [ -f "$f" ] || continue
        lines=$(count_lines "$f")
        name=$(basename "$f")
        agents_count=$((agents_count + 1))
        ondemand_lines=$((ondemand_lines + lines))
        ondemand_files=$((ondemand_files + 1))
    done
fi

# 토큰 계산
always_tokens=$(count_tokens $always_loaded_lines)
ondemand_tokens=$(count_tokens $ondemand_lines)
total_tokens=$((always_tokens + ondemand_tokens))

# ─── 2. 문제 감지 ───
score=100
critical=""
critical_count=0
warning=""
warning_count=0
info=""
info_count=0
quickwins=""

# 🔴 심각: CLAUDE.md 200줄 초과
if [ -f "$ROOT_CLAUDE" ]; then
    claude_lines=$(count_lines "$ROOT_CLAUDE")
    if [ "$claude_lines" -gt 200 ]; then
        penalty=$(( (claude_lines - 200) / 10 ))
        [ "$penalty" -gt 20 ] && penalty=20
        score=$((score - penalty))
        critical="${critical}   CLAUDE.md ${claude_lines}줄 → 200줄 이하로 압축 필요 (절감: ~$(count_tokens $((claude_lines - 150))) 토큰)\n"
        critical_count=$((critical_count + 1))
        quickwins="${quickwins}   CLAUDE.md를 인덱스 형태로 압축 (절감: ~$(count_tokens $((claude_lines - 150))) 토큰)\n"
    fi
fi

# 🔴 심각: 상시 로드 5,000 토큰 초과
if [ "$always_tokens" -gt 5000 ]; then
    excess=$(( (always_tokens - 3000) / 100 ))
    [ "$excess" -gt 30 ] && excess=30
    score=$((score - excess))
    critical="${critical}   상시 로드 총 ~${always_tokens} 토큰 (권장: 4,000 이하)\n"
    critical_count=$((critical_count + 1))
fi

# 🔴 심각: rules 파일 80줄 초과
if [ -n "$oversized_rules" ]; then
    oversized_count=$(echo -e "$oversized_rules" | grep -c "줄" 2>/dev/null || echo "0")
    penalty=$((oversized_count * 3))
    [ "$penalty" -gt 15 ] && penalty=15
    score=$((score - penalty))
    critical="${critical}${oversized_rules}"
    critical_count=$((critical_count + oversized_count))
    quickwins="${quickwins}   과대 rules 파일에서 예제/상세 설명을 skills로 이동\n"
fi

# 🟡 경고: rules 10개 초과
if [ "$rules_count" -gt 10 ]; then
    score=$((score - 10))
    warning="${warning}   rules/ 파일 ${rules_count}개 → 5~8개로 통합 권장\n"
    warning_count=$((warning_count + 1))
    quickwins="${quickwins}   관련 rules 파일 병합 (${rules_count}개 → 5~8개)\n"
fi

# 🟡 경고: skills 과대
if [ -n "$oversized_skills" ]; then
    oversized_s_count=$(echo -e "$oversized_skills" | grep -c "줄" 2>/dev/null || echo "0")
    score=$((score - oversized_s_count * 2))
    warning="${warning}${oversized_skills}"
    warning_count=$((warning_count + oversized_s_count))
fi

# 🟡 경고: 단계적 공개 비율 체크
if [ "$ondemand_files" -eq 0 ] && [ "$always_loaded_files" -gt 3 ]; then
    score=$((score - 15))
    warning="${warning}   단계적 공개 미적용: 모든 콘텐츠가 상시 로드됨\n"
    warning_count=$((warning_count + 1))
    quickwins="${quickwins}   상세 설명을 skills/로 이동하여 단계적 공개 적용\n"
fi

# 🟡 경고: 중복 감지 (같은 제목이 여러 파일에 존재)
if [ -d "$CLAUDE_DIR/rules" ]; then
    dup_headings=$(grep -rh "^## " "$CLAUDE_DIR/rules/" "$ROOT_CLAUDE" 2>/dev/null | sort | uniq -d | head -5)
    if [ -n "$dup_headings" ]; then
        dup_count=$(echo "$dup_headings" | wc -l | tr -d ' ')
        penalty=$((dup_count * 5))
        [ "$penalty" -gt 25 ] && penalty=25
        score=$((score - penalty))
        warning="${warning}   중복 섹션 ${dup_count}개 감지 (CLAUDE.md ↔ rules/ 간 동일 제목)\n"
        while IFS= read -r heading; do
            warning="${warning}     - ${heading}\n"
        done <<< "$dup_headings"
        warning_count=$((warning_count + 1))
    fi
fi

# 🟢 참고
if [ "$skills_count" -gt 0 ]; then
    info="${info}   skills ${skills_count}개 구성됨 (온디맨드 로드)\n"
    info_count=$((info_count + 1))
fi
if [ "$agents_count" -gt 0 ]; then
    info="${info}   agents ${agents_count}개 구성됨 (온디맨드 로드)\n"
    info_count=$((info_count + 1))
fi

# 점수 하한
[ "$score" -lt 0 ] && score=0

# ─── 3. 등급 ───
if [ "$score" -ge 85 ]; then
    grade="A"
    grade_color="$GREEN"
    grade_msg="훌륭합니다!"
elif [ "$score" -ge 70 ]; then
    grade="B"
    grade_color="$GREEN"
    grade_msg="양호합니다"
elif [ "$score" -ge 50 ]; then
    grade="C"
    grade_color="$YELLOW"
    grade_msg="개선이 필요합니다"
else
    grade="D"
    grade_color="$RED"
    grade_msg="즉시 최적화를 권장합니다"
fi

# ─── 4. 리포트 출력 ───
echo -e "${BOLD}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}│  ctxcraft — 토큰 효율 리포트                    │${NC}"
echo -e "${BOLD}├─────────────────────────────────────────────────┤${NC}"
echo ""
echo -e "  ${BOLD}점수: ${grade_color}${score}/100 (${grade}) — ${grade_msg}${NC}"
echo ""
echo -e "  ${BOLD}📊 토큰 분석${NC}"
echo -e "  상시 로드:  ${RED}~${always_tokens} 토큰${NC} (${always_loaded_files}개 파일, ${always_loaded_lines}줄)"
echo -e "  온디맨드:   ${GREEN}~${ondemand_tokens} 토큰${NC} (${ondemand_files}개 파일, ${ondemand_lines}줄)"
echo -e "  총 컨텍스트: ~${total_tokens} 토큰"
echo ""
echo -e "  ${DIM}상시 로드 상세:${NC}"
echo -e "$always_loaded_detail"
if [ -n "$rules_detail" ]; then
    echo -e "$rules_detail"
fi

if [ "$critical_count" -gt 0 ]; then
    echo -e "  ${RED}🔴 심각 (${critical_count}건)${NC}"
    echo -e "$critical"
fi

if [ "$warning_count" -gt 0 ]; then
    echo -e "  ${YELLOW}🟡 경고 (${warning_count}건)${NC}"
    echo -e "$warning"
fi

if [ "$info_count" -gt 0 ]; then
    echo -e "  ${GREEN}🟢 참고 (${info_count}건)${NC}"
    echo -e "$info"
fi

if [ -n "$quickwins" ]; then
    echo -e "  ${BLUE}💡 빠른 개선${NC}"
    echo -e "$quickwins"
fi

echo -e "${BOLD}└─────────────────────────────────────────────────┘${NC}"
echo ""

# ─── 5. 최적화 제안 ───
if [ "$score" -lt 85 ]; then
    echo -e "${BOLD}개선하시겠습니까?${NC}"
    echo -e "${DIM}ctxcraft 최적화 도구를 설치하면 Claude Code에서 /optimize 명령으로${NC}"
    echo -e "${DIM}자동 압축, 중복 제거, 재구조화를 수행할 수 있습니다.${NC}"
    echo ""
    printf "설치하시겠습니까? (y/n): "
    read -r REPLY
    echo ""

    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}📥 ctxcraft 최적화 도구 설치 중...${NC}"
        TEMP_DIR=$(mktemp -d)
        git clone --quiet --depth 1 "$REPO_URL" "$TEMP_DIR/ctxcraft"

        # skills 복사
        mkdir -p "$CLAUDE_DIR/skills"
        for skill_dir in "$TEMP_DIR/ctxcraft/skills/"*; do
            [ -d "$skill_dir" ] || continue
            skill_name=$(basename "$skill_dir")
            cp -r "$skill_dir" "$CLAUDE_DIR/skills/$skill_name"
            echo -e "  ✅ skills/${skill_name} 설치됨"
        done

        # agents 복사
        mkdir -p "$CLAUDE_DIR/agents"
        for agent_file in "$TEMP_DIR/ctxcraft/agents/"*; do
            [ -f "$agent_file" ] || continue
            agent_name=$(basename "$agent_file")
            cp "$agent_file" "$CLAUDE_DIR/agents/$agent_name"
            echo -e "  ✅ agents/${agent_name} 설치됨"
        done

        # 정리
        rm -rf "$TEMP_DIR"

        echo ""
        echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✅ 설치 완료!${NC}"
        echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Claude Code에서 다음 명령어를 실행하세요:"
        echo ""
        echo -e "  ${BOLD}/optimize${NC}        — 평가 결과 기반으로 자동 최적화"
        echo -e "  ${BOLD}/optimize --dry${NC}  — 변경 미리보기만"
        echo ""
        echo -e "${DIM}최적화 완료 후 ctxcraft 파일은 자동으로 삭제됩니다.${NC}"
        echo ""
    else
        echo -e "${DIM}설치를 건너뛰었습니다.${NC}"
        echo "나중에 설치하려면:"
        echo "  curl -sL https://raw.githubusercontent.com/warrenth/ctxcraft/main/evaluate.sh | bash"
    fi
else
    echo -e "${GREEN}✅ 이미 잘 최적화되어 있습니다! 추가 작업이 필요 없습니다.${NC}"
fi
