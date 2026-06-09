---
name: hih-claude
description: |
  Fresh-context Claude (Opus 4.7)를 외부 리뷰어로 호출해 독립적 두 번째 의견을 받는다.
  /hih-glm과 동일한 3-모드 구조 (review/challenge/consult).
  대상 프로젝트 tmux 세션의 pane 3 사용 (TARGET 경로 또는 HIH_CLAUDE_SESSION으로 자동 결정).
  pane 3 없으면 자동 생성 + claude --model claude-opus-4-7 자동 시작.
  headless 호출 X (메인 OAuth 토큰 fallback 위험, feedback_oauth_token_no_share 참조).

  - review: diff/commit 코드 리뷰 + GATE PASS/FAIL + synthesis recommendation
  - challenge: 적대적 — 코드를 깨려고 시도 + synthesis recommendation
  - consult: 자유 질의 (단발) + synthesis recommendation
  - 인자 없음: diff 자동 감지 후 AskUserQuestion으로 모드 선택 (/hih-glm과 동일)

  메인 PM이 Opus 4.7이라도 fresh-context의 Claude는 컨텍스트 격리 효과 (롱컨 PM의 편향/누락 보완).
  /hih-dev STEP 5에서 /review + /codex + /hih-glm + /hih-claude 4-way 비교에 자동 호출 가능.
  Use when: "claude review", "claude challenge", "claude consult", "두 번째 의견 Claude", "fresh Claude"
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# /hih-claude — Fresh Opus 4.7 두 번째 의견 (pane TUI 방식)

## 핵심 원리

메인 세션의 Claude는 long context 누적으로 편향/누락이 생긴다. fresh-context의
별도 Claude 인스턴스를 pane 3에 띄워 동일 코드/diff를 새 눈으로 보게 한다.

headless 호출(`claude --bare -p`)은 Anthropic OAuth 토큰을 외부 컨텍스트로 빠뜨릴
위험이 있어 금지 (메모리 `feedback_oauth_token_no_share.md`). **pane TUI에서
정상 부팅된 claude 인스턴스만 사용**한다.

따라서 /hih-claude는 **호출자 tmux 세션의 pane 3 (claude --model claude-opus-4-7)** 를 사용한다.
호출자가 pane 3에 prompt를 paste-buffer로 전달 → 응답을 capture-pane으로 추출 → verbatim 출력.

## 모델 정책

| 상황 | 모델 | 이유 |
|---|---|---|
| **pane 3 default** | **Opus 4.7** | 메인과 동일 family지만 fresh context로 격리 |
| review/challenge/consult | Opus 4.7 그대로 | 단일 모델 정책 |
| 사용자가 더 가벼운 의견 원함 | `/model claude-sonnet-4-6` 수동 토글 | 강제 X |

trade-off: Opus 4.7은 Sonnet 4.6 대비 응답 느리고 비용 ↑. 단, 메인이 이미 Opus라
의견 등급 일치가 중요할 때만 사용. 일반 리뷰는 /hih-glm (Z.ai 정액 $0) 우선.

## 전제 조건

1. 대상 tmux 세션이 존재 (없으면 에러).
2. `claude` CLI가 PATH에 있고 OAuth 인증 상태 (Anthropic console).
3. **pane 3 없으면 자동 생성 + `claude --model claude-opus-4-7` 자동 시작**.

## Step 0: 환경 + 세션/pane 결정

