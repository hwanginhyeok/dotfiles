---
name: hih-clear
description: 세션 종료 루틴. hih-task-clear + hih-memory + hih-git 순차 실행 후 /clear. 세션 요약을 ~/.hermes/session_reports/daily/에 MD+JSON으로 저장.
user_invocable: true
---

# /hih-clear

세션 마무리 오케스트레이터.

## 실행 순서

### 1. /hih-task-clear
태스크 정리 (완료 이동 + audit + TASK.md 인덱스 재계산)

### 2. /hih-memory
메모리 정리 (stale 체크 + 저장 + GDrive 동기화)

### 3. /hih-git
전체 프로젝트 git 커밋 + push

### 4. DIFFICULTY 기록 (선택)

이번 세션에서 2시간+ 삽질이 있었으면 `DIFFICULTY.md`에 추가.

**일반 문제해결 포맷:**
```markdown
## D-NNN: 제목
- 날짜: YYYY-MM-DD
- 상황: ...
- 문제: ...
- 삽질: ...
- 해결: ...
- 노하우: ...
```

**테스트 작업 포맷:**
```markdown
## D-NNN: [테스트] 제목
- 날짜: YYYY-MM-DD
### 테스트 대상
- 파일/기능: ...
- 테스트 방법: ...
### 테스트 결과
- 상태: 성공/실패/부분 성공
- 발견된 이슈: ...
- 예상 vs 실제: ...
### 상황
- ...
### 문제
- ...
### 삽질
- ...
### 해결
- ...
### 노하우
- ...
```

### 5. TASK 브리핑 정리

전달용 파일 정리:
```bash
rm -f /tmp/*_task_*.md
```

보관용 파일 유지 (히스토리):
```bash
ls -la ~/project-manager/content_queue/task_briefings/*
```

### 6. 세션 요약 출력 + 저장 (향상된 형식)

```
## 세션 요약

### 🎯 지시-결과물 매핑
- 지시: {사용자 지시}
- 결과물: {생성된 파일/결과}
- 시간: {소요 시간}
- 스킬: {사용된 스킬}

### 📋 작업 내용
- 완료: {태스크 목록}
- 진행 중: {태스크 목록}
- 신규: {추가된 태스크}
- 잔여 이슈 (사용자 결정): {정체/블록 등}
- 커밋: N개

### 🎯 다음 세션 TODO
- {이어갈 작업}

### 💡 메모리 업데이트
- 스킬 구성 변경: {있음/없음}
- 모델 버전 변경: {있음/없음}
- config 변경: {있음/없음}
```

**세션 요약 저장:**

```bash
# 보고 디렉토리 생성
REPORT_DIR="$HOME/.hermes/session_reports/daily"
mkdir -p "$REPORT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 마크다운 저장
SUMMARY_MD="$REPORT_DIR/summary_${TIMESTAMP}.md"
cat > "$SUMMARY_MD" << EOF
# 세션 요약 ($TIMESTAMP)
- 완료: ${TASKS_COMPLETED:-없음}
- 진행 중: ${TASKS_IN_PROGRESS:-없음}
- 신규: ${TASKS_NEW:-없음}
- 잔여 이슈: ${ISSUES_BLOCKED:-없음}
- 커밋: ${GIT_COMMIT_COUNT:-0}개
EOF

# JSON 저장
SUMMARY_JSON="$REPORT_DIR/report_${TIMESTAMP}.json"
cat > "$SUMMARY_JSON" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "session": "${SESSION_NAME:-unknown}",
  "completed_tasks": [],
  "in_progress_tasks": [],
  "new_tasks": [],
  "blocked_issues": [],
  "git_commit_count": 0,
  "git_changes": {}
}
EOF

echo "✅ 보고 저장됨: $SUMMARY_MD"
echo "✅ 보고 저장됨: $SUMMARY_JSON"
```

### 7. handoff.md 생성 (작업 있었을 때만)

작업 없는 짧은 세션은 스킵.
```markdown
# Handoff — {날짜}
## 작업 중이던 것
## 컨텍스트 (이번 세션 결정 사항)
## 다음 세션 첫 액션
```

### 8. /clear

## 주의

- git push는 /hih-git이 처리
- 순서 엄수: 1→2→3→4→5→6→7→8
- 작업 없는 짧은 세션: 1, 2, 3, 5, 7, 8만 실행 (4, 6 스킵)
