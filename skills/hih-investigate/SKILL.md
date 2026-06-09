---
name: hih-investigate
description: 버그 수정 풀 파이프라인. /investigate(근본원인) → fix → 3-way 리뷰(/review + /codex + /hih-glm) → /ship. /hih-dev가 신기능 개발용이라면 /hih-investigate는 버그 수정 + 안전 배포용. Use when. "버그 수정", "에러 조사 후 배포", "fix 파이프라인", "hih-investigate"
user_invocable: true
---

# /hih-investigate — 버그 수정 + 안전 배포 파이프라인

버그 발견 → 근본원인 확정 → fix → 3-way 리뷰 → 배포까지 한 번에.
**/hih-dev**가 "신기능 개발용 풀 파이프라인"이라면, **/hih-investigate**는 "버그 fix 전용 단축 파이프라인".

추측 fix 금지(Iron Law), 3-way 리뷰로 fix가 또 다른 버그 만들지 않는지 검증, 마지막에 자동 배포.

---

## 파이프라인 순서

```
STEP 1    /investigate    — 근본원인 확정 (4단계: investigate → analyze → hypothesize → implement)
STEP 1.5  사전 체크        — 운영 서비스 + 외부 의존 상태 (조건부)
STEP 2    fix 코드 작성    — RC 확정 후에만 코드 수정
STEP 3    fix 검증         — 단위 테스트 / 수동 재현 / 로그 확인
STEP 4    3-way 리뷰       — /review(Claude) + /codex + /hih-glm 병렬 → 합의표
            ├ 모두 동의 발견 → 즉시 수정 → STEP 4 재실행
            └ 단독 발견 → PM 검증 후 판단
STEP 5    /ship           — 커밋(fix: prefix + RC 명시) + push + PR
STEP 6    배포 후 검증     — /canary 모니터링 + DIFFICULTY.md 갱신 (조건부)
```

---

## STEP 1 — /investigate (근본원인 확정)

**Iron Law: 근본원인 확정 없이 fix 금지.**

`/investigate` 스킬을 호출해 4단계 수행:
1. **investigate**: 증상 파악 + 재현 + 로그 수집
2. **analyze**: 코드 흐름 추적 + 데이터 흐름 추적
3. **hypothesize**: 가설 수립 + 검증
4. **implement**: fix 방향 확정 (코드는 STEP 2에서)

**출력 형식**:
```
## RC 확정
- 원인: {파일:라인 + 한 줄 요약}
- 영향 범위: {다른 모듈/데이터 영향}
- fix 방향: {수정할 파일 + 변경 요지}
- 검증 방법: {STEP 3에서 어떻게 확인할지}
```

---

## STEP 1.5 — 사전 체크 (조건부, 운영 시스템)

운영 서비스가 있는 프로젝트라면 fix 전 현재 상태 확인.

### 인성이 블로그 (systemd + Supabase + Playwright)
```bash
# 서비스 active 확인
systemctl --user status blog-api blog-worker | grep -E "●|Active:"

# Supabase 영향 시 직조회
source ~/insung_blog/.env && python3 -c "..."

# Playwright 셀렉터 영향 시 selector-debug 트리거
# → 프로젝트 .claude/skills/selector-debug.md 참조
```

### 그 외 프로젝트
- be-a-studio: cron 로그 + GLM 호출 상태
- stock: x-bot.service status + Telegram 알림 흐름
- 정적 사이트/CLI: SKIP

**SKIP 조건**: 단순 코드 버그 (운영 인프라 무관)

---

## STEP 2 — fix 코드 작성

STEP 1에서 확정된 RC + fix 방향대로 구현.

### 원칙
- test-first: 수정 전 현재 동작 확인 (테스트/curl/로그)
- 주석/커밋 메시지 한국어
- 영향 범위 최소화 (관련 없는 리팩터링 금지)

### 병렬 분해 (선택)
fix가 독립 파일 여러 개에 걸치면 hih-dev STEP 1.5 병렬 분해 절차 차용.

---

## STEP 3 — fix 검증

코드 수정 완료 후 실제로 RC가 해결됐는지 확인.

### 검증 방식 (RC 유형별)
| RC 유형 | 검증 방식 |
|---------|----------|
| 함수 로직 버그 | 단위 테스트 (pytest/vitest) 실행 |
| API 응답 버그 | curl로 응답 형태 확인 |
| 셀렉터 변경 | `/browse` 또는 `debug_*.py`로 DOM 확인 |
| DB 상태 버그 | Supabase 직조회로 row 확인 |
| 워커/cron 버그 | journalctl + cron 로그 grep |
| UI 버그 | `/browse`로 페이지 screenshot |

### 출력
```
## fix 검증
RC: {STEP 1에서 확정한 원인}
검증: {수행한 명령 + 결과}
상태: ✅ 해결 / ❌ 미해결 / ⚠️ 부분 해결
```

❌이면 STEP 1으로 복귀 (RC 재분석). ⚠️이면 사용자 판단.

---

## STEP 4 — 3-way 리뷰 (병렬)

fix가 또 다른 버그를 만들지 않는지 **Claude + OpenAI Codex + GLM 5.1** 독립 검증.
fix는 특히 회귀 위험이 크기 때문에 신규 코드보다 더 엄격하게 본다.

### 실행 순서 (총 ~5분)

**1단계: GLM dispatch (비동기, pane 2)**
```bash
SESSION=$(basename $(pwd))  # 또는 HIH_GLM_SESSION
tmux send-keys -t ${SESSION}:1.2 "/hih-glm review HEAD" Enter
```

**2단계: Claude /review (~30초)**
```bash
/review
# → CRITICAL/INFORMATIONAL 분류 + PASS/FAIL
```

