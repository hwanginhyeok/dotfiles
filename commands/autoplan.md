---
name: autoplan
description: 자동 플랜 리뷰 파이프라인. 엔지니어링 → 보안 → 품질 순차 검증.
user-invocable: true
---

# 자동 플랜 리뷰 (gstack /autoplan 개인 프로젝트 적용판)

gstack의 CEO/Design/Eng 3단 리뷰를 개인 프로젝트에 맞게 간소화:
**엔지니어링 리뷰 → 보안 스캔 → 품질 검증**

## 실행 절차

### Phase 1: 컨텍스트 수집
1. CLAUDE.md, TASK.md 읽기
2. `git diff origin/main...HEAD` 전체 변경사항 수집
3. 현재 Plan 파일 검색 (`~/.claude/plans/*.md`)

### Phase 2: 엔지니어링 리뷰
code-reviewer 에이전트의 전체 워크플로우 실행:
- 2-pass 리뷰 (CRITICAL/INFORMATIONAL)
- Scope Drift 탐지
- Fix-First 자동 수정
- 테스트 커버리지 다이어그램

### Phase 3: 보안 스캔
security-auditor 에이전트의 daily 모드 실행:
- 시크릿 노출 체크
- 인젝션 취약점
- LLM 보안 (해당 시)
- 의존성 감사

### Phase 4: 품질 검증
1. 전체 Python 구문 검증 (`py_compile`)
2. TypeScript 타입 체크 (`npx tsc --noEmit`) — TS 프로젝트만
3. 기존 테스트 실행 (`pytest` 또는 `npm test`)
4. 테스트 커버리지 확인

### Phase 5: 종합 판정

결정 원칙 (gstack 기반):
1. **완전성 선택** — 더 많은 에지케이스를 커버하는 옵션
2. **DRY** — 기존 기능 중복이면 거부
3. **명시적 > 교묘함** — 10줄 명확한 코드 > 200줄 추상화
4. **행동 편향** — 머지 > 리뷰 순환 > 방치된 숙고

## 출력 형식
```markdown
# 자동 플랜 리뷰 결과

## 엔지니어링 리뷰
- CRITICAL: N개 (자동수정 N, 미해결 N)
- INFORMATIONAL: N개
- Scope Drift: DONE N / PARTIAL N / NOT DONE N

## 보안 스캔
- 발견: 심각 N, 높음 N, 보통 N

## 품질 검증
| 항목 | 상태 |
|------|------|
| 구문 | ✅/❌ |
| 타입 | ✅/❌/N/A |
| 테스트 | ✅/❌ (통과 N, 실패 N) |

## 판정: SHIP / NEEDS_FIX / BLOCKED
(사유)
```
