-- 01_load.sql — load LendingClub accepted loans (2007–2018Q4) into DuckDB.
-- Source file: Kaggle "Lending Club Loans Data" (wordsforthewise/lending-club),
-- accepted_2007_to_2018Q4.csv.gz, 2,260,701 loans, 151 columns.
-- Only the columns the analysis needs are read; the rest are dropped here.

CREATE OR REPLACE TABLE loans_raw AS
SELECT
    id, loan_amnt, funded_amnt, term, int_rate, installment,
    grade, sub_grade, emp_length, home_ownership, annual_inc,
    verification_status, issue_d, loan_status, purpose, addr_state,
    dti, fico_range_low, fico_range_high,
    total_pymnt, total_rec_prncp, total_rec_int, recoveries, out_prncp
FROM read_csv('data/raw/accepted_2007_to_2018Q4.csv.gz', header = true, all_varchar = true);

-- Cleaned analysis table. One row per accepted loan.
-- Default = loan_status 'Charged Off' or 'Default'. Fully Paid = repaid.
-- Every other status (Current, In Grace Period, Late 16-30 / 31-120 days,
-- Does not meet credit policy) is transitory: the outcome is not known yet,
-- so those loans are EXCLUDED from every default-rate denominator.
-- (Same rule as the Zenodo cleaned granting file, which drops those rows.)
CREATE OR REPLACE TABLE loans AS
SELECT
    CAST(id AS BIGINT) AS id,
    CAST(loan_amnt AS DOUBLE) AS loan_amnt,
    CAST(funded_amnt AS DOUBLE) AS funded_amnt,
    CAST(REPLACE(CAST(term AS VARCHAR), ' months', '') AS INTEGER) AS term_months,
    CAST(REPLACE(CAST(int_rate AS VARCHAR), '%', '') AS DOUBLE) AS int_rate,
    CAST(installment AS DOUBLE) AS installment,
    grade,
    sub_grade,
    CASE
        WHEN emp_length = 'n/a' THEN NULL
        WHEN emp_length = '10+ years' THEN 10
        WHEN emp_length = '< 1 year' THEN 0
        ELSE CAST(REPLACE(REPLACE(CAST(emp_length AS VARCHAR), ' years', ''), ' year', '') AS INTEGER)
    END AS emp_length_years,
    home_ownership,
    CAST(annual_inc AS DOUBLE) AS annual_inc,
    verification_status,
    CAST(strptime(CAST(issue_d AS VARCHAR), '%b-%Y') AS DATE) AS issue_date,
    CAST(RIGHT(CAST(issue_d AS VARCHAR), 4) AS INTEGER) AS issue_year,
    loan_status,
    CASE
        WHEN loan_status IN ('Charged Off', 'Default') THEN 'Default'
        WHEN loan_status = 'Fully Paid' THEN 'Fully Paid'
        ELSE 'In Progress'
    END AS outcome,
    CASE
        WHEN loan_status IN ('Charged Off', 'Default') THEN 1
        WHEN loan_status = 'Fully Paid' THEN 0
        ELSE NULL
    END AS defaulted,
    purpose,
    addr_state,
    CAST(dti AS DOUBLE) AS dti,
    (CAST(fico_range_low AS DOUBLE) + CAST(fico_range_high AS DOUBLE)) / 2 AS fico,
    CAST(total_pymnt AS DOUBLE) AS total_pymnt,
    CAST(total_rec_prncp AS DOUBLE) AS total_rec_prncp,
    CAST(total_rec_int AS DOUBLE) AS total_rec_int,
    CAST(recoveries AS DOUBLE) AS recoveries,
    CAST(out_prncp AS DOUBLE) AS out_prncp,
    -- Bands used across the analysis
    CASE
        WHEN (CAST(fico_range_low AS DOUBLE) + CAST(fico_range_high AS DOUBLE)) / 2 < 600 THEN '<600'
        WHEN (CAST(fico_range_low AS DOUBLE) + CAST(fico_range_high AS DOUBLE)) / 2 < 650 THEN '600-649'
        WHEN (CAST(fico_range_low AS DOUBLE) + CAST(fico_range_high AS DOUBLE)) / 2 < 700 THEN '650-699'
        WHEN (CAST(fico_range_low AS DOUBLE) + CAST(fico_range_high AS DOUBLE)) / 2 < 750 THEN '700-749'
        WHEN (CAST(fico_range_low AS DOUBLE) + CAST(fico_range_high AS DOUBLE)) / 2 < 800 THEN '750-799'
        ELSE '800+'
    END AS fico_band,
    CASE
        WHEN CAST(annual_inc AS DOUBLE) < 25000 THEN '<$25k'
        WHEN CAST(annual_inc AS DOUBLE) < 50000 THEN '$25-50k'
        WHEN CAST(annual_inc AS DOUBLE) < 75000 THEN '$50-75k'
        WHEN CAST(annual_inc AS DOUBLE) < 100000 THEN '$75-100k'
        WHEN CAST(annual_inc AS DOUBLE) < 150000 THEN '$100-150k'
        ELSE '$150k+'
    END AS income_band,
    CASE
        WHEN CAST(dti AS DOUBLE) < 10 THEN '<10'
        WHEN CAST(dti AS DOUBLE) < 15 THEN '10-15'
        WHEN CAST(dti AS DOUBLE) < 20 THEN '15-20'
        WHEN CAST(dti AS DOUBLE) < 25 THEN '20-25'
        WHEN CAST(dti AS DOUBLE) < 30 THEN '25-30'
        ELSE '30+'
    END AS dti_band,
    CASE
        WHEN CAST(REPLACE(CAST(int_rate AS VARCHAR), '%', '') AS DOUBLE) < 8 THEN '<8%'
        WHEN CAST(REPLACE(CAST(int_rate AS VARCHAR), '%', '') AS DOUBLE) < 11 THEN '8-11%'
        WHEN CAST(REPLACE(CAST(int_rate AS VARCHAR), '%', '') AS DOUBLE) < 14 THEN '11-14%'
        WHEN CAST(REPLACE(CAST(int_rate AS VARCHAR), '%', '') AS DOUBLE) < 17 THEN '14-17%'
        WHEN CAST(REPLACE(CAST(int_rate AS VARCHAR), '%', '') AS DOUBLE) < 20 THEN '17-20%'
        ELSE '20%+'
    END AS int_rate_band,
    CASE
        WHEN CAST(loan_amnt AS DOUBLE) < 5000 THEN '<$5k'
        WHEN CAST(loan_amnt AS DOUBLE) < 10000 THEN '$5-10k'
        WHEN CAST(loan_amnt AS DOUBLE) < 15000 THEN '$10-15k'
        WHEN CAST(loan_amnt AS DOUBLE) < 20000 THEN '$15-20k'
        WHEN CAST(loan_amnt AS DOUBLE) < 30000 THEN '$20-30k'
        ELSE '$30k+'
    END AS loan_amnt_band
FROM loans_raw
-- Drop the summary footer rows the file embeds between yearly blocks
-- (e.g. "Total amount funded in policy code 1: ..."): they have no numeric id.
WHERE TRY_CAST(id AS BIGINT) IS NOT NULL;

-- Convenience view: only loans whose outcome is known.
CREATE OR REPLACE VIEW resolved AS
SELECT * FROM loans WHERE defaulted IS NOT NULL;
