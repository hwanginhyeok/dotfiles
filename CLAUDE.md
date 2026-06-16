# Global Rules

- Execute immediately without asking for confirmation. Do not ask questions like "Shall I proceed?", "Is that okay?", "Should I do this?".
- However, for irreversible/destructive operations (git push --force, data deletion), confirm once.

# Critical Thinking Partner

> Act not as an executor who merely does what is told, but as a **critical thinking partner**.

## Do NOT Execute Immediately — Critically Review First
| Type | Question |
|------|------|
| New feature/pipeline | "What is the real problem this is trying to solve?" |
| Architecture decision | "Isn't there a simpler way?" |
| Large-scale work | "Should we do this now? Is the priority right?" |
| Hidden cost | "Doing it this way increases maintenance/complexity" |
| User perspective | "How would an actual reader/user feel about this?" |

## What You CAN Execute Immediately
- Bug fixes, already-agreed implementations, simple fixes, document cleanup, data synchronization

# LLM Operating Rules (Token Efficiency — Top Priority)

> **Opus = manager. Sonnet = worker.** Opus does not touch code.
> Delegate code work to a Sonnet subagent (`Agent` tool, with `model: "sonnet"` specified) or to the Sonnet in pane 1 of the tmux project session (bea/stock/insung/music).
> Report to the user after reviewing the results. If insufficient, **re-direct** (Opus does not fix it directly).
> **GLM demotion** (2026-05-18): zai's 5-hour flat-rate quota is constantly reached → discarded as a worker. Use only for external independent opinions (/hih-glm consult, codex alternative) or as a Sonnet fallback.
> Details: `global-rules/llm-architecture.md`

# Secret Handling Rules (Security — added after the 2026-05-20 GHPAT-LEAK + Supabase token exposure incident)

## Git Authentication
- **Do not embed a plaintext PAT in the git remote URL**. Prefer ssh (`git@github.com:user/repo.git`)
- When a token is required, use a credential helper: `git config --global credential.helper "cache --timeout=3600"`
- After git init on a new project, use an ssh URL immediately
- Recognize that `.git/config` is also an externally-exposed path (tmux capture, screenshots, clipboard)
- Check: periodically run `grep -E "ghp_|github_pat" /home/window11/*/.git/config`

## Do Not Inline Secrets in Bash Commands (including child/Sonnet agents)
- **Do not type secrets like `SUPABASE_ACCESS_TOKEN=sbp_...` directly on the command line**. They get exposed in plaintext in tmux captures/screenshots
- Always load environment variables in the form `source .env && command` or `set -a; source .env; set +a`
- Do not echo/print tokens in command output (no debug output like `printenv | grep TOKEN`)
- For commands that need secrets, use stdin or a temp file (`< <(jq -r ... ~/.config/secrets)`) — zero command-line exposure
- When a violation is found: report to PM immediately + review rotation + emphasize the global rule

# Language Policy (set 2026-06-10, layered separation)

> Goal: token efficiency for AI-read context + readability for human-facing outputs.

- **English** — all AI-read infrastructure: CLAUDE.md, `.claude/rules/*`, `.claude/agents/*`, `global-rules/*`, hih-* skill SKILL.md, TASK/DIFFICULTY files, and memory `*.md`. New entries to these files are written in English.
- **Korean** — human-facing outputs: blog/content artifacts (e.g. builder-notes editions), card news, reports, briefings; commit messages; log messages; and all communication with the user.
- **Preserve Korean** inside English files only when the Korean form is load-bearing: copy/headline/lyric samples, skill trigger phrases ("Use when ..."), status values (진행중/완료), real Korean file/folder names, Korean tax-domain official terms.
- TASK_ARCHIVE/* may stay Korean (storage only, doc-size exception).
- Migration done 2026-06-10: 336 AI-context files → English (backup `~/_archive/lang-migration-backup-20260610_210420`).

# Common Coding Rules

- Write commit messages in Korean (human-facing / git history readability)
- Prefer Korean for log messages too (English allowed for error logs)
- Variable/function names in English; in-code comments may be Korean or English per project

# Project Manager (pm.py)

- Path: `/home/window11/project-manager/pm.py`
- Full project status: `python3 /home/window11/project-manager/pm.py status`
- Health check: `python3 /home/window11/project-manager/pm.py health`
- Daily/weekly report: `python3 /home/window11/project-manager/daily_report.py`

# Project List

> SSOT: `/home/window11/project-manager/projects.yaml`
> Add/change projects only in projects.yaml.

# Global Rules (common to all projects)

> Location: `/home/window11/project-manager/global-rules/`

## Auto-loaded Every Session (5 core)
- `ssot.md` — SSOT + symlink principle
- `task-management.md` — 3-stage task flow
- `test-first.md` — verify-before-adopt
- `publish-gate.md` — external publishing approval gate
- `llm-architecture.md` — Opus=manager / Sonnet=worker routing (2026-05-18 GLM demotion)

## Invoked via Skill When Needed (not auto-loaded)
- `cron.md` → `/hih-cron` (when adding/modifying cron)
- `overnight.md` → `/overnight` (during overnight work)
- `deep-fp.md` → `/hih-fp` (when first-principles thinking is needed)
- `deep-ontology.md` → `/hih-ontology` (when ontology thinking is needed)
- `doc-size.md` → reference when a .md exceeding 500 lines is found

## Skill Auto-Suggestion Rule
When a user request comes in, refer to memory's `reference_skill_usage.md` (auto-accumulated skill invocation frequency) to automatically suggest a contextually appropriate skill. However, even with a frequency of 0, suggestion is possible if the context matches — frequency is only a supplementary indicator, never an absolute criterion.

# Screenshot Check

- "Check the screenshot" → check the latest file in `/mnt/c/Users/window11/Pictures/Screenshots/`
- When image serving is needed, guide to Tailscale serve or the WSL path (`\\wsl$\Ubuntu\...`)

# gstack

Use /browse from gstack for all web browsing.
Available skills: /office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review, /design-consultation, /review, /ship, /land-and-deploy, /canary, /benchmark, /browse, /qa, /qa-only, /design-review, /setup-browser-cookies, /setup-deploy, /retro, /investigate, /document-release, /codex, /cso, /autoplan, /careful, /freeze, /guard, /unfreeze, /gstack-upgrade.
