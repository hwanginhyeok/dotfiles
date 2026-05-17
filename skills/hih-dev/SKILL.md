---
name: hih-dev
description: 기능 개발 풀 파이프라인. 태스크 확인 → 설계 → (병렬 분해 판단) → 구현 → 검증 → 리뷰 → 배포 → 세션 마무리. 구분되는 기능이면 병렬 에이전트 자동 배정. 범용 (icloud-blog, insung, stock 등 모든 프로젝트). Use when: "개발 시작", "기능 만들어줘", "풀 파이프라인", "hih-dev", "병렬 개발"
user_invocable: true
---

# /hih-dev — 기능 개발 풀 파이프라인

새 기능 개발의 전 단계를 순서대로 수행한다.
**구분되는 기능(독립 모듈/파일 경계 명확)이면 병렬 에이전트를 자동 배정**해 속도를 높인다.
각 단계는 스킵 가능하며, 상황에 따라 분기한다.

---

## 파이프라인 순서

```
STEP 1    /hih-task        — 태스크 확인 + 이번 세션 목표 설정
STEP 1.5  병렬 분해 분석    — 독립 서브태스크 분해 가능 여부 판단
STEP 2    /office-hours    — 아이디어/설계 검토 (충분히 논의했으면 SKIP)
STEP 3    /plan-eng-review — 아키텍처·구현 계획 리뷰
STEP 4    코드 짜기         — 단일 or 병렬 에이전트 구현
            ├ 단일: PM이 직접 구현
            ├ 병렬: 서브태스크별 pane에 에이전트 배정 → 동시 구현
            └ 버그 발생 시 → /investigate (근본 원인 확정 후 복귀)
STEP 5    3-way 리뷰       — /review(Claude) + /codex + /hih-glm 병렬 실행 → 비교표
            ├ GLM dispatch (비동기) → /review (30초) → /codex (5분, GLM과 병렬)
            ├ 3-way 비교표 출력 (합의율 + 종합 게이트)
            └ 모두 동의 발견 → 즉시 수정 / 단독 발견 → PM 검증
STEP 6    /health         — 코드 품질 종합 점수 (타입체크 + 린터 + 테스트)
STEP 6.5  /qa             — 웹 QA (실제 브라우저로 UI + API 검증, 조건부)
            ├ 웹 앱이면 자동 실행: 배포 URL or localhost 확인 후 browse로 테스트
            └ 웹 앱 아니면 (Python 라이브러리, CLI 등) → SKIP
STEP 7    /ship           — 커밋 + push + PR 생성
STEP 8    /hih-clear      — 태스크 정리 + 문서화 + 메모리 갱신 (할 일 다 끝났을 때)
```

---

## STEP 1 — /hih-task

현재 프로젝트의 태스크를 브리핑한다.

- CURRENT_TASK.md / PREPARED_TASK.md / FINISHED_TASK.md 읽기
- 이번 세션에서 개발할 태스크 1~3개 선택
- 선택한 태스크를 CURRENT로 이동 (start 명령)

**출력 예시**:
```
## 이번 세션 목표
- ICB-07: naver_publisher.py 연동
- ICB-08: run_pipeline.py CLI 완성
```

---

## STEP 1.5 — 병렬 분해 분석 (자동)

STEP 1 직후 항상 실행. 병렬 에이전트 투입 여부를 판단한다.

### 병렬 가능 판단 기준 (3가지 모두 충족해야)
1. **파일 경계 분리**: 서브태스크A와 B가 수정하는 파일이 겹치지 않는가?
2. **의존성 없음**: A 결과가 B 구현에 필요하지 않은가? (순서 없이 병렬 실행 가능한가?)
3. **독립 테스트**: 각 서브태스크를 따로 검증할 수 있는가?

### 판단 결과 분기
```
병렬 가능 → N개 서브태스크로 분해 → STEP 4에서 병렬 에이전트 배정
단일 작업 → 분해 생략 → STEP 4에서 PM 직접 구현
```

### 분해 예시
| 기능 요청 | 서브태스크 분해 |
|-----------|--------------|
| 블로그 파이프라인 | A: naver_publisher.py / B: run_pipeline.py / C: 테스트 |
| 주식 대시보드 | A: 백엔드 API / B: 프론트엔드 컴포넌트 / C: DB 마이그레이션 |
| 음악 후처리 | A: 보컬 분리 / B: 마스터링 / C: 업로드 |

**출력 형식**:
```
## 병렬 분해 분석
분해 가능: ✅ / ❌ (단일)

서브태스크:
- A: {제목} — 담당 파일: {파일 목록}
- B: {제목} — 담당 파일: {파일 목록}
- C: {제목} — 담당 파일: {파일 목록}

에이전트 배정:
- pane 1 (기존 claude): 서브태스크 A
- pane 2 (신규 에이전트): 서브태스크 B
- pane 3 (신규 에이전트): 서브태스크 C
```