**3단계: Codex /codex (blocking, ~5분 — GLM도 백그라운드 진행)**
```bash
/codex review
```

**4단계: GLM 응답 capture**
```bash
tmux capture-pane -t ${SESSION}.2 -p -S -3000 > /tmp/hih_investigate_glm.txt
```

### 3-way 비교 출력 (REQUIRED)

```
## 3-WAY 리뷰 결과 — fix 안정성 검증
┌───────────────┬──────────┬───────┬────────────────────────────┐
│ 모델          │ GATE     │ 발견  │ 고유 발견                  │
├───────────────┼──────────┼───────┼────────────────────────────┤
│ Claude /review│ PASS/FAIL│ N건   │ {Claude만 찾은 회귀 위험}  │
│ /codex        │ PASS/FAIL│ N건   │ {Codex만 찾은 부작용}      │
│ /hih-glm      │ PASS/FAIL│ N건   │ {GLM만 찾은 누락 케이스}   │
└───────────────┴──────────┴───────┴────────────────────────────┘

모두 동의 (즉시 수정): {3개 모두 지적한 회귀 위험}
2개 동의 (수정 권고): {2개 이상 지적}
1개만 지적 (PM 검증):  {단독 발견 — 거짓 우려 가능성}
합의율: X%

종합 게이트: PASS / FAIL
종합 권고: {가장 우선 수정 + 이유}
```

### 종합 게이트 기준 (fix 전용 엄격 모드)
- 3개 모두 PASS → PASS
- 1개라도 FAIL이고 "모두 동의" 발견 있음 → FAIL (수정 후 STEP 4 재실행)
- 1개만 FAIL이고 "모두 동의" 발견 없음 → CONDITIONAL PASS
- **fix가 회귀 위험 1개 이상 지적되면 항상 수정 권고** (신규 개발보다 엄격)

수정 필요 시 → STEP 2 (fix 재작성) → STEP 3 (재검증) → STEP 4 (재리뷰).

### 빠른 모드 (`--fast`)
긴급 fix면 `/review`만 (30초) + 사용자에게 codex/glm SKIP 동의 받기.

---

## STEP 5 — /ship (커밋 + PR)

`/ship` 스킬 실행. **fix 전용 커밋 메시지 규칙 적용**.

### 커밋 메시지 형식
```
fix({모듈}): {간결한 fix 요약}

RC: {STEP 1에서 확정한 근본원인}
영향: {수정 범위}
검증: {STEP 3 검증 방법 요약}
3-way: {리뷰 결과 — 모두 동의 / 2 동의 / 단독}

🤖 Generated with Claude Code
```

### PR description
- "## Root Cause" — RC 한 줄
- "## Fix" — 수정 요지
- "## Verification" — 검증 결과
- "## 3-way Review" — 합의표 요약

### 안전 가드
- force push 절대 금지
- main/master 직접 push 차단 (PR 필수)
- 운영 서비스 영향 fix는 사용자 승인 게이트 한 번 더

---

## STEP 6 — 배포 후 검증 (조건부)

### 웹 앱 (Vercel/Cloudflare)
```bash
# /canary 자동 호출 — 30분 모니터링
/canary {배포 URL}
```

### 운영 시스템 (systemd)
```bash
systemctl --user restart {서비스}
sleep 2
systemctl --user status {서비스}
journalctl --user -u {서비스} -n 20 --no-pager
```

### DIFFICULTY.md 자동 갱신
이번 fix가 "삽질 케이스"였다면 (RC 추적 30분+ 또는 동일 패턴 재발) 자동 등록:
```markdown
| D-### | {제목} | {날짜} | 원인: {RC} / 회피: {스킬 트리거 또는 사전 체크} |
```

---

## 단계 스킵 규칙

| 조건 | 스킵 가능 |
|------|----------|
| RC 이미 명확 (단순 typo) | STEP 1 축약 (1단계만) |
| 운영 인프라 무관 | STEP 1.5 (사전 체크) |
| 긴급 hotfix | STEP 4 → `--fast` (Claude /review만) |
| 정적 사이트/CLI | STEP 6 (canary) |
| 동일 패턴 첫 발생 | DIFFICULTY.md 등록 SKIP |

---

## /hih-dev vs /hih-investigate 구분

| 항목 | /hih-dev | /hih-investigate |
|------|---------|-----------------|
| 목적 | 신기능 개발 | 버그 수정 |
| 시작점 | /hih-task (태스크 선택) | /investigate (RC 확정) |
| 설계 단계 | /office-hours + /plan-eng-review | (생략, RC가 설계 대체) |
| 병렬 분해 | 기본 활성 | fix 단일 파일이면 SKIP |
| 3-way 리뷰 | 신규 기능 안전성 | **fix 회귀 위험** (더 엄격) |
| 커밋 prefix | `feat:` | `fix:` |
| 배포 후 | qa | **canary 필수** (회귀 모니터링) |
| DIFFICULTY | 신규 학습만 | **삽질 케이스 자동 등록** |
| 평균 소요 | 1~3시간 | 30분~1시간 |

---

## 실행 시 출력 형식

스킬 시작 시:
```
## /hih-investigate 시작
프로젝트: {프로젝트명}
증상: {보고된 버그/에러}

파이프라인:
▶ STEP 1 investigate ← 현재
  STEP 1.5 사전 체크 (조건부)
  STEP 2 fix 코드 작성
  STEP 3 fix 검증
  STEP 4 3-way 리뷰 (Claude + Codex + GLM)
  STEP 5 ship (fix: prefix)
  STEP 6 배포 후 검증 (canary + DIFFICULTY)
```

각 단계 완료 시 `✅ STEP N 완료` 출력 후 다음 단계 진행.
