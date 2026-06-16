---
name: hih-dual
description: |
  Automates the builder(Sonnet 4.6 1M) + reviewer(GLM 4.6) + PM verification cycle. Dispatch a task
  to the builder → commit the result → have the reviewer review the diff → PM verifies false concerns →
  report the comparison to the user → improvement round or adoption. Up to 3 rounds.

  /hih-glm is a one-shot external opinion (5.1). /hih-dual is a cycle (fast iteration with the 4.6 reviewer).
  Use when: "듀얼 작업", "builder reviewer 사이클", "Sonnet + GLM 협업"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
---

# /hih-dual — Builder/Reviewer Cycle

## Core Principle

Using 2 panes of the same tmux session:
- **pane 1 (Sonnet 4.6 1M)** — builder. Writes/modifies code and commits.
- **pane 2 (GLM 4.6)** — reviewer. Critiques the diff with fast responses.
- **PM (this session)** — orchestrator. Dispatches both sides, polls for idle, compares results, verifies false concerns, requests a decision from the user.

Because PM verification is the backstop, even false concerns from reviewer 4.6 are caught (PM verifies facts with grep/python).

Advantage over a one-shot /hih-glm call: automatic builder-reviewer ping-pong + commit preservation + round management.
Disadvantage: 30~60 minutes per round. Suited for heavy tasks.

## Model Policy

| pane | Normal | During /hih-dual cycle |
|---|---|---|
| pane 1 | Sonnet 4.6 1M | unchanged (builder) |
| pane 2 | **GLM 5.1** (default) | **temporarily switched to 4.6** (fast reviewer responses). Reverts to 5.1 when the cycle ends |

## Preconditions

1. cwd basename = tmux session name (e.g. `~/music-lab` → `music-lab`)
2. 2 panes. pane 1 = `claude`(Sonnet), pane 2 = `claude-glm`(GLM)
3. `Z_AI_API_KEY` set

## Step 0: Environment Verification

```bash
[ -n "$Z_AI_API_KEY" ] || { echo "❌ Z_AI_API_KEY 없음"; exit 1; }
SESSION="${HIH_DUAL_SESSION:-$(basename $(pwd))}"
tmux has-session -t "$SESSION" 2>/dev/null || { echo "❌ 세션 '$SESSION' 없음"; exit 1; }
PANES=$(tmux list-panes -t "$SESSION" | wc -l)
[ "$PANES" -lt 2 ] && { echo "❌ pane 2개 필요"; exit 1; }
```

## Step 1: Temporarily Switch pane 2 to 4.6

```bash
# pane 2 현재 모델 검증
P2_MODEL=$(tmux capture-pane -t "${SESSION}.2" -p | grep -oE 'glm-[0-9.]+|GLM-[0-9.]+' | head -1)
echo "pane 2 현재 모델: $P2_MODEL"

# 5.1이면 4.6으로 전환 (default 5.1 가정)
if echo "$P2_MODEL" | grep -q "5.1"; then
  tmux send-keys -t "${SESSION}.2" "/model glm-4.6" Enter
  sleep 4
  echo "✅ pane 2 → GLM 4.6 (사이클 모드)"
fi
```

## Step 2: Dispatch the Task to builder(pane 1)

ARGUMENTS = the task the builder will perform. PM composes the prompt:

```bash
TS=$(date +%s)
TASK_FILE="/tmp/hih_dual_task_${TS}.txt"
cat > "$TASK_FILE" << EOF
[세션 룰: 듀얼 builder. 자율 분석 + 자율 구현 + 자율 테스트 + commit. 글로벌 LLM 라우팅 룰 적용 X.]

$@

완료 후 보고:
- git log -1 (새 commit hash)
- 테스트 통과 결과 (있으면)
- 적용 안 한 항목 + 사유
EOF

tmux load-buffer -b hih_dual_buf "$TASK_FILE"
tmux paste-buffer -t "${SESSION}.1" -b hih_dual_buf
sleep 0.5
tmux send-keys -t "${SESSION}.1" Enter
tmux delete-buffer -b hih_dual_buf
```

## Step 3: Poll for builder Idle

