---
name: hih-bea-news
description: be-a-studio weekly news card-news production, review, and publishing full pipeline. Hot-topic collection → selection → planning → photos (people = Wikidata) → deterministic 9-slide render → review → registration on Vercel dashboard. Use when "주간 뉴스 만들어", "뉴스 카드뉴스", "뉴스덱 제작", "이번 주 뉴스".
---

# /hih-bea-news — Weekly News Card-News Full Pipeline

> Established 2026-06-06. Design rules are in [[hih-bea-design]] (9-slide structure / gates). This is the SSOT for the **production + review + publishing flow**.

## 3 Fixed Themes (weekly)
| Theme | Design | Field |
|------|--------|------|
| tech | codex_swiss | AI / Big Tech / semiconductors |
| analogue | codex_kinfolk | analogue / lifestyle / wellness |
| economy | codex_statcard | current affairs / economy / stocks |
Obsidian DB: `news_db/{theme}/{YYYY-WW}.md` (Dataview frontmatter).

## Pipeline (8 stages)
1. **Collect**: WebSearch ~20 hot topics across the 3 themes (date / source / why it's hot). Real-time relevance.
2. **Select**: User picks 5 per theme (or auto-pick top by hotness).
3. **Plan (copy)**: Per topic, headline + 1–2 sentence summary + source. Korean, trustworthy and scannable.
4. **Photos**: `scripts/photo_resolver.py` — **person = resolve_person_photo(Wikidata P18, identity verification)** / concept = stock (pexels→unsplash→pixabay→wikimedia→openverse). Free commercial license only. AI fallback is the last resort.
5. **Manifest**: Write per the schema below. `manifests/week_{YYYY_WW}_{theme}.json`.
6. **Render (deterministic)**: `python scripts/render_news_deck.py --manifest <m> --out <dir> --montage` → fixed 9 slides (cover→table of contents→5 photos→outro→cta). **No improvising** — use only this script (agents must not call render_candidate_style directly; RC: T2 generic breakage).
7. **Review (QA — checklist below)**.
8. **Package + publish**: `python scripts/package_news_card.py --render-dir <dir> --manifest <m> --overwrite` → `public/cards/NW-YYYYMMDD-N/` → `python scripts/build_cards_dashboard.py` → user does [Approve + PIN] on the `be-a-studio.vercel.app` dashboard → publish to Buffer (poll_approvals */5).

## Manifest schema (SSOT — shared by render_news_deck/package)
```json
{ "theme":"tech|analogue|economy", "design_style":"codex_swiss|codex_kinfolk|codex_statcard",
  "week":"2026-W23", "cover":{"title":"","subtitle":""},
  "topics":[ {"headline":"","summary":"","source":"","photo_url":"https://","number":"$780B","unit":""} ],  // exactly 5
  "outro":{"insight":""}, "cta":{"text":"@be.analogue ..."} }
```
number/unit optional, the rest required.

## Review checklist (required — before publishing)
- [ ] **9-slide structure**: cover + table of contents (content_list) + 5 photos (content_photo_caption) + outro (content_plain) + cta
- [ ] **5 topics distinct**: `md5sum slide_0[3-7]*.png | sort -u | wc -l` = 5 (all slides differ)
- [ ] **Person identity**: person topics have a Wikidata Q-id + the actual person (generic suited man ❌). Visually confirm the PNG.
- [ ] **Photo loaded**: photo slide PNG >300KB (text cover/TOC/cta may be smaller, which is normal)
- [ ] **License**: all free commercial (PD/CC/Pexels/Pixabay/Unsplash). Google Images ❌ (copyright).
- [ ] **Visual review**: Read the deck montage to confirm photo fit and legibility (verify_before_report)

## Publishing (Vercel)
- Dashboard `be-a-studio.vercel.app/dashboard.html` → NW (purple badge) card → detail → [Approve and publish] + PIN → Supabase bea_approvals → poll_approvals (*/5) → auto_publish → Buffer.
- **External publishing is publish-gate** — user approval (PIN) is the gate.

## Automation (E — Hermes cron, day-of-week selectable)
- In the early morning on the user-chosen day: collect → (selection waits for a Telegram notification or auto top-5) → plan → photos → render_news_deck → package → dashboard build → Telegram "review/approve this week's NW cards" notification.
- Publishing only after user approval (no auto-publish).

## Lessons (preventing recurrence)
- Rendering is **render_news_deck.py only** (deterministic). Agent direct render = generic breakage.
- Person photos = **Wikidata first** (digging stock first yields generic). [[hih-bea-design]] G4 gate.
- Re-run packaging with `--overwrite`.

## Related
- Design rules / gates: [[hih-bea-design]]
- Scripts: render_news_deck.py / package_news_card.py / photo_resolver.py / build_cards_dashboard.py
