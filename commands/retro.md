---
name: retro
description: 주간/일간 엔지니어링 회고. 커밋 패턴, 프로젝트별 진행도 분석.
user-invocable: true
---

# 엔지니어링 회고 (gstack /retro 기반)

## 사용법
- `/retro` — 최근 7일 (기본)
- `/retro 24h` — 오늘
- `/retro 14d` — 2주
- `/retro global` — 전체 7개 프로젝트 횡단

## 실행 절차

### Step 1: 데이터 수집
각 프로젝트(~/stock, ~/insung_blog, ~/my-politics-stats, ~/physical_AI_rs500, ~/physical_AI_Engiuniverse, ~/포트폴리오, ~/project-manager)에서:

```bash
git log --since="7 days ago" --format="%H|%ai|%an|%s" --shortstat
```

### Step 2: 메트릭 계산
- 총 커밋 수, 추가/삭제 줄 수
- 커밋 타입 분류 (feat/fix/refactor/test/chore/docs)
- 테스트 비율 (test 파일 변경 / 전체)

### Step 3: 프로젝트별 요약 테이블

### Step 4: 시간 분포 히스토그램

### Step 5: Hotspot (가장 많이 변경된 파일 10개)

### Step 6: Ship of the Week + 연속 커밋 일수

### Step 7: TASK.md 크로스 프로젝트 진행도
각 프로젝트의 TASK.md에서 완료/진행중/대기 항목 수 집계

## 노션 연동
회고 결과를 노션 "프로젝트 브리핑" 페이지에 갱신 (Notion MCP 사용)
