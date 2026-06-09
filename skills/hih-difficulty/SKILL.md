---
name: hih-difficulty
description: 프로젝트에서 겪은 어려운 문제 + 해결 노하우 기록 관리. DIFFICULTY.md 브리핑 및 항목 추가.
user_invocable: true
---

# DIFFICULTY.md 관리

프로젝트를 진행하면서 겪은 어려운 문제, 삽질, 해결 과정을 기록한다.
미래에 같은 문제를 만났을 때 빠르게 해결하기 위한 노하우 저장소.

## 파일 위치

프로젝트 루트: `DIFFICULTY.md` (CLAUDE.md, TASK.md와 동일 선상)

## 포맷

```markdown
# Difficulties & Know-how

## D-001: {문제 제목}
- **날짜**: 2026-04-07
- **상황**: 어떤 상황에서 발생했는지
- **이슈**: 구체적으로 뭐가 안 됐는지
- **삽질**: 시도했지만 안 된 것들
- **해결**: 최종 해결 방법
- **대안**: 검토했지만 선택하지 않은 다른 방법들 + 이유
- **노하우**: 다음에 같은 문제 만나면 바로 할 것
- **회고**: 이랬으면 좋았겠다 / 처음부터 이렇게 했으면 시간 절약 / 근본적으로 개선할 점
- **관련 파일**: 해당 코드/설정 경로

## D-002: ...
```

## 기록 시점

- 2시간 이상 삽질한 문제
- 검색해도 잘 안 나온 문제
- 환경/설정 특이 이슈 (WSL, Tailscale, Playwright 등)
- 라이브러리/API 버그나 undocumented behavior
- 성능 문제 해결 과정

## 아카이브

월 이월 시 TASK_ARCHIVE/{YYYY-MM}.md에 Difficulty 섹션으로 함께 이동.
DIFFICULTY.md에서 해당 월 항목 제거.

```markdown
# Task Archive — 2026년 04월

## Finished Tasks
| # | 태스크 | 완료일 | 비고 |
...

## Difficulties
### D-001: ...
### D-002: ...
```

## 세션 종료 시 (/session-clear)

세션에서 어려운 문제를 해결했으면 DIFFICULTY.md에 자동 추가.