```bash
which claude >/dev/null 2>&1 || { echo "❌ claude CLI 없음. https://claude.ai/code 설치"; exit 1; }

# 세션 결정 우선순위:
# 1. --session 명시 인자
# 2. HIH_CLAUDE_SESSION 환경변수
# 3. TARGET 경로에서 ~/프로젝트명 추론
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

# PM 디렉토리는 세션명이 "PM"
[ "$SESSION" = "project-manager" ] && SESSION="PM"

echo "[hih-claude] 대상 세션: $SESSION"

tmux has-session -t "$SESSION" 2>/dev/null || {
  echo "❌ tmux 세션 '$SESSION' 없음."
  echo "   생성 명령: tmux new -d -s $SESSION"
  exit 1
}

# pane 3 없으면 자동 생성 + claude opus 4.7 시작
PANE_COUNT=$(tmux list-panes -t "$SESSION" | wc -l)
if [ "$PANE_COUNT" -lt 3 ]; then
  echo "⚠️  $SESSION 세션에 pane 3 없음 → 자동 생성 + claude opus 4.7 시작..."
  tmux split-window -t "${SESSION}" -h
  tmux send-keys -t "${SESSION}.3" "claude --model claude-opus-4-7" Enter
  echo "⏳ claude 부팅 대기 (20초)..."
  sleep 20
  echo "✅ pane 3 준비 완료"
fi

# pane 3 모델 검증
PANE3_INFO=$(tmux capture-pane -t "${SESSION}.3" -p | grep -oE 'Opus [0-9.]+|Sonnet [0-9.]+|Haiku [0-9.]+' | head -1)
echo "[hih-claude] session=$SESSION pane=3 model=$PANE3_INFO"

case "$PANE3_INFO" in
  *Opus*4.7*) echo "✅ Opus 4.7 — 권장 상태" ;;
  *Sonnet*|*Haiku*) echo "⚠️  $PANE3_INFO — Opus 4.7 권장이지만 진행" ;;
  *) echo "⚠️  Claude 모델 감지 실패 — 그래도 진행" ;;
esac
```

## Step 0.5: diff 자동 감지 + 모드 선택

```bash
_BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "master")
_DIFF_STAT=$(git diff origin/${_BASE} --stat 2>/dev/null | tail -1 || git diff ${_BASE} --stat 2>/dev/null | tail -1)
echo "BASE: $_BASE"
echo "DIFF: $_DIFF_STAT"
```

**인자 없음 + diff 있음** → AskUserQuestion:
```
Fresh Claude가 현재 브랜치 diff에 대해 무엇을 할까?
A) 코드 리뷰 (PASS/FAIL 게이트) — recommended
B) 챌린지 (적대적, 코드 깨기 시도)
C) 직접 질문 입력
```

**인자 있음** → 파싱해서 바로 진행:
- `review <commit-or-diff-path> [focus]` → Step 2A
- `challenge <commit-or-file> [focus]` → Step 2B
- `consult <question...>` → Step 2C

## Step 1: 모드 분기

ARGUMENTS 파싱:
- `review <commit-or-diff-path> [focus]` → Step 2A
- `challenge <commit-or-file> [focus]` → Step 2B
- `consult <question...>` → Step 2C
- 인자 없음 → Step 0.5에서 AskUserQuestion 처리

## Step 2A: review 모드

### 2A-1: diff 추출

```bash
TARGET="$1"
TS=$(date +%s)
DIFF_FILE="/tmp/hih_claude_${TS}.diff"

if [[ "$TARGET" =~ ^[a-f0-9]{6,}$ ]] || [ "$TARGET" = "HEAD" ]; then
  git show "$TARGET" > "$DIFF_FILE"
elif [ -f "$TARGET" ]; then
  cat "$TARGET" > "$DIFF_FILE"
else
  echo "❌ '$TARGET'은 commit hash도 파일도 아님"; exit 1
fi
```

### 2A-2: review prompt 구성 + paste

```bash
PROMPT_FILE="/tmp/hih_claude_prompt_${TS}.txt"
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

거짓 우려 던지지 마라. 검증 가능한 사실만. 의심되면 "확인 필요" 명시.

출력:
## CRITICAL (배포 차단)
## INFORMATIONAL (개선 권고)
## OK (잘 된 부분)
## 종합 평가 (1줄)

먼저 $DIFF_FILE을 Read로 읽고 시작.
EOF

tmux load-buffer -b hih_claude_buf "$PROMPT_FILE"
tmux paste-buffer -t "${SESSION}.3" -b hih_claude_buf
sleep 0.5
tmux send-keys -t "${SESSION}.3" Enter
tmux delete-buffer -b hih_claude_buf
```

