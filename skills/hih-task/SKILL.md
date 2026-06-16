---
name: hih-task
description: "태스크 브리핑 + 설계 대화(brainstorming) + 플랜 작성 + 관리. add 시 설계 대화 → PLAN 작성 → 승인까지. 세션 시작 시 사용."
user_invocable: true
---

# /hih-task

태스크를 브리핑하고, **설계 대화 → 플랜까지 포함해서** 관리한다.
핵심 원칙: **태스크만 추가 금지. 설계 대화를 거쳐 PLAN까지 같이 적어야 한다.**

## 실행 순서

### 1. 태스크 파일 읽기
- `TASK.md` — 인덱스
- `CURRENT_TASK.md` — 진행 중
- `PREPARED_TASK.md` — 예정 (P1만 상세, P2/P3 개수만)
- `FINISHED_TASK.md` — 최근 5개만

### 2. 브리핑 출력

```
## 태스크 브리핑 — {프로젝트명}

### Current ({N}개)
| # | 태스크 | 시작일 | 경과 | blocked | 상태 |
|---|--------|--------|------|---------|------|
| PM-42 | OAuth 인증 구현 | 05-14 | 25일 | — | 🟡 plan 없음 |

### Prepared — P1 ({N}개)
| # | 태스크 | depends | plan |
|---|--------|---------|------|
| PM-55 | RSS 모니터링 | — | ✅ 있음 |

P2 {N}개 / P3 {N}개

### 통계
- 완료율: {N}/{total} ({pct}%)
- 평균 소요: {N}일
- stuck (7일+ 무업데이트): {N}개
- plan 없는 current: {N}개 ⚠️

### 조치 필요
- [ ] stuck 태스크: {리스트}
- [ ] plan 없는 태스크: {리스트}
- [ ] blocked 해결 방안
- [ ] prepared → current 전환 후보
```

### 3. Obsidian vault 갱신
태스크 변경 후 자동 실행:
```bash
python3 /home/window11/project-manager/scripts/gen_vault.py
```
vault 없으면 스킵.

---

## 명령어

| 명령 | 동작 |
|------|------|
| `add "태스크명"` | **설계 대화(brainstorming) 시작** → PLAN 작성 → 승인 → PREPARED 추가 |
| `plan #번호` | 기존 태스크에 PLAN 작성/수정 |
| `start #번호` | PREPARED → CURRENT (시작일 기입) + PLAN 없으면 경고 |
| `done #번호` | CURRENT → FINISHED (완료일 기입) + DIFFICULTY 판단 |
| `block #번호 사유` | blocked 컬럼 업데이트 |
| `archive` | FINISHED → TASK_ARCHIVE/{YYYY-MM}.md |
| `review #번호` | 지시 vs 실행 갭 리뷰 (PM 전용) |

---

## 🔴 핵심: add 시 설계 대화(brainstorming) → PLAN 강제

`add "태스크명"` 입력 시 **다음 5단계**를 반드시 거친다:

### Phase 1: 프로젝트 문맥 탐색 (자동)
코드를 읽고 문맥을 파악한다:
- 프로젝트 루트의 주요 파일/디렉토리 구조 스캔
- 관련 기존 코드, 최근 커밋, 기존 태스크 의존성 확인
- 관련 PLAN 파일(`plans/*.md`)이 있으면 참조
- **이 단계에서는 코드 작성/수정 절대 금지. 오직 읽기만.**

### Phase 2: 명확화 질문 (1~2개)
문맥 파악 후, **한 번에 하나씩** 질문한다:
```
📌 설계 확인:
{태스크명}에 대해 {문맥에서 발견한 내용}을 확인했습니다.
다음이 궁금합니다:
- {질문 1}
```
- 모호한 부분, 범위 경계, 기술적 선택지에 대해 질문
- **여러 질문을 한 번에 쏟지 않는다.** 최대 2개까지만.
- 사용자가 "그냥 알아서 해"라고 하면 Phase 3로 바로 진행 (AI가 판단)

### Phase 3: 2~3개 접근법 제시 + 추천
```markdown
## 🧠 설계 제안 — {태스크명}

### 접근법 A: {이름}
- 방식: {간단 설명}
- 장점: {...}
- 단점: {...}
- 소요: {N}시간 예상

### 접근법 B: {이름}
- 방식: {간단 설명}
- 장점: {...}
- 단점: {...}
- 소요: {N}시간 예상

### 접근법 C: {이름} (선택적)
- ...

### 💡 추천: 접근법 {X}
이유: {왜 이게 최선인지 1~2줄}
```
- 각 접근법의 **트레이드오프**를 명시
- 반드시 **추천**을 표시

### Phase 4: 설계 승인
사용자가 선택:
- **"A로 해"** → 해당 접근법으로 PLAN 작성
- **"추천대로 해"** → 추천 접근법으로 PLAN 작성
- **"수정: {피드백}"** → 피드백 반영 후 다시 제안
- **"취소"** → 태스크 추가 중단

### Phase 5: PLAN 문서화 + PREPARED 추가
승인된 설계로 PLAN을 작성한다:

