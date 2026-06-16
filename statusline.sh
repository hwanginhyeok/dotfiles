#!/bin/bash
input=$(cat)

# GLM 세션 감지
IS_GLM=false
if [[ "${ANTHROPIC_BASE_URL:-}" == *"z.ai"* ]]; then
  IS_GLM=true
fi

# 모델명 (짧게)
if $IS_GLM; then
  MODEL="GLM-5.1"
else
  MODEL=$(echo "$input" | jq -r '.model.display_name' | sed 's/ (.*context)//' | sed 's/Claude //')
fi

# 컨텍스트 — 사용량 기준 표기 (5h/7d와 방향 통일, 2026-05-23 변경)
CTX_REMAIN=$(echo "$input" | jq -r '.context_window.remaining_percentage // 0' | cut -d. -f1)
CTX_USED=$((100 - ${CTX_REMAIN:-0}))

# 디렉토리 (JSON의 workspace.current_dir 우선)
DIR=$(echo "$input" | jq -r '.workspace.current_dir // empty')
DIR=$(basename "${DIR:-$(pwd)}")

# 색상
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
RESET='\033[0m'

# 컨텍스트 색상 (사용량 기준 — 5h/7d와 통일)
if [ "${CTX_USED:-0}" -ge 90 ]; then CTX_COLOR=$RED
elif [ "${CTX_USED:-0}" -ge 70 ]; then CTX_COLOR=$YELLOW
else CTX_COLOR=$GREEN; fi

# --- 5시간 rate limit ---
RATE_5H_PCT=0
RATE_5H_TIME=""
if ! $IS_GLM; then
  RATE_5H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0' | cut -d. -f1)
  RATE_5H_TS=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // 0')
  if [ "${RATE_5H_TS:-0}" -gt 0 ]; then
    RATE_5H_TIME=$(date -d "@$RATE_5H_TS" '+%H:%M' 2>/dev/null)
  fi
fi

if [ "${RATE_5H_PCT:-0}" -ge 80 ]; then R5_COLOR=$RED
elif [ "${RATE_5H_PCT:-0}" -ge 50 ]; then R5_COLOR=$YELLOW
else R5_COLOR=$GREEN; fi

# --- 7일(전체) rate limit ---
RATE_7D_PCT=0
RATE_7D_LABEL=""
if ! $IS_GLM; then
  RATE_7D_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0' | cut -d. -f1)
  RATE_7D_TS=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // 0')
  if [ "${RATE_7D_TS:-0}" -gt 0 ]; then
    DOW_EN=$(date -d "@$RATE_7D_TS" '+%a' 2>/dev/null)
    case $DOW_EN in
      Mon) DOW="월" ;; Tue) DOW="화" ;; Wed) DOW="수" ;; Thu) DOW="목" ;;
      Fri) DOW="금" ;; Sat) DOW="토" ;; Sun) DOW="일" ;; *) DOW="?" ;;
    esac
    RATE_7D_DATE=$(date -d "@$RATE_7D_TS" '+%m/%d' 2>/dev/null)
    RATE_7D_LABEL="${DOW}${RATE_7D_DATE}"
  fi
fi

if [ "${RATE_7D_PCT:-0}" -ge 80 ]; then R7_COLOR=$RED
elif [ "${RATE_7D_PCT:-0}" -ge 50 ]; then R7_COLOR=$YELLOW
else R7_COLOR=$GREEN; fi

# 야간작업 진행 (유용한 알림만 유지)
OVERNIGHT=""
if [ -f tonight_prompt.txt ]; then
  OVERNIGHT=" | ${YELLOW}야간작업중${RESET}"
elif [ -f tonight_prompt_done.txt ]; then
  OVERNIGHT=" | ${GREEN}야간완료${RESET}"
fi

# daily_alert 경고
ALERT=""
ALERT_FILE="$HOME/.pm_logs/daily_alert.txt"
if [ -s "$ALERT_FILE" ]; then
  ALERT_MSG=$(head -1 "$ALERT_FILE")
  ALERT=" | ${YELLOW}⚠ ${ALERT_MSG}${RESET}"
fi

if $IS_GLM; then
  echo -e "[${MODEL}] ctx:${CTX_COLOR}${CTX_USED}%${RESET} | 📁${DIR}${OVERNIGHT}${ALERT}"
else
  echo -e "[${MODEL}] ctx:${CTX_COLOR}${CTX_USED}%${RESET} | 📁${DIR} | 5h:${R5_COLOR}${RATE_5H_PCT}%↺${RATE_5H_TIME}${RESET} | 7d:${R7_COLOR}${RATE_7D_PCT}%↺${RATE_7D_LABEL}${RESET}${OVERNIGHT}${ALERT}"
fi