### 2A-3: idle 폴링 + 응답 capture

```bash
RESP_FILE="/tmp/hih_claude_response_${TS}.txt"
START=$(date +%s)
TIMEOUT=600

while true; do
  ELAPSED=$(($(date +%s) - START))
  [ $ELAPSED -gt $TIMEOUT ] && { echo "⚠️  10분 timeout"; break; }

  TAIL=$(tmux capture-pane -t "${SESSION}.3" -p | tail -8)
  # Claude idle 마커: "for agents" 라벨이 보이고 ❯ prompt 라인이 비어있음
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

### 2A-4: GATE 판정

```bash
CRIT_BODY=$(awk '/^[#●] CRITICAL/,/^[#●] INFORMATIONAL/' "$RESP_FILE" | head -20)

if echo "$CRIT_BODY" | grep -qiE "없음|없다|0건|배포 차단.*없음|해당 없음"; then
  GATE="PASS"
else
  CRIT_COUNT=$(echo "$CRIT_BODY" | grep -cE "^[0-9]+\.|^- \[|^### |\*\*[A-Z]+-[0-9]")
  GATE="FAIL ($CRIT_COUNT)"
fi
```

### 2A-5: 출력 (verbatim) + synthesis recommendation

```
Claude Opus 4.7 SAYS (review):
═══════════════════════════════════════════════
<응답 풀버전 — 자르거나 요약 X>
═══════════════════════════════════════════════
GATE: PASS|FAIL (N)
대상: <commit/file>  세션: <session>.3
Duration: Xs  Cost: API 정액 (메인 동일)
```

**synthesis recommendation (REQUIRED)** — verbatim 출력 후 반드시 1줄:
```
Recommendation: <액션> because <가장 actionable한 발견을 구체적으로 명시한 이유>
```

### 2A-6: cross-model 비교 (선택적)

이번 세션에서 `/codex review`, `/hih-glm review`, `/review` 중 하나 이상이 이미 실행된 경우 N-way 비교:

```
## N-WAY 크로스 모델 분석
┌────────────────────────────────────────────────────────────┐
│ 모델              │ GATE      │ 발견 수 │ 고유 발견           │
│ Claude /review    │ PASS/FAIL │ N건     │ {메인 Claude 고유}  │
│ /codex            │ PASS/FAIL │ N건     │ {Codex 고유}        │
│ /hih-glm          │ PASS/FAIL │ N건     │ {GLM 고유}          │
│ /hih-claude (fresh) │ PASS/FAIL │ N건   │ {fresh Opus 고유}   │
└────────────────────────────────────────────────────────────┘
모두 동의: {N개 모두 지적한 발견} ← 최우선 수정
2개 이상: {2개 이상 지적한 발견}
합의율: X%

