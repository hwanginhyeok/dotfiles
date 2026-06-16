---
name: hih-decide
description: Record a decision entry in the Decision Log. Trigger when user makes a decision, sets a working method, or gives feedback on approach.
user_invocable: true
---

# /hih-decide

의사결정을 Decision Log에 기록하는 스킬.

## 트리거 조건 (자동 감지)

다음 상황이 감지되면 사용자에게 "의사결정으로 기록할까요?" 확인 후 실행:

1. 사용자가 기술 선택을 결정함 (예: "A로 가자", "이 방식으로 하자")
2. 작업 방식/프로세스를 정함 (예: "앞으로는 이렇게 하자")
3. 피드백을 줌 (예: "이건 별로였어", "다음엔 이렇게 해")
4. 우선순위를 조정함 (예: "이거 먼저 하자", "이건 보류")
5. 아키텍처/구조를 결정함 (예: "이 구조로 가자")

## 실행 절차

### Step 1: 의사결정 내용 파악

대화 컨텍스트에서 다음을 추출:
- 무슨 상황이었는지 (상황)
- 고려했던 선택지들 (옵션)
- 최종 선택 (결정)
- 왜 그렇게 했는지 (이유)

### Step 2: 카테고리 분류

- `tech-choice`: 기술/도구 선택
- `priority`: 우선순위 결정
- `process`: 작업 방식/프로세스
- `user-feedback`: 사용자 피드백 기반 결정
- `architecture`: 구조/설계 결정

### Step 3: DECISIONS.md에 엔트리 추가

```bash
DECISIONS_FILE="$HOME/project-manager/decision-log/DECISIONS.md"
```

엔트리 형식:
```markdown
## DL-NNN: 제목
- **날짜**: YYYY-MM-DD
- **카테고리**: tech-choice / priority / process / user-feedback / architecture
- **상황**: 무슨 상황이었는지 (1~2줄)
- **옵션**: 고려했던 선택지들
- **결정**: 최종 선택
- **이유**: 왜 이렇게 했는지
- **결과**: 결과가 어땠는지 (성공/부분/실패)
- **학습**: 다음에 비슷하면 어떻게 할지
```

**번호 할당**: 기존 가장 큰 DL-NNN + 1
**삽입 위치**: 파일 최상단 (헤더 뒤, 첫 번째 엔트리 앞)

### Step 4: 500줄 제한 확인 및 아카이브

```bash
LINE_COUNT=$(wc -l < "$DECISIONS_FILE")
if [ "$LINE_COUNT" -gt 500 ]; then
    # 아카이브 절차 수행 (아래 "아카이브 절차" 섹션 참조)
fi
```

#### 아카이브 절차

1. `wc -l DECISIONS.md` 로 현재 줄 수 확인
2. 500줄 초과 시:
   a. 오래된 엔트리(마지막 20개 제외) 추출
   b. `archive/decisions_YYYYMM.md` 로 이동
      - 같은 월 파일이 이미 존재하면 append
   c. DECISIONS.md에는 최근 20개 엔트리만 유지
   d. PATTERNS.md는 아카이브하지 않음 (항상 전체 유지)
3. 아카이브 후 DECISIONS.md 줄 수가 여전히 500 초과면 다시 수행

### Step 5: 사용자에게 기록 완료 알림

```
📝 의사결정 기록됨: DL-NNN — {제목}
   카테고리: {카테고리}
   파일: ~/project-manager/decision-log/DECISIONS.md
```

## 서브에이전트 제한

서브에이전트는 DECISIONS.md를 직접 수정하지 않는다.
의사결정이 발생하면 내용을 PM에게 보고 → PM이 DECISIONS.md에 기록.

이유: 병렬 서브에이전트가 동시에 DECISIONS.md를 수정하면 충돌 발생.

## 주의사항

- 한국어로 작성
- 날짜 형식: YYYY-MM-DD
- "결과" 필드는 즉시 알 수 없으면 "진행 중"으로 기록, 나중에 업데이트
- "학습" 필드는 다음 비슷한 상황에서의 행동 지침
- 사소한 결정(파일명, 변수명 등)은 제외 — 의미 있는 선택만 기록
