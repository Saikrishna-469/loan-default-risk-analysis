-- 04_purpose.sql — what the borrower says the money is for.

-- Q1: default rate by purpose
SELECT
    purpose,
    COUNT(*) AS n_loans,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_of_loans_pct,
    COUNT(*) FILTER (WHERE defaulted = 1) AS n_defaults,
    ROUND(100.0 * COUNT(*) FILTER (WHERE defaulted = 1) / SUM(COUNT(*) FILTER (WHERE defaulted = 1)) OVER (), 2) AS share_of_defaults_pct,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(AVG(loan_amnt), 0) AS avg_loan_amnt,
    ROUND(AVG(int_rate), 2) AS avg_int_rate_pct
FROM resolved
GROUP BY purpose
ORDER BY default_rate_pct DESC;

-- Q2: purpose x grade — the riskiest purpose/grade cells (min 1,000 loans)
SELECT
    purpose,
    grade,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct
FROM resolved
GROUP BY purpose, grade
HAVING COUNT(*) >= 1000
ORDER BY default_rate_pct DESC
LIMIT 20;
