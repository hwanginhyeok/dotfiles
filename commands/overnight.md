---
name: overnight
description: 야간작업 실행. 각 프로젝트의 tonight_prompt.txt를 확인하고 tmux 세션에 투입.
user-invocable: true
---

# 야간작업 실행

## 실행 절차

1. **tonight_prompt 확인**: 아래 프로젝트 경로에서 `tonight_prompt.txt` 존재 여부 확인
   - `~/stock/tonight_prompt.txt`
   - `~/insung_blog/tonight_prompt.txt`
   - `~/my-politics-stats/tonight_prompt.txt`
   - `~/physical_AI_rs500/tonight_prompt.txt`

2. **프롬프트 내용 표시**: 각 프로젝트의 tonight_prompt 내용을 보여주고 확인

3. **tmux 세션 투입**: 각 프로젝트별 tmux 세션에 Claude 에이전트 투입
   - `tmux new-session -d -s overnight-{프로젝트명}`
   - overnight-runner 에이전트 사용

4. **모니터링**: 각 세션 진행 상황 주기적 확인
   - `tmux capture-pane -t overnight-{프로젝트명} -p | tail -5`

## 가드레일
- git push 금지
- .env 수정 금지
- DB 스키마 변경 금지
- 에러 3회 반복 시 스킵

## 완료 후
- 각 프로젝트의 `logs/overnight_progress.log` 확인
- 브리핑 파일 생성 여부 확인
- `tonight_prompt.txt` → `tonight_prompt_done.txt` 이름 변경 확인
