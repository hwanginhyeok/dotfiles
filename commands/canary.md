---
name: canary
description: 배포 후 프로덕션 모니터링. curl로 헬스체크, 로그 감시, 상태 확인.
user-invocable: true
---

# 카나리 모니터링 (gstack /canary browse-free 적용판)

배포 후 프로덕션 상태를 주기적으로 확인한다.

## 대상 프로젝트
- insung_blog: localhost:8001 (API 서버) + 텔레그램 봇
- my-politics-stats: Vercel 배포 URL
- stock: cron 작업 상태

## 워크플로우

### Step 1: 모니터링 대상 설정
프로젝트별 헬스체크 엔드포인트:
```bash
# API 서버
curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/health

# Vercel 배포
curl -s -o /dev/null -w "%{http_code}" https://my-politics-stats.vercel.app

# tmux 세션 상태
tmux has-session -t blog 2>/dev/null && echo "OK" || echo "DOWN"
```

### Step 2: 베이스라인 캡처
배포 전 상태를 기록:
- 각 엔드포인트 응답시간/상태코드
- 프로세스 상태 (tmux 세션, 포트 리스닝)
- 최근 에러 로그 수

### Step 3: 모니터링 루프
60초 간격으로 각 엔드포인트 체크:
- **CRITICAL**: 응답 없음 또는 5xx
- **HIGH**: 새 에러 로그 발생
- **MEDIUM**: 응답시간 2배 이상 증가
- **LOW**: 경고 로그 증가
- 2회 연속 발생 시에만 알림 (일시적 오류 무시)

### Step 4: 로그 감시
```bash
# API 서버 로그
tmux capture-pane -t blog:api -p | grep -i "error\|exception\|traceback" | tail -5

# cron 실행 로그
tail -20 ~/.pm_logs/daily_*.log | grep -i "error\|fail"
```

### Step 5: 헬스 리포트
```
## 카나리 리포트 — YYYY-MM-DD HH:MM

| 서비스 | 상태 | 응답시간 | 비고 |
|--------|------|---------|------|
| API (8001) | ✅ 200 | 45ms | |
| blog tmux | ✅ 3/3 | — | api/telegram/worker |
| Vercel | ✅ 200 | 120ms | |
| cron daily | ✅ | — | 마지막 실행: 07:00 |

### 판정: HEALTHY / DEGRADED / BROKEN
```

### Step 6: 기준선 갱신
HEALTHY 판정 시 현재 상태를 새 기준선으로 저장 제안.
