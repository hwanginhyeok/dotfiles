/usr/bin/bash: warning: setlocale: LC_ALL: cannot change locale (ko_KR.UTF-8)
/usr/bin/bash: warning: setlocale: LC_ALL: cannot change locale (ko_KR.UTF-8)
/usr/bin/bash: warning: setlocale: LC_ALL: cannot change locale (ko_KR.UTF-8)
---
name: hih-dev
description: Full feature development pipeline. Task check → design → (parallel decomposition judgment) → implementation → 2-phase subagent review → 3-way review → deployment → session wrap-up. If the features are distinct, parallel agents are auto-assigned. Universal (works for all projects — icloud-blog, insung, stock, etc.). Use when: "개발 시작", "기능 만들어줘", "풀 파이프라인", "hih-dev", "병렬 개발"
user_invocable: true
---

# /hih-dev — Full Feature Development Pipeline

Performs every stage of new feature development in order.
**If the feature is distinct (clear independent module / file boundaries), parallel agents are auto-assigned** to increase speed.
Each step can be skipped, and the flow branches depending on the situation.

---

## Pipeline Order

```
STEP 0    Operations health check  — systemd / service / cron status (conditional, operational systems)
STEP 1    /hih-task        — task check + set this session's goal
STEP 1.5  Parallel decomposition analysis — judge whether independent subtasks can be split out
STEP 1.7  Project-specific skill trigger — .claude/skills/ matching (selector-debug, etc.)
STEP 2    /office-hours    — idea/design review (SKIP if already sufficiently discussed)
STEP 3    /plan-eng-review — architecture / implementation plan review
STEP 4    Write the code   — single or parallel agent implementation
            ├ single: PM implements directly
            ├ parallel: assign an agent per subtask pane → simultaneous implementation
            └ on a bug → /investigate (return after confirming root cause)
STEP 4.5  2-Phase Subagent Review — 스펙 준수 리뷰 + 코드 품질 리뷰 (subtask 단위)
            ├ Phase 1: 스펙 준수 리뷰 — 지시사항 vs 실행결과 매칭 검증
            ├ Phase 2: 코드 품질 리뷰 — DRY / 에러 핸들링 / 엣지 케이스 검증
            └ 이슈 발견 시 수정 → 재리뷰 루프 (통과 시 다음 단계)
STEP 5    3-way review     — run /review(Claude) + /codex + /hih-glm in parallel → comparison table
            ├ GLM dispatch (async) → /review (30 sec) → /codex (5 min, parallel with GLM)
            ├ output the 3-way comparison table (agreement rate + composite gate)
            └ all-agreed findings → fix immediately / single-flagged findings → PM verification
STEP 6    /health         — composite code quality score (type check + linter + tests)
STEP 6.3  Security scan    — security-auditor agent on the diff (escalate to /cso for high-risk), ship-blocking gate
STEP 6.5  /qa             — web QA (verify UI + API in a real browser, conditional)
            ├ if it's a web app, auto-run: check deploy URL or localhost then test via browse
            └ if not a web app (Python library, CLI, etc.) → SKIP
STEP 6.7  Log verification — confirm normal execution in journalctl / service logs (conditional)
STEP 7    /ship           — commit + push + create PR
STEP 7.5  publish-gate check — confirm the _confirm() gate when external-publish automation changes
STEP 7.7  /canary         — 30-min post-deploy monitoring (web app + external deploy)
STEP 8    /hih-clear      — task cleanup + documentation + memory update (when everything is done)
```

---

## STEP 0 — Operations Health Check (Conditional)

For projects with operational services, check the current state before starting work. This blocks the pattern of developing on a dead service and discovering it only later.

### Per-project health check
| Project | Command |
|---------|------|
| **insung_blog** | `systemctl --user status blog-api blog-worker \| grep -E "●\|Active:"` |
| **be-a-studio** | `tail -20 ~/.pm_logs/be_a_studio_daily.log` + cron last-run time |
| **stock** | `systemctl --user status x-bot \| grep Active` + `tail -20 ~/.pm_logs/news_kr.log` |
| **music-lab** | (no service, SKIP) |
| **icloud-blog** | (CLI only, SKIP) |

### When inactive/failed is found
- Attempt restart immediately (`systemctl --user restart {service}`)
- If it still fails after restart, find the cause with `journalctl --user -u {service} -n 30`
- Report to the user + hold STEP 1 (health recovery first)

