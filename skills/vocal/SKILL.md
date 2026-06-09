---
name: vocal
description: |
  보컬 디렉터 에이전트 호출. 보컬 스타일 정의, Suno 보컬 태그 최적화, 발음 가이드.
  Use when: "보컬 스타일", "어떤 가수 느낌", "발음 가이드", "보컬 태그", "vocal"
allowed-tools:
  - Read
  - Write
  - Bash
  - Agent
---

# /vocal — 보컬 디렉션 스킬

보컬 디렉터 에이전트를 호출해서 보컬 스타일과 Suno 태그를 최적화한다.

## 사전 확인
```bash
cat songs/*/concept.md 2>/dev/null | grep -E "보컬|스타일|참조|아티스트" | head -10
cat songs/*/suno_prompt*.md 2>/dev/null | head -10
```

## 작업 지시
Agent tool로 `vocalist` 에이전트를 호출한다.

프롬프트:
```
music-lab 프로젝트의 보컬 디렉터로 활동해줘.
concept.md와 최신 suno_prompt 파일을 읽고,
사용자의 요청에 맞게 보컬 방향을 잡아줘.

요청: [사용자 입력]

출력:
1. 추천 보컬 레퍼런스 아티스트 + 이유
2. Suno Style of Music 보컬 태그 (복붙용)
3. 섹션별 보컬 디렉션 주석
4. 발음 주의 라인 리스트
```

## 결과 처리
- `suno_prompt.md`의 Style of Music 보컬 태그 업데이트
- concept.md 보컬 섹션 업데이트
- commit 제안
