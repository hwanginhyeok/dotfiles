#!/bin/bash
# ╔══════════════════════════════════════════════╗
# ║  dotfiles install.sh                         ║
# ║  기존 파일 → .bak 백업 후 심링크 생성          ║
# ╚══════════════════════════════════════════════╝

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}✅ $1${RESET}"; }
warn() { echo -e "${YELLOW}⚠️  $1${RESET}"; }
info() { echo -e "   $1"; }

# 심링크 생성 함수 (기존 파일은 .bak으로 백업)
link() {
    local src="$DOTFILES_DIR/$1"
    local dst="$2"

    mkdir -p "$(dirname "$dst")"

    # 이미 같은 심링크면 스킵
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        ok "$1 → $dst (이미 연결됨)"
        return
    fi

    # 기존 파일/심링크 백업
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mv "$dst" "${dst}.bak"
        warn "기존 파일 백업: ${dst}.bak"
    fi

    ln -s "$src" "$dst"
    ok "$1 → $dst"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  dotfiles 설치 (from: $DOTFILES_DIR)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── tmux 설정 ──────────────────────────────────
link "tmux.conf"        "$HOME/.tmux.conf"
link "tmux-startup.sh"  "$HOME/.tmux-startup.sh"
chmod +x "$DOTFILES_DIR/tmux-startup.sh"

# ── Claude Code 상태바 ──────────────────────────
link "statusline.sh"    "$HOME/.claude/statusline-command.sh"
chmod +x "$DOTFILES_DIR/statusline.sh"

# ── tmux 설정 리로드 ───────────────────────────
echo ""
if tmux info &>/dev/null 2>&1; then
    tmux source-file ~/.tmux.conf 2>/dev/null && ok "tmux.conf 리로드 완료" || warn "tmux.conf 리로드 실패 (수동으로: tmux source ~/.tmux.conf)"
else
    info "tmux 미실행 — 다음 세션부터 설정 자동 적용"
fi

# ── 완료 안내 ──────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  설치 완료"
echo ""
info "tmux 세션 시작:  ~/.tmux-startup.sh"
info "새 환경 세팅:    git clone https://github.com/hwanginhyeok/dotfiles.git ~/dotfiles && ~/dotfiles/install.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
