#!/usr/bin/env bash
# hih-tax 세법 변경 감지 (알림 전용 — 자동 수정 절대 안 함)
#
# 설계 의도 (제1원칙):
#   세법은 연 1회 사이클로 바뀐다 (7~8월 개정안 발표 → 12월 국회 통과 → 익년 1/1 시행).
#   따라서 "매일 자동 갱신"은 헛돈다. LLM이 세무 수치를 자동으로 덮어쓰면 틀린 조언 위험.
#   → 이 스크립트는 "지금 갱신을 점검할 때다"를 사람에게 알리기만 한다.
#      실제 검증·갱신은 사람이 `/hih-tax 세법 갱신` 세션에서 승인 후 수행 (publish-gate).
#
# 알림 신호 3종:
#   1. 달력 윈도우: 8월(개정안)·12월(통과)·1월(시행) → 정기 점검 알림
#   2. 검증일 노후: tax-data.md last_verified가 N개월+ 지남 → stale 경고
#   3. (선택) 국세청 보도자료 스크랩: TAX_WATCH_URL 설정 시 best-effort, 실패해도 무방
#
# cron 등록 (Hermes가 등록 — feedback_cron_hermes_only):
#   0 9 1 * *  cd /home/window11/hih-skills/hih-tax && bash scripts/check_tax_updates.sh >> ~/.pm_logs/hih_tax_updates.log 2>&1
#   (매월 1일 09:00. 8/12/1월에만 정기알림, 그 외엔 노후 시에만 알림 → 노이즈 최소)
#
# 환경변수: ~/.hermes/.env 의 TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
#   (선택) TAX_WATCH_URL — 국세청 세법개정 보도자료 페이지 URL (검증 후 설정)

set -u

SKILL_DIR="/home/window11/hih-skills/hih-tax"
DATA_FILE="$SKILL_DIR/references/tax-data.md"
ENV_FILE="${HIH_TAX_ENV:-$HOME/.hermes/.env}"
STATE_DIR="$HOME/.pm_logs"
STATE_FILE="$STATE_DIR/hih_tax_updates.state"   # 마지막 스크랩 스냅샷 해시
STALE_MONTHS=6                                   # 검증일 N개월 초과 시 경고

mkdir -p "$STATE_DIR"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        # shellcheck disable=SC1091
        source "$ENV_FILE"
        set +a
    fi
}

send_telegram() {
    local message="$1"
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        echo "[$(ts)] [WARN] TELEGRAM 토큰 미설정 ($ENV_FILE) — 알림 생략. 메시지: $message"
        return 1
    fi
    curl -fsS --max-time 10 \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${message}" \
        -d "parse_mode=HTML" \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" > /dev/null \
        && echo "[$(ts)] [OK] 텔레그램 알림 전송" \
        || echo "[$(ts)] [ERR] 텔레그램 전송 실패"
}

# tax-data.md last_verified 읽기 → 경과 개월 계산
verified_age_months() {
    local lv
    lv=$(grep -m1 'last_verified:' "$DATA_FILE" 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
    [[ -z "$lv" ]] && { echo 999; return; }
    local lv_epoch now_epoch
    lv_epoch=$(date -d "$lv" +%s 2>/dev/null) || { echo 999; return; }
    now_epoch=$(date +%s)
    echo $(( (now_epoch - lv_epoch) / 2592000 ))   # 30일 ≈ 1개월
}

# (선택) 국세청 보도자료 best-effort 스크랩 — 실패 무방
scrape_check() {
    [[ -z "${TAX_WATCH_URL:-}" ]] && return 0
    local html new_hash old_hash
    html=$(curl -fsS --max-time 15 "$TAX_WATCH_URL" 2>/dev/null) || {
        echo "[$(ts)] [INFO] 스크랩 실패(무시): $TAX_WATCH_URL"; return 0; }
    # "세법개정 / 개정세법" 포함 라인만 추려 해시
    new_hash=$(echo "$html" | grep -oE '세법개정|개정세법|세법 개정' | sort -u | md5sum | cut -d' ' -f1)
    old_hash=$(cat "$STATE_FILE" 2>/dev/null || echo "")
    if [[ -n "$new_hash" && "$new_hash" != "$old_hash" ]]; then
        echo "$new_hash" > "$STATE_FILE"
        [[ -n "$old_hash" ]] && echo "SCRAPE_CHANGED"
    fi
}

main() {
    load_env
    local month age scrape_signal msg=""
    month=$(date +%-m)
    age=$(verified_age_months)
    scrape_signal=$(scrape_check)

    # 1. 달력 윈도우 정기 알림
    case "$month" in
        8)  msg="📋 <b>세법개정안 발표 시즌(8월)</b>%0A기재부 세법개정안이 나오는 때입니다. 절세 전략에 영향 가능. 발표 확인 후 필요 시 <code>/hih-tax 세법 갱신</code>." ;;
        12) msg="📋 <b>세법 정기국회 통과 시즌(12월)</b>%0A개정세법 국회 통과·공포 시기. 익년 1/1 시행분 확인하세요." ;;
        1)  msg="🔔 <b>새해 세법 시행(1월)</b>%0A올해 시행 세법을 hih-tax에 반영할 때입니다. <code>/hih-tax 세법 갱신</code> 실행 → 변경분 검증·승인 후 tax-data.md 갱신." ;;
    esac

    # 2. 검증일 노후 경고 (정기 알림 없는 달에만 별도로)
    if [[ -z "$msg" && "$age" -ge "$STALE_MONTHS" ]]; then
        msg="⚠️ <b>hih-tax 세무 데이터 노후</b>%0Atax-data.md 마지막 검증 ${age}개월 전. <code>/hih-tax 세법 갱신</code>으로 핵심 수치 재확인 권장."
    fi

    # 3. 스크랩 변경 감지 (있으면 덧붙임)
    if [[ "$scrape_signal" == "SCRAPE_CHANGED" ]]; then
        msg="${msg}%0A%0A🆕 국세청 보도자료에서 세법개정 관련 신규 게시 감지. 내용 확인 필요."
    fi

    if [[ -n "$msg" ]]; then
        echo "[$(ts)] 알림 발송: month=$month age=${age}m scrape=$scrape_signal"
        send_telegram "$msg"
    else
        echo "[$(ts)] 이상 없음 (month=$month, verified ${age}m ago). 알림 생략."
    fi
}

main
