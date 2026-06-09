---
name: hih-bea-daily
description: be-a-studio 일일 카드뉴스(AN/DG 일반 카드) 수동 제작·검증 풀 파이프라인. 정상 날짜 강제·가짜날짜 금지·k 정규조정·cover PNG(제목+사진) 검증·사진라우팅/글로벌소스 반영·publish-gate. Use when "일일 카드 만들어", "daily 카드 N개", "예시 카드 생성", "AN/DG 카드 수동 제작".
---

# /hih-bea-daily — 일일 카드뉴스 수동 제작 풀 파이프라인

> 2026-06-08 정립. cron 자동화(run_daily.sh)는 별도 SSOT — 이 스킬은 **수동으로 N개 만들 때의 정규 절차 + 가드 + 검증**.
> 디자인 규칙/게이트는 [[hih-bea-design]], 주간 뉴스덱은 [[hih-bea-news]] (트랙 다름 — 9장×3테마 NW 카드).
> **배경**: 스킬 부재로 즉흥 생성하다 가짜날짜(20260699) 우회 + folin 빈커버 사고 발생(2026-06-08). 그 교훈을 가드로 내장.

## 트랙 구분 (헷갈리지 말 것)
| 트랙 | 스킬 | 산출 |
|------|------|------|
| **일일 일반 카드** | **이 스킬** | AN/DG 카드, 7~8장, card_id `AN-YYYYMMDD-NN` |
| 주간 뉴스덱 | [[hih-bea-news]] | NW 카드, 9장 고정×3테마 |

## 절대 가드 (위반 = 사고 재발)
1. **가짜 날짜 절대 금지.** card_id는 반드시 실제 날짜 `YYYYMMDD`. 큐레이션 한도 부족을 날짜 조작으로 우회 금지(20260699 사고).
2. **한도는 정규 파라미터로.** 10건 필요하면 `daily_curator.py --k N` (브랜드별 선별 수) 또는 `--k-per-brand` 조정. 우회 X.
3. **card_id 충돌 금지.** 같은 날 기존 카드가 있으면 다음 번호로 이어가기(-04~). 기존 산출물 덮어쓰기 금지.
4. **cover PNG 직접 검증.** 파일 크기/로그 추정 금지 — 반드시 Read로 열어 **제목+사진** 확인(거짓 PASS 3회 전례).
5. **publish-gate.** 생성만. 외부 발행은 사용자 승인(대시보드 PIN). vercel 배포 임의 실행 금지.

## 기획 모델 (2026-06-08 비교 채택)
기획(daily_planner→content_planner)은 **Codex가 기본**(`BEA_PLANNER=codex`). 비교 실측(PR#41): codex 84초·제목 3/3·slot 어휘 정확 vs claude 389초·2/3·느림 → **codex 채택**. codex 실패 시 GLM 자동 폴백(content_planner.py:1091). 명시 전환: `BEA_PLANNER=claude|panel|glm`.
> codex가 slot 어휘를 정확히 생성해 과거 GLM의 `slot='title'`/`cta layout='quote'` 무효 어휘 렌더 에러가 줄어듦.

## 파이프라인 (정규 — run_daily.sh SSOT)
`DATE=YYYYMMDD`. 같은 날 재수집 불필요 시 1~2 생략하고 기존 `content_queue/daily_raw/$DATE.json` 재사용.

```bash
# 1. 수집 (이미 있으면 생략)
python3 scripts/daily_collector.py --date $DATE
# 2. enrich
python3 scripts/enrich_youtube.py --raw content_queue/daily_raw/$DATE.json   # 또는 enrich_news / enrich_gemini
python3 scripts/enrich_summary.py --date $DATE
# 3. 큐레이션 — 여기서 개수 조정 (--k). 가짜날짜 대신 이걸로!
python3 scripts/daily_curator.py --date $DATE --k 10
# 4. codex 재정제
python3 scripts/enrich_summary.py --date $DATE --codex --candidates
# 5. 기획
python3 scripts/daily_planner.py --date $DATE
# 6. 프롬프트
python3 scripts/plan_to_prompt.py --date $DATE
# 7. 카피 (카드별)
python3 scripts/content_copywriter.py --card-id "$card_id"
# 8. 렌더 (카드별) — 사진 라우팅/folin title fix 자동 적용
python3 scripts/render_from_plan.py --card-id "$card_id"
# 9. provenance
python3 scripts/generate_provenance.py --card-id "$card_id"
# 10. 후검증 + 대시보드
python3 scripts/card_postcheck.py --date $DATE --alert
python3 scripts/dashboard_md.py --date $DATE
```

## 검증 체크리스트 (발행 전 필수 — PNG 직접)
- [ ] **가짜날짜 0**: 전 card_id가 실제 `$DATE`
- [ ] **완전 렌더**: 각 카드 슬라이드 에러 0 (`/tmp/render_*.log`에 terminal error 없음). 아래 "알려진 planner 어휘 에러" 확인
- [ ] **cover 제목**: cover slide PNG Read → 제목 보임 (folin/longblack 등 텍스트 스타일도 — PR#40 slot 기반 fix 반영)
- [ ] **cover 사진**: 사진 콘텐츠 카드는 photo-capable 스타일(careet/the_edit_pick/photo_overlay/folin_dark 등)에 실제 사진 렌더 (PR#39 라우팅). 텍스트 스타일(longblack 등)은 사진 없는 게 정상
- [ ] **글로벌 비중**: 소스에 글로벌(영어/RSS) 섞임 ([[reference: sources.yaml]] 한:글 ~1:1.4, PR#37)
- [ ] **스타일 다양성**: cover 스타일이 한 종으로 안 몰림

## 알려진 planner 어휘 에러 (발견 시 fix — 2026-06-08 예시 생성에서 관측)
content_planner/copywriter가 가끔 레거시/무효 어휘를 생성해 렌더 terminal error 유발:
- `slot='title'` (레거시) → 유효: `cover|cta|content_N`. slide1 slot이 title이면 cover 누락(AN-07 사고)
- cta `layout='quote'` → 유효: `''` 또는 `cta`
- data slide 필수 키 누락 → preflight 스킵
→ 발견 시 해당 `_final.json` slot/layout 교정 후 재렌더, 또는 planner 생성단 fix 발주(BAS 후속).

## 산출물
- 렌더: `rendered/{card_id}/v2/slide*.png`
- 발행: 대시보드 `be-a-studio.vercel.app` → 승인+PIN → poll_approvals(*/5) → Buffer

## 관련
- 디자인 게이트: [[hih-bea-design]] / 주간뉴스: [[hih-bea-news]]
- 스크립트: daily_collector / daily_curator(--k) / daily_planner / plan_to_prompt / content_copywriter / render_from_plan
