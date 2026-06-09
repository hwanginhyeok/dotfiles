---
name: hih-cron
description: cron 점검 + 추가/수정 시 자동 호출. 기존 cron에 합칠 수 있으면 합치고, 아니면 추가. 충돌·중복 방지.
user_invocable: true
---

# /hih-cron

cron 작업을 추가/수정할 때 호출한다. 무작정 새 줄 추가하지 말고, **기존 cron과 합칠 수 있는지 먼저 검토**한 후 결정한다.

상세 cron 스케줄 SSOT: `~/project-manager/global-rules/cron.md`

## 실행 시 동작

### 1. 현재 cron 스냅샷 확인
```bash
crontab -l
```

### 2. 추가하려는 작업 분류 (필수 출력)
```
## 추가/수정 요청
- 작업: <스크립트 경로 + 인자>
- 시각: <cron expression>
- 목적: <왜 필요한가>
- 로그 위치: <log path>
```

### 3. 합치기 후보 탐색 (필수 출력)
```
## 합치기 검토
- 같은 시각 항목: <crontab에서 매칭되는 줄들>
- 같은 디렉토리/스크립트 패밀리: <같은 프로젝트의 다른 cron>
- 합칠 수 있는가? Y / N
- 합치기 방식:
  - (A) 한 스크립트에 모드 인자 추가 (예: briefing.sh morning|evening)
  - (B) 같은 시각이면 && 또는 ; 로 체이닝
  - (C) 새 wrapper 스크립트로 묶기
  - (D) 합칠 수 없음 → 새 줄로 추가
```

### 4. 충돌 체크 (필수 출력)
```
## 충돌 체크
- 동시 실행 부담: 같은 시각에 무거운 작업 중복 시 분리
- 의존성: A가 B 결과 필요하면 시각 차이 두기
- 락 파일/DB 접근 충돌: 동일 리소스 접근하는 작업은 직렬화
```

### 5. 추천 결정 (필수 출력)
```
## 결정
- 권고: 합치기 / 추가 / 분리
- 이유: <왜>
- 적용 cron expression:
  <줄 그대로>
- 등록 방법:
  사용자가 `crontab -e`로 직접 추가 (룰: cron 등록은 사용자 직접)
- 검증: 등록 후 다음 실행 시각에 로그 확인
```

## 룰

1. **무조건 추가 금지** — 합치기 검토 거치지 않으면 진행 안 함
2. **사용자 직접 등록** — `crontab -e`만 사용. 스크립트가 자동 등록 금지 (글로벌 룰 cron.md)
3. **30일+ 로그 자동 삭제 검토** — 새 cron 추가 시 로그 회전 룰 동시 검토
4. **시각 충돌 회피** — 정각(:00)에 작업이 너무 몰리면 :05/:10/:15로 분산
5. **기존 cron 수정 시** — 변경 전후 diff 보고 후 진행

## 합치기 패턴 예시

### 패턴 A: 모드 인자
```
# Before (2줄):
0 6 * * * /path/morning_brief.sh
0 22 * * * /path/evening_brief.sh

# After (1 스크립트 + 2 cron 줄, 그러나 스크립트 내부 로직 통합):
0 6 * * * /path/brief.sh morning
0 22 * * * /path/brief.sh evening
```

### 패턴 B: 같은 시각 체이닝
```
# Before (2줄, 같은 06:00):
0 6 * * * /path/sync_a.sh
0 6 * * * /path/sync_b.sh

# After (1줄):
0 6 * * * /path/sync_a.sh && /path/sync_b.sh
```

### 패턴 C: wrapper로 묶기
```
# Before (3줄, 같은 패밀리):
0 7 * * * /path/daily_part1.sh
0 7 * * * /path/daily_part2.sh
0 7 * * * /path/daily_part3.sh

# After (1줄):
0 7 * * * /path/daily_pipeline.sh   # 내부에서 part1/2/3 순차 호출
```

## 출처
- 글로벌 룰: `~/project-manager/global-rules/cron.md` (전체 스케줄 SSOT)
- "cron 등록/변경은 사용자가 직접" 원칙 (cron.md)
