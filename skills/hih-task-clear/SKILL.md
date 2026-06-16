---
name: hih-task-clear
description: Session task cleanup only. Move completed items + task_audit + recompute the TASK.md index. The TASK part of hih-clear.
user_invocable: true
---

# /hih-task-clear

Cleans up only the task files.

## Execution order

### 1. Reflect completed/new tasks
- Read `CURRENT_TASK.md`
- Tasks completed this session → move to `FINISHED_TASK.md` (record completion date)
- New TODO → check for ID collision before adding to `PREPARED_TASK.md`:
  ```bash
  grep -h "^| {NEW_ID} " CURRENT_TASK.md PREPARED_TASK.md FINISHED_TASK.md TASK_ARCHIVE/*.md 2>/dev/null
  ```
  Add only if there are 0 matches. If an existing ID is found, use max+1.

### 2. Update depends when a parent task is absorbed/merged
If absorption/merge/discard occurred this session:
- Absorbed/merged → `depends: X` → `depends: Y`
- Discarded (line removed) → `depends: —`
- Moved to archive → `depends: —` or `(archive YYYY-MM)`

### 3. Run task_audit
```bash
python3 /home/window11/project-manager/scripts/task_audit.py --project {프로젝트명} --text
```

Can be handled automatically:
- Zombie lines (`~~strikethrough~~` + completed/cancelled marking) → remove or move to FINISHED
- Duplicate IDs → reassign max+1 on the PREPARED side
- Orphan dependencies → search TASK_ARCHIVE, then set to `—`

Requires user decision (report only):
- CURRENT stalled 21+ days → request a discard/restart decision
- blocked 14+ days → confirm whether the blocker can be resolved
- P1 inflation (70%+) → propose P2/P3 demotion candidates

### 4. Recompute the TASK.md index
Verify the actual counts:
```bash
echo "CURRENT: $(grep -c "^| " CURRENT_TASK.md)개"
echo "PREPARED: $(grep -c "^| " PREPARED_TASK.md)개"
```
Update the TASK.md summary line with the actual counts.

### 5. Re-verify with task_audit
Re-run after cleanup → confirm 0 issues. Include any remaining issues in the hih-clear session summary.
