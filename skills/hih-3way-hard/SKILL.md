/usr/bin/bash: warning: setlocale: LC_ALL: cannot change locale (ko_KR.UTF-8)
---
name: hih-3way-hard
version: 2.0.0
description: |
  다중 라운드 3모델 교차 검증 리뷰. PM(이 세션)이 직접 실행하는 절차서.
  Round 1(독립) → Round 2(교차) → Round 3(집중, 필요시)를 거쳐 수렴도를 측정하고 최종 합의를 도출.
  hih-investigate(버그 수정)의 기본 리뷰 방식.
  Use when: "3-way hard review", "심층 리뷰", "다중 라운드 리뷰", "hih-3way-hard", "교차 검증"
---

# /hih-3way-hard — Multi-Round Convergence Review

## 실행 주체

**PM (이 세션)**. PM이 직접 각 라운드를 실행하고, 결과를 취합하며, 수렴도를 계산한다.
이 스킬은 PM이 따라야 할 **정확한 실행 절차서**다. "에이전트가 알아서" 실행하지 않는다.

## 도구 매핑 (실제 환경)

| 리뷰어 | 호출 방식 | 도구 | 상태 |
|--------|-----------|------|------|
| GLM | `execute_code`에서 `call_glm()` | `/home/window11/project-manager/scripts/glm_client.py` | ✅ 정상 |
| Codex | `terminal`에서 `codex exec` | `/home/window11/.local/bin/codex` | ⚠️ 인증 필요 |
| Claude | PM이 직접 분석 또는 `delegate_task` | 현재 세션 | ✅ 정상 |

> Codex 인증 실패 시 자동으로 2-way(Claude+GLM)로 강등, 라운드당 합의 기준 조정.

---

## 라운드 구조

```
Round 1 (독립): 각 모델이 blinded로 리뷰 → PM이 정규화 → 비교 테이블
Round 2 (교차): 각 모델이 R1 결과를 보고 AGREE/DISAGREE/WITHDRAW 판정 → 수렴도 측정
Round 3 (집중, 필요시): 미합의 이슈만 CONFIRMED/REJECTED/DEFER 판정
```

### 종료 조건

- **100% 합의** (어느 라운드에서든) → 즉시 최종 보고서
- **Round 2 후 수렴도 ≥ 80%** → 최종 보고서
- **Round 3 완료** → 강제 종료 + 미합의 항목 PM 판정

---

## STEP 0 — 사전 검증

### 0a. 도구 가용성

hih-3way STEP 0와 동일:

```bash
# GLM
python3 -c "import sys; sys.path.insert(0,'/home/window11/project-manager/scripts'); from glm_client import call_glm" 2>&1

# Codex
codex exec "echo test" 2>&1 | grep -q "401\|Unauthorized" && echo "CODEX_AUTH_FAILED" || echo "CODEX_OK"
```

### 0b. 모드 결정

- 3개 OK → 3-way (합의 기준: 3/3, 2/3)
- Codex 실패 → 2-way (합의 기준: 2/2)
- GLM 실패 → 중단

### 0c. 작업 디렉토리

```bash
mkdir -p /tmp/hih_3way_hard
rm -f /tmp/hih_3way_hard/*.txt
```

---

## STEP 1 — Round 1: 독립 리뷰 (Blinded)

### 1a. 코드 준비

```
TARGET = {사용자 지정}
CODE = read_file(TARGET) 또는 git diff
```

### 1b. 각 모델에 동일 프롬프트로 리뷰 요청

**공통 프롬프트:**
```
다음 코드를 리뷰하라. 버그, 보안, 성능, 설계, 가독성 문제를 찾아라.

[코드]
{CODE}

출력 형식:
ISSUE-N: [제목]
  심각도: CRITICAL | HIGH | MEDIUM | LOW | INFO
  위치: [파일:라인 또는 함수]
  설명: [문제]
  권고: [수정]
```

**PM이 각 모델을 직접 호출:**

1. **GLM** → `execute_code`에서 `call_glm(prompt=..., system="시니어 리뷰어")`
   - 결과 → `/tmp/hih_3way_hard/r1_glm.txt`