```markdown
## 태스크: {태스크명}
ID: {PROJECT}-{N}
우선순위: P1/P2/P3
depends: {의존 태스크 ID 또는 —}
접근법: {선택된 접근법}

### 목표 (What)
{이 태스크가 끝나면 무엇이 달라지는가? 1~2줄}

### 실행 계획 (How)
1. {단계 1 — 구체적으로}
2. {단계 2}
3. {단계 3}

### 완료 기준 (Definition of Done)
- [ ] {검증 가능한 조건 1}
- [ ] {검증 가능한 조건 2}

### 예상 리스크
- {리스크}: {대응}

### 소요 예상
- 시간: {N}시간 / 난이도: {상/중/하}
```

**PLAN을 사용자에게 보여주고 최종 승인받는다.**
"OK" → PREPARED에 추가. "수정" → 수정 후 재승인.

---

### 🚫 HARD GATE: 설계 승인 전 코드 금지
- Phase 1~4 동안 **절대 코드를 작성/수정하지 않는다.**
- 오직 프로젝트 파일 읽기, 질문, 설계 제안만 한다.
- 코드 작성은 `start` 후에만 허용.
- **PLAN 없이 태스크 추가 절대 금지.**

---

### 빠른 경로 (간단한 태스크)
태스크가 매우 단순하면 (예: 설정 파일 수정, 단순 버그 픽스):
- Phase 2~3을 생략하고 바로 Phase 5로 진행 가능
- 단, 사용자에게 "간단한 작업이라 바로 PLAN 작성합니다"라고 안내

---

## 파일 포맷

### CURRENT_TASK.md
```markdown
# Current Tasks

| # | 태스크 | 시작일 | blocked | 상태 | plan |
|---|--------|--------|---------|------|------|
| PM-42 | OAuth 인증 | 05-14 | — | 진행 중 | ✅ |
```

### PREPARED_TASK.md
```markdown
# Prepared Tasks

| # | 태스크 | 우선순위 | depends | 비고 |
|---|--------|:-------:|---------|------|
```

### PLAN 파일 (태스크당 1개)
경로: `plans/{ID}.md` (프로젝트 루트 plans/ 디렉토리)

```markdown
---
task_id: PM-42
status: current
created: 2026-06-08
approved_by: user
approach: {선택된 접근법}
---

# PM-42: OAuth 인증 구현

## 목표
Google OAuth로 YouTube API 인증. refresh token 저장까지.

## 설계 배경
{brainstorming에서 논의된 내용 요약. 왜 이 접근법을 선택했는지.}

## 실행 계획
1. google_client_secret.json 확인
2. OAuth URL 생성 (youtube.readonly scope)
3. 사용자 브라우저에서 승인
4. code → token 교환
5. google_token.json 저장
6. API 호출 테스트

## 완료 기준
- [ ] refresh_token 확보
- [ ] YouTube API subscriptions.list 호출 성공
- [ ] token.json 저장 확인

## 리스크
- PKCE 불필요 (localhost redirect 사용)
- 토큰 만료 시 자동 갱신 로직 필요

## 변경 이력
- 2026-06-08: plan 작성 (접근법: {선택된 접근법})
- 2026-06-08: step 1-6 완료. done.
```

---

## start 시 PLAN 체크

`start #번호` 실행 시:
1. `plans/{ID}.md` 존재 확인
2. **PLAN 없으면 경고**: "⚠️ PLAN이 없습니다. plan 먼저 작성할까요?"
3. PLAN 있으면 → CURRENT 이동 + 시작일 기입

## done 시 자동 판단

1. PLAN의 완료 기준이 전부 충족됐는지 체크
2. 미충족 항목 있으면 경고: "⚠️ 완료 기준 {N}개 미충족. 그래도 done?"
3. 시작~완료 기간이 길거나 blocked 이력 있으면 DIFFICULTY.md 기록 제안

## review 시 (PM 전용)

`review #번호` 실행 시:
1. PLAN의 "실행 계획" 단계별로 실제 수행 내역 매칭
2. 각 단계별로 ✅ 이행 / ⚠️ 부분 / ❌ 누락 / 🔄 변경 표시
3. 변경·누락 사유 분석
4. 사용자 보고

```
## 지시 vs 실행 리뷰 — {ID}
- (1) {계획}: ✅/⚠️/❌ — {실제}
- (2) {계획}: ✅/⚠️/❌ — {실제}
결론: ✅ / ⚠️ N건 / ❌ 재지시
```

## 아카이브 규칙
- FINISHED_TASK.md의 항목이 **100개 이상** → 아카이브 실행
- **월이 이월**되면 → 이전 달 항목 아카이브
- 아카이브 경로: `TASK_ARCHIVE/{YYYY-MM}.md`
- PLAN 파일(`plans/{ID}.md`)은 아카이브해도 유지 (참조용)

## 주의
- PM 세션: 읽기만. 수정 지시는 tmux로 각 세션에 전달.
- 개별 프로젝트 세션: 직접 수정 가능.
- 세션 종료 시 태스크 정리는 `/hih-task-clear` 사용.
- **태스크만 추가하고 방치하면 안 됨. 반드시 설계 대화 → PLAN 승인까지.**
