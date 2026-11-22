-- 05_borrower.sql — what is known about the borrower at application time:
-- credit score, income, debt burden, employment, home ownership.

-- Q1: default rate by FICO band
SELECT
    fico_band,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_int_rate_pct
FROM resolved
GROUP BY fico_band
ORDER BY MIN(fico);

-- Q2: default rate by annual-income band
SELECT
    income_band,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(AVG(loan_amnt), 0) AS avg_loan_amnt
FROM resolved
GROUP BY income_band
ORDER BY MIN(annual_inc);

-- Q3: default rate by debt-to-income band
SELECT
    dti_band,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct
FROM resolved
GROUP BY dti_band
ORDER BY MIN(dti);

-- Q4: FICO x DTI heatmap — the two application-time risk levers together
SELECT
    fico_band,
    dti_band,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct
FROM resolved
GROUP BY fico_band, dti_band
ORDER BY MIN(fico), MIN(dti);

-- Q5: employment length, home ownership, verification status
SELECT
    CASE
        WHEN emp_length_years IS NULL THEN 'unknown'
        WHEN emp_length_years = 0 THEN '0 years'
        WHEN emp_length_years <= 2 THEN '1-2 years'
        WHEN emp_length_years <= 5 THEN '3-5 years'
        WHEN emp_length_years <= 9 THEN '6-9 years'
        ELSE '10+ years'
    END AS emp_band,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct
FROM resolved
GROUP BY emp_band
ORDER BY MIN(emp_length_years);

-- Q6: home ownership
SELECT
    home_ownership,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct
FROM resolved
GROUP BY home_ownership
ORDER BY default_rate_pct DESC;

-- Q7: verification status
SELECT
    verification_status,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct
FROM resolved
GROUP BY verification_status
ORDER BY default_rate_pct DESC;

-- Q8: the high-risk interaction — low FICO + high DTI vs everyone else
SELECT
    CASE WHEN fico < 670 AND dti >= 20 THEN 'FICO <670 AND DTI >=20'
         ELSE 'all other resolved loans' END AS segment,
    COUNT(*) AS n_loans,
    COUNT(*) FILTER (WHERE defaulted = 1) AS n_defaults,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct
FROM resolved
GROUP BY segment;
