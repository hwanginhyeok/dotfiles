#!/bin/bash
# ╔══════════════════════════════════════════════╗
# ║  tmux 세션 백그라운드 생성 스크립트             ║
# ║  - pm / hi2 고정 세션 (Claude 자동 시작)        ║
# ║  - 워커 세션은 필요 시 수동 생성               ║
# ║  - attach 하지 않는다 (새 탭은 plain bash)       ║
# ║  - attach 할 땐 수동: tmux attach -t pm         ║
# ╚══════════════════════════════════════════════╝

# ── 고정 세션 (pm + hi2) ─────────────────────────
SESSIONS=(pm hi2)
PROJECT_DIRS=(
    "$HOME/projects/프로젝트관리자"
    "$HOME/projects/HIH_2"
)

for i in "${!SESSIONS[@]}"; do
    name="${SESSIONS[$i]}"
    dir="${PROJECT_DIRS[$i]}"
    if ! tmux has-session -t "$name" 2>/dev/null; then
        tmux new-session -d -s "$name" -c "$dir"
        tmux send-keys -t "$name" 'claude' Enter
    fi
done

# ── Hermes 게이트웨이 (Telegram 연결) ────────────
if ! tmux has-session -t hermes 2>/dev/null; then
    tmux new-session -d -s hermes -c "$HOME"
    tmux send-keys -t hermes 'hermes gateway run' Enter
fi
