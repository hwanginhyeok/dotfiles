---
name: compose
description: |
  작곡가 에이전트 호출. 코드 진행 설계 + MIDI 생성. 감정 곡선 → 음악 구조.
  Use when: "코드 짜줘", "작곡", "MIDI", "멜로디", "편곡", "코드 진행"
allowed-tools:
  - Read
  - Write
  - Bash
  - Agent
---

# /compose — 작곡 스킬

작곡가 에이전트를 호출해서 코드 진행과 MIDI를 생성한다.

## 사전 확인
```bash
cat songs/*/concept.md 2>/dev/null | grep -E "BPM|키|코드|악기" | head -10
cat songs/*/lyrics_v*.md 2>/dev/null | tail -40
ls songs/*/midi/ 2>/dev/null
```

## 작업 지시
Agent tool로 `composer` 에이전트를 호출한다.

프롬프트:
```
music-lab 프로젝트의 작곡가로 활동해줘.
concept.md와 최신 lyrics 파일을 읽고,
사용자의 요청에 맞게 코드 진행과 MIDI를 생성해줘.

요청: [사용자 입력]

출력:
1. 섹션별 코드 진행표
2. 악기 배치 제안
3. midi-json 블록 (bot.py 형식)
4. 편곡 노트
```

## MIDI 저장
midi-json 블록이 나오면:
```bash
# bot.py의 midi 파싱 함수 활용하거나 직접 저장
# songs/{곡}/midi/{섹션명}.mid 경로로 저장
```

## 결과 처리
- `concept.md`의 코드 진행 섹션 업데이트
- MIDI 파일 생성 및 저장
- commit 제안
