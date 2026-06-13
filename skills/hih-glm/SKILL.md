---
name: hih-glm
description: |
  Call GLM (Z.ai Pro flat-rate) as an external reviewer to get an independent second opinion.
  Same 3-mode structure as /codex (review/challenge/consult).
  All 3 modes default to GLM 5.1 (accuracy first).
  Uses pane 2 of the target project's tmux session (auto-determined from the TARGET path or HIH_GLM_SESSION).
  If pane 2 doesn't exist, auto-create it + auto-start claude-glm 5.1.
  No headless calls (it falls back to the Anthropic console so the Z.ai Pro flat rate doesn't apply — a $0.40 loss case).

  - review: code review of diff/commit + GATE PASS/FAIL + synthesis recommendation
  - challenge: adversarial — attempt to break the code + synthesis recommendation
  - consult: free-form question (one-shot) + synthesis recommendation
  - no args: auto-detect diff, then pick the mode via AskUserQuestion (same as /codex)

  /hih-dual is separate (builder/reviewer cycle, 4.6 reviewer).
  In /hih-dev STEP 5, it is auto-invoked for the /review + /codex + /hih-glm 3-way comparison.
  Use when: "glm review", "glm challenge", "glm consult", "second opinion GLM"
allowed-tools:
  - Bash
  - Read
  - Write
---

# /hih-glm — GLM 5.1 second opinion (pane TUI method)

## Core principle

A GLM headless call (`claude --bare -p`) falls back to Anthropic console subscription auth,
so the Z.ai Pro flat rate doesn't apply (verified: routes to Haiku + a $0.40 loss case).
**Only a session launched in a pane TUI via the `claude-glm` alias gets the Z.ai flat rate.**

Therefore /hih-glm uses **pane 2 of the caller's tmux session (claude-glm 5.1 default)**.
The PM sends the prompt to pane 2 via paste-buffer → extracts the response via capture-pane → outputs it verbatim.

---

## ★ /hih-claude와의 관계 — 공통 TUI 세션 제어 패턴

> **본 스킬은 /hih-claude와 동일한 TUI 세션 제어 패턴을 사용한다.**
> 구조(Step 0 ~ Step 2C), paste → poll → capture 플로우, GATE 판정 로직, idle polling,
> error handling 테이블이 모두 동일하다.
> 아래에 공통 패턴에서 **이 스킬만의 차이점**만 별도 정의하고,
> 나머지는 /hih-claude의 해당 Step과 동일 구조를 따른다.

### 차이점 요약 (공통 패턴에서 교체되는 항목)

| 항목 | hih-glm (본 파일) | hih-claude 참조 |
|---|---|---|
| 대상 pane | **2** | 3 |
| CLI 명령 | `claude-glm --model glm-5.1` | `claude --model claude-opus-4-7` |
| 사전 검증 | `$Z_AI_API_KEY` 존재 확인 | `which claude` |
| 세션 환경변수 | `HIH_GLM_SESSION` | `HIH_CLAUDE_SESSION` |
| 임시파일 접두어 | `hih_glm_` | `hih_claude_` |
| 버퍼명 | `hih_glm_buf` | `hih_claude_buf` |
| 프롬프트 언어 | **한국어** | 영어 |
| 모델 정책 | GLM 5.1 단일 | Opus 4.7 단일 |
| 비용 | $0 (Z.ai Pro 정액) | API flat rate |
| N-way 비교 포함 모델 | Claude /review, /codex, /hih-glm | + /hih-claude |

---

## Model policy (org-wide rule)

| Situation | Model | Reason |
|---|---|---|
| **pane 2 normal default** | **GLM 5.1** | Accuracy first. Fewer false concerns (verified vs 4.6) |
| /hih-glm review/challenge/consult | 5.1 as-is | Already default, so no switch |
| /hih-dual reviewer cycle | Temporary switch to 4.6 | Fast cycle, with PM verification as backstop |
| User doing fast code work directly | User manually toggles `/model glm-4.6` | Not forced, user's judgment |

trade-off: 5.1 responds ~30% slower than 4.6 (measured 1m20s vs 2m30s). Flat rate, so no cost.
The value of accuracy outweighs the latency cost (saves time verifying false concerns).

## Prerequisites

1. The target tmux session exists (error if not).
2. The `Z_AI_API_KEY` environment variable is set.
3. **If pane 2 doesn't exist, auto-create it + auto-start `claude-glm --model glm-5.1`.**

## Step 0: environment + session/pane determination

> /hih-claude Step 0와 동일 구조. 차이점: 사전검증 → `$Z_AI_API_KEY`, pane → **2**, CLI → `claude-glm --model glm-5.1`, 환경변수 → `HIH_GLM_SESSION`

```bash
[ -n "$Z_AI_API_KEY" ] || { echo "❌ Z_AI_API_KEY 없음. ~/.bashrc에 Z_AI_API_KEY 설정"; exit 1; }

# 세션 결정 우선순위:
# 1. --session 명시 인자
# 2. HIH_GLM_SESSION 환경변수
# 3. TARGET 경로에서 ~/프로젝트명 추론 (예: /home/window11/insung_blog/... → insung_blog)
# 4. basename(pwd) fallback

TARGET_ARG="$1"
SESSION="${ARG_SESSION:-${HIH_GLM_SESSION:-}}"

if [ -z "$SESSION" ]; then
  # target이 절대 경로면 프로젝트 디렉토리 추론
  if [[ "$TARGET_ARG" =~ ^/home/[^/]+/([^/]+) ]]; then
    SESSION="${BASH_REMATCH[1]}"
  # diff 파일 내부에 프로젝트 경로 있으면 추론
  elif [ -f "$TARGET_ARG" ] && grep -qE "^diff --git" "$TARGET_ARG" 2>/dev/null; then
    PROJ=$(grep -oE '/home/[^/]+/([^/]+)/' "$TARGET_ARG" | head -1 | cut -d/ -f4)
    SESSION="${PROJ:-$(basename $(pwd))}"
  else
    SESSION=$(basename $(pwd))
  fi
fi

echo "[hih-glm] 대상 세션: $SESSION"

tmux has-session -t "$SESSION" 2>/dev/null || {
  echo "❌ tmux 세션 '$SESSION' 없음."
  echo "   생성 명령: tmux new -d -s $SESSION"
  exit 1
}

# pane 2 없으면 자동 생성 + claude-glm 시작
PANE_COUNT=$(tmux list-panes -t "$SESSION" | wc -l)
if [ "$PANE_COUNT" -lt 2 ]; then
  echo "⚠️  $SESSION 세션에 pane 2 없음 → 자동 생성 + claude-glm 5.1 시작..."
  tmux split-window -t "${SESSION}" -h
  tmux send-keys -t "${SESSION}.2" "claude-glm --model glm-5.1" Enter
  echo "⏳ claude-glm 부팅 대기 (20초)..."
  sleep 20
  echo "✅ pane 2 준비 완료"
fi

# pane 2 모델 검증
PANE2_INFO=$(tmux capture-pane -t "${SESSION}.2" -p | grep -oE 'glm-[0-9.]+|GLM-[0-9.]+' | head -1)
echo "[hih-glm] session=$SESSION pane=2 model=$PANE2_INFO"

case "$PANE2_INFO" in
  *5.1*) echo "✅ 5.1 default — 권장 상태" ;;
  *4.6*) echo "⚠️  4.6 — 5.1로 복귀 권장: /model glm-5.1" ;;
  *) echo "⚠️  GLM 모델 감지 실패 — 그래도 진행" ;;
esac
```

## Step 0.5: auto-detect diff + mode selection

> /hih-claude Step 0.5와 동일 구조. diff 감지 로직 완전 동일. AskUserQuestion 메시지만 한국어.

```bash
# base branch 감지
_BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "master")
_DIFF_STAT=$(git diff origin/${_BASE} --stat 2>/dev/null | tail -1 || git diff ${_BASE} --stat 2>/dev/null | tail -1)
echo "BASE: $_BASE"
echo "DIFF: $_DIFF_STAT"
```

**No args + diff present** → AskUserQuestion:
```
GLM이 현재 브랜치 diff에 대해 무엇을 할까?
A) 코드 리뷰 (PASS/FAIL 게이트) — recommended
B) 챌린지 (적대적, 코드 깨기 시도)
C) 직접 질문 입력
```

**Args present** → parse and proceed directly:
- `review <commit-or-diff-path> [focus]` → Step 2A
- `challenge <commit-or-file> [focus]` → Step 2B
- `consult <question...>` → Step 2C

## Step 1: mode branching

> /hih-claude Step 1과 동일.

## Step 2A: review mode

### 2A-1: extract diff

> /hih-claude 2A-1과 동일 구조. 임시파일 접두어만 `hih_glm_`.

```bash
TARGET="$1"  # commit hash, HEAD, 또는 파일 경로
TS=$(date +%s)
DIFF_FILE="/tmp/hih_glm_${TS}.diff"

if [[ "$TARGET" =~ ^[a-f0-9]{6,}$ ]] || [ "$TARGET" = "HEAD" ]; then
  git show "$TARGET" > "$DIFF_FILE"
elif [ -f "$TARGET" ]; then
  cat "$TARGET" > "$DIFF_FILE"
else
  echo "❌ '$TARGET'은 commit hash도 파일도 아님"; exit 1
fi
```

### 2A-2: build review prompt + paste

> /hih-claude 2A-2와 동일 구조. **프롬프트만 한국어.** 버퍼명 → `hih_glm_buf`, pane → `${SESSION}.2`.

(No model-switch step — pane 2 is already 5.1 default)

```bash
PROMPT_FILE="/tmp/hih_glm_prompt_${TS}.txt"
cat > "$PROMPT_FILE" << EOF
[중요] ~/.claude/, ~/.agents/, .claude/skills/, agents/ 파일은 읽지 마라. 저장소 코드만 본다.

[리뷰어 모드] commit/diff 비판적 리뷰. 직접 수정 X. 리뷰 보고서만 markdown.

자료:
- diff 파일: $DIFF_FILE (Read 도구로 읽어)
- 대상: $TARGET
- focus: $2 (있으면 그 영역 우선)

체크리스트 (모두 짚어):
1. 보안: 시크릿 노출, 권한, 인젝션
2. 예외처리: 에러 분류, 부분 실패 시 상태 일관성
3. 테스트: 누락 케이스, mock 정확성
4. 한국어 메시지 일관성 (있으면)
5. 코드 스타일·중복
6. 회귀 위험
7. 환경 의존성 (WSL/headless/cron)

거짓 우려 던지지 마라. 검증 가능한 사실만. 라이브러리 내부 계층(MRO 등) 의심되면 짚되,
"확인 필요"라고 명시 (PM이 직접 검증함).

출력:
## CRITICAL (배포 차단)
## INFORMATIONAL (개선 권고)
## OK (잘 된 부분)
## 종합 평가 (1줄)

먼저 $DIFF_FILE을 Read로 읽고 시작.
EOF

# paste-buffer로 prompt 전송
tmux load-buffer -b hih_glm_buf "$PROMPT_FILE"
tmux paste-buffer -t "${SESSION}.2" -b hih_glm_buf
sleep 0.5
tmux send-keys -t "${SESSION}.2" Enter
tmux delete-buffer -b hih_glm_buf
```

### 2A-3: idle polling + response capture

> /hih-claude 2A-3과 동일 구조. pane → `${SESSION}.2`, 임시파일 → `hih_glm_`.

```bash
RESP_FILE="/tmp/hih_glm_response_${TS}.txt"
START=$(date +%s)
TIMEOUT=600  # 10분

while true; do
  ELAPSED=$(($(date +%s) - START))
  [ $ELAPSED -gt $TIMEOUT ] && { echo "⚠️  10분 timeout"; break; }

  TAIL=$(tmux capture-pane -t "${SESSION}.2" -p | tail -8)
  # idle 마커: "Cogitated for|Brewed for|Worked for|Sautéed for|Cooked for|Baked for"
  if echo "$TAIL" | grep -qE "Cogitated for|Brewed for|Worked for|Sautéed for|Cooked for|Baked for"; then
    if echo "$TAIL" | tail -3 | grep -qE "^❯ \s*$"; then
      sleep 2  # 안정화
      break
    fi
  fi
  sleep 5
done

tmux capture-pane -t "${SESSION}.2" -p -S -3000 > "$RESP_FILE"
```

### 2A-4: GATE judgment

> /hih-claude 2A-4와 완전 동일 로직 (awk + grep 패턴).

```bash
# CRITICAL 섹션 본문 검사 (헤더 다음 라인부터)
CRIT_BODY=$(awk '/^[#●] CRITICAL/,/^[#●] INFORMATIONAL/' "$RESP_FILE" | head -20)

if echo "$CRIT_BODY" | grep -qiE "없음|없다|0건|배포 차단.*없음|해당 없음"; then
  GATE="PASS"
else
  CRIT_COUNT=$(echo "$CRIT_BODY" | grep -cE "^[0-9]+\.|^- \[|^### |\*\*[A-Z]+-[0-9]")
  GATE="FAIL ($CRIT_COUNT)"
fi
```

### 2A-5: output (verbatim) + synthesis recommendation

> /hih-claude 2A-5와 동일 구조. 출력 헤더만 "GLM 5.1 SAYS", 비용 → "$0 (Z.ai Pro 정액)".

```
GLM 5.1 SAYS (review):
═══════════════════════════════════════════════
<응답 풀버전 — 자르거나 요약 X>
═══════════════════════════════════════════════
GATE: PASS|FAIL (N)
대상: <commit/file>  세션: <session>.2
Duration: Xs  Cost: $0 (Z.ai Pro 정액)
```

**synthesis recommendation (REQUIRED)** — after the verbatim output, always add exactly 1 line:
```
Recommendation: <액션> because <가장 actionable한 발견을 구체적으로 명시한 이유>
```
- The reason must name the highest-impact item among CRITICAL/INFORMATIONAL
- Generic reasons like "because it's good" or "because it's safe" are prohibited — referencing the actual finding is required

### 2A-6: cross-model comparison (optional)

> /hih-claude 2A-6과 동일 구조. 3-way (hih-glm은 /hih-claude 미포함).

If `/codex review` or `/review` (Claude) was already run in this session, do a 3-way comparison:

```
## 3-WAY 크로스 모델 분석
┌─────────────────────────────────────────────────────┐
│ 모델          │ GATE   │ 발견 수 │ 고유 발견               │
│ Claude /review│ PASS/FAIL │ N건   │ {Claude만 찾은 것}      │
│ /codex        │ PASS/FAIL │ N건   │ {Codex만 찾은 것}       │
│ /hih-glm      │ PASS/FAIL │ N건   │ {GLM만 찾은 것}         │
└─────────────────────────────────────────────────────┘
모두 동의: {3개 모두 지적한 발견} ← 최우선 수정 대상
2개 동의: {2개 이상 지적한 발견}
합의율: X% (N/M 고유 발견 overlap)

종합 권고: <3개 모델 분석 기반 최종 액션>
```

## Step 2B: challenge mode

> /hih-claude 2B와 동일 구조. 프롬프트만 한국어. GATE 로직 동일.

Same structure as 2A. Only the prompt becomes adversarial:

```
[적대적 검증] 이 코드가 PROD에서 깨질 시나리오를 찾는다.
- 엣지 케이스 (빈 입력, 거대 입력, 동시성)
- 실패 모드 (네트워크/권한/디스크/lock)
- 보안 (인젝션, 권한 우회, 시크릿, 경합)
- 회귀
- silent 데이터 손상

칭찬 X. 문제만. 거짓 시나리오는 X — 검증 가능한 것만.

출력:
## 깨질 시나리오 (재현 단계 포함)
## 가능성 등급 (높음/중간/낮음)
## 권고 픽스 (1줄씩)
```

GATE: 1+ break scenario rated "높음" (high) → FAIL, otherwise → PASS.

Output format:
```
GLM 5.1 SAYS (challenge):
═══════════════════════════════════════════════
<응답 풀버전 — 자르거나 요약 X>
═══════════════════════════════════════════════
GATE: PASS|FAIL
```

**synthesis recommendation (REQUIRED)** — after the verbatim output, always exactly 1 line:
```
Recommendation: <액션> because <blast radius 기준 가장 위험한 시나리오 명시>
```

## Step 2C: consult mode

> /hih-claude 2C와 동일 구조. 프롬프트 언어만 한국어.

prompt = filesystem boundary + the user's question as-is.
Call the same way at 5.1 default. No model switch.

No session continuity (one-shot). For follow-ups the user calls again (baking the prior context into the prompt).

No GATE judgment — output only, verbatim.

Output format:
```
GLM 5.1 SAYS (consult):
═══════════════════════════════════════════════
<응답 풀버전 — 자르거나 요약 X>
═══════════════════════════════════════════════
Cost: $0 (Z.ai Pro 정액)
```

**synthesis recommendation (REQUIRED)** — after the verbatim output, always exactly 1 line:
```
Recommendation: <액션> because <가장 actionable한 GLM 인사이트 명시>
```

## Caller pane mapping — automatic + override

Default: cwd basename → tmux session. For exceptions, use an environment variable or argument:

```bash
# 우선순위: --session 인자 > $HIH_GLM_SESSION > basename(pwd)
SESSION="${ARG_SESSION:-${HIH_GLM_SESSION:-$(basename $(pwd))}}"
```

## Error handling

| Case | Handling |
|---|---|
| Z_AI_API_KEY missing | "Set Z_AI_API_KEY in ~/.bashrc" |
| tmux session missing | Error + guidance on the create command (no auto-create — the session is the user's responsibility) |
| pane 2 missing | **Auto-create** (`tmux split-window -h`) + auto-start `claude-glm --model glm-5.1` |
| pane 2 is 4.6 | Warn + proceed anyway (5.1-recommended message) |
| pane 2 not GLM | Warn + proceed anyway |
| idle 10-min timeout | Force capture + "GLM unresponsive — check the pane directly" |
| empty response | "GLM response is empty — check the pane directly" |

## Usage examples

```bash
# 최근 commit 리뷰 (cwd가 music-lab)
/hih-glm review HEAD

# 특정 commit + focus
/hih-glm review 91046ab 보안

# 적대적 검증
/hih-glm challenge scripts/token_guard.py 동시성

# 자유 질의
/hih-glm consult "Suno API polling이 v1+v2 페어 보증하나?"
```

## Core principles

1. **Responses are verbatim** — no truncation or summarizing.
2. **PM is the fact-check backstop** — if GLM throws a false concern, the PM corrects it with grep/python before reporting to the user. 5.1 has fewer false concerns but not zero (measured/verified).
3. **Keep 5.1 default** — review/challenge/consult all use 5.1. No model switch (causes confusion + adds latency cost).
4. **One-shot** — no session continuity. For follow-ups, call again.
5. **Headless calls prohibited** — risk of Anthropic console fallback. Use the pane TUI only.

## Temp file cleanup

```bash
find /tmp -maxdepth 1 -name "hih_glm_*" -mtime +7 -delete 2>/dev/null
```

## Verification case (2026-05-06)

PIPE-F10 v2 (commit 91046ab) GLM 5.1 review, measured:
- Duration: 2m30s, Cost: $0
- CRITICAL: 0 (5.1 directly verified and invalidated the MRO interception that 4.6 had thrown as a false concern)
- INFORMATIONAL: 7 (all LOW~P3 — delete BLOCK_HOURS / OSError scope / rate_limit matching empirical check / --check CLI break, etc.)
- Summary: "Deployable. Accurately resolves v1's core problem; only I-4 (rate_limit) is recommended for empirical confirmation."

→ Clear accuracy advantage over the 4.6 v1+v2 re-review (2 false concerns).
