---
name: hih-cron
description: Checks cron + auto-invoked when adding/modifying cron. If it can be merged into an existing cron, merge it; otherwise add it. Prevents conflicts and duplication.
user_invocable: true
---

# /hih-cron

Invoke this when adding/modifying a cron job. Don't blindly add a new line — first **review whether it can be merged into an existing cron**, then decide.

Detailed cron schedule SSOT: `~/project-manager/global-rules/cron.md`

## Behavior on execution

### 1. Check current cron snapshot
```bash
crontab -l
```

### 2. Classify the job to add (required output)
```
## Add/modify request
- Job: <script path + args>
- Time: <cron expression>
- Purpose: <why it's needed>
- Log location: <log path>
```

### 3. Search for merge candidates (required output)
```
## Merge review
- Same-time entries: <matching lines in crontab>
- Same directory/script family: <other cron in the same project>
- Can it be merged? Y / N
- Merge method:
  - (A) Add a mode argument to one script (e.g., briefing.sh morning|evening)
  - (B) If same time, chain with && or ;
  - (C) Wrap into a new wrapper script
  - (D) Cannot merge → add as a new line
```

### 4. Conflict check (required output)
```
## Conflict check
- Concurrent execution load: separate if heavy jobs overlap at the same time
- Dependencies: if A needs B's result, stagger the times
- Lock file/DB access conflicts: serialize jobs that access the same resource
```

### 5. Recommended decision (required output)
```
## Decision
- Recommendation: merge / add / separate
- Reason: <why>
- Cron expression to apply:
  <line as-is>
- Registration method:
  User adds it directly via `crontab -e` (rule: cron registration is done by the user directly)
- Verification: check the log at the next run time after registration
```

## Rules

1. **No unconditional adding** — do not proceed without going through the merge review
2. **User registers directly** — use only `crontab -e`. Scripts must not auto-register (global rule cron.md)
3. **Review 30-day+ log auto-deletion** — review the log rotation rule at the same time when adding a new cron
4. **Avoid time conflicts** — if too many jobs cluster at the top of the hour (:00), spread them to :05/:10/:15
5. **When modifying an existing cron** — report the before/after diff before proceeding

## Merge pattern examples

### Pattern A: mode argument
```
# Before (2 lines):
0 6 * * * /path/morning_brief.sh
0 22 * * * /path/evening_brief.sh

# After (1 script + 2 cron lines, but the script's internal logic is unified):
0 6 * * * /path/brief.sh morning
0 22 * * * /path/brief.sh evening
```

### Pattern B: same-time chaining
```
# Before (2 lines, same 06:00):
0 6 * * * /path/sync_a.sh
0 6 * * * /path/sync_b.sh

# After (1 line):
0 6 * * * /path/sync_a.sh && /path/sync_b.sh
```

### Pattern C: wrap together
```
# Before (3 lines, same family):
0 7 * * * /path/daily_part1.sh
0 7 * * * /path/daily_part2.sh
0 7 * * * /path/daily_part3.sh

# After (1 line):
0 7 * * * /path/daily_pipeline.sh   # calls part1/2/3 sequentially internally
```

## Sources
- Global rule: `~/project-manager/global-rules/cron.md` (full schedule SSOT)
- "cron registration/changes are done by the user directly" principle (cron.md)
