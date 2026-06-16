/usr/bin/bash: warning: setlocale: LC_ALL: cannot change locale (ko_KR.UTF-8)
---
name: hih-git
description: Briefs git status across all projects + batch commit/push/pull. For the PM orchestrator.
user_invocable: true
---

# /hih-git

Briefs the git status of all projects and performs batch commit/push/pull.

## yaml structure note

`projects` in `projects.yaml` is a **dict** structure (not a list):
```python
data = yaml.safe_load(open('projects.yaml'))
projects = data['projects']  # {name: {path:..., ...}}
for name, info in projects.items():
    path = os.path.expanduser(info.get('path', ''))
```

PM itself (`~/project-manager`) is not in the yaml, so it must be added separately.

## Execution order

### 1. Full git status briefing

#### 1-0. Git Identity 사전 검증 (commit/push 전 필수)

모든 commit/push 작업 전에 반드시 git user.name / user.email 설정 여부를 확인한다.

```bash
git config user.name && git config user.email
```

- **설정됨** → 정상 진행
- **미설정** → 해당 프로젝트에 대해 작업 중단 후 사용자에게 경고 + 안내:
  ```
  ⛔ {프로젝트명}: git identity 미설정
  → 설정 후 재시도:
    git config user.name "이름"
    git config user.email "이메일"
  ```
- **주의**: `--global`이 아닌 해당 리포지토리(local) 설정을 우선 확인한다.

All projects in projects.yaml + PM itself:
- number of uncommitted files (`git status --short`)
- number of unpushed commits (`git log @{u}..HEAD --oneline`)
- current branch
- latest commit message (35 chars)

```
## Git Status Briefing

| Project | uncommitted | unpushed | Branch | Latest commit |
|---------|:-----------:|:--------:|--------|----------|
| ✅ 인성이 | 0 | 0 | master | chore: ... |
| ⚠️ 주식부자 | 1 | 0 | master | handoff |
| 🔴 be-a-studio | 22 | 3 | master | feat: ... |

⚠️ Action needed:
- 주식부자: 1 uncommitted
- be-a-studio: 22 uncommitted + 3 unpushed
```

### 2. Interactive commands

| Command | Action |
|------|------|
| `push` | Batch push only projects with no uncommitted changes (if rejected, pull --rebase then retry) |
| `push all` | If uncommitted, `git add -A && git commit -m "chore: 정리"` then push |
| `pull` | stash all → pull --rebase → stash pop |
| `sync` | pull + push |
| `status` | Re-output the briefing |

### 3. push execution logic

```
For each project:
1. Check whether .env/credentials are staged → if so, warn + abort
2. If uncommitted → git add -A + git commit -m "chore: 정리"
3. git push
4. rejected → git pull --rebase → retry git push
5. Output result
```

### 4. pull execution logic

```
For each project:
1. uncommitted → git stash
2. git pull --rebase
3. stash pop (warn on conflict, do not auto-resolve)
```

## Notes
- force push is absolutely prohibited
- Do not auto-resolve conflicts → report to the user
  - 단, **사용자가 명시적으로 승인**한 경우 theirs/ours 전략으로 rebase를 계속할 수 있다
- If .env or credentials are staged, warn + skip that project

### Rebase 충돌 해결 절차

`git pull --rebase` 또는 `git rebase` 수행 중 충돌이 발생하면:

1. **충돌 파일 목록 확인**:
   ```bash
   git diff --name-only --diff-filter=U
   ```

2. **사용자에게 충돌 내용 보고 + 해결 전략 선택 요청**:
   - `ours` — 로컬 변경 우선 (기존 브랜치 것을 유지)
   - `theirs` — 원격 변경 우선 (리베이스 대상 것을 유지)
   - `manual` — 사용자가 직접 편집

3. **사용자 승인 시 theirs/ours 전략으로 일괄 해결**:
   ```bash
   # 전부 ours로 해결
   for f in $(git diff --name-only --diff-filter=U); do git checkout --ours "$f" && git add "$f"; done

   # 전부 theirs로 해결
   for f in $(git diff --name-only --diff-filter=U); do git checkout --theirs "$f" && git add "$f"; done
   ```

4. **해결 완료 후 rebase 계속**:
   ```bash
   GIT_EDITOR=true git rebase --continue
   ```

5. **rebase 자체를 포기해야 하는 경우**:
   ```bash
   git rebase --abort
   ```
   사용자에게 원인을 보고하고 수동 해결을 안내한다.
