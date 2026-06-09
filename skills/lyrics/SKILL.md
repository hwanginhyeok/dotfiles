---
name: lyrics
description: |
  작사가 에이전트 호출. 컨셉 → 가사. 김이나 작사법 기반.
  Use when: "가사 써줘", "작사", "2절 써줘", "브릿지", "lyrics"
allowed-tools:
  - Read
  - Write
  - Bash
  - Agent
---

# /lyrics — 작사 스킬

작사가 에이전트를 호출해서 가사를 쓴다.

## 사전 확인
```bash
ls songs/*/lyrics_v*.md 2>/dev/null | sort
cat songs/*/concept.md 2>/dev/null | grep -E "장르|BPM|핵심|화자" | head -10
```

## 작업 지시
Agent tool로 `lyricist` 에이전트를 호출한다.

프롬프트:
```
music-lab 프로젝트의 작사가로 활동해줘.
현재 작업 중인 곡의 concept.md와 기존 lyrics 파일을 읽고,
사용자의 요청에 맞게 가사를 작성해줘.

요청: [사용자 입력]

출력:
1. 작성한 가사 (섹션 마커 포함)
2. 발음 디자인 노트 (주요 라인 설명)
3. 저장 경로 제안
```

## 결과 처리
- 가사 확정 시 `lyrics_v{N}.md`로 저장 (버전업)
- `suno_prompt.md` 업데이트 필요 여부 확인
- git add + commit 제안