**SKIP condition**: static site, CLI tool, library (no operational infrastructure)

---

## STEP 1 — /hih-task

Brief the current project's tasks.

- Read CURRENT_TASK.md / PREPARED_TASK.md / FINISHED_TASK.md
- Select 1–3 tasks to develop this session
- Move the selected tasks to CURRENT (start command)

**Output example**:
```
## This session's goals
- ICB-07: naver_publisher.py integration
- ICB-08: complete run_pipeline.py CLI
```

---

## STEP 1.5 — Parallel Decomposition Analysis (Auto)

Always run right after STEP 1. Judge whether to deploy parallel agents.

### Parallelizability criteria (all 3 must be satisfied)
1. **File boundary separation**: Do subtask A and B modify non-overlapping files?
2. **No dependency**: Is A's result not required for B's implementation? (Can they run in parallel with no ordering?)
3. **Independent testing**: Can each subtask be verified separately?

### Branching on the judgment result
```
Parallelizable → decompose into N subtasks → assign parallel agents in STEP 4
Single task    → skip decomposition → PM implements directly in STEP 4
```

### Decomposition examples
| Feature request | Subtask decomposition |
|-----------|--------------|
| Blog pipeline | A: naver_publisher.py / B: run_pipeline.py / C: tests |
| Stock dashboard | A: backend API / B: frontend component / C: DB migration |
| Music post-processing | A: vocal separation / B: mastering / C: upload |

**Output format**:
```
## Parallel decomposition analysis
Decomposable: ✅ / ❌ (single)

Subtasks:
- A: {title} — assigned files: {file list}
- B: {title} — assigned files: {file list}
- C: {title} — assigned files: {file list}

Agent assignment:
- pane 1 (existing claude): subtask A
- pane 2 (new agent): subtask B
- pane 3 (new agent): subtask C
```

---

## STEP 1.7 — Project-Specific Skill Trigger

Depending on the work, auto-trigger the project-specific skills registered in the project's `.claude/skills/`.
Project-specific skills hold domain knowledge that hih-dev does not know (bot health check, service operations, etc.).

### Auto-trigger matrix
| Project | Trigger keyword | Matching skill |
|---------|-------------|----------|
| **insung_blog** | bot status / operations check | `.claude/skills/bot-health-check.md` |
| **insung_blog** | service / worker / E2E | `.claude/skills/service-test.md` |
| **insung_blog** | ops 점검 / cron 건강 | `.claude/skills/hih-ops-check/` |
| **insung_blog** | extension (selector/cookie/release cycle) | `.claude/rules/extension-vs-web-cycle.md` (rule) |
| **be-a-studio** | (no per-project skill defined) | (SKIP) |
| **stock** | (no per-project skill defined) | (SKIP) |

> insung_blog: discovery, collection, publishing, comment selectors, and the NID_AUT cookie have all been migrated to the Chrome extension (v0.9.8).
> The bot server only does AI comment generation (Ollama). The selector/cookie skills were deleted as part of the 2026-05-21 bot-server retirement.

### Trigger procedure
1. Check the `.claude/skills/*.md` list in the current working directory
2. Match each skill file's trigger keywords against this session's goals
3. On a match, Read that skill file to load the domain knowledge → apply in STEP 4

**SKIP condition**: the project has no `.claude/skills/` directory, or the work is outside the project domain

---

## STEP 3 — /plan-eng-review

Review the architecture and implementation plan.

- Which files will be created or modified
- Dependency flow (which module calls which module)
- Edge cases + error-handling direction
- Confirm testability

Begin implementation after the review passes.

---

## STEP 4 — Write the Code

Implement according to the plan finalized in plan-eng-review.

### TDD 원칙 (test-driven-development)

**반드시 `superpowers:test-driven-development` 스킬의 원칙을 따른다.**

구현 순서 (Red-Green-Refactor):
1. **Red — 테스트 먼저 작성**: 구현하기 전에 실패하는 테스트를 먼저 작성한다
2. **Green — 최소 구현**: 테스트를 통과하는 최소한의 코드를 작성한다
3. **Refactor — 개선**: 테스트가 통과하는 상태를 유지하며 리팩토링한다

> 이 원칙은 STEP 6(/health)의 테스트 결과와 직접 연결된다.
> TDD로 작성된 테스트는 STEP 6에서 품질 점수의 핵심 근거가 되며,
> 테스트 커버리지 저하나 실패는 즉시 수정 후 재측정한다.