2. **Codex** (인증 시) → `terminal`에서 `codex exec "..."`
   - 결과 → `/tmp/hih_3way_hard/r1_codex.txt`
   - 401 시 → CODEX_SKIP=true
3. **Claude** → PM이 직접 분석 (또는 `delegate_task`)
   - 결과 → `/tmp/hih_3way_hard/r1_claude.txt`

> 병렬 실행: GLM(execute_code)과 Codex(terminal)를 동시에 호출 가능. Claude는 그 사이 PM이 분석.

### 1c. 정규화 (기계적 룰 우선 + PM 판단 보조)

3개(또는 2개) 결과를 정규화한다. **자동화 가능한 부분은 기계적 룰로 먼저 처리**하여 PM 부담을 줄인다.

**Tier 1 — 자동 매핑 (execute_code로 실행, PM 개입 없음):**
1. 같은 파일:라인 위치 → 무조건 같은 이슈
2. 같은 함수명/클래스명 + 하나 이상의 키워드 일치 → 같은 이슈
   - 키워드 사전: {버그, 보안, 성능, 메모리, 누수, N+1, 인젝션, 인증, 권한, 에러, 예외, null, ...}
3. 정확한 용어 일치 ("SQL 인젝션" == "SQL 인젝션")

**Tier 2 — PM 판단 (Tier 1에서 매핑 안 된 이슈만):**
- 의미적 유사도: "Lazy Loading Issue" ≈ "N+1 쿼리" — PM이 직접 판단
- 모호한 케이스: 별도 ID 부여 (나중에 미합의로 처리)

> 3-way hard 리뷰 자체 테스트 결과, Tier 1 룰이 이슈의 약 80%를 자동 처리한다. Tier 2는 나머지 20%만.

**Round 1 비교 테이블 생성:**

```
## Round 1 비교
| 이슈 ID | 설명        | Claude | Codex | GLM | 합의 수 |
|---------|-------------|--------|-------|-----|---------|
| I-01    | {요약}      | O      | O     | O   | 3/3     |
| I-02    | {요약}      | O      | X     | O   | 2/3     |
| I-03    | {요약}      | X      | O     | X   | 1/3     |
```

**초기 수렴도**: (3/3 + 2/3 이슈 수) / 전체 × 100

---

## STEP 2 — Round 2: 교차 리뷰

### 2a. 각 모델에게 자기 R1 결과 + 전체 비교 테이블 제공

> **stateless 문제 해결**: 각 모델에게 자신의 R1 결과를 변수로 다시 주입한다.

**Round 2 프롬프트 (모델 A 예시):**
```
3명의 리뷰어가 코드를 리뷰한 Round 1 결과다.

[Round 1 비교 테이블]
{R1_TABLE — STEP 1c 결과}

[당신의 Round 1 리뷰 결과]
{MY_R1_REVIEW — /tmp/hih_3way_hard/r1_{model}.txt 내용}

지시사항:
1. 다른 리뷰어가 찾았지만 당신이 놓친 이슈에 대해:
   - AGREE: 타당하다
   - DISAGREE: 오답/과잉이다 (이유 명시)
   - UNSURE: 추가 정보 필요
2. 다른 리뷰어가 반박한 당신의 이슈 재확인:
   - WITHDRAW: 내 이슈가 틀림 인정
   - MAINTAIN: 여전히 유효 (추가 근거)
3. 새 이슈 발견 시 추가 가능 (NEW)

출력:
ISSUE-I-XX: [이슈]
  내 R1 입장: [보고/미보고]
  재검토 입장: AGREE | DISAGREE | WITHDRAW | MAINTAIN | UNSURE | NEW
  이유: [설명]
```

### 2b. PM이 각 모델 호출

각 모델에게 **자기 R1 결과를 포함**하여 동일한 R2 프롬프트 전송:

1. **GLM**: `call_glm(prompt=R2_PROMPT_GLM, ...)` — R2_PROMPT_GLM에는 r1_glm.txt 내용 포함
2. **Codex**: `codex exec "{R2_PROMPT_CODEX}"` — r1_codex.txt 내용 포함
3. **Claude**: PM이 직접 판정

결과 각각 저장: `/tmp/hih_3way_hard/r2_{model}.txt`

### 2c. Round 2 분석 + 수렴도 계산

