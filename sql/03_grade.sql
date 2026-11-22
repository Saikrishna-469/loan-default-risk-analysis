-- 03_grade.sql — default by LendingClub grade: the lender's own risk price.
-- Grade is assigned by the lender after application, so it is the single
-- strongest summary of assessed risk — and the check on whether the pricing
-- (interest rate) matches the realised default rate.

-- Q1: default rate by grade
SELECT
    grade,
    COUNT(*) AS n_loans,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_of_loans_pct,
    COUNT(*) FILTER (WHERE defaulted = 1) AS n_defaults,
    ROUND(100.0 * COUNT(*) FILTER (WHERE defaulted = 1) / SUM(COUNT(*) FILTER (WHERE defaulted = 1)) OVER (), 2) AS share_of_defaults_pct,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_int_rate_pct,
    ROUND(SUM(loan_amnt) FILTER (WHERE defaulted = 1), 0) AS funded_to_defaulted_usd
FROM resolved
GROUP BY grade
ORDER BY grade;

-- Q2: default rate by sub-grade (finer pricing ladder)
SELECT
    sub_grade,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_int_rate_pct
FROM resolved
GROUP BY sub_grade
ORDER BY sub_grade;

-- Q3: default rate by interest-rate band
SELECT
    int_rate_band,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_int_rate_pct
FROM resolved
GROUP BY int_rate_band
ORDER BY MIN(int_rate);

-- Q4: grade x term — does a 60-month term make the same grade riskier?
SELECT
    grade,
    term_months,
    COUNT(*) AS n_loans,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_int_rate_pct
FROM resolved
GROUP BY grade, term_months
ORDER BY grade, term_months;
