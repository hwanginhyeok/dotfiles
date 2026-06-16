---
name: hih-clear
description: Session shutdown routine. Runs hih-task-clear + hih-memory + hih-git sequentially, then /clear. Saves the session summary to ~/.hermes/session_reports/daily/ as MD+JSON. Also logs decisions to Decision Log.
user_invocable: true
---

# /hih-clear

Session wrap-up orchestrator.

## Execution order

### 1. /hih-task-clear
Task cleanup (move completed items + audit + recompute TASK.md index)

### 2. /hih-memory
Memory cleanup (stale check + save + GDrive sync)

### 3. /hih-git
Commit + push git for all projects

### 4. Decision Log 업데이트

이번 세션에서 내린 주요 의사결정이 있으면 Decision Log에 기록.

```bash
DECISIONS_FILE="$HOME/project-manager/decision-log/DECISIONS.md"
```

**감지 대상:**
- 기술/도구 선택을 결정한 경우
- 작업 방식이나 프로세스를 정한 경우
- 사용자 피드백으로 방향을 바꾼 경우
- 우선순위를 조정한 경우
- 아키텍처/구조를 결정한 경우

**형식:** /hih-decide 스킬의 엔트리 형식을 따름.

**의사결정이 없으면 이 단계를 건너뜀.**

### 5. DIFFICULTY logging (optional)

If this session involved 2+ hours of grinding, add an entry to `DIFFICULTY.md`.

**General problem-solving format:**
```markdown
## D-NNN: Title
- Date: YYYY-MM-DD
- Situation: ...
- Problem: ...
- Grind: ...
- Solution: ...
- Know-how: ...
```

**Test work format:**
```markdown
## D-NNN: [Test] Title
- Date: YYYY-MM-DD
### Test target
- File/feature: ...
- Test method: ...
### Test result
- Status: success/failure/partial success
- Issues found: ...
- Expected vs actual: ...
### Situation
- ...
### Problem
- ...
### Grind
- ...
### Solution
- ...
### Know-how: ...
```

### 6. TASK briefing cleanup

Clean up delivery files:
```bash
rm -f /tmp/*_task_*.md
```

Keep archive files (history):
```bash
ls -la ~/project-manager/content_queue/task_briefings/*
```

### 7. Print + save session summary (enhanced format)

```
## Session summary

### Instruction-to-deliverable mapping
- Instruction: {user instruction}
- Deliverable: {file/result produced}
- Time: {time spent}
- Skill: {skill used}

### Work content
- Completed: {task list}
- In progress: {task list}
- New: {tasks added}
- Remaining issues (user decision): {stalled/blocked, etc.}
- Commits: N

### Next session TODO
- {work to continue}

### Memory updates
- Skill config change: {yes/no}
- Model version change: {yes/no}
- config change: {yes/no}

### Decisions this session
- {list of DL-NNN entries added, if any}
```

**Save the session summary:**

```bash
# Create report directory
REPORT_DIR="$HOME/.hermes/session_reports/daily"
mkdir -p "$REPORT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Save markdown
SUMMARY_MD="$REPORT_DIR/summary_${TIMESTAMP}.md"
cat > "$SUMMARY_MD" << EOF
# Session summary ($TIMESTAMP)
- Completed: ${TASKS_COMPLETED:-none}
- In progress: ${TASKS_IN_PROGRESS:-none}
- New: ${TASKS_NEW:-none}
- Remaining issues: ${ISSUES_BLOCKED:-none}
- Commits: ${GIT_COMMIT_COUNT:-0}
- Decisions logged: ${DECISIONS_LOGGED:-0}
EOF

# Save JSON
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
  "git_changes": {},
  "decisions_logged": 0
}
EOF

echo "Report saved: $SUMMARY_MD"
echo "Report saved: $SUMMARY_JSON"
```

### 8. Create handoff.md (only when there was work)

Skip for short sessions with no work.
```markdown
# Handoff — {date}
## What was being worked on
## Context (decisions made this session)
## First action for next session
```

### 9. /clear

## Notes

- git push is handled by /hih-git
- Strict order: 1→2→3→4→5→6→7→8→9
- Short sessions with no work: run only 1, 2, 3, 4(check), 6, 8, 9 (skip 5, 7)