PM이 각 이슈별 최종 입장 정리:

```
## Round 2 결과
| 이슈 ID | 설명    | Claude   | Codex    | GLM      | 최종 상태  |
|---------|---------|----------|----------|----------|-----------|
| I-01    | {요약}  | MAINTAIN | AGREE    | AGREE    | 합의 (3/3) |
| I-02    | {요약}  | MAINTAIN | DISAGREE | MAINTAIN | 부분 (2/3) |
```

**수렴도 = (합의 완료 이슈 수) / (유효 이슈 수) × 100**
- 합의 완료 = 3/3 동의
- WITHDRAW는 이슈를 삭제하지 않는다. 상태만 UNRESOLVED로 유지하여 Round 3에서 재검토 대상이 되도록 한다.
  (3-way hard 자체 리뷰 I-02 반영: WITHDRAW로 이슈가 소멸하면 R3 진입 명분이 사라지는 구조 결함 방지)

### 2d. 종료 판정

- 수렴도 = 100% → 최종 보고서 생성 (STEP 4)
- 수렴도 ≥ 80% → 최종 보고서 생성 (미합의 항목은 PM 판정 표시)
- 수렴도 < 80% → Round 3 진행

---

## STEP 2.5 — normalize_reviews 헬퍼 (R3 input 자동 생성)

> 3-way hard 자체 리뷰 I-09 반영: PM이 수동으로 R3 input 포맷을 맞추는 건 현실 불가.
> execute_code로 자동화한다.

```python
# execute_code에서 실행
import re, json

def normalize_reviews(r2_files, r1_table):
    """R2 결과 파일들에서 미합의 이슈를 자동 추출하여 R3 input 생성."""
    unresolved = []
    for fpath in r2_files:  # ['/tmp/.../r2_claude.txt', '/tmp/.../r2_glm.txt']
        with open(fpath) as f:
            text = f.read()
        # ISSUE-I-XX 패턴 추출
        for m in re.finditer(r'ISSUE-(I-\d+):.*?(?=ISSUE-I|\Z)', text, re.DOTALL):
            block = m.group()
            iid = re.search(r'I-(\d+)', block).group(1)
            stance = re.search(r'재검토 입장:\s*(\w+)', block)
            if stance and stance.group(1) in ('DISAGREE', 'UNSURE', 'MAINTAIN'):
                unresolved.append({'id': f'I-{iid}', 'text': block[:300]})
    # 중복 제거 (같은 ID)
    seen = set()
    r3_input = []
    for u in unresolved:
        if u['id'] not in seen:
            seen.add(u['id'])
            r3_input.append(u)
    return r3_input

r3_issues = normalize_reviews(
    ['/tmp/hih_3way_hard/r2_claude.txt', '/tmp/hih_3way_hard/r2_glm.txt'],
    r1_table
)
print(f"R3 대상 이슈: {len(r3_issues)}건")
```

PM이 이 헬퍼로 추출된 이슈 목록만 R3 프롬프트에 주입하면 된다.

---

## STEP 3 — Round 3: 집중 재리뷰 (필요시)

미합의 이슈(STEP 2.5에서 자동 추출)만 추출하여 집중 판정.

### 3a. 미합의 이슈 프롬프트

```
2라운드까지 진행했지만 합의에 도달하지 못한 이슈들이다.
각 이슈에 대해 최종 판정을 내려라.

[미합의 이슈 + Round 2 입장 요약]
{UNRESOLVED_ISSUES}

지시사항:
1. 각 이슈당 최종 결론:
   - CONFIRMED: 실제 문제, 수정 필요
   - REJECTED: 문제 아님, 무시
   - DEFER: 추가 조사 필요 (PM 판정)
2. 근거를 2-3문장으로 제시
3. 새 이슈 추가 금지

출력:
ISSUE-I-XX: [이슈]
  최종 판정: CONFIRMED | REJECTED | DEFER
  근거: [설명]
```

### 3b. PM이 각 모델 호출 + 결과 집계

각 모델의 R3 판정을 집계:

```
CONFIRMED 2/3+ → 수정 권고
REJECTED  2/3+ → 기각
그 외      → PM 판정 (DEFER)
```

