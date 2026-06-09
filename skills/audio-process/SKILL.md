---
name: audio-process
description: |
  Suno AI 음원 후처리 파이프라인. 보컬 분리(Demucs) → 후처리(Pedalboard) →
  마스터링(Matchering) → 라우드니스(-14 LUFS). 음원 경로를 주면 자동 처리.
  Use when: "음원 처리해줘", "후처리", "마스터링", "보컬 분리", "믹싱"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# 음원 후처리 스킬

Suno AI로 생성한 음원을 릴리즈 품질로 다듬는 파이프라인.

## 사전 조건 확인

```bash
python3 -c "import demucs, pedalboard, soundfile, pyloudnorm, matchering; print('모든 패키지 OK')" 2>/dev/null || echo "MISSING_PACKAGES"
which ffmpeg 2>/dev/null || echo "FFMPEG_MISSING"
```

패키지 없으면:
```bash
pip3 install --break-system-packages pydub soundfile pyloudnorm pedalboard noisereduce demucs matchering
sudo apt install -y ffmpeg
```

## 워크플로우

### Step 0: 사용자에게 모드 확인

AskUserQuestion으로 물어보기:

> 음원 후처리 모드를 선택해주세요.

옵션:
- A) **풀 처리** — 보컬 분리 → 후처리 → 믹싱 → 마스터링 (보컬/MR 개별 조정 필요할 때)
- B) **마스터링만** — Suno 원본이 이미 좋을 때. 라우드니스 + 톤 보정만.
- C) **레퍼런스 마스터링** — 참조곡 WAV가 있을 때. 톤/라우드니스 자동 매칭.

### Step 1: 곡 디렉토리 확인

```bash
SONG_DIR=$(find songs/ -maxdepth 1 -type d | grep -v "^songs/$" | head -1)
echo "SONG_DIR: $SONG_DIR"
ls "$SONG_DIR/suno/" 2>/dev/null
```

사용자가 곡 디렉토리나 파일 경로를 지정하면 그걸 사용.
없으면 AskUserQuestion으로 파일 경로 확인.

### Step 2: 처리 스크립트 실행

**모드 A (풀 처리):**
```bash
cd "$SONG_DIR"
python3 scripts/process.py suno/INPUT_FILE.mp3
```

**모드 B (마스터링만):**
```bash
cd "$SONG_DIR"
python3 scripts/process.py suno/INPUT_FILE.mp3 --skip-separation
```

**모드 C (레퍼런스 마스터링):**
```bash
cd "$SONG_DIR"
python3 scripts/process.py suno/INPUT_FILE.mp3 -r REFERENCE_FILE.wav
```

### Step 3: 결과 확인

```bash
ls -lh "$SONG_DIR/release/"
python3 -c "
import soundfile as sf
import pyloudnorm as pyln
audio, sr = sf.read('$SONG_DIR/release/final.wav')
meter = pyln.Meter(sr)
lufs = meter.integrated_loudness(audio)
print(f'LUFS: {lufs:.1f}')
print(f'샘플레이트: {sr}')
print(f'길이: {len(audio)/sr:.1f}초')
"
```

### Step 4: 결과 보고

사용자에게 결과 보고:
- 최종 파일 경로
- LUFS 값 (-14 기준 OK/조정 필요)
- 파일 크기, 길이, 포맷
- 다음 단계 제안 (배포 준비, 추가 조정 등)

### Step 5: 파라미터 조정 (선택)

사용자가 "보컬 더 밝게", "리버브 줄여줘" 등 피드백 주면:
- `scripts/process.py`의 Pedalboard 파라미터 수정
- 재처리 실행

주요 조정 가능 파라미터:
| 파라미터 | 현재값 | 조정 방향 |
|---------|--------|----------|
| 하이패스 | 80Hz | 올리면 더 밝음, 내리면 풍성 |
| 컴프레션 ratio | 3:1 | 올리면 균일, 내리면 다이나믹 |
| 컴프레션 threshold | -20dB | 올리면 자연스러움, 내리면 꽉 참 |
| EQ 3kHz | +2dB | 보컬 프레즌스 |
| EQ 10kHz | +1.5dB | 에어/밝기 |
| 리버브 wet | 15% | 올리면 공간감, 내리면 드라이 |
| 보컬 게인 | +2dB | 보컬 볼륨 |
| 믹스 비율 | MR 75% / 보컬 85% | 보컬 앞/뒤 조절 |

## 처리 스크립트 없는 곡

`scripts/process.py`가 없는 곡이면, 기존 곡의 스크립트를 복사:
```bash
cp songs/01_봄이라고_부를게/scripts/process.py "$SONG_DIR/scripts/process.py"
```

## 주의사항

- Demucs 첫 실행 시 모델 다운로드 ~300MB
- CPU 처리 시 3~5분 소요 (GPU 있으면 ~30초)
- Matchering은 레퍼런스 곡이 WAV여야 함 (MP3 불가)
- 최종 출력: WAV 16bit 44.1kHz, -14 LUFS (Spotify/Apple Music 표준)
