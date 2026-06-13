---
name: hih-memory
description: "세션 메모리 정리 + GDrive 동기화. stale check + 학습 저장 + rclone copy (안전 모드). 인자: --sync (기본) / --no-sync / --drift-only. hih-memory-sync의 실제 구현."
user_invocable: true
---

# /hih-memory

세션 메모리 정리 + GDrive 동기화를 수행합니다.
`/hih-memory-sync`는 이 스킬의 `--sync` 모드를 호출하는 래퍼입니다.

## 인자

| 인자 | 동작 |
|------|------|
| (기본) | 1~4단계 모두 수행 (stale check + 학습 저장 + GDrive sync + drift 보고) |
| `--no-sync` | 1~3단계만 수행 (GDrive 동기화 생략) |
| `--drift-only` | GDrive drift 측정 + hygiene check만 수행 (1,2,3단계 생략) |

## 실행 순서

### 1. 중복 확인 (생성 전 필수)
새 메모리 파일 추가 전 반드시 중복 확인:
```bash
ls ~/.claude/projects/$(pwd|sed 's|/|-|g')/memory/project/ | grep -i {topic}
```
- 발견 → 기존 파일 업데이트 (새로 만들지 않음)
- 파일명에 `_vN`, `_YYYYMMDD` → 이름 정리 후 업데이트

### 2. Stale 파일 점검
```bash
find ~/.claude/projects/$(pwd|sed 's|/|-|g')/memory/project -name "*.md" -mtime +3
```
- 활성 프로젝트 (projects.yaml focus=true): 3일+ → 업데이트 또는 보관
- 보류 프로젝트: 30일+ → 보관
- 보관 대상 → `memory/archive/YYYY-MM/` 로 이동

### 3. 이번 세션 학습 저장
기억할 가치가 있는 것만 저장 (없으면 생략):
- 사용자 피드백/선호 → `feedback/feedback_*.md`
- 프로젝트 상태 변화 → `project/project_*.md`
- 외부 시스템 참조 → `reference/reference_*.md`
- MEMORY.md 인덱스 업데이트 (200줄 이하 유지)

### 4. GDrive 동기화 (--no-sync 시 생략)

**정책: rclone copy만 사용 (sync 금지)**
- `rclone copy --update` 는 additive — 삭제를 전파하지 않아 안전
- `rclone sync` 는 원격 파일 삭제 위험이 있어 사용 금지
- Home PC = primary. 노트북은 세션 시작 시 GDrive→local 다운로드
- 충돌 시 `--update` 기준 최신 mtime 우선

#### 4a. Drift 측정 (동기화 전)
```bash
rclone check ~/.claude/projects/-home-window11-project-manager/memory/ gdrive:.claude-memory/pm/ --exclude ".git/**" 2>&1 | grep -E "missing|differences|matching"
```

#### 4b. 업로드 (rclone copy — additive only)
```bash
rclone copy ~/.claude/projects/-home-window11-project-manager/memory/ gdrive:.claude-memory/pm/ --update --exclude ".git/**"
```

#### 4c. Hygiene — 30일+ 미수정 파일
```bash
find ~/.claude/projects/-home-window11-project-manager/memory -name '*.md' -mtime +30 -printf '%TY-%Tm-%Td %p\n' | sort
```

#### 4d. 인덱스 정합성 — MEMORY.md vs 실제 파일 수
```bash
echo "MEMORY.md index: $(grep -cE '^\- \[' ~/.claude/projects/-home-window11-project-manager/memory/MEMORY.md) / actual: $(find ~/.claude/projects/-home-window11-project-manager/memory -name '*.md' | wc -l)"
```

#### 4e. 결과 보고
- 동기화 전후 drift 변화
- rclone copy 결과
- hygiene 경고 (stale 파일 목록)

## 관련
- 래퍼 스킬: `/hih-memory-sync` → 이 스킬의 `--sync` 모드 호출
- 세션 종료 전체 정리: `/hih-clear`
- 동기화 경로/방법: memory `reference_memory_sync.md`
