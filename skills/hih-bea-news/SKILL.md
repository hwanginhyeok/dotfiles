---
name: hih-bea-news
description: be-a-studio 주간 뉴스 카드뉴스 제작·검수·발행 풀 파이프라인. 핫토픽 수집→선택→기획→사진(인물=Wikidata)→결정적 9장 렌더→검수→Vercel 대시보드 등록까지. Use when "주간 뉴스 만들어", "뉴스 카드뉴스", "뉴스덱 제작", "이번 주 뉴스".
---

# /hih-bea-news — 주간 뉴스 카드뉴스 풀 파이프라인

> 2026-06-06 정립. 디자인 규칙은 [[hih-bea-design]] (9장 구조·게이트). 이건 **제작+검수+발행 흐름** SSOT.

## 3 테마 고정 (주간)
| 테마 | 디자인 | 분야 |
|------|--------|------|
| tech | codex_swiss | AI·빅테크·반도체 |
| analogue | codex_kinfolk | 아날로그·라이프·웰니스 |
| economy | codex_statcard | 시사·경제·주식 |
Obsidian DB: `news_db/{theme}/{YYYY-WW}.md` (Dataview frontmatter).

## 파이프라인 (8단계)
1. **수집**: WebSearch로 3테마 핫토픽 ~20개(날짜·출처·왜핫한지). 실시간성.
2. **선택**: 사용자가 테마별 5개 고름(또는 핫도 상위 자동).
3. **기획(카피)**: 토픽별 헤드라인+요약1~2문장+출처. 한국어, 신뢰감·스캔성.
4. **사진**: `scripts/photo_resolver.py` — **인물=resolve_person_photo(Wikidata P18, 신원검증)** / 개념=stock(pexels→unsplash→pixabay→wikimedia→openverse). 무료 상업 라이선스만. AI 폴백은 최후.
5. **매니페스트**: 아래 스키마로 작성. `manifests/week_{YYYY_WW}_{theme}.json`.
6. **렌더(결정적)**: `python scripts/render_news_deck.py --manifest <m> --out <dir> --montage` → 9장 고정(cover→목차→사진5→마무리→cta). **임기응변 금지** — 이 스크립트만 사용(에이전트 직접 render_candidate_style 금지, T2 generic 깨짐 RC).
7. **검수(QA — 아래 체크리스트)**.
8. **패키지+발행**: `python scripts/package_news_card.py --render-dir <dir> --manifest <m> --overwrite` → `public/cards/NW-YYYYMMDD-N/` → `python scripts/build_cards_dashboard.py` → 사용자가 `be-a-studio.vercel.app` 대시보드에서 [승인+PIN] → Buffer 게시(poll_approvals */5).

## 매니페스트 스키마 (SSOT — render_news_deck/package 공용)
```json
{ "theme":"tech|analogue|economy", "design_style":"codex_swiss|codex_kinfolk|codex_statcard",
  "week":"2026-W23", "cover":{"title":"","subtitle":""},
  "topics":[ {"headline":"","summary":"","source":"","photo_url":"https://","number":"$780B","unit":""} ],  // 정확히 5
  "outro":{"insight":""}, "cta":{"text":"@be.analogue ..."} }
```
number/unit 선택, 나머지 필수.

## 검수 체크리스트 (필수 — 발행 전)
- [ ] **9장 구조**: cover + 목차(content_list) + 사진5(content_photo_caption) + 마무리(content_plain) + cta
- [ ] **5토픽 분리**: `md5sum slide_0[3-7]*.png | sort -u | wc -l` = 5 (slide 다 다름)
- [ ] **인물 신원**: 인물 토픽은 Wikidata Q-id + 실제 그 사람(generic 정장남성 ❌). PNG 시각 확인.
- [ ] **사진 로드**: 사진 슬라이드 PNG >300KB (텍스트 cover/목차/cta는 작아도 정상)
- [ ] **라이선스**: 전부 무료 상업(PD/CC/Pexels/Pixabay/Unsplash). 구글 이미지 ❌(저작권).
- [ ] **시각 검수**: 덱 몽타주 Read로 사진 적합성·가독성 확인 (verify_before_report)

## 발행 (Vercel)
- 대시보드 `be-a-studio.vercel.app/dashboard.html` → NW(보라 배지) 카드 → 상세 → [승인 후 게시]+PIN → Supabase bea_approvals → poll_approvals(*/5) → auto_publish → Buffer.
- **외부 게시는 publish-gate** — 사용자 승인(PIN)이 게이트.

## 자동화 (E — Hermes cron, 요일 선택형)
- 사용자가 정한 요일 새벽에: 수집→(선택은 텔레그램 알림 대기 or 자동 상위5)→기획→사진→render_news_deck→package→dashboard 빌드 → 텔레그램 "이번 주 NW 카드 검수/승인" 알림.
- 발행은 사용자 승인 후(자동 게시 X).

## 교훈 (재발방지)
- 렌더는 **render_news_deck.py만** (결정적). 에이전트 직접 렌더 = generic 깨짐.
- 인물 사진 = **Wikidata 우선**(스톡 먼저 뒤지면 generic). [[hih-bea-design]] G4 게이트.
- 패키지 재실행은 `--overwrite`.

## 관련
- 디자인 규칙/게이트: [[hih-bea-design]]
- 스크립트: render_news_deck.py / package_news_card.py / photo_resolver.py / build_cards_dashboard.py
