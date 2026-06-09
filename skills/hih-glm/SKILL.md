---
name: hih-glm
description: |
  GLM (Z.ai Pro 정액)을 외부 리뷰어로 호출해 독립적 두 번째 의견을 받는다.
  /codex와 동일한 3-모드 구조 (review/challenge/consult).
  3 모드 모두 GLM 5.1 default (정확도 우선).
  대상 프로젝트 tmux 세션의 pane 2 사용 (TARGET 경로 또는 HIH_GLM_SESSION으로 자동 결정).
  pane 2 없으면 자동 생성 + claude-glm 5.1 자동 시작.
  headless 호출 X (Anthropic console로 fallback해서 Z.ai Pro 정액 안 적용됨, $0.40 손실 사례).

  - review: diff/commit 코드 리뷰 + GATE PASS/FAIL + synthesis recommendation
  - challenge: 적대적 — 코드를 깨려고 시도 + synthesis recommendation
  - consult: 자유 질의 (단발) + synthesis recommendation
  - 인자 없음: diff 자동 감지 후 AskUserQuestion으로 모드 선택 (/codex와 동일)

  /hih-dual은 별도 (builder/reviewer 사이클, 4.6 reviewer).
  /hih-dev STEP 5에서 /review + /codex + /hih-glm 3-way 비교로 자동 호출됨.
  Use when: "glm review", "glm challenge", "glm consult", "두 번째 의견 GLM"
allowed-tools:
  - Bash
  - Read
  - Write
---

# /hih-glm — GLM 5.1 두 번째 의견 (pane TUI 방식)

## 핵심 원리

GLM headless 호출(`claude --bare -p`)은 Anthropic console subscription auth로
fallback돼서 Z.ai Pro 정액이 안 적용된다 (Haiku로 라우팅 + $0.40 손해 사례 검증됨).
**pane TUI에서 `claude-glm` alias로 띄운 세션만 Z.ai 정액 적용**된다.

따라서 /hih-glm은 **호출자 tmux 세션의 pane 2 (claude-glm 5.1 default)** 를 사용한다.
PM이 pane 2에 prompt를 paste-buffer로 전달 → 응답을 capture-pane으로 추출 → verbatim 출력.

## 모델 정책 (전사 룰)

| 상황 | 모델 | 이유 |
|---|---|---|
| **pane 2 평상시 default** | **GLM 5.1** | 정확도 우선. 거짓 우려 적음 (4.6 대비 검증됨) |
| /hih-glm review/challenge/consult | 5.1 그대로 | 이미 default라 전환 X |
| /hih-dual reviewer 사이클 | 4.6 임시 전환 | 빠른 사이클, PM 검증 백스톱 있음 |
| 사용자가 직접 빠른 코드 작업 | 사용자가 `/model glm-4.6` 수동 토글 | 강제 X, 사용자 판단 |

trade-off: 5.1은 4.6 대비 응답 ~30% 느림 (실측 1m20s vs 2m30s). 정액이라 비용 X.
정확도 가치가 latency 비용보다 큼 (거짓 우려 검증 시간 절약).

## 전제 조건

1. 대상 tmux 세션이 존재 (없으면 에러).
2. `Z_AI_API_KEY` 환경변수 설정.
3. **pane 2 없으면 자동 생성 + `claude-glm --model glm-5.1` 자동 시작**.

## Step 0: 환경 + 세션/pane 결정

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

## Step 0.5: diff 자동 감지 + 모드 선택 (/codex와 동일 구조)

```bash
# base branch 감지
_BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "master")
_DIFF_STAT=$(git diff origin/${_BASE} --stat 2>/dev/null | tail -1 || git diff ${_BASE} --stat 2>/dev/null | tail -1)
echo "BASE: $_BASE"
echo "DIFF: $_DIFF_STAT"
```

