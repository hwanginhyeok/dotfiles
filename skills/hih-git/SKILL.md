---
name: hih-git
description: 전체 프로젝트 git 상태 브리핑 + 일괄 커밋/push/pull. PM 오케스트레이터용.
user_invocable: true
---

# /hih-git

전체 프로젝트의 git 상태를 브리핑하고, 일괄 커밋/push/pull을 수행한다.

## yaml 구조 주의

`projects.yaml`의 `projects`는 **dict** 구조 (list 아님):
```python
data = yaml.safe_load(open('projects.yaml'))
projects = data['projects']  # {name: {path:..., ...}}
for name, info in projects.items():
    path = os.path.expanduser(info.get('path', ''))
```

PM 자체(`~/project-manager`)는 yaml에 없으므로 별도 추가 필요.

## 실행 순서

### 1. 전체 git 상태 브리핑

projects.yaml 전 프로젝트 + PM 자체:
- uncommitted 파일 수 (`git status --short`)
- unpushed 커밋 수 (`git log @{u}..HEAD --oneline`)
- 현재 브랜치
- 최근 커밋 메시지 (35자)

```
## Git 상태 브리핑

| 프로젝트 | uncommitted | unpushed | 브랜치 | 최근 커밋 |
|---------|:-----------:|:--------:|--------|----------|
| ✅ 인성이 | 0 | 0 | master | chore: ... |
| ⚠️ 주식부자 | 1 | 0 | master | handoff |
| 🔴 be-a-studio | 22 | 3 | master | feat: ... |

⚠️ 조치 필요:
- 주식부자: uncommitted 1개
- be-a-studio: uncommitted 22개 + unpushed 3개
```

### 2. 인터랙티브 명령

| 명령 | 동작 |
|------|------|
| `push` | uncommitted 없는 프로젝트만 일괄 push (rejected면 pull --rebase 후 재시도) |
| `push all` | uncommitted 있으면 `git add -A && git commit -m "chore: 정리"` 후 push |
| `pull` | 전체 stash → pull --rebase → stash pop |
| `sync` | pull + push |
| `status` | 브리핑 재출력 |

### 3. push 실행 로직

```
각 프로젝트:
1. .env/credentials staged 여부 확인 → 있으면 경고 + 중단
2. uncommitted 있으면 → git add -A + git commit -m "chore: 정리"
3. git push
4. rejected → git pull --rebase → git push 재시도
5. 결과 출력
```

### 4. pull 실행 로직

```
각 프로젝트:
1. uncommitted → git stash
2. git pull --rebase
3. stash pop (충돌 시 경고, 자동 해결 안 함)
```

## 주의
- force push 절대 금지
- 충돌 자동 해결 안 함 → 사용자 보고
- .env, credentials staged면 경고 + 해당 프로젝트 스킵
