---
name: hih-3way
version: 2.0.0
description: |
  1-round 3모델 병렬 코드 리뷰. PM(이 세션)이 직접 실행하는 절차서.
  GLM(call_glm) + Codex(codex exec) + Claude(PM 직접 분석)를 병렬 호출하여
  비교 테이블 + 합의율 + Composite gate를 출력한다.
  hih-dev STEP 5의 SSOT.
  Use when: "3-way review", "3-way 리뷰", "병렬 리뷰", "hih-3way", "모델 비교 리뷰"
---

# /hih-3way — 3-Model Parallel Review (1-round)

## 실행 주체

**PM (이 세션)**. PM이 직접 각 도구를 호출하고 결과를 취합한다.
이 스킬은 "에이전트가 알아서 실행"하는 게 아니라, **PM이 따라야 할 정확한 실행 절차서**다.

## 도구 매핑 (실제 환경)

| 리뷰어 | 호출 방식 | 도구 | 상태 |
|--------|-----------|------|------|
| GLM | `execute_code`에서 `call_glm()` | `/home/window11/project-manager/scripts/glm_client.py` | ✅ 정상 |
| Codex | `terminal`에서 `codex exec` | `/home/window11/.local/bin/codex` | ⚠️ 인증 필요 |
| Claude | PM이 직접 분석 또는 `delegate_task` | 현재 세션 | ✅ 정상 |

> Codex 인증 실패 시 자동으로 2-way(Claude+GLM)로 강등된다.

---

## STEP 0 — 사전 검증

### 0a. 도구 가용성 확인

```bash
# GLM
python3 -c "import sys; sys.path.insert(0,'/home/window11/project-manager/scripts'); from glm_client import call_glm" 2>&1

# Codex (인증 상태)
codex exec "echo test" 2>&1 | grep -q "401\|Unauthorized" && echo "CODEX_AUTH_FAILED" || echo "CODEX_OK"

# Claude — 별도 확인 불필요 (PM 자체)
```

### 0b. 모드 결정

- 3개 전부 OK → **3-way 모드**
- Codex만 실패 → **2-way 모드 (Claude+GLM)**, 합의 기준 조정
- GLM 실패 → **중단**, 사용자에게 Z_AI_API_KEY 확인 요청

### 0c. 작업 디렉토리 초기화

```bash
mkdir -p /tmp/hih_3way
rm -f /tmp/hih_3way/*.txt
```

---

## STEP 1 — 리뷰 대상 준비

### 1a. 대상 확인

사용자로부터 리뷰 대상(TARGET)을 받는다.
- 파일 경로 (예: `/path/to/file.py`)
- 디렉토리 (예: `src/auth/`)
- PR/diff (예: `git diff HEAD~1`)

### 1b. 코드 추출

```
TARGET = {사용자 지정 경로}
CODE = read_file(TARGET) 또는 terminal("git diff ...")
```

### 1c. 공통 리뷰 프롬프트 준비

```
다음 코드를 리뷰하라. 목표: 버그, 보안, 성능, 설계 결함, 가독성 문제.

[코드]
{CODE}

출력 형식 (반드시 준수):
ISSUE-N: [제목]
  심각도: CRITICAL | HIGH | MEDIUM | LOW | INFO
  위치: [파일:라인 또는 함수명]
  설명: [문제]
  권고: [수정 방법]
```

---

## STEP 2 — 병렬 리뷰 실행 (PM이 직접 호출)

### 2a. GLM 리뷰 — `execute_code`

```python
import os, sys
sys.path.insert(0, '/home/window11/project-manager/scripts')
from glm_client import call_glm

result = call_glm(
    prompt=REVIEW_PROMPT,  # STEP 1c에서 준비
    project="현재 프로젝트명",
    feature="3way-review",
    system="시니어 코드 리뷰어. 논리적/실행적 결함을 찾아라.",
)
# result['response']를 /tmp/hih_3way/glm.txt로 저장
```

**성공 조건**: `result['status'] == 'ok'`
**실패 시**: 오류 메시지 기록, GLM은 리뷰어에서 제외

### 2b. Codex 리뷰 — `terminal` (인증 시에만)

```bash
cd {리뷰 대상 프로젝트 루트}
timeout 180 codex exec --skip-git-repo-check "{REVIEW_PROMPT}" > /tmp/hih_3way/codex.txt 2>&1
# 401 감지 시 → CODEX_SKIP=true
```

**인증 실패 감지**: 출력에 `401 Unauthorized` 포함 시 Codex 스킵
**타임아웃**: 180초 초과 시 Codex 스킵

### 2c. Claude 리뷰 — PM 직접 분석

PM(이 세션)이 동일한 프롬프트로 **직접** 코드를 분석한다.
- CODE를 읽고 ISSUE-N 형식으로 리뷰 작성
- 결과를 `/tmp/hih_3way/claude.txt`에 저장 (`write_file`)