---

## STEP 3 — /plan-eng-review

아키텍처와 구현 계획을 리뷰한다.

- 어떤 파일을 만들거나 수정할지
- 의존성 흐름 (어떤 모듈이 어떤 모듈을 호출하는지)
- 엣지 케이스 + 에러 처리 방향
- 테스트 가능성 확인

리뷰 통과 후 구현 시작.

---

## STEP 4 — 코드 짜기

plan-eng-review에서 확정된 계획대로 구현한다.

### 단일 구현 (병렬 분해 ❌)
- 한 번에 하나의 모듈/기능 단위로 작업
- test-first 룰: 코드 수정 전 현재 동작 확인
- 주석과 커밋 메시지는 한국어

### 병렬 구현 (병렬 분해 ✅)

#### 에이전트 배정 절차

**1. 현재 pane 상태 확인**
```bash
tmux list-panes -t {세션}:1
# 예: bea / stock / insung / music
```

**2. 필요 pane 부족 시 추가**
```bash
tmux split-window -t {세션}:1 -c ~/{프로젝트경로}
tmux select-layout -t {세션}:1 main-vertical
```

**3. 각 pane에 에이전트 시작**
```bash
tmux send-keys -t {세션}:1.2 "claude --add-dir ~/project-manager" Enter
tmux send-keys -t {세션}:1.3 "claude --add-dir ~/project-manager" Enter
```

**4. 태스크 브리핑 파일 작성 후 전달**
```bash
# 브리핑 파일 작성
cat > /tmp/hih_task_B.md << 'EOF'
## 서브태스크 B: {제목}

### 담당 파일 (이 파일들만 수정)
- {파일 경로}

### 구현 목표
{구체적 목표}

### 완료 조건
- [ ] {체크리스트}

### 주의
- pane1 에이전트와 파일 겹침 없음. 담당 파일 외 수정 금지.
- 완료 시 git add + commit (push는 PM 지시 대기)
EOF

# 에이전트에게 전달
tmux send-keys -t {세션}:1.2 "cat /tmp/hih_task_B.md" Enter
```

**5. 완료 확인**
```bash
# 각 pane 에이전트가 완료 커밋하면 git log로 확인
git -C ~/{프로젝트} log --oneline -5
```

**6. PM 검증 (L2 hunk)**
```bash
git -C ~/{프로젝트} show --stat {커밋해시}
```

### 버그 분기 — /investigate
구현 중 예상치 못한 버그나 에러 발생 시:
1. `/investigate` 스킬 호출
2. 근본 원인 확정 (추측으로 수정 금지)
3. 원인 확정 후 STEP 4로 복귀

---

## STEP 5 — 3-way 리뷰 (/review + /codex + /hih-glm)

구현 완료 후 **Claude + OpenAI Codex + GLM 5.1** 3개 모델이 독립적으로 diff를 리뷰한다.
모두 동의한 발견 = 최우선 수정, 1개만 지적한 발견 = PM이 직접 검증 후 판단.

### 실행 순서 (총 소요: ~5분, 3개 병렬)

**1단계: GLM dispatch (비동기)**
```bash
# GLM을 먼저 pane에 dispatch → 백그라운드에서 계산 시작
SESSION=$(basename $(pwd))  # 또는 HIH_GLM_SESSION
tmux list-panes -t $SESSION | wc -l  # pane 2 확인
# /hih-glm review HEAD 를 pane 2에 전달
```

**2단계: Claude /review (빠름, ~30초)**
- `/review` 스킬 실행 (Claude 자체 diff 리뷰)
- CRITICAL/INFORMATIONAL 분류 + PASS/FAIL

**3단계: Codex /codex (blocking, ~5분)**
- `/codex review` 실행 (이 동안 GLM도 백그라운드에서 계산 중)
- codex가 끝나면 GLM 응답도 대부분 완료됨

**4단계: GLM 응답 capture**
```bash
tmux capture-pane -t ${SESSION}.2 -p -S -3000 > /tmp/hih_3way_glm.txt
```

### 3-way 비교 출력 (REQUIRED)

3개 모두 완료 후 반드시 비교표 출력:

