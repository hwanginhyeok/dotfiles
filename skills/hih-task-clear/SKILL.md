---
name: hih-task-clear
description: 세션 태스크 정리 전용. 완료 이동 + task_audit + TASK.md 인덱스 재계산. hih-clear의 TASK 파트.
user_invocable: true
---

# /hih-task-clear

태스크 파일만 정리한다.

## 실행 순서

### 1. 완료/신규 태스크 반영
- `CURRENT_TASK.md` 읽기
- 이번 세션 완료 태스크 → `FINISHED_TASK.md`로 이동 (완료일 기입)
- 새 TODO → `PREPARED_TASK.md` 추가 전 ID 충돌 검사:
  ```bash
  grep -h "^| {NEW_ID} " CURRENT_TASK.md PREPARED_TASK.md FINISHED_TASK.md TASK_ARCHIVE/*.md 2>/dev/null
  ```
  0건이어야 추가. 기존 ID 발견 시 max+1로.

### 2. 부모 태스크 흡수/병합 시 depends 갱신
이번 세션에서 흡수/병합/폐기 발생 시:
- 흡수/병합 → `depends: X` → `depends: Y`
- 폐기(라인 삭제) → `depends: —`
- archive 이동 → `depends: —` 또는 `(archive YYYY-MM)`

### 3. task_audit 실행
```bash
python3 /home/window11/project-manager/scripts/task_audit.py --project {프로젝트명} --text
```

자동 처리 가능:
- 좀비 라인 (`~~취소선~~` + 완료/취소 마킹) → 제거 또는 FINISHED 이동
- 중복 ID → PREPARED 측 max+1 재부여
- 고아 의존성 → TASK_ARCHIVE 검색 후 `—` 처리

사용자 결정 필요 (보고만):
- CURRENT 21일+ 정체 → 폐기/재시작 결정 요청
- blocked 14일+ → 블로커 해소 가능 여부 확인
- P1 인플레이션 (70%+) → P2/P3 강등 후보 제시

### 4. TASK.md 인덱스 재계산
실제 카운트 확인:
```bash
echo "CURRENT: $(grep -c "^| " CURRENT_TASK.md)개"
echo "PREPARED: $(grep -c "^| " PREPARED_TASK.md)개"
```
TASK.md 요약 라인을 실제 수로 갱신.

### 5. task_audit 재검증
정리 후 재실행 → 이슈 0건 확인. 남은 이슈는 hih-clear 세션 요약에 포함.
