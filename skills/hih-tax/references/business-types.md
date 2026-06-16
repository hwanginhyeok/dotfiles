# Classification by Business Type — Bookkeeping Obligation · Expense Rate · Taxation Type · Tax-Saving Points

> Reference point: **2025 tax year (filed in 2026)**. Re-verify amounts on Hometax right before filing.
> Use this table for business-owner profiling (SKILL STEP 1): from ① business type → determine bookkeeping obligation, expense-rate tier, and taxable/tax-exempt status.

---

## 1. Taxation Type Determination (VAT perspective)

| Type | Criteria | VAT Filing |
|------|----------|------------|
| **General taxpayer (일반과세자)** | Annual revenue 104 million KRW or more, or business type/region excluded from simplified status | Output tax 10% − input tax. Final return in Jan and Jul |
| **Simplified taxpayer (간이과세자)** | Annual revenue **under 104 million KRW** (raised from 2024.7) | Revenue × business-type VAT rate × 10%. Filed in January only |
| └ Real-estate rental · taxable entertainment | Annual revenue **under 48 million KRW** (exception business types) | Same |
| **VAT payment exemption** | Among simplified taxpayers, annual revenue **under 48 million KRW** | Must file but payment exempt; cannot issue tax invoices |
| **Tax-exempt business (면세사업자)** | VAT-exempt goods/services (tax-exempt types below) | No VAT. Instead, **business-place status report (사업장현황신고)** (2/10) |

**Excluded from simplified status (always general taxpayer)**: manufacturing, wholesale (some), licensed professionals, real-estate dealing, holding another general-taxation business place, etc. The NTS determines this at new registration.

### Tax-Exempt Business Types (VAT-exempt → subject to business-place status report)
- Medical/health (some clinics · oriental clinics · pharmacies), education (some academies · private tutoring), agricultural/livestock/fishery products (unprocessed), books · newspapers, artistic creation, residential rental, freelance personal services (some), etc.
- Tax-exempt businesses pay no VAT, but **they do pay comprehensive income tax**.

---

## 2. Bookkeeping Obligation Determination (income tax perspective)

Based on prior-year revenue (sales). **At or above the threshold = double-entry bookkeeping obligation; below it = subject to simplified bookkeeping.**

| Business Group | Representative Types | Double-Entry Bookkeeping Threshold | Simple Expense Rate Threshold (estimation) |
|-----------|----------|-------------------|----------------------|
| **Group 1** | Wholesale/retail, real-estate dealing, agriculture/forestry/fishery, mining | **300 million KRW** or more | 60 million KRW |
| **Group 2** | Manufacturing, food/lodging, construction, transport/warehousing, information & communications, finance/insurance | **150 million KRW** or more | 36 million KRW |
| **Group 3** | Real-estate rental, services (professional/scientific/technical), education, health, arts, personal services, household employment | **75 million KRW** or more | 24 million KRW |
| **Licensed professionals** | Doctors · lawyers · tax accountants · CPAs · patent attorneys · architects, etc. | **Double-entry bookkeeping mandatory regardless of amount** | Simple expense rate not applicable |

> **New business owners** are subject to simplified bookkeeping in their first year regardless of revenue (except licensed professionals and certain scales).

