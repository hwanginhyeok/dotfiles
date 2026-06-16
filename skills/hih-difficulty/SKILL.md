---
name: hih-difficulty
description: Records and manages difficult problems encountered in projects + their solution know-how. Briefs DIFFICULTY.md and adds entries.
user_invocable: true
---

# DIFFICULTY.md Management

Records difficult problems, dead-ends, and solution processes encountered while working on projects.
A know-how repository for quickly solving the same problem when it comes up again in the future.

## File Location

Project root: `DIFFICULTY.md` (on the same level as CLAUDE.md, TASK.md)

## Format

```markdown
# Difficulties & Know-how

## D-001: {Problem Title}
- **Date**: 2026-04-07
- **Situation**: In what situation it occurred
- **Issue**: Specifically what didn't work
- **Dead-ends**: Things that were tried but didn't work
- **Solution**: The final solution method
- **Alternatives**: Other methods that were considered but not chosen + reasons
- **Know-how**: What to do immediately when hitting the same problem next time
- **Retrospective**: What would have been better / doing it this way from the start would have saved time / fundamental points to improve
- **Related files**: The relevant code/config paths

## D-002: ...
```

## When to Record

- A problem that took more than 2 hours of dead-ends
- A problem that was hard to find even by searching
- Environment/config peculiarities (WSL, Tailscale, Playwright, etc.)
- Library/API bugs or undocumented behavior
- Performance problem-solving processes

## Archiving

When rolling over to the next month, move it to TASK_ARCHIVE/{YYYY-MM}.md together as a Difficulty section.
Remove that month's entries from DIFFICULTY.md.

```markdown
# Task Archive — April 2026

## Finished Tasks
| # | Task | Completed | Notes |
...

## Difficulties
### D-001: ...
### D-002: ...
```

## On Session End (/session-clear)

If a difficult problem was solved in the session, automatically add it to DIFFICULTY.md.