```bash
# Sonnet idle 마커: "Worked for|Cooked for|Sautéed for|Beaming|Cogitated for"
START=$(date +%s)
TIMEOUT=900  # 15분 (큰 작업 대비)

while true; do
  ELAPSED=$(($(date +%s) - START))
  [ $ELAPSED -gt $TIMEOUT ] && { echo "⚠️  builder 15분 timeout"; break; }
  TAIL=$(tmux capture-pane -t "${SESSION}.1" -p | tail -8)
  if echo "$TAIL" | grep -qE "Worked for|Cooked for|Sautéed for|Cogitated for|Baked for"; then
    if echo "$TAIL" | tail -3 | grep -qE "^❯ \s*$"; then
      sleep 3
      break
    fi
  fi
  sleep 8
done

tmux capture-pane -t "${SESSION}.1" -p -S -3000 > "/tmp/hih_dual_builder_${TS}.txt"
```

## Step 4: Analyze builder Result + Extract diff

```bash
# 새 commit 확인
NEW_COMMIT=$(cd "$(pwd)" && git log --oneline -1 | awk '{print $1}')
NEW_COMMIT_PREV=$(cd "$(pwd)" && git log --oneline -2 | tail -1 | awk '{print $1}')

# diff 추출
DIFF_FILE="/tmp/hih_dual_diff_${TS}.txt"
git show "$NEW_COMMIT" > "$DIFF_FILE"
DIFF_LINES=$(wc -l < "$DIFF_FILE")

# 사용자에게 1차 보고
echo "======================="
echo "BUILDER (Sonnet 4.6 1M) 완료"
echo "  새 commit: $NEW_COMMIT (이전: $NEW_COMMIT_PREV)"
echo "  diff 라인: $DIFF_LINES"
echo "======================="
```

## Step 5: Dispatch the Review to reviewer(pane 2 GLM 4.6)

```bash
REVIEW_FILE="/tmp/hih_dual_review_prompt_${TS}.txt"
cat > "$REVIEW_FILE" << EOF
[중요] ~/.claude/, .claude/skills/, .agents/, agents/ 파일 읽지 마라. 저장소 코드만.

[리뷰어 모드] Sonnet 4.6이 task를 commit ${NEW_COMMIT}로 처리. 비판적 리뷰.
직접 수정 X. 리뷰 보고서만 markdown.

자료:
- diff 파일: ${DIFF_FILE} (Read 도구로 읽어)
- commit hash: ${NEW_COMMIT}
- task 컨텍스트: $@

체크리스트:
1. 보안 / 예외처리 / 테스트 누락
2. 회귀 위험 (기존 동작 깰 가능성)
3. 한국어 메시지 일관성
4. 코드 스타일·중복
5. 환경 의존성 (WSL/headless/cron)

거짓 우려 던지지 마라. 검증 가능한 사실만. 의심되는 내부 라이브러리 계층은
"확인 필요"로 명시 (PM이 직접 검증함).

출력:
## CRITICAL (배포 차단)
## INFORMATIONAL (개선 권고)
## OK (잘 된 부분)
## 종합 평가 (1줄)

먼저 ${DIFF_FILE}을 Read로 읽고 시작.
EOF

tmux load-buffer -b hih_dual_rev_buf "$REVIEW_FILE"
tmux paste-buffer -t "${SESSION}.2" -b hih_dual_rev_buf
sleep 0.5
tmux send-keys -t "${SESSION}.2" Enter
tmux delete-buffer -b hih_dual_rev_buf
```

## Step 6: Poll for reviewer Idle

Same structure as Step 3. GLM 4.6 idle markers: "Cogitated for|Brewed for|Pondered for|Cooked for|Baked for".

```bash
# 동일 패턴, timeout 600초 (10분 — 4.6은 빠름)
```

## Step 7: PM Verification (Backstop)