**인자 없음 + diff 있음** → AskUserQuestion:
```
GLM이 현재 브랜치 diff에 대해 무엇을 할까?
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

### 2A-2: review prompt 구성 + paste

(모델 전환 단계 X — pane 2가 이미 5.1 default)

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

### 2A-3: idle 폴링 + 응답 capture

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

### 2A-4: GATE 판정

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

### 2A-5: 출력 (verbatim) + synthesis recommendation

```
GLM 5.1 SAYS (review):
═══════════════════════════════════════════════
<응답 풀버전 — 자르거나 요약 X>
═══════════════════════════════════════════════
GATE: PASS|FAIL (N)
대상: <commit/file>  세션: <session>.2
Duration: Xs  Cost: $0 (Z.ai Pro 정액)
```

**synthesis recommendation (REQUIRED)** — verbatim 출력 후 반드시 1줄 추가:
```
Recommendation: <액션> because <가장 actionable한 발견을 구체적으로 명시한 이유>
```
- 이유는 CRITICAL/INFORMATIONAL 중 가장 영향이 큰 항목을 명시해야 함
- "좋아서", "안전해서" 같은 일반적 이유 금지 — 실제 발견 언급 필수

### 2A-6: cross-model 비교 (선택적)

이번 세션에서 `/codex review` 또는 `/review`(Claude)가 이미 실행된 경우 3-way 비교:

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

## Step 2B: challenge 모드

2A와 동일 구조. prompt만 적대적으로:

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

GATE: 깨질 시나리오 "높음" 등급 1+건 → FAIL, 그 외 → PASS.

출력 형식:
```
GLM 5.1 SAYS (challenge):
═══════════════════════════════════════════════
<응답 풀버전 — 자르거나 요약 X>
═══════════════════════════════════════════════
GATE: PASS|FAIL
```

**synthesis recommendation (REQUIRED)** — verbatim 출력 후 반드시 1줄:
```
Recommendation: <액션> because <blast radius 기준 가장 위험한 시나리오 명시>
```

## Step 2C: consult 모드

prompt = filesystem boundary + 사용자 질문 그대로.
동일하게 5.1 default로 호출. 모델 전환 X.

세션 연속성 X (단발). 후속은 사용자가 다시 호출 (이전 컨텍스트 prompt에 박아서).

GATE 판정 X — 출력만 verbatim.

출력 형식:
```
GLM 5.1 SAYS (consult):
═══════════════════════════════════════════════
<응답 풀버전 — 자르거나 요약 X>
═══════════════════════════════════════════════
Cost: $0 (Z.ai Pro 정액)
```

**synthesis recommendation (REQUIRED)** — verbatim 출력 후 반드시 1줄:
```
Recommendation: <액션> because <가장 actionable한 GLM 인사이트 명시>
```

## 호출자 pane 매핑 — 자동 + 오버라이드

기본: cwd basename → tmux 세션. 예외 시 환경변수 또는 인자:

```bash
# 우선순위: --session 인자 > $HIH_GLM_SESSION > basename(pwd)
SESSION="${ARG_SESSION:-${HIH_GLM_SESSION:-$(basename $(pwd))}}"
```

## 에러 처리

| 케이스 | 처리 |
|---|---|
| Z_AI_API_KEY 없음 | "~/.bashrc에 Z_AI_API_KEY 설정" |
| tmux 세션 없음 | 에러 + 생성 명령 안내 (자동 생성 X — 세션은 사용자 몫) |
| pane 2 없음 | **자동 생성** (`tmux split-window -h`) + `claude-glm --model glm-5.1` 자동 시작 |
| pane 2가 4.6 | 경고 + 그래도 진행 (5.1 권장 메시지) |
| pane 2가 GLM 아님 | 경고 + 그래도 진행 |
| idle 10분 timeout | 강제 capture + "GLM 무응답 — pane 직접 확인" |
| 빈 응답 | "GLM 응답 비어있음 — pane 직접 확인" |

## 사용 예

```bash
# 최근 commit 리뷰 (cwd가 music-lab)
/hih-glm review HEAD

# 특정 commit + focus
/hih-glm review 91046ab 보안

# 적대적 검증
/hih-glm challenge scripts/token_guard.py 동시성

# 자유 질의
/hih-glm consult "Suno API polling이 v1+v2 페어 보장하나?"
```

## 핵심 원칙

1. **응답은 verbatim** — 자르거나 요약 X.
2. **PM이 사실 검증 백스톱** — GLM이 거짓 우려 던지면 PM이 grep/python으로 정정 후 사용자 보고. 5.1은 거짓 우려 적지만 0은 아님 (실측 검증).
3. **5.1 default 유지** — review/challenge/consult 모두 5.1. 모델 전환 X (헷갈림 + latency 추가 비용).
4. **단발** — 세션 연속 X. 후속은 다시 호출.
5. **headless 호출 금지** — Anthropic console fallback 위험. pane TUI만 사용.

## 임시 파일 청소

```bash
find /tmp -maxdepth 1 -name "hih_glm_*" -mtime +7 -delete 2>/dev/null
```

## 검증 사례 (2026-05-06)

PIPE-F10 v2 (commit 91046ab) GLM 5.1 리뷰 실측:
- Duration: 2m30s, Cost: $0
- CRITICAL: 0건 (4.6이 거짓 우려 던졌던 MRO 가로채기를 5.1이 직접 검증해서 무효화)
- INFORMATIONAL: 7건 (모두 LOW~P3, BLOCK_HOURS 삭제 / OSError 범위 / rate_limit 매칭 실증 / --check CLI break 등)
- 종합: "배포 가능. v1 핵심 문제 정확 해결, I-4(rate_limit)만 실증 확인 권고"

→ 4.6 v1+v2 재리뷰 (거짓 우려 2건) 대비 정확도 명확 우위.