### Expense Rate Tiers (when filing by estimation without books)
- **Simple expense rate eligible**: below the "Simple Expense Rate Threshold" above + new business. Multiply revenue by the simple expense rate (60–90%-ish by type) to recognize expenses → very simple.
- **Standard expense rate eligible**: at or above the simple expense rate threshold. Main expenses (purchases · labor · rent) are recognized only with documentation; the rest is recognized only at the standard expense rate (usually single digit to ~10%) → without documentation, taxes balloon. **In practice, this forces bookkeeping.**
- For exact expense rates by type: Hometax 「조회/발급 > 기타조회 > 기준·단순 경비율」 or the NTS expense-rate notice.
- **Standard expense rate estimation cap (multiplier)**: standard-expense-rate income is capped at `simple-expense-rate income × multiplier`. Multiplier = 2.8x for those subject to simplified bookkeeping / 3.4x for those obligated to double-entry bookkeeping.
- Expense rate example (2025 tax year, verified 2026-05-31): e-commerce retail (525101) **simple 86.0% / standard 11.8%** ([indicode](https://indicode.kr/explanation/business/2024/525101)). Rates differ by type, so re-verify with your own code on Hometax.

### Subject to Faithful-Reporting Verification (tax accountant's verification statement required, filing deadline 6/30)
| Group | Threshold Revenue |
|------|--------------|
| Group 1 | 1.5 billion KRW or more |
| Group 2 | 750 million KRW or more |
| Group 3 | 500 million KRW or more |

---

## 3. Profiles by Business Type + Tax-Saving Points

### Restaurant / Café (Group 2)
- Taxation type: usually general/simplified. Deemed input tax credit (VAT credit on purchases of agricultural/livestock/fishery products) is key.
- Tax saving: ① deemed input tax credit (purchases of tax-exempt agricultural products) ② credit card sales tax credit ③ thorough qualified documentation for ingredients · rent · labor ④ expense out delivery-app fees.
- Pitfall: risk of being caught for omitting cash sales. Match POS · delivery-app settlements with reported sales.

### Online Shopping Mall / Open Market / Smart Store (Group 1 wholesale/retail)
- Taxation type: general if sales are large. The 300 million double-entry bookkeeping threshold is high.
- Tax saving: ① receive 100% of purchase (sourcing) tax invoices ② expense out delivery · packaging · advertising costs ③ platform fees · PG fees as expenses ④ inventory valuation.
- Pitfall: platform settlement records = reported to the NTS. Sales cannot be omitted. Aggregate across multiple platforms.

### Freelancer / Solo Knowledge Service (developer · designer · instructor · writer, Group 3 personal services)
- Usually business income with 3.3% withholding. Often a tax-exempt personal service.
- Tax saving: ① compare advantage of simple expense rate vs. actual-expense bookkeeping (for high income, bookkeeping is often more favorable) ② expense out laptop · software · communications · education costs ③ Noran Umbrella (노란우산) + pension account tax credit ④ already-withheld tax = prepaid tax refund.
- Pitfall: relying only on the simple expense rate (e.g., 64.1%) leads to excessive tax in high-income brackets.

### Hair Salon / Nail / Personal Service (Group 3)
- Tax saving: ① documentation for materials · rent · labor ② manage timing of the simplified→general transition ③ watch out for cash-receipt mandatory-issuance business types (non-issuance penalty tax).

### Academy / Tutoring Center / Private Tutoring (Group 3, partly tax-exempt)
- If tax-exempt, business-place status report (2/10). Tax saving: qualified withholding on instructor labor, materials · rent.

### Real-Estate Rental (Group 3, double-entry bookkeeping 75 million)
- Watch out for deemed rental income (deposit × fixed-deposit interest rate) being taxed. Tax saving: expense out interest costs · property tax · repair costs; consider separate-taxation residential rental (under 20 million).

### Construction / Interior / Transport (Group 2)
- Tax saving: tax invoices for outsourcing · material costs, depreciation of vehicles · equipment, qualified reporting of day-labor wages.

### Manufacturing (Group 2, double-entry bookkeeping 150 million)
- Tax saving: input tax on raw materials, machinery depreciation · integrated investment tax credit, possible startup SME reduction.

---

## 4. Determination Output Template (STEP 1 result)

```
## 세무 프로파일 — {업종}
- 업종 그룹: 그룹{n} ({대표 업종})
- 과세유형: {일반 / 간이 / 면세}  (근거: 매출 {X} {기준 비교})
- 장부의무: {복식부기 / 간편장부}  (근거: 직전매출 {X} {vs 복식부기 기준 Y})
- 추계 시 경비율: {기준경비율 / 단순경비율} 대상
- 성실신고 대상 여부: {예/아니오}
- 핵심 절세 포인트: {업종별 3가지}
```
