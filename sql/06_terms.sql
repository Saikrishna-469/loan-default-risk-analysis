-- 06_terms.sql — loan size, term and geography.

-- Q1: default rate by loan-amount band
SELECT
    loan_amnt_band,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_int_rate_pct
FROM resolved
GROUP BY loan_amnt_band
ORDER BY MIN(loan_amnt);

-- Q2: default rate by term (36 vs 60 months)
SELECT
    term_months,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(AVG(loan_amnt), 0) AS avg_loan_amnt,
    ROUND(AVG(int_rate), 2) AS avg_int_rate_pct
FROM resolved
GROUP BY term_months
ORDER BY term_months;

-- Q3: default rate by state (min 10,000 resolved loans — small states are noisy)
SELECT
    addr_state,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct
FROM resolved
GROUP BY addr_state
HAVING COUNT(*) >= 10000
ORDER BY default_rate_pct DESC;

-- Q4: pricing check — average interest rate charged per grade
-- (does the rate ladder match the realised default ladder in 03_grade?)
SELECT
    grade,
    ROUND(MIN(int_rate), 2) AS min_rate,
    ROUND(AVG(int_rate), 2) AS avg_rate,
    ROUND(MAX(int_rate), 2) AS max_rate
FROM resolved
GROUP BY grade
ORDER BY grade;
