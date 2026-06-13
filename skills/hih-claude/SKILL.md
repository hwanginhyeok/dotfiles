---
name: hih-claude
description: |
  Invoke a fresh-context Claude (Opus 4.7) as an external reviewer to get an independent second opinion.
  Same 3-mode structure as /hih-glm (review/challenge/consult).
  Uses pane 3 of the target project's tmux session (auto-determined from the TARGET path or HIH_CLAUDE_SESSION).
  If pane 3 does not exist, it is auto-created + claude --model claude-opus-4-7 is auto-started.
  No headless invocation (risk of the main OAuth token falling back, see feedback_oauth_token_no_share).

  - review: diff/commit code review + GATE PASS/FAIL + synthesis recommendation
  - challenge: adversarial — attempt to break the code + synthesis recommendation
  - consult: free-form query (one-shot) + synthesis recommendation
  - no args: auto-detect diff, then select mode via AskUserQuestion (same as /hih-glm)

  Even if the main PM is Opus 4.7, a fresh-context Claude provides context isolation (compensating for the bias/omissions of a long-context PM).
  Can be auto-invoked in /hih-dev STEP 5 for the /review + /codex + /hih-glm + /hih-claude 4-way comparison.
  Use when: "claude review", "claude challenge", "claude consult", "두 번째 의견 Claude", "fresh Claude"
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# /hih-claude — Fresh Opus 4.7 Second Opinion (pane TUI method)

## Core Principle

The Claude in the main session accumulates long context, causing bias/omissions. A separate
fresh-context Claude instance is launched in pane 3 to look at the same code/diff with fresh eyes.

Headless invocation (`claude --bare -p`) risks leaking the Anthropic OAuth token into an external
context, so it is prohibited (memory `feedback_oauth_token_no_share.md`). **Only use a claude
instance that booted normally in a pane TUI.**

Therefore /hih-claude uses the **caller's tmux session pane 3 (claude --model claude-opus-4-7)**.
The caller delivers the prompt to pane 3 via paste-buffer → extracts the response via capture-pane → outputs verbatim.

---

## ★ 공통 TUI 세션 제어 패턴 (hih-claude = 정의원, hih-glm = 동일 패턴 사용)

> **아래 Step 0 ~ Step 2C 구조는 /hih-glm과 완전히 동일한 패턴이다.**
> 차이점만 별도 표기. hih-glm은 이 패턴을 참조하여 pane 번호·모델명·환경변수만 교체한다.

### 공통 구조 vs 스킬별 차이

| 항목 | hih-claude (본 파일) | hih-glm |
|---|---|---|
| 대상 pane | **3** | 2 |
| CLI 명령 | `claude --model claude-opus-4-7` | `claude-glm --model glm-5.1` |
| 사전 검증 | `which claude` | `$Z_AI_API_KEY` 존재 확인 |
| 세션 환경변수 | `HIH_CLAUDE_SESSION` | `HIH_GLM_SESSION` |
| 임시파일 접두어 | `hih_claude_` | `hih_glm_` |
| 버퍼명 | `hih_claude_buf` | `hih_glm_buf` |
| idle 마커 | `Cogitated for\|Brewed for\|...\|for agents` | 동일 |
| GATE 판정 로직 | 동일 (awk + grep) | 동일 |
| paste → poll → capture 플로우 | 동일 | 동일 |
| review/challenge/consult 프롬프트 | 영어 | 한국어 |
| 모델 정책 | Opus 4.7 단일 | GLM 5.1 단일 |
| 비용 | API flat rate (main과 동일) | $0 (Z.ai Pro 정액) |
| N-way 비교 시 포함 모델 | Claude /review, /codex, /hih-glm, /hih-claude | Claude /review, /codex, /hih-glm |

---

## Model Policy

| Situation | Model | Reason |
|---|---|---|
| **pane 3 default** | **Opus 4.7** | Same family as the main, but isolated via fresh context |
| review/challenge/consult | Opus 4.7 as-is | Single-model policy |
| User wants a lighter opinion | `/model claude-sonnet-4-6` manual toggle | Not forced |

trade-off: Opus 4.7 is slower to respond and costs more than Sonnet 4.6. Use only when the main is
already Opus and matching the opinion tier matters. For general reviews, prefer /hih-glm (Z.ai flat rate $0).

## Preconditions

1. The target tmux session exists (error if not).
2. The `claude` CLI is on PATH and OAuth-authenticated (Anthropic console).
3. **If pane 3 does not exist, it is auto-created + `claude --model claude-opus-4-7` auto-started.**

## Step 0: Environment + session/pane determination