종합 권고: <모든 모델 분석 기반 최종 액션>
```

## Step 2B: challenge 모드

2A와 동일 구조. prompt만 적대적:

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

GATE: "높음" 등급 1+건 → FAIL, 그 외 → PASS.

출력 형식:
```
Claude Opus 4.7 SAYS (challenge):
═══════════════════════════════════════════════
<응답 풀버전>
═══════════════════════════════════════════════
GATE: PASS|FAIL
```

**synthesis recommendation (REQUIRED)**:
```
Recommendation: <액션> because <blast radius 기준 가장 위험한 시나리오 명시>
```

## Step 2C: consult 모드

prompt = filesystem boundary + 사용자 질문 그대로.

세션 연속성 X (단발). 후속은 사용자가 다시 호출.

GATE 판정 X — 출력만 verbatim.

출력 형식:
```
Claude Opus 4.7 SAYS (consult):
═══════════════════════════════════════════════
<응답 풀버전>
═══════════════════════════════════════════════
Cost: API 정액
```

**synthesis recommendation (REQUIRED)**:
```
Recommendation: <액션> because <가장 actionable한 fresh-Claude 인사이트 명시>
```

## 호출자 pane 매핑 — 자동 + 오버라이드

```bash
# 우선순위: --session 인자 > $HIH_CLAUDE_SESSION > project-manager→PM 변환 > basename(pwd)
SESSION="${ARG_SESSION:-${HIH_CLAUDE_SESSION:-$(basename $(pwd))}}"
[ "$SESSION" = "project-manager" ] && SESSION="PM"
```

## 에러 처리

| 케이스 | 처리 |
|---|---|
| claude CLI 없음 | "claude CLI 설치 필요" |
| tmux 세션 없음 | 에러 + 생성 명령 안내 (자동 생성 X) |
| pane 3 없음 | **자동 생성** (`tmux split-window -h`) + `claude --model claude-opus-4-7` 자동 시작 |
| pane 3가 다른 모델 | 경고 + 그래도 진행 (Opus 4.7 권장 메시지) |
| pane 3가 Claude 아님 | 경고 + 그래도 진행 |
| idle 10분 timeout | 강제 capture + "Claude 무응답 — pane 직접 확인" |
| 빈 응답 | "Claude 응답 비어있음 — pane 직접 확인" |
| pane 3 이미 다른 작업 점유 | 경고 + 사용자에게 빈 pane 직접 명시 요청 (`HIH_CLAUDE_SESSION` 또는 `--session`) |

## 사용 예

```bash
# 최근 commit 리뷰 (cwd가 insung_blog)
/hih-claude review HEAD

# 특정 commit + focus
/hih-claude review 91046ab 보안

# 적대적 검증
/hih-claude challenge scripts/token_guard.py 동시성

# 자유 질의
/hih-claude consult "이 아키텍처 결정의 hidden cost는?"

# 세션 명시 (예: hermes에서 PM 세션 호출)
HIH_CLAUDE_SESSION=PM /hih-claude consult "..."
```

## 핵심 원칙

1. **응답은 verbatim** — 자르거나 요약 X.
2. **메인 PM이 사실 검증 백스톱** — fresh Claude가 거짓 우려 던지면 grep/검증 후 사용자 보고.
3. **Opus 4.7 default** — 단일 모델, 헷갈림 회피.
4. **단발** — 세션 연속 X. 후속은 다시 호출 (이전 컨텍스트 prompt에 박아서).
5. **headless 호출 금지** — OAuth 토큰 외부 전파 위험. pane TUI만.
6. **/hih-glm 우선** — 일반 리뷰는 Z.ai Pro 정액으로 $0. /hih-claude는 메인 동일 등급 의견이 필요할 때만 (예: critical 결정, /hih-glm + /codex 의견 충돌 시 tiebreaker).

## 임시 파일 청소

```bash
find /tmp -maxdepth 1 -name "hih_claude_*" -mtime +7 -delete 2>/dev/null
```

## 검증 사례 (2026-05-21)

첫 테스트 — `consult` 모드 격리 세션(`hih-test`) 실측:

- 세션 자동 생성 + pane 3 split 정상 (`tmux split-window -h` 2회)
- `claude --model claude-opus-4-7` 부팅 25초 ⏱️ (Claude Code v2.1.146 / "Opus 4.7 with xhigh effort" / Claude Max OAuth)
- prompt paste-buffer → Enter → idle 폴링: **총 ~40초**에 응답 완료, idle 마커 "Churned for 8s" 감지
- 응답 capture verbatim 추출 성공 (3줄 답변, ctx:94%까지 점유)
- 메인 PM(`PM:1.1`) 컨텍스트와 격리 확인 — 별도 OAuth 토큰 누출 없음 (TUI 부팅이라 정상)

결론: /hih-glm과 동일 패턴으로 정상 동작. headless 우회 위험 없이 fresh Opus 4.7 의견 가능.
첫 호출 시 부팅 25초 오버헤드는 감수해야 함 (이후 호출은 같은 pane 재사용).
