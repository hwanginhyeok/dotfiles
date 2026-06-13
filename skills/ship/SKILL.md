---
name: ship
preamble-tier: 4
version: 1.0.0
description: |
  Ship 워크플로: 플랫폼 감지, base 브랜치 병합, 테스트 실행, 코드 리뷰,
  VERSION 범프, CHANGELOG 갱신, 커밋, 푸시, PR 생성.
  "ship", "deploy", "push to main", "create a PR" 등에 사용.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - WebSearch
---

## Preamble (시작 시 실행)

```bash
_UPD=$(~/.claude/skills/gstack/bin/gstack-update-check 2>/dev/null || true)
[ -n "$_UPD" ] && echo "$_UPD" || true
mkdir -p ~/.gstack/sessions && touch ~/.gstack/sessions/"$PPID"
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
_REPRO_MODE=$(source <(~/.claude/skills/gstack/bin/gstack-repo-mode 2>/dev/null) 2>/dev/null && echo "$REPO_MODE" || echo "unknown")
echo "REPO_MODE: ${REPO_MODE:-unknown}"
_SESSION_ID="$$-$(date +%s)"
```

gstack 업그레이드, 텔레메트리, 프로액티브, 라우팅 등의 설정 프롬프트는
이미 설정된 경우(마커 파일 존재) 자동 스킵. SPAWNED_SESSION=true면 모든
인터랙티브 프롬프트를 스킵하고 추천 옵션 자동 선택.

## 핵심 원칙

- **완전 자동화**: `/ship` 입력 후 PR URL이 나올 때까지 불필요한 질문 금지
- **멱등성**: 재실행 시 검증은 모두 재실행, 액션은 이미 완료된 경우 스킵
- **검증 없이 완료 선언 금지**: 모든 주장은 실행 증거로 뒷받침
- **bisect 가능한 커밋**: 각 커밋은 하나의 논리적 변경 단위

## 중지 조건 (STOP)

- base 브랜치에서 실행 중인 경우 (중단)
- 자동 해결 불가능한 병합 충돌
- 브랜치 내 테스트 실패
- Pre-landing 리뷰에서 ASK 항목
- MINOR/MAJOR 버전 범프 필요
- AI 평가 커버리지가 최소 임계값 미만
- Plan 항목이 NOT DONE 상태

## 자동 처리 (중지 안 함)

- 커밋되지 않은 변경 (항상 포함)
- PATCH/MICRO 버전 범프 (자동 선택)
- CHANGELOG 내용 (diff에서 자동 생성)
- 커밋 메시지 승인
- 자동 수정 가능한 리뷰 발견 (dead code, N+1, stale comments)

---

## Step 0: 플랫폼 및 base 브랜치 감지

```bash
git remote get-url origin 2>/dev/null
```

- URL에 "github.com" → GitHub, "gitlab" → GitLab
- GitHub: `gh pr view --json baseRefName -q .baseRefName` → `gh repo view --json defaultBranchRef`
- GitLab: `glab mr view -F json` → `glab repo view -F json`
- 폴백: `git symbolic-ref refs/remotes/origin/HEAD` → `main` → `master`

## Step 1: Pre-flight

1. base 브랜치면 중단: "base 브랜치입니다. feature 브랜치에서 실행하세요."
2. `git status` + `git diff <base>...HEAD --stat` + `git log <base>..HEAD --oneline`
3. Review Readiness Dashboard 표시 (기존 리뷰 상태 요약)
4. Eng Review 없으면 Step 9에서 자체 리뷰 실행 안내

## Step 2: 배포 파이프라인 확인

새 바이너리/CLI/라이브러리 추가 시 CI/CD 릴리즈 워크플로우 있는지 확인.
없으면 사용자에게 워크플로우 추가 여부 질문.

## Step 3: Base 브랜치 병합

```bash
git fetch origin <base> && git merge origin/<base> --no-edit
```

충돌 시: 단순한 것(VERSION, CHANGELOG 순서)은 자동 해결, 복잡하면 중단.

## Step 4: 테스트 프레임워크 감지

프로젝트 런타임과 기존 테스트 프레임워크 감지. 없으면 부트스트랩 제안.
`.gstack/no-test-bootstrap` 마커가 있으면 스킵.

## Step 5: 테스트 실행

```bash
# 프로젝트에 맞는 테스트 명령 실행
bin/test-lane 2>&1 | tee /tmp/ship_tests.txt &
npm run test 2>&1 | tee /tmp/ship_vitest.txt &
wait
```