```bash
which claude >/dev/null 2>&1 || { echo "❌ claude CLI 없음. https://claude.ai/code 설치"; exit 1; }

# Session resolution priority:
# 1. --session explicit argument
# 2. HIH_CLAUDE_SESSION environment variable
# 3. infer ~/project-name from the TARGET path
# 4. basename(pwd) fallback

TARGET_ARG="$1"
SESSION="${ARG_SESSION:-${HIH_CLAUDE_SESSION:-}}"

if [ -z "$SESSION" ]; then
  if [[ "$TARGET_ARG" =~ ^/home/[^/]+/([^/]+) ]]; then
    SESSION="${BASH_REMATCH[1]}"
  elif [ -f "$TARGET_ARG" ] && grep -qE "^diff --git" "$TARGET_ARG" 2>/dev/null; then
    PROJ=$(grep -oE '/home/[^/]+/([^/]+)/' "$TARGET_ARG" | head -1 | cut -d/ -f4)
    SESSION="${PROJ:-$(basename $(pwd))}"
  else
    SESSION=$(basename $(pwd))
  fi
fi

# The PM directory's session name is "PM"
[ "$SESSION" = "project-manager" ] && SESSION="PM"

echo "[hih-claude] Target session: $SESSION"

tmux has-session -t "$SESSION" 2>/dev/null || {
  echo "❌ tmux 세션 '$SESSION' 없음."
  echo "   Create command: tmux new -d -s $SESSION"
  exit 1
}

# If pane 3 does not exist, auto-create + start claude opus 4.7
PANE_COUNT=$(tmux list-panes -t "$SESSION" | wc -l)
if [ "$PANE_COUNT" -lt 3 ]; then
  echo "⚠️  $SESSION 세션에 pane 3 없음 → auto-create + start claude opus 4.7..."
  tmux split-window -t "${SESSION}" -h
  tmux send-keys -t "${SESSION}.3" "claude --model claude-opus-4-7" Enter
  echo "⏳ Waiting for claude to boot (20s)..."
  sleep 20
  echo "✅ pane 3 ready"
fi

# Verify pane 3 model
PANE3_INFO=$(tmux capture-pane -t "${SESSION}.3" -p | grep -oE 'Opus [0-9.]+|Sonnet [0-9.]+|Haiku [0-9.]+' | head -1)
echo "[hih-claude] session=$SESSION pane=3 model=$PANE3_INFO"

case "$PANE3_INFO" in
  *Opus*4.7*) echo "✅ Opus 4.7 — recommended state" ;;
  *Sonnet*|*Haiku*) echo "⚠️  $PANE3_INFO — Opus 4.7 recommended but proceeding" ;;
  *) echo "⚠️  Claude model detection failed — proceeding anyway" ;;
esac
```

## Step 0.5: Auto-detect diff + mode selection

```bash
_BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "master")
_DIFF_STAT=$(git diff origin/${_BASE} --stat 2>/dev/null | tail -1 || git diff ${_BASE} --stat 2>/dev/null | tail -1)
echo "BASE: $_BASE"
echo "DIFF: $_DIFF_STAT"
```

**No args + diff present** → AskUserQuestion:
```
What should Fresh Claude do with the current branch diff?
A) Code review (PASS/FAIL gate) — recommended
B) Challenge (adversarial, attempt to break the code)
C) Enter a direct question
```

**Args present** → parse and proceed immediately:
- `review <commit-or-diff-path> [focus]` → Step 2A
- `challenge <commit-or-file> [focus]` → Step 2B
- `consult <question...>` → Step 2C

## Step 1: Mode branching

Parse ARGUMENTS:
- `review <commit-or-diff-path> [focus]` → Step 2A
- `challenge <commit-or-file> [focus]` → Step 2B
- `consult <question...>` → Step 2C
- No args → handled by AskUserQuestion in Step 0.5

## Step 2A: review mode

### 2A-1: Extract diff

```bash
TARGET="$1"
TS=$(date +%s)
DIFF_FILE="/tmp/hih_claude_${TS}.diff"

if [[ "$TARGET" =~ ^[a-f0-9]{6,}$ ]] || [ "$TARGET" = "HEAD" ]; then
  git show "$TARGET" > "$DIFF_FILE"
elif [ -f "$TARGET" ]; then
  cat "$TARGET" > "$DIFF_FILE"
else
  echo "❌ '$TARGET'은 commit hash도 파일도 아님 (neither a commit hash nor a file)"; exit 1
fi
```

### 2A-2: Build review prompt + paste

