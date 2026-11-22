# Dashboard spec — Power BI / Tableau build

Rebuild `dashboard/index.html` as an interactive dashboard from the CSVs in
`dashboard/` (all produced by `run_analysis.py` from `data/loans.duckdb`).

## Data model
- One fact table: `resolved` loans (1,345,350 rows) — import from the DuckDB
  database or from a `resolved.csv` export. Grain: one row per loan.
- Measures:
  - `Default rate = DIVIDE(COUNTROWS(FILTER(resolved, defaulted = 1)), COUNTROWS(resolved))`
  - `Funded $ = SUM(loan_amnt)`; `Funded to defaulted $ = SUMX(FILTER(resolved, defaulted = 1), loan_amnt)`
  - `Net principal lost $ = SUMX(FILTER(resolved, defaulted = 1), loan_amnt - total_rec_prncp)`
  - `Loss rate on funded = Net principal lost $ / Funded $`
- Dimensions: grade, sub_grade, purpose, fico_band, income_band, dti_band,
  int_rate_band, loan_amnt_band, term_months, issue_year, addr_state,
  home_ownership, verification_status, emp_length_years.

## Pages
1. **Overview** — KPI cards: resolved loans, default rate, funded to
   defaulted $, net principal lost $. Bar: default rate by grade (use
   `03_grade_q1.csv` values to validate). Line: default rate by issue year,
   with a footnote that 2017–2018 are censored (most loans still Current).
2. **Borrower risk** — heatmap: FICO band × DTI band, value = default rate
   (`05_borrower_q4.csv`). Bars: default rate by FICO band, income band, DTI
   band. Slicer: grade.
3. **Product & purpose** — horizontal bar: default rate by purpose
   (`04_purpose_q1.csv`). Grouped bar: grade × term (36 vs 60 months,
   `03_grade_q4.csv`). Table: purpose × grade, top 20 by default rate
   (`04_purpose_q2.csv`).
4. **Loss concentration** — bar: net principal lost $ by grade
   (`07_concentration_q4.csv`). Cards: share of defaults from grades D–G
   (43.25%), from FICO <670 (23.26%), from debt consolidation + credit card
   (80.05%).

## Formatting
- Default rate as % with 1 decimal; dollars in $m with 1 decimal.
- Colour: sequential red scale for default rate (light = low, dark = high);
  navy `#1f3a5f` for headers, matching the static dashboard.
- Add a text box on every page: "Default rates use resolved loans only
  (Fully Paid vs Charged Off / Default). Loans still Current, Late or In
  Grace Period are excluded."

## Validation
After building, check: overall default rate = 19.96%; grade A = 6.04%,
grade G = 49.93%; 60-month term = 32.45% vs 36-month = 16.00%; net
principal lost = $3.00B. If any differs, the data load — not the visual —
is wrong; re-run `load.py`.