```bash
RESP_FILE="/tmp/hih_dual_review_response_${TS}.txt"
tmux capture-pane -t "${SESSION}.2" -p -S -3000 > "$RESP_FILE"

# 4섹션 추출
awk '/^[#●] CRITICAL/,/^[#●] INFORMATIONAL/' "$RESP_FILE" > "/tmp/hih_dual_critical_${TS}.txt"
awk '/^[#●] INFORMATIONAL/,/^[#●] OK/' "$RESP_FILE" > "/tmp/hih_dual_info_${TS}.txt"

# 거짓 우려 검증 — PM이 의심되는 항목 직접 확인
# 예: MRO 의심 → python -c "from x import Y; print(Y.__mro__)"
# 예: 파일 부재 의심 → ls 또는 git ls-files
# (이건 케이스별로 PM이 판단)
```

PM verifies suspicious CRITICAL/INFO items with grep/python/ls → marks false concerns separately.

## Step 8: Comparison Report + Decision to the User

```
## /hih-dual round N 보고

### Builder (Sonnet 4.6 1M)
- commit: <hash>
- 변경: <stat>
- 핵심: <요약 1줄>

### Reviewer (GLM 4.6) verbatim
═══════════════════════
<응답 풀버전>
═══════════════════════

### PM 검증
| 항목 | reviewer 분류 | PM 판정 |
| ... | CRITICAL | ✅ valid 또는 ❌ 거짓 우려 (근거: ...) |

### 결정 (사용자)
(A) 개선 라운드 발사 (Sonnet에 픽스 묶음 → 다음 라운드)
(B) v1 그대로 채택 + 잔여 별도 태스크
(C) 폐기 (commit revert)
```

## Step 9: Round Management

When the user selects (A) → increment the round counter → dispatch the fix bundle to the builder → repeat Steps 3~8.
**Maximum 3 rounds**. On entering round 4, strongly recommend "split into a separate task" to the user.

## Step 10: End the Cycle + Revert pane 2

```bash
tmux send-keys -t "${SESSION}.2" "/model glm-5.1" Enter
sleep 4
echo "✅ pane 2 → GLM 5.1 (default 복귀)"
```

## Usage Examples

```bash
# music-lab cwd에서
/hih-dual "PIPE-F10c — token_guard rate_limit 매칭 픽스. 'rateLimitExceeded' (camelCase→ratelimitexceeded) 누락 케이스 추가 + 테스트 1개"

# project-manager cwd에서
/hih-dual "scripts/dual_pane.sh 에러 핸들링 보강 — 빈 prompt + 세션 부재 + pane 부재 케이스"
```

## Core Principles

1. **PM is the cycle manager** — dispatching, polling, verifying, and round decisions are all PM's. The user only intervenes at decision points.
2. **Reviewer response verbatim** — do not truncate or summarize.
3. **PM verification backstop** — the 4.6 reviewer may raise false concerns. PM corrects them with grep/python before reporting to the user.
4. **Maximum 3 rounds** — if more is needed, recommend splitting the task.
5. **Revert pane 2 to 5.1 when the cycle ends** — guarantee the default state.
6. **Preserve the builder commit** — on discard, the user makes an explicit revert decision. PM does NOT auto-revert.

## Error Handling

| Case | Handling |
|---|---|
| builder 15-minute timeout | Force capture + "Sonnet 무응답 — pane 직접 확인" |
| reviewer 10-minute timeout | Force capture + keep 4.6 + user decision |
| builder requests user confirmation (like AskUserQuestion) | PM relays that question to the user + answer → syncs to the builder |
| reviewer 4.6 false concerns 5+ | "5.1로 재리뷰 권고 — /hih-glm review <hash>" |
| pane 1·2 model wrong | Warn + proceed anyway |

## Verification Case (PIPE-F10, 2026-05-06)

First verification of the builder/reviewer pattern in music-lab (manual procedure):
- v1 (commit 2ccf182): Sonnet 30-minute work, GLM 4.6 review 1m20s — 5 CRITICAL items
- PM decision: adopt 3 CRITICAL items → dispatch fix bundle to builder
- v2 (commit 91046ab): Sonnet 4-minute fix, GLM 4.6 re-review 70s — 2 false concerns (MRO, untracked) — corrected by PM verification
- Result: PROD ready, remaining INFO split into the separate task PIPE-F10b

This SKILL is the automated version of that procedure.

## Temp File Cleanup

```bash
find /tmp -maxdepth 1 -name "hih_dual_*" -mtime +7 -delete 2>/dev/null
```
