---
name: hih-memory-sync
description: "GDrive 메모리 동기화 래퍼. hih-memory --sync를 호출. 인자: --drift-only (drift/위생 점검만). 사용: '메모리 동기화', 'GDrive 메모리', '메모리 백업', '메모리 관리 확인'."
user_invocable: true
---

# /hih-memory-sync — hih-memory 래퍼

> 이 스킬은 `/hih-memory`의 GDrive 동기화 기능을 호출하는 래퍼입니다.
> 실제 로직은 모두 `/hih-memory`에 있습니다.

## 실행

```bash
# 기본: drift 측정 + 동기화 + 위생 점검
/hih-memory --sync

# drift/위생 점검만 (업로드 없이 상태만 확인)
/hih-memory --drift-only
```

## 배경

2026-06-13: `hih-memory`와 `hih-memory-sync`가 rclone을 서로 다른 모드(sync vs copy)로 호출하여
데이터 무결성 위험이 있었습니다. 두 스킬을 통합하고 rclone copy 모드만 사용하도록 통일.

- `/hih-memory` = 통합 구현 (stale check + 학습 저장 + GDrive sync)
- `/hih-memory-sync` = 이 래퍼 (`/hih-memory --sync` 호출)

## 정책

- **rclone copy만 사용** (sync 금지). 삭제 전파 방지.
- **Home PC = primary**. 노트북은 세션 시작 시 다운로드.
- **충돌**: `--update` 기준 최신 mtime 우선.

## 자동화 (Hermes cron)

- 매일 22:30 `/hih-memory --sync` → `~/.pm_logs/memory_sync.log`

## 관련

- 실제 구현: `/hih-memory`
- 세션 종료 전체 정리: `/hih-clear`
- 동기화 경로/방법: memory `reference_memory_sync.md`
