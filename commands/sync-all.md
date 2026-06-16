---
name: sync-all
description: 모든 프로젝트 git fetch → pull → push 동기화
user-invocable: true
---

# 전체 프로젝트 Git 동기화

## 대상 프로젝트
- `~/stock`
- `~/insung_blog`
- `~/my-politics-stats`
- `~/physical_AI_rs500`
- `~/physical_AI_Engiuniverse`
- `~/포트폴리오`
- `~/project-manager`

## 실행 절차

각 프로젝트에 대해 순차 실행:

1. `git fetch --all` — 원격 정보 갱신
2. `git status` — 로컬 변경사항 확인
3. 변경사항이 없으면 `git pull --rebase` — 원격 변경 가져오기
4. 커밋된 로컬 변경이 있으면 `git push` — 푸시
5. 커밋되지 않은 변경이 있으면 스킵 (경고 표시)

## 결과 출력 형식
```
| 프로젝트 | 상태 | 동작 | 비고 |
|---------|------|------|------|
| stock | clean | pull+push | 2 commits pushed |
| insung_blog | dirty | skip | 3 uncommitted files |
```

## 주의사항
- merge conflict 발생 시 해당 프로젝트 스킵하고 알림
- force push 절대 금지