```bash
PROMPT_FILE="/tmp/hih_claude_prompt_${TS}.txt"
cat > "$PROMPT_FILE" << EOF
[Important] Do NOT read files under ~/.claude/, ~/.agents/, .claude/skills/, agents/. Only look at the repository code.

[Reviewer mode] Critical review of the commit/diff. Do NOT edit directly. Review report in markdown only.

Materials:
- diff file: $DIFF_FILE (read it with the Read tool)
- target: $TARGET
- focus: $2 (if provided, prioritize that area)

Checklist (cover all):
1. Security: secret exposure, permissions, injection
2. Exception handling: error classification, state consistency on partial failure
3. Tests: missing cases, mock accuracy
4. Korean message consistency (if any)
5. Code style and duplication
6. Regression risk
7. Environment dependencies (WSL/headless/cron)

Do NOT throw false concerns. Only verifiable facts. If in doubt, explicitly mark "확인 필요" (needs verification).

Output:
## CRITICAL (blocks deployment)
## INFORMATIONAL (improvement recommendations)
## OK (well done parts)
## Overall assessment (1 line)

Start by reading $DIFF_FILE with Read first.
EOF

tmux load-buffer -b hih_claude_buf "$PROMPT_FILE"
tmux paste-buffer -t "${SESSION}.3" -b hih_claude_buf
sleep 0.5
tmux send-keys -t "${SESSION}.3" Enter
tmux delete-buffer -b hih_claude_buf
```

### 2A-3: idle polling + capture response

```bash
RESP_FILE="/tmp/hih_claude_response_${TS}.txt"
START=$(date +%s)
TIMEOUT=600

while true; do
  ELAPSED=$(($(date +%s) - START))
  [ $ELAPSED -gt $TIMEOUT ] && { echo "⚠️  10-minute timeout"; break; }

  TAIL=$(tmux capture-pane -t "${SESSION}.3" -p | tail -8)
  # Claude idle marker: the "for agents" label is visible and the ❯ prompt line is empty
  if echo "$TAIL" | grep -qE "Cogitated for|Brewed for|Worked for|Sautéed for|Cooked for|Baked for|for agents"; then
    if echo "$TAIL" | tail -3 | grep -qE "^❯ \s*$"; then
      sleep 2
      break
    fi
  fi
  sleep 5
done

tmux capture-pane -t "${SESSION}.3" -p -S -3000 > "$RESP_FILE"
```

### 2A-4: GATE determination

```bash
CRIT_BODY=$(awk '/^[#●] CRITICAL/,/^[#●] INFORMATIONAL/' "$RESP_FILE" | head -20)

if echo "$CRIT_BODY" | grep -qiE "없음|없다|0건|배포 차단.*없음|해당 없음"; then
  GATE="PASS"
else
  CRIT_COUNT=$(echo "$CRIT_BODY" | grep -cE "^[0-9]+\.|^- \[|^### |\*\*[A-Z]+-[0-9]")
  GATE="FAIL ($CRIT_COUNT)"
fi
```

### 2A-5: Output (verbatim) + synthesis recommendation

```
Claude Opus 4.7 SAYS (review):
═══════════════════════════════════════════════
<full response — do NOT truncate or summarize>
═══════════════════════════════════════════════
GATE: PASS|FAIL (N)
Target: <commit/file>  Session: <session>.3
Duration: Xs  Cost: API flat rate (same as main)
```

**synthesis recommendation (REQUIRED)** — after the verbatim output, always 1 line:
```
Recommendation: <action> because <concretely state the reason, naming the most actionable finding>
```

### 2A-6: cross-model comparison (optional)

If one or more of `/codex review`, `/hih-glm review`, `/review` has already run in this session, do an N-way comparison:

```
## N-WAY cross-model analysis
┌────────────────────────────────────────────────────────────┐
│ Model             │ GATE      │ Findings│ Unique findings     │
│ Claude /review    │ PASS/FAIL │ N       │ {main Claude unique}│
│ /codex            │ PASS/FAIL │ N       │ {Codex unique}      │
│ /hih-glm          │ PASS/FAIL │ N       │ {GLM unique}        │
│ /hih-claude (fresh) │ PASS/FAIL │ N     │ {fresh Opus unique} │
└────────────────────────────────────────────────────────────┘
All agree: {findings flagged by all N} ← top priority to fix
2 or more: {findings flagged by 2 or more}
Agreement rate: X%

Overall recommendation: <final action based on all model analyses>
```

## Step 2B: challenge mode

Same structure as 2A. Only the prompt is adversarial:

```
[Adversarial verification] Find scenarios where this code breaks in PROD.
- Edge cases (empty input, huge input, concurrency)
- Failure modes (network/permissions/disk/lock)
- Security (injection, privilege bypass, secrets, races)
- Regression
- Silent data corruption

No praise. Problems only. No false scenarios — only verifiable ones.

Output:
## Scenarios that break (with reproduction steps)
## Likelihood grade (높음/중간/낮음 = high/medium/low)
## Recommended fixes (1 line each)
```