```
## 3-WAY 리뷰 결과
┌───────────────┬──────────┬───────┬────────────────────────────┐
│ 모델          │ GATE     │ 발견  │ 고유 발견                  │
├───────────────┼──────────┼───────┼────────────────────────────┤
│ Claude /review│ PASS/FAIL│ N건   │ {Claude만 찾은 것}         │
│ /codex        │ PASS/FAIL│ N건   │ {Codex만 찾은 것}          │
│ /hih-glm      │ PASS/FAIL│ N건   │ {GLM만 찾은 것}            │
└───────────────┴──────────┴───────┴────────────────────────────┘

모두 동의 (즉시 수정):  {3개 모두 지적한 발견 목록}
2개 동의 (수정 권고):   {2개 이상 지적한 발견 목록}
1개만 지적 (PM 검증):   {단독 발견 — 거짓 우려 여부 PM이 확인}
합의율: X%

종합 게이트: PASS / FAIL
종합 권고: <가장 우선 수정할 것 + 이유>
```

**종합 게이트 기준:**
- 3개 모두 PASS → PASS
- 1개라도 FAIL이고 "모두 동의" 발견 있음 → FAIL (수정 후 재리뷰)
- 1개만 FAIL이고 "모두 동의" 발견 없음 → CONDITIONAL PASS (PM 검증 후 판단)

수정 필요 시 → 수정 후 STEP 5 재실행. PASS 후 STEP 6으로.

---

## STEP 6 — /health

코드 품질 종합 점수 확인.

- 타입체크 (mypy / tsc 등)
- 린터 (ruff / eslint 등)
- 테스트 러너
- 데드코드 탐지

**기준**: 이전 점수보다 낮아지면 수정 후 재측정.

---

## STEP 6.5 — /qa (조건부)

**웹 앱 여부 자동 감지 후 실행 결정:**

```bash
# 웹 앱 여부 판단 (하나라도 해당하면 웹 앱)
[ -f apps/web/package.json ] || [ -f package.json ] && grep -q '"next"\|"react"\|"vue"\|"express"' package.json 2>/dev/null
```

**웹 앱이면:**
1. 배포 URL 또는 로컬 dev 서버 확인:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null
   # 또는 CLAUDE.md / Vercel 설정에서 배포 URL 탐색
   ```
2. URL 확인되면 `/qa` 스킬 실행:
   - 이번 세션에서 수정한 페이지/기능 중심으로 테스트
   - 실제 Chromium 브라우저로 스크린샷 + console 에러 확인
   - 인증 필요 페이지: 쿠키 있으면 임포트, 없으면 공개 페이지만
3. 버그 발견 시:
   - Critical/High → 즉시 수정 후 재테스트 (STEP 4로 복귀)
   - Medium 이하 → PREPARED_TASK에 등록 후 계속

**SKIP 조건:**
- 웹 앱 아님 (Python 라이브러리, CLI, 스크립트 등)
- `--no-qa` 플래그
- 로컬 서버 없고 배포 URL도 없음 (이 경우 경고만 출력)

**출력:**
```
## QA 결과
URL: {테스트한 URL}
스크린샷: {N}장
버그: {Critical N건 / High N건 / Medium N건}
상태: PASS / ISSUES FOUND
```

---

## STEP 7 — /ship

커밋 + push + PR 생성.

- 커밋 메시지: 한국어, 의미 단위
- PR 제목: 간결하게 (70자 이내)
- force push 절대 금지

---

## STEP 8 — /hih-clear (조건부)

**실행 조건**: 이번 세션 목표 태스크가 전부 완료됐을 때.

**SKIP 조건**: 아직 남은 태스크가 있거나 다음 세션에서 이어갈 예정.

- 완료 태스크 → FINISHED_TASK.md 이동
- DIFFICULTY.md 갱신 (어려웠던 것 있으면)
- 메모리 갱신
- 세션 요약 출력

---

## 단계 스킵 규칙

| 조건 | 스킵 가능 단계 |
|------|--------------|
| 이미 충분히 논의함 | STEP 2 (office-hours) |
| 단순 버그픽스 | STEP 2, STEP 3 |
| 버그 없이 구현 완료 | STEP 4 분기 (investigate) |
| 아직 할 일 남음 | STEP 8 (hih-clear) |
| 빠른 머지 필요 | STEP 5 → /review만 실행 (codex/glm skip) |
| 웹 앱 아님 or `--no-qa` | STEP 6.5 (qa) |

---

## 실행 시 출력 형식

스킬 시작 시:
```
## /hih-dev 시작
프로젝트: {프로젝트명}
목표: {이번 세션 태스크}

파이프라인:
✅ STEP 1 hih-task
⏭ STEP 2 office-hours (SKIP — 이미 논의 완료)
▶ STEP 3 plan-eng-review ← 현재
  STEP 4 코드 짜기
  STEP 5 3-way 리뷰 (Claude + Codex + GLM)
  STEP 6 health
  STEP 6.5 qa (웹 앱이면 자동 실행)
  STEP 7 ship
  STEP 8 hih-clear
```

각 단계 완료 시 `✅ STEP N 완료` 출력 후 다음 단계 진행.
