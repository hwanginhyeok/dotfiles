---
name: hih-bea-design
description: be-a-studio 카드뉴스 디자인 생성·검증 규칙 SSOT. 신규 스타일을 12슬롯 동적 풀세트로 만들고 7게이트로 검증. Codex HTML 생성 + Mustache 동적 + 브랜드 일관. Use when "be-a-studio 디자인 추가", "카드 스타일 생성", "디자인 게이트 검사", "candidate 풀세트".
---

# /hih-bea-design — be-a-studio 카드 디자인 생성·검증 SSOT

> 2026-06-06 정립(야간 멀티에이전트 17종 풀세트 + 외부 3-way 리뷰 codex+GLM 교정 반영).
> 목적: 신규 카드 디자인을 **동적(Mustache)·브랜드 일관·게이트 통과** 상태로 일관 생성.

## 설계 원칙 (외부 리뷰로 검증된 것)
1. **디자인 HTML은 Codex가 생성** (clone+recolor 아님 — 실 레이아웃 설계). cover를 few-shot로 톤 일관.
2. **scaffold 재사용**: README frontmatter + render_candidate_style.py + ai_background_gen. 바닥부터 X.
3. **production photo 변수 = `{{photo_url}}`** (render_candidate_style.py:56 주입). `{{photo_path}}`·절대경로 금지.
4. **accent_color는 semantic token** — 무지성 #D62828 단순치환 금지. brand_accent(#D62828 고정·배지/CTA) / style_accent(차트 자유) / divider(SharedPalette).

## 표준 12슬롯 (풀세트 필수)
`cover, content_plain, content_quote, content_list, content_data, content_qa, content_compare, content_photo_full, content_photo_caption, content_divider, content_typo_emphasis, cta`
참조 계약: `config/design_library/candidates/photo_overlay/components/` (Mustache 변수명 SSOT: {{headline}}/{{subtitle}}/{{eyebrow}}/{{body}}/{{quote}}/{{number}}/{{unit}}/{{photo_url}}/{{watermark_text}} 등).

## 생성 플로우 (스타일별)
1. **사전학습 Read**: 대상 cover.html(있으면 DNA) + photo_overlay 12슬롯(계약).
2. **Codex 생성**: 누락 슬롯을 한번에. 프롬프트 필수 명시 — "1080×1080, {{photo_url}}, Mustache 변수로 모든 콘텐츠(하드코딩 금지), 절대경로 금지, 브랜드요소(Be:An. 점#D62828 + Be:Analogue 워터마크 + 빨강 포인트), cover 톤 계승".
3. **candidate 배치**: `config/design_library/candidates/{id}/components/` + README frontmatter(photo_overlay 복사, status candidate, layouts 12 true, 사진필요 시 photo.required true).
4. **렌더**: `source .env && python scripts/render_candidate_style.py {id}` (사진슬롯은 `--content-json`으로 photo_url 주입, 템플릿엔 {{photo_url}} 유지).
5. **게이트 검증**: `python scripts/verify_design_gate.py {id}` → 7게이트 PASS 확인.

## 뉴스덱 표준 구조 (9장) — 사용자 확정 SSOT (2026-06-06)
주간 뉴스 카드뉴스는 **반드시** 이 서사 구조를 따른다(슬롯 채우기식 금지):
| # | 슬롯 | 내용 |
|---|------|------|
| 1 | cover | 주차 핵심 제목 + 테마·주차 |
| 2 | content_list | **목차** — 5토픽 인덱스 |
| 3~7 | content_photo_caption | 토픽별 **대표사진 + 헤드라인 + 요약 + 출처** ×5 |
| 8 | content_plain/divider | **마무리** — 관통 인사이트 한 줄 |
| 9 | cta | **엔딩** — Be:Analogue 아웃트로 |

### 대표사진 우선순위 (필수)
1. **실제 이미지 먼저** — 인물(공인)은 `photo_resolver` wikimedia_commons로 **실제 사진 직접**, 개념은 stock(pexels→unsplash→pixabay→wikimedia).
2. **없으면 AI 생성** — `ai_background_gen`(HQ Portra 패턴).
3. 사진 출처/방식(real-wikimedia/real-stock/ai-gen) Obsidian 노트 기록.

