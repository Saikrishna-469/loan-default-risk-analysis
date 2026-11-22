# Cleaning notes — Loan Default Risk Analysis

## Source
- Kaggle dataset "Lending Club Loans Data" (`wordsforthewise/lending-club`), file
  `accepted_2007_to_2018Q4.csv.gz`, downloaded 2026-11-19 with no Kaggle
  account (public download endpoint). 2,260,701 data rows, 151 columns.
- Rejected-loan files in the same Kaggle download were not used: this analysis
  is about loans that were actually funded.
- LendingClub became Happen Bank in June 2026; the data are historical
  LendingClub loans, 2007–2018.

## Decisions (each one affects the numbers — documented, not hidden)

1. **Outcome definition.** Default = `loan_status` in ("Charged Off", "Default").
   Repaid = "Fully Paid". Everything else — Current (878,317 loans), Late
   16-30 / 31-120 days, In Grace Period, "Does not meet credit policy" —
   is **excluded from every default-rate denominator** because the outcome is
   not known yet. 1,345,350 loans have a resolved outcome; 915,318 do not.
   Consequence: recent vintages (2017–2018) are under-represented in default
   rates, because most of their loans are still Current. The by-year chart
   must be read with that caveat (see Limitations in the README).
2. **Embedded summary footers.** The CSV concatenates yearly extracts, each
   ending in a footer row such as
   `Total amount funded in policy code 1: 6417608175,,,,...`. 33 such rows
   were dropped (`WHERE TRY_CAST(id AS BIGINT) IS NOT NULL`). The file was
   read with `all_varchar=true` so one bad row could not abort the load.
3. **Columns kept.** Only 23 of 151 columns are loaded (see `sql/01_load.sql`).
   Dropped: free-text `desc`/`emp_title`, post-origination fields not used
   except `total_pymnt`/`total_rec_prncp`/`recoveries`/`out_prncp` (used only
   for the realised-loss calculation, never as model features), and the
   `sec_app_*` joint-application fields (rarely populated).
4. **Type cleaning.** `int_rate` ("13.49%") → numeric; `term` (" 36 months")
   → 36/60; `emp_length` ("10+ years", "< 1 year", "1 year", "n/a") →
   0–10 years or NULL (78,516 resolved loans have unknown employment length
   and default at 26.9% — the highest of any employment band, noted in the
   analysis); `issue_d` ("Jan-2015") → date + year; FICO = mean of
   `fico_range_low`/`fico_range_high`.
5. **Bands.** FICO, income, DTI, interest-rate and loan-amount bands are
   defined in `sql/01_load.sql` and used consistently in every query.
6. **No leakage in the model.** The stretch logistic regression uses only
   application-time features (FICO, DTI, income, employment length, loan
   amount, term, home ownership, purpose, verification status). Grade,
   sub-grade and interest rate are the lender's own post-application
   assessment and are excluded; post-origination fields (payments received,
   recoveries, outstanding principal) would leak the outcome.

## QA results (from `load.py`)
- Total loans loaded: 2,260,668 (2,260,701 rows − 33 footer rows)
- Issue years: 2007–2018
- Resolved outcomes: 1,345,350; transitory: 915,318
- Grades: 7 (A–G); purposes: 14
- Null grade / annual income / FICO among resolved loans: 0
- Funded amount to charged-off/defaulted loans: $4,180,709,750

## Known quirks
- **Approved loans only.** The file contains loans LendingClub actually
  funded. Rejected applications are a separate file and are not analysed
  here, so nothing in this repo describes the applicant pool — only the
  funded book. FICO in the data starts at ~660 (only 2 resolved loans below
  650): the lender's minimum score floor is visible in the data itself.
- **"Does not meet credit policy" loans** (2,749) are a small legacy bucket
  with mixed outcomes; they are counted in the resolved set when their
  status is Fully Paid / Charged Off, and in the transitory set otherwise.
  They are 0.2% of loans and do not move any headline number.
- **Verified borrowers default MORE** (Verified 23.9% vs Not Verified 14.7%).
  This is not evidence that verification causes defaults: LendingClub
  verifies income/employment more often on riskier applications, so the
  verified group is selected to be riskier. The model odds ratio for
  Verified (1.12) reflects the same selection. Do not read it causally.
- **Duplicate ids?** None found: `id` is unique across the 2,260,668 loans.
- **2018 is a partial year** (through Q4) and mostly unresolved; the 2018
  default rate (15.8%) is not comparable with 2015–2016.