GATE: 1+ "높음" (high) grade → FAIL, otherwise → PASS.

Output format:
```
Claude Opus 4.7 SAYS (challenge):
═══════════════════════════════════════════════
<full response>
═══════════════════════════════════════════════
GATE: PASS|FAIL
```

**synthesis recommendation (REQUIRED)**:
```
Recommendation: <action> because <name the most dangerous scenario by blast radius>
```

## Step 2C: consult mode

prompt = filesystem boundary + the user's question verbatim.

No session continuity (one-shot). For follow-ups, the user invokes again.

No GATE determination — output only, verbatim.

Output format:
```
Claude Opus 4.7 SAYS (consult):
═══════════════════════════════════════════════
<full response>
═══════════════════════════════════════════════
Cost: API flat rate
```

**synthesis recommendation (REQUIRED)**:
```
Recommendation: <action> because <name the most actionable fresh-Claude insight>
```

## Caller pane mapping — auto + override

```bash
# Priority: --session arg > $HIH_CLAUDE_SESSION > project-manager→PM conversion > basename(pwd)
SESSION="${ARG_SESSION:-${HIH_CLAUDE_SESSION:-$(basename $(pwd))}}"
[ "$SESSION" = "project-manager" ] && SESSION="PM"
```

## Error handling

| Case | Handling |
|---|---|
| claude CLI missing | "claude CLI 설치 필요 (claude CLI installation required)" |
| tmux session missing | Error + creation command guidance (no auto-creation) |
| pane 3 missing | **Auto-create** (`tmux split-window -h`) + auto-start `claude --model claude-opus-4-7` |
| pane 3 is a different model | Warn + proceed anyway (Opus 4.7 recommended message) |
| pane 3 is not Claude | Warn + proceed anyway |
| idle 10-min timeout | Force capture + "Claude 무응답 — pane 직접 확인 (Claude unresponsive — check the pane directly)" |
| empty response | "Claude 응답 비어있음 — pane 직접 확인 (Claude response empty — check the pane directly)" |
| pane 3 already occupied by another task | Warn + ask the user to explicitly specify an empty pane (`HIH_CLAUDE_SESSION` or `--session`) |

## Usage examples

```bash
# Review the latest commit (cwd is insung_blog)
/hih-claude review HEAD

# Specific commit + focus
/hih-claude review 91046ab 보안

# Adversarial verification
/hih-claude challenge scripts/token_guard.py 동시성

# Free-form query
/hih-claude consult "이 아키텍처 결정의 hidden cost는?"

# Specify session (e.g., call the PM session from hermes)
HIH_CLAUDE_SESSION=PM /hih-claude consult "..."
```

## Core principles

1. **Response is verbatim** — do NOT truncate or summarize.
2. **Main PM is the fact-check backstop** — if fresh Claude throws a false concern, grep/verify before reporting to the user.
3. **Opus 4.7 default** — single model, avoid confusion.
4. **One-shot** — no session continuity. Follow-ups are re-invoked (embedding the prior context in the prompt).
5. **No headless invocation** — risk of OAuth token external propagation. pane TUI only.
6. **Prefer /hih-glm** — general reviews are $0 on the Z.ai Pro flat rate. Use /hih-claude only when you need an opinion at the same tier as the main (e.g., critical decisions, tiebreaker when /hih-glm + /codex opinions conflict).

## Temp file cleanup

```bash
find /tmp -maxdepth 1 -name "hih_claude_*" -mtime +7 -delete 2>/dev/null
```

## Verification case (2026-05-21)

First test — measured in an isolated `consult`-mode session (`hih-test`):

- Session auto-creation + pane 3 split worked (`tmux split-window -h` x2)
- `claude --model claude-opus-4-7` boot took 25s ⏱️ (Claude Code v2.1.146 / "Opus 4.7 with xhigh effort" / Claude Max OAuth)
- prompt paste-buffer → Enter → idle polling: response completed in **~40s total**, idle marker "Churned for 8s" detected
- Response capture verbatim extraction succeeded (3-line answer, occupied up to ctx:94%)
- Confirmed isolation from the main PM (`PM:1.1`) context — no separate OAuth token leak (normal since it is a TUI boot)

Conclusion: works correctly with the same pattern as /hih-glm. A fresh Opus 4.7 opinion is possible without the headless-bypass risk.
The 25s boot overhead on first invocation must be accepted (subsequent invocations reuse the same pane).
