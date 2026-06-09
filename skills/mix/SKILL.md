---
name: mix
description: |
  믹싱 엔지니어 에이전트 호출. 스템 분석 + 파라미터 조정 + 재처리.
  사용자 피드백 → mix_stems.py 수정 → 재실행.
  Use when: "믹스 조정", "보컬 키워줘", "기타 줄여줘", "리버브", "믹싱", "재처리", "mix"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Agent
---

# /mix — 믹싱 스킬

믹싱 엔지니어 에이전트를 호출해서 스템 믹스를 조정하고 재처리한다.

## 사전 확인
```bash
# 현재 믹스 상태
ls -lh songs/*/processed/*.wav songs/*/release/*.wav 2>/dev/null
python3 -c "
import soundfile as sf, pyloudnorm as pyln, numpy as np
audio, sr = sf.read('songs/01_봄이라고_부를게/release/final.wav')
meter = pyln.Meter(sr)
print(f'현재 LUFS: {meter.integrated_loudness(audio):.1f}')
print(f'현재 피크: {20*np.log10(np.max(np.abs(audio))):.1f} dBFS')
" 2>/dev/null
```

## 작업 지시
Agent tool로 `mixing-engineer` 에이전트를 호출한다.

프롬프트:
```
music-lab 프로젝트의 믹싱 엔지니어로 활동해줘.
현재 스템 분석 → 사용자 피드백 반영 → mix_stems.py 파라미터 수정 → 재처리.

사용자 피드백: [사용자 입력]

출력:
1. 현재 스템별 LUFS/피크 분석
2. 피드백에 따른 파라미터 수정 계획
3. mix_stems.py 구체적 수정 내용
4. 재처리 실행
5. 변경 전/후 비교
```

## 결과 처리
- release/final.wav 갱신 확인
- LUFS -14.0 유지 확인
- 피크 -3 ~ -6 dBFS 범위 확인
- 만족스러우면 commit 제안
