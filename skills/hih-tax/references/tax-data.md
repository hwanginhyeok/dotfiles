# Tax Figures SSOT (Single Source of Truth)

> **This file is the source for all amounts, tax rates, and thresholds.** If a number in any other reference file differs from this file, **this file takes precedence**.
> Each value carries a `시행연도` (effective year — attribution/application basis), a `검증일` (verification date — the last day a human checked the source), and an `출처` (source).
> Tax law changes on a once-a-year cycle (amendment bill announced Jul–Aug → passed by the National Assembly in Dec → takes effect Jan 1 of the following year). If `last_verified` is old, the skill re-checks at the point of use.

```yaml
meta:
  기준_귀속연도: 2025          # filing for May 2026
  last_verified: 2026-05-31
  다음_점검_권장: 2026-08-01    # tax-amendment-bill announcement season
```

---

## WATCHED FACTS (subject to change detection / JIT verification)

> Core values tracked by cron detection + point-of-use verification. If a value in this table changes, the skill's advice changes.

| key | Value (2025 attribution) | 시행연도 | 검증일 | 출처 |
|-----|--------------|---------|--------|------|
| 간이과세_기준 | annual revenue under KRW 104 million | 2024.7~ | 2026-05-31 | [정책브리핑](https://www.korea.kr/news/policyNewsView.do?newsId=148930428) |
| 간이과세_예외업종_기준 | KRW 48 million (real-estate rental / taxable entertainment) | 2024.7~ | 2026-05-31 | 국세청 |
| 부가세_납부면제_기준 | annual revenue under KRW 48 million | current | 2026-05-31 | [국세청 부가세](https://www.nts.go.kr/nts/cm/cntnts/cntntsView.do?cntntsId=7693&mi=2272) |
| 종소세_세율표 | 6–45%, 8 brackets (below) | 2023~ | 2026-05-31 | [국세청 세율](https://www.nts.go.kr/nts/cm/cntnts/cntntsView.do?mi=2227&cntntsId=7667) |
| 복식부기_기준_그룹1 | KRW 300 million | current | 2026-05-31 | [국세청 기장의무](https://www.nts.go.kr/nts/cm/cntnts/cntntsView.do?mi=2230&cntntsId=7669) |
| 복식부기_기준_그룹2 | KRW 150 million | current | 2026-05-31 | 국세청 |
| 복식부기_기준_그룹3 | KRW 75 million | current | 2026-05-31 | 국세청 |
| 단순경비율_기준_그룹1/2/3 | 60 million / 36 million / 24 million | current | 2026-05-31 | 국세청 |
| 성실신고_기준_그룹1/2/3 | 1.5 billion / 750 million / 500 million | current | 2026-05-31 | 국세청 |
| 노란우산_소득공제_한도 | 6 million (income ≤ 40 million) / 4 million / 2 million | 2025~ | 2026-05-31 | [중기중앙회](https://yumam.kbiz.or.kr/yuma/contents/contents/contents.do?mnSeq=29) |
| 연금계좌_세액공제_한도 | pension savings + IRP KRW 9 million, 12–15% | current | 2026-05-31 | 국세청 |
| 전자신고세액공제 | comprehensive income tax KRW 20,000 / VAT KRW 10,000 | current | 2026-05-31 | 국세청 |
| 신용카드_발행세액공제 | 1.3% of issued amount, annual cap KRW 10 million (e-commerce possibly excluded) | sunset ~2026.12.31 | 2026-05-31 | 조특법 §46 |
| 기장세액공제 | 20% when filing simplified bookkeeping → double-entry bookkeeping, max KRW 1 million | current | 2026-05-31 | 국세청 |
| 기준경비율_배율 | simplified bookkeeping 2.8× / double-entry bookkeeping 3.4× | current | 2026-05-31 | 국세청 |
| 종소세_신고기한 | 5/1–5/31 (good-faith filing 6/30) | current | 2026-05-31 | [국세청](https://www.nts.go.kr/nts/cm/cntnts/cntntsView.do?mi=2225&cntntsId=7665) |

---

## Comprehensive Income Tax Rate Table (2025 attribution)

| Tax base | Rate | Progressive deduction |
|----------|------|----------|
| KRW 14 million or less | 6% | — |
| KRW 14 million – 50 million | 15% | 1.26 million |
| KRW 50 million – 88 million | 24% | 5.76 million |
| KRW 88 million – 150 million | 35% | 15.44 million |
| KRW 150 million – 300 million | 38% | 19.94 million |
| KRW 300 million – 500 million | 40% | 25.94 million |
| KRW 500 million – 1 billion | 42% | 35.94 million |
| over KRW 1 billion | 45% | 65.94 million |

> Computed tax = tax base × rate − progressive deduction. Local income tax of 10% is separate.

---

## Update Procedure (`/hih-tax 세법 갱신`)

When you receive a tax-law-change detection alert, or when `last_verified` is more than 6 months old:

1. **Re-verify each WATCHED FACTS key on the web** (prioritize primary sources: 국세청 / 홈택스 / 정책브리핑).
2. **Present only changed values as a diff**: `간이과세_기준: 104 million → 1XX million (source: ...)`.
3. **Only edit this file after user approval** (test-first / publish-gate: silent auto-edits are prohibited).
4. When editing, update the `검증일` of the affected row + `meta.last_verified`, and record the change in the CHANGELOG below.
5. If a change also affects figures in other reference files (business-types / tax-saving / tax-calendar), update them together.

---

## CHANGELOG (tax-law change history)

| Date | Change | 시행연도 | 출처 |
|------|------|---------|------|
| 2026-05-31 | Initial draft (2025 attribution basis finalized) | 2025 | 국세청/정책브리핑 |
| 2026-05-31 | Reinforced during testing: added credit-card issuance tax credit (1.3% / 10 million / e-commerce possibly excluded), bookkeeping tax credit (20% / 1 million), standard expense-rate multipliers (2.8× / 3.4×), e-commerce expense rate (525101 simplified 86% / standard 11.8%) | 2025 | 조특법§46/indicode/국세청 |
