---
name: hih-memory
description: 세션 메모리 정리 전용. stale 체크 + 세션 학습 저장 + GDrive 동기화. hih-clear의 MEMORY 파트.
user_invocable: true
---

# /hih-memory

메모리만 정리한다.

## 실행 순서

### 1. 신규 작성 전 grep 강제
메모리 파일 추가 전 반드시 중복 확인:
```bash
ls ~/.claude/projects/$(pwd|sed 's|/|-|g')/memory/project/ | grep -i {토픽}
```
- 발견 시 → 기존 파일 갱신 (신규 생성 X)
- 파일명에 `_vN`, `_YYYYMMDD` 있으면 rename 후 갱신

### 2. stale 파일 점검
```bash
find ~/.claude/projects/$(pwd|sed 's|/|-|g')/memory/project -name "*.md" -mtime +3
```
- 활성 프로젝트 (projects.yaml focus=true): 3일+ → 갱신 또는 archive
- 보류 프로젝트: 30일+ → archive
- archive 대상은 `memory/archive/YYYY-MM/`으로 이동

### 3. 이번 세션 학습 저장
기억할 가치 있는 것만 저장 (없으면 스킵):
- 사용자 피드백/선호 → `feedback/feedback_*.md`
- 프로젝트 상태 변화 → `project/project_*.md`
- 외부 시스템 참조 → `reference/reference_*.md`
- MEMORY.md 인덱스 갱신 (200줄 미만 유지)

### 4. GDrive 동기화
```bash
rclone sync ~/.claude/projects/-home-window11-project-manager/memory/ gdrive:.claude-memory/pm/ --exclude ".git/**"
```