> 대안: 독립 컨텍스트가 필요하면 `delegate_task`로 별도 Claude 서브에이전트 사용.

---

## STEP 3 — PM 정규화 (수동 매핑)

**자동 정규화는 불가능하다.** PM이 3개 결과를 직접 읽고 유사 이슈를 매핑한다.

### 3a. 각 결과 읽기

```
read_file("/tmp/hih_3way/glm.txt")
read_file("/tmp/hih_3way/codex.txt")  # 있으면
read_file("/tmp/hih_3way/claude.txt")
```

### 3b. 이슈 정규화 규칙

PM이 다음 기준으로 유사 이슈를 동일 ID로 그룹핑:
1. **정확한 키워드 매칭**: "SQL 인젝션", "N+1 쿼리" 등 동일 용어
2. **위치 일치**: 같은 파일/함수를 가리키면 같은 이슈로 간주
3. **의미적 유사도**: "Lazy Loading Issue" ≈ "N+1 쿼리" — PM이 판단
4. **모호한 케이스**: 별도 ID 부여 (나중에 미합의로 처리)

> PM이 직접 판단한다. LLM이 자동으로 클러스터링하지 않는다.

---

## STEP 4 — 비교 테이블 + 합의율 (필수 출력)

### 출력 형식

```
## 3-WAY REVIEW RESULT

리뷰 대상: {TARGET}
모드: 3-way | 2-way (Codex 실패) | 2-way (GLM 실패)

| 이슈 ID | 설명            | Claude | Codex | GLM | 합의 |
|---------|-----------------|--------|-------|-----|------|
| I-01    | {이슈 요약}     | O      | O     | O   | 3/3  |
| I-02    | {이슈 요약}     | O      | X     | O   | 2/3  |
| I-03    | {이슈 요약}     | X      | O     | X   | 1/3  |

전원 동의 (즉시 수정): {3/3 이슈 목록}
과반 동의 (수정 권고): {2/3 이슈 목록}
단독 의견 (PM 검증):   {1/3 이슈 목록}

합의율: X%
```

### 합의율 계산

```
합의율 = (3/3 또는 2/3 합의 이슈 수) / (전체 고유 이슈 수) × 100
```

---

## STEP 5 — Composite Gate 판정

### 게이트 기준

| 조건 | GATE |
|------|------|
| 전원 PASS + "전원 동의" 이슈 0건 | **PASS** |
| "전원 동의" 이슈 1건+ (CRITICAL/HIGH) | **FAIL** — 수정 후 재실행 |
| 과반 동의만 있고 전원 동의 없음 | **CONDITIONAL** — PM이 단독 이슈 검증 후 판정 |

### 2-way 모드 기준 (Codex 실패 시)

| 조건 | GATE |
|------|------|
| 2/2 동의 이슈 0건 | **PASS** |
| 2/2 동의 + CRITICAL/HIGH | **FAIL** |
| 1/2만 있음 | **CONDITIONAL** — PM이 직접 판정 |

---

## STEP 6 — 후속 액션

- **PASS** → 다음 단계로 진행 (hih-dev STEP 6 등)
- **CONDITIONAL** → PM이 단독 이슈 각각 검증 → CONFIRM/REJECT 판정
- **FAIL** → 수정 후 STEP 2부터 재실행 (최대 3회)

---

## 실패 케이스 대응

| 상황 | 대응 |
|------|------|
| GLM 키 없음 | 중단. `~/.secrets` 또는 `glm-key-helper.sh` 확인 안내 |
| Codex 401 | 자동 2-way 강등. 게이트 기준 조정. 사용자에게 인증 안내 |
| Codex 타임아웃 | Codex 스킵, 2-way 진행 |
| 모델이 형식 미준수 | PM이 결과에서 이슈 추출, 빈 결과면 "이슈 없음"으로 기록 |
| 코드 너무 김 | 청크 분할 또는 "핵심 파일만"으로 범위 축소 |

---

## 호출 명령

```
/hih-3way [파일 경로 또는 디렉토리]
/hih-3way git diff HEAD~1
```

또는 대화 내에서:
```
이 코드에 3-way review 돌려줘.
```

---

## 주의사항

1. **PM이 직접 실행**: 이 스킬은 LLM이 "알아서" 실행하는 게 아니다. PM이 각 단계를 도구 호출로 수행한다.
2. **정규화는 수동**: 3개 결과의 자동 클러스터링은 불가능. PM이 읽고 매핑한다.
3. **소요 시간**: 3-way ~3분, 2-way ~1분 (GLM이 가장 느림)
4. **비용**: GLM은 Z.AI 정액제 (호출당 비용 없음). Codex는 OpenAI API 비용.
5. **결과 보관**: `/tmp/hih_3way/` 결과 파일은 hih-3way-hard에서 재사용 가능.
