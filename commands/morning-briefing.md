---
name: morning-briefing
description: 야간작업 결과 + 각 프로젝트 상태 + 오늘 할 일 브리핑
user-invocable: true
---

# 아침 브리핑

## 수집 항목

### 1. 야간작업 결과
- 각 프로젝트의 `logs/overnight_progress.log` 확인
- `tonight_prompt_done.txt` 존재 여부 확인
- `docs/프로젝트/overnight_brief_*.md` 최신 파일 읽기

### 2. 프로젝트 현황
- `python3 ~/project-manager/pm.py status` 실행
- 각 프로젝트의 미커밋 변경사항
- 최근 24시간 커밋 목록

### 3. 리포트 데이터
- `~/.pm_logs/daily_latest.json` 읽기
- `~/.pm_logs/weekly_latest.json` 읽기 (월요일인 경우)

### 4. 오늘 할 일
- 각 프로젝트 TASK.md에서 진행중/대기중 항목 파싱
- 우선순위별 정렬

## 출력 형식

```markdown
# 아침 브리핑 — YYYY-MM-DD

## 야간작업 결과
(있으면 표시)

## 프로젝트 현황 요약
| 프로젝트 | 브랜치 | 미커밋 | 최근커밋 | 태스크 |
|---------|--------|--------|---------|--------|

## 오늘 할 일
### 높은 우선순위
- [ ] ...
### 보통 우선순위
- [ ] ...
```

## 노션 갱신
- 브리핑 결과를 노션 "프로젝트 브리핑" 페이지(ID: 3223eb8af0d18136847bf942c32b5dc6)에 갱신
