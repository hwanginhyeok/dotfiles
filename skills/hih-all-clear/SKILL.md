---
name: hih-all-clear
description: 전 프로젝트 세션 일괄 정리. 각 세션 상황 파악 → /hih-clear → /clear. PM 오케스트레이터용 배치 종료 루틴.
user_invocable: true
---

# /hih-all-clear

PM에서 한 번에 **모든 프로젝트 tmux 세션** 정리 + 종료.

## 언제 쓰나
- 하루 작업 마무리 시 전 세션 한꺼번에 정리
- PC 재시작 전 전 프로젝트 깔끔하게 handoff
- 장기 세션 context 고갈 직전 일괄 리셋

## 실행

```bash
python3 /home/window11/project-manager/scripts/hih_all_clear.py
```

스크립트가 자동으로:
1. 실행 중인 tmux 세션 목록 파악 (PM, hermes 제외)
2. idle/busy 판정 → busy 세션 스킵
3. idle 세션에 `/hih-clear` 병렬 송신
4. 완료 폴링 (30초 간격, 최대 15분)
5. 종합 결과 보고

## 완료 후 PM 세션

PM은 자기 자신을 /clear 못 함. 스크립트 완료 후 직접:
```
/hih-clear
/clear
```

## 주의
- busy 세션(tool 실행 중)은 자동 스킵 — 수동으로 별도 처리
- .env, credentials는 각 세션의 /hih-clear가 보호
- git push는 hih-git으로 별도 진행 (hih-clear는 push 안 함)
