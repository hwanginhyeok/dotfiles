---
name: hih-task
description: 프로젝트 태스크 브리핑 + 인터랙티브 관리 (done/start/add/block/archive). 세션 시작 시 사용.
user_invocable: true
---

# /hih-task

태스크를 브리핑하고 인터랙티브하게 관리한다.
태스크 정리(audit)는 `/hih-task-clear`, 메모리는 `/hih-memory`, git은 `/hih-git`.

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
| # | 태스크 | 시작일 | blocked |
...

### Prepared — P1 ({N}개)
| # | 태스크 | depends |
...
P2 {N}개 / P3 {N}개

### 조치 필요
- [ ] blocked 해결 방안
- [ ] prepared → current 전환 후보
- [ ] 아카이브 대상 (100개+)
```

### 3. Obsidian vault 갱신
태스크 변경 후 자동 실행:
```bash
python3 /home/window11/project-manager/scripts/gen_vault.py
```
vault 없으면 스킵.

### 4. 인터랙티브 관리
브리핑 후 사용자 요청에 따라:

| 명령 | 동작 |
|------|------|
| `done #번호` | CURRENT → FINISHED (완료일 기입) + vault 갱신 |
| `start #번호` | PREPARED → CURRENT (시작일 기입) + vault 갱신 |
| `add 태스크명` | PREPARED 추가 (ID 충돌 검사 후) + vault 갱신 |
| `block #번호 사유` | blocked 컬럼 업데이트 + vault 갱신 |
| `archive` | FINISHED → TASK_ARCHIVE/{YYYY-MM}.md |

**done 시 자동 판단**: 시작~완료 기간이 길거나 blocked 이력 있으면 DIFFICULTY.md 기록 제안.

**add 시 ID 충돌 검사**:
```bash
grep -h "^| {NEW_ID} " CURRENT_TASK.md PREPARED_TASK.md FINISHED_TASK.md TASK_ARCHIVE/*.md 2>/dev/null
```

## 파일 포맷

```markdown
# CURRENT_TASK.md
| # | 태스크 | 시작일 | blocked | 비고 |

# PREPARED_TASK.md
| # | 태스크 | 우선순위 | depends | 비고 |

# FINISHED_TASK.md
| # | 태스크 | 완료일 | 비고 |
```

아카이브: FINISHED 100개+ 또는 월 이월 시 → `TASK_ARCHIVE/{YYYY-MM}.md`

## 주의
- PM 세션: 읽기만. 수정 지시는 tmux로 각 세션에 전달.
- 개별 프로젝트 세션: 직접 수정 가능.
- 세션 종료 시 태스크 정리는 `/hih-task-clear` 사용.
