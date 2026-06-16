---
name: hih-bea-daily
description: be-a-studio daily card-news (AN/DG general cards) manual production & verification full pipeline. Real-date enforcement, fake-date prohibition, k regular adjustment, cover PNG (title+photo) verification, photo-routing/global-source reflection, publish-gate. Use when "일일 카드 만들어", "daily 카드 N개", "예시 카드 생성", "AN/DG 카드 수동 제작".
---

# /hih-bea-daily — Daily Card-News Manual Production Full Pipeline

> Established 2026-06-08. The cron automation (run_daily.sh) is a separate SSOT — this skill is the **regular procedure + guards + verification for when you manually produce N cards**.
> Design rules/gates are in [[hih-bea-design]]; the weekly news deck is in [[hih-bea-news]] (different track — 9-slide × 3-theme NW cards).
> **Background**: With no skill in place, ad-hoc generation led to a fake-date (20260699) bypass + folin empty-cover incident (2026-06-08). Those lessons are baked in as guards.

## Track distinction (don't get confused)
| Track | Skill | Output |
|------|------|------|
| **Daily general cards** | **this skill** | AN/DG cards, 7~8 slides, card_id `AN-YYYYMMDD-NN` |
| Weekly news deck | [[hih-bea-news]] | NW cards, fixed 9 slides × 3 themes |

## Absolute guards (violation = incident recurrence)
1. **Fake dates absolutely prohibited.** card_id must use the real date `YYYYMMDD`. Do not work around a curation quota shortfall by manipulating the date (the 20260699 incident).
2. **Use regular parameters for quotas.** If you need 10 items, adjust `daily_curator.py --k N` (per-brand selection count) or `--k-per-brand`. No workarounds.
3. **No card_id collisions.** If existing cards already exist for the same day, continue with the next number (-04~). Do not overwrite existing outputs.
4. **Verify cover PNG directly.** Do not infer from file size/logs — you must open it with Read and confirm **title+photo** (3 prior cases of false PASS).
5. **publish-gate.** Generation only. External publishing requires user approval (dashboard PIN). Do not run vercel deploy arbitrarily.

## Planning model (adopted by comparison 2026-06-08)
Planning (daily_planner→content_planner) defaults to **Codex** (`BEA_PLANNER=codex`). Measured comparison (PR#41): codex 84s · titles 3/3 · accurate slot vocabulary vs claude 389s · 2/3 · slow → **codex adopted**. On codex failure, GLM auto-fallback (content_planner.py:1091). Explicit switch: `BEA_PLANNER=claude|panel|glm`.
> codex generates slot vocabulary accurately, reducing the past GLM render errors from invalid vocabulary like `slot='title'` / `cta layout='quote'`.

## Pipeline (regular — run_daily.sh SSOT)
`DATE=YYYYMMDD`. If recollection is unnecessary for the same day, skip 1~2 and reuse the existing `content_queue/daily_raw/$DATE.json`.

```bash
# 1. Collect (skip if it already exists)
python3 scripts/daily_collector.py --date $DATE
# 2. enrich
python3 scripts/enrich_youtube.py --raw content_queue/daily_raw/$DATE.json   # or enrich_news / enrich_gemini
python3 scripts/enrich_summary.py --date $DATE
# 3. Curation — adjust the count here (--k). Use this instead of a fake date!
python3 scripts/daily_curator.py --date $DATE --k 10
# 4. codex re-refine
python3 scripts/enrich_summary.py --date $DATE --codex --candidates
# 5. Planning
python3 scripts/daily_planner.py --date $DATE
# 6. Prompts
python3 scripts/plan_to_prompt.py --date $DATE
# 7. Copy (per card)
python3 scripts/content_copywriter.py --card-id "$card_id"
# 8. Render (per card) — photo routing/folin title fix applied automatically
python3 scripts/render_from_plan.py --card-id "$card_id"
# 9. provenance
python3 scripts/generate_provenance.py --card-id "$card_id"
# 10. Post-verification + dashboard
python3 scripts/card_postcheck.py --date $DATE --alert
python3 scripts/dashboard_md.py --date $DATE
```

## Verification checklist (required before publishing — PNG directly)
- [ ] **Zero fake dates**: every card_id uses the real `$DATE`
- [ ] **Complete render**: zero slide errors per card (no terminal error in `/tmp/render_*.log`). Check the "known planner vocabulary errors" below
- [ ] **cover title**: Read the cover slide PNG → title is visible (including text styles like folin/longblack — reflects the PR#40 slot-based fix)
- [ ] **cover photo**: photo-content cards render an actual photo on photo-capable styles (careet/the_edit_pick/photo_overlay/folin_dark etc.) (PR#39 routing). Text styles (longblack etc.) having no photo is normal
- [ ] **Global proportion**: sources mix in global (English/RSS) ([[reference: sources.yaml]] KR:global ~1:1.4, PR#37)
- [ ] **Style diversity**: cover styles aren't all clustered into one type

## Known planner vocabulary errors (fix when found — observed in 2026-06-08 example generation)
content_planner/copywriter occasionally generates legacy/invalid vocabulary, causing render terminal errors:
- `slot='title'` (legacy) → valid: `cover|cta|content_N`. If slide1 slot is title, the cover is missing (the AN-07 incident)
- cta `layout='quote'` → valid: `''` or `cta`
- missing required keys on a data slide → preflight skip
→ When found, correct the slot/layout in the relevant `_final.json` and re-render, or commission a fix at the planner generation stage (BAS follow-up).

## Outputs
- Render: `rendered/{card_id}/v2/slide*.png`
- Publish: dashboard `be-a-studio.vercel.app` → approve+PIN → poll_approvals(*/5) → Buffer

## Related
- Design gate: [[hih-bea-design]] / weekly news: [[hih-bea-news]]
- Scripts: daily_collector / daily_curator(--k) / daily_planner / plan_to_prompt / content_copywriter / render_from_plan