---

## STEP 4 — 최종 보고서 생성

### 출력 파일

`/tmp/hih_3way_hard/final_report.md`

### 형식

```markdown
## 3-WAY HARD REVIEW — FINAL REPORT

- 리뷰 대상: {TARGET}
- 라운드 수: {N} (최대 3)
- 모드: {3-way | 2-way}
- 총 소요: ~{N}분
- 수렴도: {X}% (최종)
- 리뷰어: Claude, {Codex,} GLM

### 합의된 이슈 — 수정 권고 (CONFIRMED)

| # | 이슈 ID | 이슈 | 심각도 | 합의 | 권고 수정 |
|---|---------|------|--------|------|-----------|

### 기각된 이슈 (REJECTED)

| # | 이슈 ID | 이슈 | 기각 사유 | 투표 |
|---|---------|------|-----------|------|

### 미합의 이슈 — PM 판정 필요 (DEFER)

| # | 이슈 ID | 이슈 | Claude | Codex | GLM | 비고 |
|---|---------|------|--------|-------|-----|------|

### 라운드별 수렴도 추이

| 라운드 | 유효 이슈 | 합의 이슈 | 수렴도 |
|--------|-----------|-----------|--------|
| R1     | N         | N         | X%     |
| R2     | N         | N         | X%     |
| R3     | N         | N         | X%     |

### 최종 GATE

- 합의율: {X}%
- CRITICAL/HIGH 합의 이슈: {N}건
- GATE: **PASS** | **CONDITIONAL** | **FAIL**

PM 액션:
- CONDITIONAL → 미합의 DEFER 이슈 PM 판정 후 GATE 재확정
```

### GATE 기준

| 조건 | GATE |
|------|------|
| CRITICAL 합의 0건, HIGH 합의 0건 | **PASS** |
| CRITICAL 0건, HIGH ≥1 또는 DEFER 존재 | **CONDITIONAL** |
| CRITICAL 합의 ≥1건 | **FAIL** |

---

## 실패 케이스 대응

| 상황 | 대응 |
|------|------|
| GLM 키 없음 | 중단. `.secrets` / `glm-key-helper.sh` 확인 안내 |
| Codex 401 | 자동 2-way 강등. 합의 기준 2/2로 조정. 안내만 출력. |
| Codex 타임아웃 (180s) | 해당 라운드에서 Codex 스킵 |
| 모델이 형식 미준수 | PM이 텍스트에서 이슈 추출. 빈 결과면 "이슈 없음". |
| 코드 너무 김 | 핵심 파일/함수만으로 범위 축소 |
| Round 1 수렴도 이미 80%+ | Round 2 생략 가능, 바로 최종 보고서 |

---

## PM 실행 체크리스트

각 라운드마다 PM은 다음을 수행한다:

- [ ] 각 모델 결과 파일 저장 확인 (`ls /tmp/hih_3way_hard/r{N}_*.txt`)
- [ ] 3개(또는 2개) 결과 전부 읽기 (`read_file`)
- [ ] 이슈 정규화 (수동 매핑)
- [ ] 비교 테이블 생성
- [ ] 수렴도 계산
- [ ] 종료 조건 확인
- [ ] 사용자에게 진행 상황 보고 (각 라운드 종료 시)

---

## 호출 명령

```
/hih-3way-hard [파일 경로 또는 디렉토리]
/hih-3way-hard git diff HEAD~1
```

또는 대화 내에서:
```
이 코드에 3-way hard review 돌려줘.
회귀 위험 크니까 hard 모드로.
```

---

## 주의사항

1. **PM이 직접 실행**: 이 스킬은 자동 실행이 아니다. PM이 각 단계를 도구 호출로 수행.
2. **정규화는 수동**: 자동 클러스터링 불가능. PM이 읽고 매핑.
3. **stateless 보완**: Round 2에서 각 모델에게 자기 R1 결과를 반드시 다시 주입.
4. **소요**: 3-way 3라운드 최대 15분. 2-way 2라운드 ~5분.
5. **비용**: GLM 정액제. Codex는 OpenAI 비용 (라운드당 1회).
6. **DEFER은 PM 판정**: 자동 CONFIRM/REJECT하지 않는다.
