---
name: hih-dual
description: |
  builder(Sonnet 4.6 1M) + reviewer(GLM 4.6) + PM 검증 사이클 자동화. 한 작업을
  builder에 발주 → 결과 commit → reviewer에 diff 리뷰 → PM이 거짓 우려 검증 →
  사용자에게 비교 보고 → 개선 라운드 또는 채택. 최대 3 라운드.

  /hih-glm은 단발 외부 의견 (5.1). /hih-dual은 사이클 (4.6 reviewer로 빠른 반복).
  Use when: "듀얼 작업", "builder reviewer 사이클", "Sonnet + GLM 협업"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
---

# /hih-dual — Builder/Reviewer 사이클

## 핵심 원리

같은 tmux 세션의 pane 2개로:
- **pane 1 (Sonnet 4.6 1M)** — builder. 코드 작성/수정/commit.
- **pane 2 (GLM 4.6)** — reviewer. 빠른 응답으로 diff 비판.
- **PM (이 세션)** — orchestrator. 양쪽 발사·idle 폴링·결과 비교·거짓 우려 검증·사용자에게 결정 요청.

PM 검증이 백스톱이라 reviewer 4.6의 거짓 우려도 잡힘 (PM이 grep/python으로 사실 검증).

/hih-glm 단발 호출 대비 장점: 빌더-리뷰어 자동 핑퐁 + commit 보존 + 라운드 관리.
단점: 라운드당 30~60분. 무거운 작업 적합.

## 모델 정책

| pane | 평상시 | /hih-dual 사이클 시 |
|---|---|---|
| pane 1 | Sonnet 4.6 1M | 그대로 (builder) |
| pane 2 | **GLM 5.1** (default) | **4.6 임시 전환** (빠른 reviewer 응답). 사이클 끝나면 5.1 복귀 |

## 전제 조건

1. cwd basename = tmux 세션명 (예: `~/music-lab` → `music-lab`)
2. pane 2개. pane 1 = `claude`(Sonnet), pane 2 = `claude-glm`(GLM)
3. `Z_AI_API_KEY` 설정

## Step 0: 환경 검증

```bash
[ -n "$Z_AI_API_KEY" ] || { echo "❌ Z_AI_API_KEY 없음"; exit 1; }
SESSION="${HIH_DUAL_SESSION:-$(basename $(pwd))}"
tmux has-session -t "$SESSION" 2>/dev/null || { echo "❌ 세션 '$SESSION' 없음"; exit 1; }
PANES=$(tmux list-panes -t "$SESSION" | wc -l)
[ "$PANES" -lt 2 ] && { echo "❌ pane 2개 필요"; exit 1; }
```

## Step 1: pane 2를 4.6으로 임시 전환

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

## Step 2: builder(pane 1)에 task 발사

ARGUMENTS = builder가 수행할 task. PM이 prompt 구성:

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

## Step 3: builder idle 폴링

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

## Step 4: builder 결과 분석 + diff 추출

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

## Step 5: reviewer(pane 2 GLM 4.6)에 리뷰 발사

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

## Step 6: reviewer idle 폴링

Step 3과 동일 구조. GLM 4.6 idle 마커: "Cogitated for|Brewed for|Pondered for|Cooked for|Baked for".

```bash
# 동일 패턴, timeout 600초 (10분 — 4.6은 빠름)
```

## Step 7: PM 검증 (백스톱)

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

PM이 CRITICAL/INFO 항목 중 의심되는 것 grep/python/ls로 검증 → 거짓 우려는 별도 표시.

## Step 8: 사용자에게 비교 보고 + 결정

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

## Step 9: 라운드 관리

사용자가 (A) 선택 시 → 라운드 카운터 ++ → builder에 픽스 묶음 발사 → Step 3~8 반복.
**최대 3 라운드**. 4 라운드 진입 시 사용자에게 "별도 태스크 분리" 강제 권고.

## Step 10: 사이클 종료 + pane 2 복귀

```bash
tmux send-keys -t "${SESSION}.2" "/model glm-5.1" Enter
sleep 4
echo "✅ pane 2 → GLM 5.1 (default 복귀)"
```

## 사용 예

```bash
# music-lab cwd에서
/hih-dual "PIPE-F10c — token_guard rate_limit 매칭 픽스. 'rateLimitExceeded' (camelCase→ratelimitexceeded) 누락 케이스 추가 + 테스트 1개"

# project-manager cwd에서
/hih-dual "scripts/dual_pane.sh 에러 핸들링 보강 — 빈 prompt + 세션 부재 + pane 부재 케이스"
```

## 핵심 원칙

1. **PM이 사이클 매니저** — 발사·폴링·검증·라운드 결정 모두 PM. 사용자는 결정 포인트에서만 개입.
2. **Reviewer 응답 verbatim** — 자르거나 요약 X.
3. **PM 검증 백스톱** — 4.6 reviewer가 거짓 우려 던질 수 있음. PM이 grep/python으로 정정 후 사용자 보고.
4. **최대 3 라운드** — 더 많이 필요하면 작업 분할 권고.
5. **사이클 끝나면 pane 2 5.1 복귀** — default 상태 보장.
6. **builder commit 보존** — 폐기 시 사용자가 명시적 revert 결정. PM이 자동 revert X.

## 에러 처리

| 케이스 | 처리 |
|---|---|
| builder 15분 timeout | 강제 capture + "Sonnet 무응답 — pane 직접 확인" |
| reviewer 10분 timeout | 강제 capture + 4.6 그대로 + 사용자 결정 |
| builder가 사용자 컨펌 요청(AskUserQuestion 같음) | PM이 그 질문을 사용자에게 전달 + 답변 → builder에 sync |
| reviewer 4.6 거짓 우려 5건+ | "5.1로 재리뷰 권고 — /hih-glm review <hash>" |
| pane 1·2 모델 잘못 | 경고 + 그래도 진행 |

## 검증 사례 (PIPE-F10, 2026-05-06)

builder/reviewer 패턴 음악-lab에서 첫 검증 (수동 절차):
- v1 (commit 2ccf182): Sonnet 30분 작업, GLM 4.6 리뷰 1m20s — CRITICAL 5건
- PM 결정: CRITICAL 3건 채택 → builder에 픽스 묶음 발사
- v2 (commit 91046ab): Sonnet 4분 픽스, GLM 4.6 재리뷰 70s — 거짓 우려 2건 (MRO, untracked) — PM 검증으로 정정
- 결과: PROD ready, 잔여 INFO는 PIPE-F10b 별도 태스크로 분리

이 SKILL은 그 절차를 자동화한 버전.

## 임시 파일 청소

```bash
find /tmp -maxdepth 1 -name "hih_dual_*" -mtime +7 -delete 2>/dev/null
```