### Single implementation (parallel decomposition ❌)
- Work one module/feature unit at a time
- **test-first**: 반드시 테스트를 먼저 작성 후 구현 (superpowers:test-driven-development 따름)
- Comments and commit messages in Korean

### Parallel implementation (parallel decomposition ✅)

#### Agent assignment procedure

**1. Check current pane state**
```bash
tmux list-panes -t {session}:1
# e.g.: bea / stock / insung / music
```

**2. Add panes if there aren't enough**
```bash
tmux split-window -t {session}:1 -c ~/{project_path}
tmux select-layout -t {session}:1 main-vertical
```

**3. Start an agent in each pane**
```bash
tmux send-keys -t {session}:1.2 "claude --add-dir ~/project-manager" Enter
tmux send-keys -t {session}:1.3 "claude --add-dir ~/project-manager" Enter
```

**4. Write the task briefing file then deliver it**
```bash
# Write the briefing file
cat > /tmp/hih_task_B.md << 'EOF'
## Subtask B: {title}

### Assigned files (modify only these files)
- {file path}

### Implementation goal
{specific goal}

### Completion conditions
- [ ] {checklist}

### Caution
- No file overlap with the pane1 agent. Do not modify files outside the assigned set.
- On completion, git add + commit (wait for PM instruction to push)
EOF

# Deliver to the agent
tmux send-keys -t {session}:1.2 "cat /tmp/hih_task_B.md" Enter
```

**5. Confirm completion**
```bash
# When each pane's agent commits on completion, check via git log
git -C ~/{project} log --oneline -5
```

**6. PM verification (L2 hunk)**
```bash
git -C ~/{project} show --stat {commit_hash}
```

### Bug branch — /investigate
When an unexpected bug or error occurs during implementation:
1. Invoke the `/investigate` skill
2. Confirm the root cause (do not fix by guessing)
3. Return to STEP 4 after confirming the cause

---

## STEP 4.5 — 2-Phase Subagent Review (subtask 단위)

STEP 4에서 각 subtask(또는 단일 구현 단위)가 완료된 직후, **서브에이전트 주도 2단계 리뷰**를 실행한다.
이 단계는 STEP 5(3-way review) 전에 수행되며, 구현 품질을 조기에 보장하여 후속 3-way review의 부담을 줄인다.

### Phase 1: 스펙 준수 리뷰 (Spec Review)

**목적**: subtask에 주어진 지시사항(브리핑 파일, plan-eng-review 결과)과 실제 실행 결과가 정확히 매칭되는지 검증.

**검증 항목**:
1. **요구사항 커버리지**: 브리핑에 명시된 모든 요구사항이 구현되었는가?
2. **완료 조건 충족**: 각 체크리스트 항목이 실제로 만족되는가?
3. **파일 범위 준수**: 할당된 파일만 수정되었는가? (병렬 subtask 시 중요)
4. **인터페이스 일치**: plan-eng-review에서 정의한 모듈 간 인터페이스가 그대로 구현되었는가?

**실행 방법**:
```
## 스펙 준수 리뷰 결과
Subtask: {title}

| 검증 항목 | 상태 | 비고 |
|-----------|------|------|
| 요구사항 커버리지 | ✅/❌ | 누락 항목: {list} |
| 완료 조건 충족 | ✅/❌ | 미충족 항목: {list} |
| 파일 범위 준수 | ✅/❌ | 범위 외 수정: {list} |
| 인터페이스 일치 | ✅/❌ | 불일치: {list} |

판정: PASS / FAIL (수정 필요)
```

- **PASS** → Phase 2(코드 품질 리뷰)로 진행
- **FAIL** → 수정 후 Phase 1 재실행 (무한 루프 방지: 최대 3회)

### Phase 2: 코드 품질 리뷰 (Code Quality Review)

**목적**: 스펙 준수가 확인된 코드의 내재적 품질을 검증.

