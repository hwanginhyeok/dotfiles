---
name: suno-prompt
description: |
  Suno 프롬프트 엔지니어 에이전트 호출. 컨셉 + 가사 → 최적화된 Suno 프롬프트 생성.
  Style 태그, 섹션 마커, Extend 프롬프트 포함.
  Use when: "Suno 프롬프트", "태그 만들어줘", "Suno에 넣을", "프롬프트 최적화", "suno-prompt"
allowed-tools:
  - Read
  - Write
  - Bash
  - Agent
---

# /suno-prompt — Suno 프롬프트 생성 스킬

Suno 프롬프트 엔지니어 에이전트를 호출해서 최적화된 Suno 프롬프트를 생성한다.

## 사전 확인
```bash
cat songs/*/concept.md 2>/dev/null
cat songs/*/lyrics_v*.md 2>/dev/null | tail -80
cat docs/suno_guide.md 2>/dev/null | grep -A10 "Style\|태그\|팁" | head -30
```

## 작업 지시
Agent tool로 `suno-prompt-engineer` 에이전트를 호출한다.

프롬프트:
```
music-lab 프로젝트의 Suno 프롬프트 엔지니어로 활동해줘.
concept.md, 최신 lyrics 파일, suno_guide.md를 읽고,
사용자의 요청에 맞게 Suno 프롬프트를 생성/최적화해줘.

요청: [사용자 입력]

출력:
1. Style of Music 태그 (복붙용, 200자 이내)
2. 섹션 마커 포함 전체 가사 (Suno 형식)
3. 프롬프트 설계 노트
4. Extend 프롬프트 (필요 시)
```

## 결과 처리
- `suno_prompt.md` 또는 `suno_prompt_v{N}.md`로 저장
- 기존 프롬프트 있으면 버전업
- commit 제안

## 특이 케이스
- **Extend 요청**: 기존 곡 연장. "앞부분은 좋은데 Bridge 부분부터 다시 생성하고 싶어"
- **스타일 변경**: "더 lo-fi하게", "드럼 빼줘" 등 Style 태그 수정
- **Cover 버전**: 기존 곡의 다른 아티스트 스타일 커버 프롬프트