**테스트 실패 소유권 판별:**
- **In-branch**: 브랜치 변경으로 인한 실패 → 중단, 사용자가 수정해야 함
- **Pre-existing**: 기존 실패 → REPO_MODE에 따라 수정/TODO/이슈 할당/스킵

## Step 6: Eval 스위트 (프롬프트 파일 변경 시에만)

프롬프트 관련 파일이 diff에 있으면 해당 eval 스위트를 `EVAL_JUDGE_TIER=full`로 실행.
실패 시 중단.

## Step 7: 테스트 커버리지 감사 (subagent)

subagent에 위임. diff의 모든 코드 경로 추적 후:
1. ASCII 커버리지 다이어그램 생성
2. 커버되지 않은 경로에 대해 테스트 자동 생성 (최대 20개)
3. 커버리지 게이트: CLAUDE.md의 Minimum/Target 또는 기본값(60%/80%)
4. 회귀 테스트는 필수 — 해당 diff가 기존 동작을 수정하면 즉시 작성

## Step 8: Plan 완료 감사 (subagent)

계획 파일 발견 시:
1. 모든 실행 가능 항목 추출 (체크박스, 번호 단계, 명령문)
2. diff와 교차 검증: DONE / PARTIAL / NOT DONE / CHANGED / UNVERIFIABLE
3. NOT DONE → 사용자에게 중단/계속/제외 선택
4. UNVERIFIABLE → 항목별 개별 확인

## Step 9: Pre-landing 리뷰

1. `.claude/skills/review/checklist.md` 읽기 (없으면 중단)
2. `git diff origin/<base>` 전체 검토
3. CRITICAL 패스: SQL/데이터 안전성, LLM 출력 신뢰 경계
4. INFORMATIONAL 패스: 나머지 모든 카테고리
5. 전문가 subagent 병렬 디스패치 (testing, maintainability 필수; security, performance, data-migration, api-contract, design은 조건부)
6. Red Team: 200+ 라인이거나 CRITICAL 발견 시
7. 결과: AUTO-FIX 항목 자동 수정, ASK 항목만 사용자에게 질문
8. 수정 발생 시 커밋 후 `/ship` 재실행 안내

## Step 10: Greptile 리뷰 코멘트 (PR 존재 시)

기존 PR의 Greptile 코멘트 분류: valid_actionable / already_fixed / false_positive.
ACTIONABLE은 사용자에게 수정/스킵 선택, 나머지는 자동 처리.

## Step 11: 적대적 리뷰 (항상 실행)

- **Claude subagent**: 공격자 관점에서 diff 검토, 엣지 케이스/보안/레이스 컨디션 발견
- **Codex adversarial**: `codex exec`로 크로스모델 검토 (가능한 경우)
- **Codex structured review**: 200+ 라인인 경우 P1 게이트 포함 리뷰
- 모든 결과를 종합하여 고신뢰 발견 우선 수정

## Step 12: VERSION 범프 (자동 결정)

```bash
BASE_VERSION=$(git show origin/<base>:VERSION 2>/dev/null | tr -d '\r\n[:space:]')
CURRENT_VERSION=$(cat VERSION 2>/dev/null | tr -d '\r\n[:space:]')
```

**상태 판별:**
- FRESH → 범프 실행
- ALREADY_BUMPED → 스킵 (큐 드리프트 확인)
- DRIFT_STALE_PKG → package.json만 동기화
- DRIFT_UNEXPECTED → 수동 해결 필요, 중단

**범프 레벨 자동 결정:**
- MICRO (4th): < 50줄, 사소한 수정
- PATCH (3rd): 50+줄, 기능 신호 없음
- MINOR (2nd): 기능 신호 감지 또는 500+줄 → **사용자에게 질문**
- MAJOR (1st): 마일스톤/브레이킹 체인지 → **사용자에게 질문**

VERSION 파일과 package.json 모두 갱신.

## Step 13: CHANGELOG 자동 생성

1. `git log <base>..HEAD --oneline`으로 모든 커밋 나열
2. `git diff <base>...HEAD`로 전체 diff 분석
3. 커밋을 주제별 그룹핑 (Added/Changed/Fixed/Removed)
4. `## [X.Y.Z.W] - YYYY-MM-DD` 형식으로 CHANGELOG 항목 작성
5. 모든 커밋이 최소 하나의 불릿에 매핑되었는지 교차 확인
6. **사용자에게 변경 내용 설명을 요청하지 않음** — diff에서 자동 추론