### 테마 고정 디자인 (주간 뉴스)
T1 테크/AI=codex_swiss · T2 아날로그/라이프=codex_kinfolk · T3 시사/경제=codex_statcard. 주간 갱신. Obsidian DB: `news_db/{theme}/{YYYY-WW}.md`(Dataview frontmatter).

## 사진 위 글자 대비 보장 원칙 — 스크림 기법 (2026-06-06 규칙화)

> **어떤 사진이 배경에 와도 글자가 항상 읽혀야 한다 (WCAG AA 4.5:1).**

### 스크림(Scrim) 원칙
- 사진 위에 글자가 겹치는 **모든 영역**에 스크림(글자 뒤 그라데이션/반투명 패널)을 깐다.
- 글자가 raw 사진이 아니라 **통제된 배경** 위에 앉도록 보장.
- 다크 스크림 + 흰 글자(권장, 가장 견고) 또는 라이트 스크림 + 다크 글자 (디자인 톤에 맞게).
- 불투명도 기준: `linear-gradient transparent → rgba(0,0,0,0.6~0.75)` 이상 — 글자 박스 전체 커버.

### 구현 패턴
```css
/* 다크 스크림 — 하단 글자 영역 */
.photo::after {
  content: "";
  position: absolute; inset: 0;
  background: linear-gradient(180deg,
    rgba(0,0,0,0.0) 40%,
    rgba(0,0,0,0.65) 100%);
}
/* 라이트 스크림 — 상단 eyebrow 영역 (밝은 배경 디자인) */
.canvas::before {
  background: linear-gradient(to bottom,
    rgba(245,241,234,0.72) 0%,
    rgba(245,241,234,0.0) 38%, ...);
}
```

### 적용 대상 슬롯 (반드시 스크림 포함)
- `cover.html` — {{photo_url}} 있는 경우
- `content_photo_caption.html`
- `content_photo_full.html`

### 검증
- G8 게이트(verify_design_gate.py)가 자동 검사: 사진 슬롯에 `linear-gradient(rgba)` 없으면 WARN.

---

## 8게이트 (verify_design_gate.py)
| # | 게이트 | 기준 |
|---|--------|------|
| 1 | 절대경로 금지 | url()/src=/href=에 file:///·/home·/mnt 0건 |
| 2 | 12슬롯 완성 | 표준 12 컴포넌트 전부 존재 |
| 3 | Mustache 동적 | content 본문/숫자/라벨 = {{변수}}, 하드코딩 샘플 0 |
| 4 | photo 계약 | {{photo_path}}·절대경로 금지; **사진 슬롯(content_photo_caption/full + photo.required=true cover)은 url()/src= 컨텍스트에 {{photo_url}} 렌더 요소 필수** (없으면 FAIL) |
| 5 | 브랜드 요소 | 전 슬롯 로고+워터마크+#D62828 |
| 6 | CSS 변수 | var(--) 권장(warn) |
| 7 | 렌더 가능 | samples/*.png >5KB |
| 8 | 사진 위 글자 대비(스크림) | 사진 슬롯(cover/photo_caption/photo_full)에 linear-gradient rgba 오버레이 없으면 WARN |

→ FAIL 0이어야 candidate 인정. **승격(templates+format_map)은 publish-gate**(사용자 시각승인 후).

## 멀티에이전트 대량 생성 (교훈)
- **Gemini/Codex 동시 호출 버스트 금지** — 워크플로 51에이전트 동시 = cascade 실패(2026-06-06). **소배치(≤3 동시) + 에이전트 내부 순차**가 안전선(검증됨).
- 발주 시 공유 계약서 파일 참조 + 스타일 그룹 3개씩.

## 자동화 연계
- git pre-commit hook: candidate 변경 시 `verify_design_gate.py --all` 자동 실행(위반 차단).
- cron(Hermes): 일간 게이트 스캔 → 위반 텔레그램 알림.

## 관련
- 계약 원본: `config/design_library/candidates/.pm_brief_fullset_contract.md`(있으면)
- 리뷰: `docs/reviews/style_review_29_*.md`, `pipeline_review_*.md`
- 디자인 토큰 분할(candidates vs templates): 메모리 `project_bea_candidates_vs_templates_split`
