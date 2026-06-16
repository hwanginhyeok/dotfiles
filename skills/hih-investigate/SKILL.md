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
STEP 4.5  보안 스캔        — security-auditor 에이전트로 fix diff 스캔 (고위험 시 /cso 격상), ship 차단 게이트
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
|| RC 유형 | 검증 방식 ||
||---------|----------||
|| 함수 로직 버그 | 단위 테스트 (pytest/vitest) 실행 ||
|| API 응답 버그 | curl로 응답 형태 확인 ||
|| 셀렉터 변경 | `/browse` 또는 `debug_*.py`로 DOM 확인 ||
|| DB 상태 버그 | Supabase 직조회로 row 확인 ||
|| 워커/cron 버그 | journalctl + cron 로그 grep ||
|| UI 버그 | `/browse`로 페이지 screenshot ||

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

### 실행 순서 + 비교표 형식

→ **SSOT: hih-3way-hard 스킬** (fix는 회귀 위험이 크므로 기본적으로 hard 모드 사용)
→ 일반 기능 개발은 `/hih-3way` (1-round), 버그 수정은 `/hih-3way-hard` (다중 라운드)
- 실행 순서 (GLM dispatch → /review → /codex → GLM capture)
- 3-way 비교표 형식 (모델별 GATE/발견/고유 발견 + 합의율)
- 종합 게이트 기본 로직

GLM capture 파일명만 `/tmp/hih_investigate_glm.txt`로 사용.

### fix 전용 엄격 모드 (hih-dev과의 차이점)

hih-dev STEP 5의 종합 게이트 기준에 **아래 엄격 규칙을 추가 적용**:

1. **회귀 위험 1건 이상 = 항상 수정 권고** (신규 개발보다 엄격)
2. **CONDITIONAL PASS 세분화**:
   - 1개만 FAIL + "모두 동의" 발견 없음 → CONDITIONAL PASS
   - CONDITIONAL PASS여도 회귀 위험이 있으면 수정 권고
3. 수정 필요 시 → STEP 2 (fix 재작성) → STEP 3 (재검증) → STEP 4 (재리뷰)

### 빠른 모드 (긴급 수정)
긴급 수정 시 STEP 4를 `/review`(Claude만, ~30초)로 축소. **별도 명령행 인자가 아님** — Step-skip Rules의 "긴급 hotfix" 행으로 자동 적용. "긴급해", "빨리", "--fast" 키워드 사용 시 발동.

---

## STEP 4.5 — 보안 스캔 (ship 차단 게이트)

3-way 리뷰(STEP 4) 통과 후, **ship 전에** fix diff를 전용 보안 스캔한다.
fix는 회귀 위험이 크고 — 특히 **보안 회귀**(인증 우회 재발, 입력 검증 제거, 시크릿 노출)는
기능 회귀보다 치명적이다. STEP 4의 codex challenge로는 부족하므로 명시적 게이트로 분리한다.

### 스캔 범위 — fix diff만 (빠르고 관련성 높음)
```bash
git diff master..HEAD
```
중점: 하드코딩 시크릿/토큰, 인젝션(SQL/명령어/경로), 인증·인가 허점, 입력 검증,
SSRF/오픈 리다이렉트, 안전하지 않은 역직렬화, **신규 추가 의존성**(공급망 위험).
fix 특유 점검: "버그를 막으려고 추가한 코드가 새 공격 표면을 만들지 않았는가?"

### 도구 선택 (STEP 4의 3way ↔ 3way-hard 패턴과 동일)
| 상황 | 도구 | 이유 |
|------|------|------|
| 일반 fix | `security-auditor` 에이전트 (diff) | 격리 컨텍스트, 고속, zero-noise |
| **고위험 fix** (인증 / 시크릿 / 결제 / 외부 입력 / 신규 의존성) | `/cso` (daily, 8/10 게이트) | 시크릿 고고학 + 의존성 공급망 + OWASP/STRIDE |
| 운영 서비스 영향 fix | `/cso` (daily) | 프로덕션 직접 영향 — 더 엄격 |

기본은 `security-auditor` 에이전트. 위 고위험 표면을 건드리면 자동으로 `/cso` 격상 (별도 플래그 불필요).

### 게이트 규칙 (fix 전용 엄격 모드 — 신규 개발보다 엄격)
| 심각도 | 조치 |
|--------|------|
| **CRITICAL / HIGH** | **ship 차단.** STEP 2(fix 재작성)로 복귀 → STEP 3 재검증 → STEP 4.5 재스캔. STEP 5 진행 금지. |
| **MEDIUM** | 보안 회귀면 즉시 수정. 무관하면 PREPARED_TASK 등록 + PM 승인 |
| **LOW / INFO** | PR description에 명기 후 진행 |
| **0건** | PASS → STEP 5(ship) 진행 |

> 글로벌 시크릿 규칙 적용: remote에 평문 PAT 금지, bash 인라인 시크릿 금지, `.env` grep 시 마스킹.
> diff에 하드코딩 시크릿 = CRITICAL.

### 출력
```
## 보안 스캔 결과
도구: security-auditor (diff) / cso (고위험: {사유})
발견: Critical N / High N / Medium N / Low N
게이트: PASS / BLOCKED ({차단 항목})
```

**SKIP 조건:**
- docs-only / 설정-only (시크릿 표면·신규 의존성 없음)
- `--fast` 긴급 hotfix 시에도 **CRITICAL/HIGH 스캔은 유지** (보안은 긴급보다 우선) — security-auditor 단축 스캔으로 축소만 가능

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

|| 조건 | 스킵 가능 ||
||------|----------||
|| RC 이미 명확 (단순 typo) | STEP 1 축약 (1단계만) ||
|| 운영 인프라 무관 | STEP 1.5 (사전 체크) ||
|| 긴급 hotfix | STEP 4 → `--fast` (Claude /review만) — 단 STEP 4.5 CRITICAL/HIGH 스캔은 유지 ||
|| docs/설정-only (시크릿 표면 없음) | STEP 4.5 (보안 스캔) ||
|| 정적 사이트/CLI | STEP 6 (canary) ||
|| 동일 패턴 첫 발생 | DIFFICULTY.md 등록 SKIP ||

---

## /hih-dev vs /hih-investigate 구분

|| 항목 | /hih-dev | /hih-investigate ||
||------|---------|-----------------||
|| 목적 | 신기능 개발 | 버그 수정 ||
|| 시작점 | /hih-task (태스크 선택) | /investigate (RC 확정) ||
|| 설계 단계 | /office-hours + /plan-eng-review | (생략, RC가 설계 대체) ||
|| 병렬 분해 | 기본 활성 | fix 단일 파일이면 SKIP ||
|| 3-way 리뷰 | 신규 기능 안전성 | **fix 회귀 위험** (더 엄격) ||
|| 보안 스캔 | STEP 6.3 (ship 전) | STEP 4.5 (ship 전, **보안 회귀** 중점·더 엄격) ||
|| 커밋 prefix | `feat:` | `fix:` ||
|| 배포 후 | qa | **canary 필수** (회귀 모니터링) ||
|| DIFFICULTY | 신규 학습만 | **삽질 케이스 자동 등록** ||
|| 평균 소요 | 1~3시간 | 30분~1시간 ||

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
  STEP 4.5 보안 스캔 (ship 차단 게이트)
  STEP 5 ship (fix: prefix)
  STEP 6 배포 후 검증 (canary + DIFFICULTY)
```

각 단계 완료 시 `✅ STEP N 완료` 출력 후 다음 단계 진행.