## Step 14: TODOS.md 자동 업데이트

TODOS.md가 없으면 생성 제안, 구조가 맞지 않으면 재구성 제안.
diff와 커밋 메시지를 기반으로 완료된 항목 자동 감지 후 `## Completed`로 이동.
보수적으로 판단 — 확실한 증거가 있는 항목만 완료 처리.

## Step 15: 커밋 (bisect 가능한 청크)

1. 변경을 논리적 단위로 그룹핑
2. 순서: 인프라 → 모델/서비스 → 컨트롤러/뷰 → VERSION+CHANGELOG
3. 각 커밋은 독립적으로 유효해야 함 (깨진 import 금지)
4. 형식: `<type>: <summary>` (feat/fix/chore/refactor/docs)
5. 마지막 커밋에만 버전 태그 포함
6. Continuous checkpoint 모드인 경우 WIP 커밋을 먼저 squash

## Step 16: 검증 게이트

**코드가 Step 5 이후 변경되면 반드시 재실행:**
- 테스트 재실행 (수정 발생 시)
- 빌드 실행 (있는 경우)
- "이미 테스트함" → 코드가 바뀜. 다시 실행.
- 테스트 실패 시 중단, Step 5로 복귀.

## Step 17: Push

```bash
# 이미 푸시된 경우 스킵
git fetch origin <branch-name> 2>/dev/null
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/<branch-name> 2>/dev/null || echo "none")
[ "$LOCAL" = "$REMOTE" ] && echo "ALREADY_PUSHED" || git push -u origin <branch-name>
```

## Step 18: 문서 동기화 (subagent)

/document-release subagent 실행. README.md, CLAUDE.md 등 문서 자동 갱신.
PR 생성 전에 실행하여 PR 본문에 결과 포함.

## Step 19: PR/MR 생성

**이미 PR이 존재하면 본문 갱신, 없으면 새로 생성.**
PR 제목은 항상 `v$NEW_VERSION`로 시작.

**PR 본문 필수 섹션:**
- Summary: 모든 변경을 논리적 섹션으로 그룹핑
- Test Coverage: 커버리지 다이어그램
- Pre-Landing Review: 리뷰 결과
- Design Review: 프론트엔드 변경 시 (선택)
- Eval Results: 프롬프트 변경 시 (선택)
- Plan Completion: 계획 파일이 있는 경우
- TODOS: 완료된 항목 목록
- Documentation: Step 18 결과
- Test plan: 체크박스 형식

```bash
# GitHub
gh pr create --base <base> --title "v$NEW_VERSION <type>: <summary>" --body "$(cat <<'EOF'
<PR 본문>
EOF
)"
# GitLab
glab mr create -b <base> -t "v$NEW_VERSION <type>: <summary>" -d "$(cat <<'EOF'
<MR 본문>
EOF
)"
```

## Step 20: Ship 메트릭 저장

```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)" && mkdir -p ~/.gstack/projects/$SLUG
echo '{"skill":"ship","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","coverage_pct":COVERAGE_PCT,"plan_items_total":PLAN_TOTAL,"plan_items_done":PLAN_DONE,"version":"VERSION","branch":"BRANCH"}' >> ~/.gstack/projects/$SLUG/$BRANCH-reviews.jsonl
```

## Telemetry (마지막에 실행)

```bash
_TEL_END=$(date +%s) && _TEL_DUR=$(( _TEL_END - _TEL_START ))
~/.claude/skills/gstack/bin/gstack-timeline-log '{"skill":"ship","event":"completed","branch":"'$(git branch --show-current 2>/dev/null || echo unknown)'","outcome":"OUTCOME","duration_s":"'"$_TEL_DUR"'","session":"'"$_SESSION_ID"'"}' 2>/dev/null || true
```

## 중요 규칙

- 테스트 실패 시 중단, 테스트 스킵 금지
- Pre-landing 리뷰 스킵 금지
- Force push 금지, 일반 push만 사용
- 사소한 확인 질문 금지 ("푸시할까요?" 등)
- VERSION은 항상 4자리 형식 (MAJOR.MINOR.PATCH.MICRO)
- CHANGELOG 날짜: YYYY-MM-DD
- 커밋은 bisect 가능하게 분할
- TODOS 완료 감지는 보수적으로
- 코드 변경 후 반드시 재검증, 신뢰는 증거로만
- **목표: 사용자가 `/ship` 입력 → 리뷰 + PR URL + 문서 동기화까지 자동 완료**
