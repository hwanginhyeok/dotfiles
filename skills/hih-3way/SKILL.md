---
name: hih-3way
version: 1.0.0
description: |
  1-round 3모델 병렬 리뷰. Claude /review + /codex + /hih-glm을 동시에 실행하여
  비교 테이블 + 합의율 + Composite gate를 출력한다.
  hih-dev STEP 5를 독립 스킬로 추출한 것.
  Use when: "3-way review", "3-way 리뷰", "병렬 리뷰", "hih-3way", "모델 비교 리뷰"
---

# /hih-3way — 3-Model Parallel Review (1-round)

구현 완료 후 **Claude + OpenAI Codex + GLM 5.1** — 3개 모델이 동일한 diff를 독립 리뷰.
3개 모두 동의한 발견 = 최우선 수정 대상, 1개만 지적 = PM이 직접 확인 후 판단.

---

## 실행 순서 (총 ~5분, 3개 병렬)

### Step 1: GLM dispatch (async)

GLM을 pane 2에 먼저 보내 백그라운드에서 연산 시작.

```bash
# GLM을 해당 pane에 비동기 디스패치
SESSION=$(basename $(pwd))  # 또는 HIH_GLM_SESSION
tmux list-panes -t $SESSION | wc -l  # pane 2 존재 확인
tmux send-keys -t ${SESSION}:1.2 "/hih-glm review HEAD" Enter
```

> pane 2가 없으면 /hih-glm 스킬이 자동 생성 + claude-glm 부팅.

### Step 2: Claude /review (빠름, ~30초)

- `/review` 스킬 실행 (Claude 자체 diff 리뷰)
- CRITICAL/INFORMATIONAL 분류 + PASS/FAIL 판정
- 결과를 임시 저장

```bash
# /review 결과는 세션 내에 저장됨
# (이 스킬의 호출자인 PM이 /review를 직접 실행하거나,
#  이미 실행된 결과를 참조)
```

### Step 3: /codex (블로킹, ~5분)

- `/codex review` 실행
- 이 동안 GLM도 백그라운드에서 연산 중
- codex 완료 시점에 GLM 응답도 대부분 완료됨

```bash
# /codex review 실행
# 결과를 임시 저장
```

### Step 4: GLM 응답 캡처

```bash
SESSION=$(basename $(pwd))
tmux capture-pane -t ${SESSION}.2 -p -S -3000 > /tmp/hih_3way_glm.txt
```

### Step 5: 비교 테이블 + 합의율 + Composite gate

3개 모델의 결과를 취합하여 비교 테이블 생성.

---

## 3-WAY REVIEW 결과 형식 (필수)

3개 모델 모두 완료 후, **반드시** 아래 비교 테이블을 출력:

```
## 3-WAY REVIEW RESULT
┌───────────────┬──────────┬───────┬────────────────────────────┐
│ 모델          │ GATE     │ 발견수 │ 고유 발견                  │
├───────────────┼──────────┼───────┼────────────────────────────┤
│ Claude /review│ PASS/FAIL│ N건   │ {Claude만 찾은 것}         │
│ /codex        │ PASS/FAIL│ N건   │ {Codex만 찾은 것}          │
│ /hih-glm      │ PASS/FAIL│ N건   │ {GLM만 찾은 것}            │
└───────────────┴──────────┴───────┴────────────────────────────┘

모두 동의 (즉시 수정):   {3개 모델 모두 지적한 발견}
2개 동의 (수정 권고):     {2개 이상 지적한 발견}
1개만 지적 (PM 확인):    {단일 지적 — PM이 오탐인지 판단}
합의율: X%

Composite gate: PASS / FAIL
Composite recommendation: <최우선 수정 항목 + 이유>
```

---

## Composite Gate 판정 기준

| 조건 | 판정 | 후속 액션 |
|------|------|-----------|
| 3개 모두 PASS | **PASS** | 다음 단계 진행 |
| 1개 이상 FAIL + "모두 동의" 발견 존재 | **FAIL** | 수정 후 3-way 재실행 |
| 1개만 FAIL + "모두 동의" 발견 없음 | **CONDITIONAL PASS** | PM이 단일 지적 검증 후 판단 |

### 합의율 계산

```
합의율 = (모두 동의 발견 수 / 전체 고유 발견 수) × 100%
```

- 합의율 100%: 3개 모델이 완벽히 동일한 발견
- 합의율 0%: 모든 발견이 서로 다름 (모델마다 다른 관점)

---

## 발견 분류별 액션

### 모두 동의 (3/3 동의) → 즉시 수정
- 3개 모델이 모두 지적한 사항
- 의심할 여지 없는 진짜 문제
- 수정 후 재리뷰 필요 없으면 다음 단계 진행

### 2개 동의 (2/3 동의) → 수정 권고
- 다수 모델이 지적한 사항
- 실제 문제일 가능성 높음
- 수정 권고, PM 판단에 따라 보류 가능

### 1개만 지적 (1/3) → PM 검증
- 단일 모델만 지적한 사항
- 오탐(false positive) 가능성 존재
- PM이 직접 grep/python으로 검증 후 판단
- GLM 5.1은 검증됨: false concern 비율이 4.6 대비 현저히 낮음
- 단, 0은 아님 (PM이 팩트체크 백스톱 역할)

---

## 타임아웃 및 에러 처리

| 상황 | 처리 |
|------|------|
| GLM 10분 타이임아웃 | 강제 캡처 + "GLM 응답 없음 — pane 직접 확인" 경고 |
| /codex 실패 | 2-way 리뷰로 강등 (Claude + GLM만) + 경고 출력 |
| /review 실패 | 2-way 리뷰로 강등 (Codex + GLM만) + 경고 출력 |
| 2개 이상 모델 실패 | FAIL + "수동 리뷰 필요" 에스컬레이션 |

---

## hih-dev에서의 호출 방식

hih-dev STEP 5에서는 다음과 같이 참조:

```
> hih-3way 스킬 실행
```

hih-dev은 이 스킬을 호출하고, 결과를 받아 STEP 6으로 진행 여부를 판단.

---

## SKIP 조건

- 코드 변경 없음 (docs-only, 설정 파일만 변경)
- `--fast-merge` 플래그: /review만 실행 (codex/glm 생략)
- 단일 라인 변경 등 자명한 수정

---

## 실행 시작 시 출력 형식

```
## /hih-3way start
대상: HEAD (또는 {commit hash})
모델: Claude /review + /codex + GLM 5.1

▶ Step 1: GLM dispatch (async)...
▶ Step 2: Claude /review...
▶ Step 3: /codex...
▶ Step 4: GLM 캡처...
▶ Step 5: 비교 테이블 생성...
```

각 Step 완료 시 `✅ Step N done` 출력 후 다음 Step 진행.
