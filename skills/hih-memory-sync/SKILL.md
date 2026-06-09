---
name: hih-memory-sync
description: PM 메모리를 GDrive에 동기화(백업/배포) + 메모리 위생 점검(stale/drift). 정기 관리용. Use when "메모리 동기화", "GDrive 메모리", "메모리 백업", "메모리 관리 확인".
---

# /hih-memory-sync — 메모리 GDrive 동기화 + 위생 점검

> 2026-06-06 신설. 배경: GDrive 메모리가 15일 stale(40파일 누락) 방치 사고 — /hih-clear 의존 sync가 세션 미종료 시 누락. 정기 자동화 필요.

## 무엇을 하나
1. **drift 측정**: 로컬 메모리 vs `gdrive:.claude-memory/pm/` 차이(missing/differences).
2. **업로드 동기화**: `scripts/sync_memory_gdrive.sh` 실행 (rclone copy --update, additive — 삭제 전파 X 사고방지).
3. **위생 점검**: stale 메모리(mtime 30일+) 목록 + MEMORY.md 인덱스와 실제 파일 수 정합.
4. **보고**: 전후 drift + 동기화 결과 + 위생 경고.

## 실행
```bash
# 1) 동기화 전 상태
rclone check ~/.claude/projects/-home-window11-project-manager/memory/ gdrive:.claude-memory/pm/ --exclude ".git/**" 2>&1 | grep -E "missing|differences|matching"

# 2) 동기화
bash /home/window11/project-manager/scripts/sync_memory_gdrive.sh

# 3) 위생 — 30일+ 미수정 메모리
find ~/.claude/projects/-home-window11-project-manager/memory -name '*.md' -mtime +30 -printf '%TY-%Tm-%Td %p\n' | sort

# 4) 인덱스 정합 — MEMORY.md 라인 수 vs 실제 파일 수
echo "MEMORY.md 인덱스: $(grep -cE '^\- \[' ~/.claude/projects/-home-window11-project-manager/memory/MEMORY.md) / 실제: $(find ~/.claude/projects/-home-window11-project-manager/memory -name '*.md' | wc -l)"
```

## 정책
- **additive only**(rclone copy): 삭제는 GDrive에 전파 안 함 — 멀티기기/사고로 인한 손실 방지. 의도적 삭제는 수동 `rclone sync`.
- **집 PC = primary**. 노트북은 세션 시작 시 GDrive→로컬 다운로드(reference_memory_sync).
- **충돌**: `--update`로 최신 mtime 우선.

## 자동화 (cron — Hermes)
- 매일 22:30 `sync_memory_gdrive.sh` → `~/.pm_logs/memory_sync.log`.
- 주간 위생 리포트(stale 30일+ 목록) 텔레그램 옵션.

## 관련
- 동기화 경로/방법: 메모리 `reference_memory_sync.md`
- 세션종료 정리: `/hih-memory`(stale체크+학습저장+sync), `/hih-clear`
