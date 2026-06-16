#!/usr/bin/env bash
# Claude Code status line command
# 입력: JSON via stdin

input=$(cat)

# 현재 디렉토리 (홈 디렉토리는 ~ 로 축약)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
home_dir="$HOME"
short_cwd="${cwd/#$home_dir/~}"

# 모델 표시명 (짧게)
model=$(echo "$input" | jq -r '.model.display_name // ""')

# 컨텍스트 사용률
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# 누적 토큰 (입력 + 출력)
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# git 브랜치 (cwd 기준)
git_branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

# 출력 조합
parts=()

# 디렉토리 + git 브랜치
if [ -n "$git_branch" ]; then
    parts+=("$(printf '\033[0;34m%s\033[0m' "$short_cwd") $(printf '\033[0;33m(%s)\033[0m' "$git_branch")")
else
    parts+=("$(printf '\033[0;34m%s\033[0m' "$short_cwd")")
fi

# 모델
if [ -n "$model" ]; then
    parts+=("$(printf '\033[0;36m%s\033[0m' "$model")")
fi

# 컨텍스트 사용률
if [ -n "$used_pct" ]; then
    # 사용률에 따라 색상 변경: 80% 이상 빨강, 60% 이상 노랑, 나머지 초록
    used_int=$(printf '%.0f' "$used_pct")
    if [ "$used_int" -ge 80 ]; then
        ctx_color='\033[0;31m'
    elif [ "$used_int" -ge 60 ]; then
        ctx_color='\033[0;33m'
    else
        ctx_color='\033[0;32m'
    fi
    parts+=("$(printf "${ctx_color}ctx:%.0f%%\033[0m" "$used_pct")")
fi

# 누적 토큰
if [ "$total_in" -gt 0 ] || [ "$total_out" -gt 0 ]; then
    total_k=$(( (total_in + total_out) / 1000 ))
    parts+=("$(printf '\033[0;90m%dk tokens\033[0m' "$total_k")")
fi

# 구분자로 연결
printf '%s' "${parts[0]}"
for part in "${parts[@]:1}"; do
    printf ' | %s' "$part"
done
printf '\n'