**검증 항목**:
1. **DRY (Don't Repeat Yourself)**: 중복 코드가 없는가? 공통 로직은 유틸로 추출했는가?
2. **에러 핸들링**: 모든 외부 호출(API, DB, 파일 I/O)에 에러 핸들링이 있는가?
3. **엣지 케이스**: 빈 입력, null/None, 경계값, 동시성 등 극단 케이스가 처리되는가?
4. **가독성**: 함수/변수 네이밍이 의도를 명확히 전달하는가? 주석이 충분한가?
5. **보안**: 하드코딩된 시크릿, SQL 인젝션, 입력 검증 누락 등이 없는가?

**실행 방법**:
```
## 코드 품질 리뷰 결과
Subtask: {title}

| 검증 항목 | 상태 | 발견 사항 |
|-----------|------|-----------|
| DRY | ✅/❌ | 중복 위치: {list} |
| 에러 핸들링 | ✅/❌ | 누락 지점: {list} |
| 엣지 케이스 | ✅/❌ | 미처리 케이스: {list} |
| 가독성 | ✅/❌ | 개선 제안: {list} |
| 보안 | ✅/❌ | 위험 항목: {list} |

판정: PASS / FIX-REQUIRED / WARN
```

- **PASS** → STEP 4.5 완료, STEP 5(3-way review)로 진행
- **FIX-REQUIRED** → 수정 후 Phase 1부터 재실행 (스펙 준수 재확인)
- **WARN** → PM 판단에 따라 경고 사항을 메모하고 진행 (PREPARED_TASK에 등록)

### 수정 → 재리뷰 루프

```
Phase 1 FAIL → 수정 → Phase 1 재실행 (최대 3회)
  └ 3회 초과 시: PM에게 에스컬레이션, 설계 재검토

Phase 2 FIX-REQUIRED → 수정 → Phase 1 재실행 (수정이 스펙에 영향 가능)
Phase 2 WARN → PM 판단 → 진행 또는 수정
```

### 병렬 구현 시 리뷰 흐름

병렬 subtask의 경우, 각 subtask가 독립적으로 STEP 4.5를 수행한다:

```
Subtask A 완료 → Phase 1 → Phase 2 → PASS → 대기
Subtask B 완료 → Phase 1 → Phase 2 → PASS → 대기
Subtask C 완료 → Phase 1 → Phase 2 → PASS → 대기
모든 subtask PASS → STEP 5 (3-way review, 전체 diff 대상)
```

**주의**: 한 subtask에서 FAIL이 발생하면 해당 subtask만 수정하고 재리뷰. 다른 subtask는 대기 상태 유지.

**SKIP condition**: 코드 변경이 없는 경우(docs-only, 설정 파일만 변경 등)

### 공유 리소스 보호 (중요)

다음 파일은 병렬 서브에이전트가 직접 수정 금지. PM만 수정:
- DECISIONS.md, PATTERNS.md, PERSONA.md
- project-manager/decision-log/ 하위 전체
- PREPARED_TASK.md, FINISHED_TASK.md (PM 관리)

서브에이전트는 자신의 코드 파일만 수정. 공유 리소스 변경이 필요하면 PM에게 보고.

### 파일 쓰기 검증 (중요)

patch/write_file 후 반드시 실제 파일 내용으로 성공 여부 확인:
1. 도구 반환값만으로 '성공' 판단 금지
2. patch 실패 시 FAILED로 보고 (성공으로 보고 금지)
3. write_file 후 read_file로 내용 일치 확인

---

## STEP 5 — 3-way Review (/hih-3way)

> **SSOT: hih-3way 스킬**. 아래는 요약. 전체 로직은 `/hih-3way` 스킬을 로드하여 실행.

### 실행 방식

**기본 (1-round 빠른 리뷰):**
```
/hih-3way    # Claude /review + /codex + /hih-glm 병렬 → 비교 테이블 + Composite gate
```

**심층 (다중 라운드 합의 리뷰):**
```
/hih-3way-hard    # 최대 3라운드 반복 → 교차 검증 → 수렴도 측정 → 최종 합의
```

### 선택 기준
| 상황 | 스킬 | 소요 |
|------|------|------|
| 일반 기능 개발 | /hih-3way | ~5분 |
| 중요 변경 (API/보안/아키텍처) | /hih-3way-hard | ~15분 |
| Fast merge (--fast-merge) | /review만 | ~30초 |

### 결과에 따른 액션
- PASS → STEP 6으로 진행
- CONDITIONAL PASS → PM이 단일 이슈 검증 후 판정
- FAIL → 수정 후 재실행 (최대 3회)

---

## STEP 6 — /health

Check the composite code quality score.

- Type check (mypy / tsc, etc.)
- Linter (ruff / eslint, etc.)
- Test runner
- Dead code detection

**Criterion**: if the score drops below the previous score, fix and re-measure.

### TDD 연결 검증

STEP 4에서 TDD 원칙에 따라 작성된 테스트가 이 단계에서 검증된다:
- STEP 4에서 test-first로 작성한 테스트가 모두 통과하는지 확인
- 테스트 커버리지가 기준치 이상인지 확인 (신규 코드는 최소 1개 이상의 테스트 필수)
- 테스트 실패 시 STEP 4로 돌아가 Red-Green-Refactor 사이클 재수행

---

## STEP 6.3 — Security Scan (ship-blocking gate)

After code quality passes (STEP 6), run a dedicated security scan **before** /qa and /ship.
This closes the gap where the only security check was a single checklist line in STEP 4.5 and
the adversarial pass in STEP 5. Security is now an explicit gate, not a side effect.

### Scope — diff only (fast, relevant)
Scan the newly added/changed code, not the whole repo:
```bash
git diff master..HEAD
```
Focus areas: hardcoded secrets/tokens, injection (SQL/command/path), authn/authz gaps,
input validation, SSRF/open redirect, unsafe deserialization, and **newly added dependencies**
(`package.json` / `requirements.txt` / lockfiles → supply-chain risk).

### Tool selection (mirrors STEP 5's 3way ↔ 3way-hard)
| Situation | Tool | Why |
|-----------|------|-----|
| Normal feature change | `security-auditor` agent on the diff | Isolated context, fast, zero-noise |
| **High-risk change** (auth / secrets / payment / external user input / new deps) | `/cso` (daily mode, 8/10 gate) | Infra-first: secrets archaeology + dependency supply chain + OWASP/STRIDE |
| Pre-release / monthly | `/cso` comprehensive (2/10 bar) | Deep scan, trend tracking |

Default: dispatch the `security-auditor` agent. Auto-escalate to `/cso` when the diff touches
any high-risk surface above. The escalation is automatic (no extra flag), same as STEP 5.

### Gate rules
| Severity | Action |
|----------|--------|
| **CRITICAL / HIGH** | **Block ship.** Fix → return to STEP 4 → re-scan. Do NOT proceed to STEP 7. |
| **MEDIUM** | Fix now, or register in PREPARED_TASK with explicit justification + PM sign-off |
| **LOW / INFO** | Note in the PR description, proceed |
| **0 findings** | PASS → proceed to STEP 6.5 |

> Secret-handling rules (global CLAUDE.md) are enforced here: no plaintext PAT in remotes,
> no inline secrets in bash, `.env` masked on grep. A hardcoded secret in the diff = CRITICAL.

### Output
```
## Security scan result
Tool: security-auditor (diff) / cso (high-risk: {reason})
Findings: Critical N / High N / Medium N / Low N
Gate: PASS / BLOCKED ({blocking items})
```

**SKIP conditions:**
- docs-only change (no executable code)
- config-only change with no secret surface and no new dependency
- `--no-sec` flag (explicit opt-out — record the reason in the PR)

---

## STEP 6.5 — /qa (Conditional)

**Auto-detect whether it's a web app, then decide whether to run:**

```bash
# Determine whether it's a web app (a web app if any one of these matches)
[ -f apps/web/package.json ] || [ -f package.json ] && grep -q '"next"\|"react"\|"vue"\|"express"' package.json 2>/dev/null
```

**If it's a web app:**
1. Confirm the deploy URL or local dev server:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null
   # or find the deploy URL from CLAUDE.md / Vercel config
   ```
2. Once the URL is confirmed, run the `/qa` skill:
   - Test centered on the pages/features modified this session
   - Screenshots + console error check in a real Chromium browser
   - Auth-required pages: if cookies exist, import them; otherwise public pages only
3. On finding bugs:
   - Critical/High → fix immediately then retest (return to STEP 4)
   - Medium or below → register in PREPARED_TASK then continue

**SKIP conditions:**
- Not a web app (Python library, CLI, script, etc.)
- `--no-qa` flag
- No local server and no deploy URL (in this case, output a warning only)

**Output:**
```
## QA result
URL: {tested URL}
Screenshots: {N}
Bugs: {Critical N / High N / Medium N}
Status: PASS / ISSUES FOUND
```

---

## STEP 6.7 — Log Verification (Conditional)

For projects with operational services, confirm normal execution in the logs after a code change.
Blocks the "tests pass but silent fail in production" pattern (publisher silent fail PR #1 case).

### Per-project log verification
| Project | Command |
|---------|------|
| **insung_blog** | `journalctl --user -u blog-worker -n 30 --no-pager \| grep -iE "error\|fail\|exception"` |
| **be-a-studio** | `tail -50 ~/.pm_logs/be_a_studio_daily.log \| grep -iE "error\|fail"` |
| **stock** | `journalctl --user -u x-bot -n 30 --no-pager \| grep -iE "error\|fail"` |

### Pass criteria
- 0 new errors (ignore existing known errors)
- At least 1 normal-execution log (e.g., "publish succeeded", "cron triggered")
- If it doesn't pass, return to STEP 4 (re-fix the code)

**SKIP condition**: no operational system / the change is unrelated to operations (e.g., docs-only change)

---

## STEP 7 — /ship

Commit + push + create PR.

- Commit message: Korean, by meaning unit
- PR title: concise (within 70 characters)
- Never force push

---

## STEP 7.5 — publish-gate Check (Conditional)

Auto-grep whether external-publish automation entered the code. Enforces the publish-gate rule ("auto-generate OK, auto-publish NO") at the code level.

### grep pattern
```bash
# Detect auto-call patterns of external-publish functions in the newly added diff
git diff master..HEAD | grep -iE "^\+.*(publish|post_to|send_to|upload|tweet|발행|게시).*\("
```

### Gate rules
| Project | Auto OK | Manual gate required |
|---------|--------|----------------|
| **insung_blog** | comments auto, notifications | blog publish (`_confirm()`) |
| **stock** | market briefing (reporting) | external Naver publish |
| **be-a-studio** | rendering auto | YouTube upload |
| **music-lab** | Suno generation auto | YouTube upload |

When found:
- If the `_confirm()` / user-approval gate is missing, add it then retry STEP 7
- If it's a legitimate auto-call (reporting/notification), state it in the PR description

**SKIP condition**: a change with no external-publish impact (UI only, internal logic only, tests only)

---

## STEP 7.7 — /canary (Conditional)

For a web app or external deploy, monitor for 30 minutes right after deployment.

```bash
/canary {deploy URL}
# or
/canary https://insung-blog.vercel.app
```

### Watch items
- Keep console errors at 0
- 0 page-load failures
- Performance regression vs. baseline ≤ 10%
- Compare screenshots of key pages

### Alert triggers
- New console error occurs → alert immediately + confirm rollback with the user
- Regression found → register in PREPARED_TASK then keep watching

**SKIP condition**: not a web app / static site / no external deploy / local changes only

---

## STEP 8 — /hih-clear (Conditional)

**Execution condition**: when all of this session's target tasks are complete.

**SKIP condition**: there are still remaining tasks, or you'll continue in the next session.

- Completed tasks → move to FINISHED_TASK.md
- Update DIFFICULTY.md (if there was anything difficult)
- Update memory
- Output session summary

---

## Step Skip Rules

| Condition | Skippable step |
|------|--------------|
| Already discussed sufficiently | STEP 2 (office-hours) |
| Simple bug fix | STEP 2, STEP 3 |
| Implementation complete with no bugs | STEP 4 branch (investigate) |
| Tasks still remaining | STEP 8 (hih-clear) |
| Fast merge needed | STEP 5 → run only /review (skip codex/glm) |
| Not a web app or `--no-qa` | STEP 6.5 (qa) |
| Docs-only / config-only no secret surface / `--no-sec` | STEP 6.3 (security scan) |
| No code changes (docs-only) | STEP 4.5 (2-phase review) |

---

## Output Format on Execution

At skill start:
```
## /hih-dev start
Project: {project name}
Goal: {this session's task}

Pipeline:
✅ STEP 1 hih-task
⏭ STEP 2 office-hours (SKIP — already discussed)
▶ STEP 3 plan-eng-review ← current
  STEP 4 write the code
  STEP 4.5 2-phase subagent review (스펙 준수 + 코드 품질)
  STEP 5 3-way review (Claude + Codex + GLM)
  STEP 6 health
  STEP 6.3 security scan (ship-blocking gate)
  STEP 6.5 qa (auto-run if web app)
  STEP 7 ship
  STEP 8 hih-clear
```

On each step's completion, output `✅ STEP N done` then proceed to the next step.
