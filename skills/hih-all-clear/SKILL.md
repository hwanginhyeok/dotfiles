---
name: hih-all-clear
description: Batch cleanup of all project sessions. Assess each session's state → /hih-clear → /clear. Batch shutdown routine for the PM orchestrator.
user_invocable: true
---

# /hih-all-clear

Clean up and shut down **all project tmux sessions** at once from the PM.

## When to use
- Cleaning up all sessions together at the end of a day's work
- Handing off all projects cleanly before a PC restart
- Batch reset just before a long-running session exhausts its context

## Execution

```bash
python3 /home/window11/project-manager/scripts/hih_all_clear.py
```

The script automatically:
1. Identifies the list of running tmux sessions (excluding PM, hermes)
2. Determines idle/busy → skips busy sessions
3. Sends `/hih-clear` in parallel to idle sessions
4. Polls for completion (30-second interval, up to 15 minutes)
5. Reports the aggregate results

## PM session after completion

The PM cannot /clear itself. After the script completes, do it directly:
```
/hih-clear
/clear
```

## Notes
- Busy sessions (running a tool) are skipped automatically — handle them manually and separately
- .env and credentials are protected by each session's /hih-clear
- git push is done separately via hih-git (hih-clear does not push)
