---
name: benchmark
description: 성능 벤치마크. curl + Python으로 응답시간/크기 측정, PR 단위 리그레션 탐지.
user-invocable: true
---

# 성능 벤치마크 (gstack /benchmark browse-free 적용판)

gstack의 /benchmark를 browse 없이 구현. curl과 Python으로 측정.

## 대상
- 웹 프로젝트: HTTP 엔드포인트 응답시간/크기
- Python 프로젝트: 주요 함수 실행시간
- 전체: 빌드 시간, 테스트 실행시간

## 워크플로우

### Step 1: 측정 대상 식별
- 웹: `grep -r "app.get\|app.post\|@router" --include="*.py"` → API 엔드포인트
- Next.js: `ls app/**/page.tsx` → 페이지 라우트
- `--endpoints URL1,URL2` 직접 지정 가능

### Step 2: 베이스라인 측정
```bash
# HTTP 엔드포인트
curl -w "%{time_total},%{size_download},%{http_code}" -o /dev/null -s URL

# Python 함수
python3 -c "import time; t=time.time(); FUNC(); print(time.time()-t)"

# 빌드 시간
time npm run build 2>&1 | tail -1

# 테스트 시간
time pytest 2>&1 | tail -1
```

### Step 3: 비교 (이전 기준선 대비)
- 기준선 파일: `~/.pm_logs/benchmark_{프로젝트}_{날짜}.json`
- 델타 계산: (현재 - 기준) / 기준 × 100%

### Step 4: 리그레션 판정
| 조건 | 판정 |
|------|------|
| 응답시간 >50% 또는 >500ms 증가 | REGRESSION |
| 응답시간 >20% 증가 | WARNING |
| 번들/빌드 크기 >25% 증가 | REGRESSION |
| 그 외 | OK |

### Step 5: 리포트
```
## 벤치마크 결과 — {프로젝트}

| 엔드포인트 | 응답시간 | 크기 | 상태코드 | 판정 |
|-----------|---------|------|---------|------|
| /api/xxx | 120ms (+15%) | 2.3KB | 200 | OK |
| /api/yyy | 850ms (+60%) | 15KB | 200 | REGRESSION |

### 빌드
| 항목 | 시간 | 판정 |
|------|------|------|
| build | 45s (+10%) | OK |
| test | 12s (-5%) | OK |

### 결론: PASS / HAS_REGRESSIONS
```

기준선 저장: `~/.pm_logs/benchmark_{프로젝트}_{날짜}.json`
