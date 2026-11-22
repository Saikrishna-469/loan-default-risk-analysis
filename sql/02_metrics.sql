-- 02_metrics.sql — overall KPIs. All default rates use resolved loans only
-- (Fully Paid vs Charged Off / Default); transitory loans are excluded.

-- Q1: headline KPIs on resolved loans
SELECT
    COUNT(*) AS n_resolved_loans,
    COUNT(*) FILTER (WHERE defaulted = 1) AS n_defaults,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(SUM(loan_amnt), 0) AS total_funded_usd,
    ROUND(SUM(loan_amnt) FILTER (WHERE defaulted = 1), 0) AS funded_to_defaulted_usd,
    ROUND(SUM(loan_amnt - total_rec_prncp) FILTER (WHERE defaulted = 1), 0) AS net_principal_lost_usd,
    ROUND(AVG(loan_amnt), 0) AS avg_loan_amnt,
    ROUND(AVG(int_rate), 2) AS avg_int_rate_pct,
    ROUND(AVG(fico), 0) AS avg_fico
FROM resolved;

-- Q2: loan_status mix across ALL loans (shows why transitory loans are excluded)
SELECT
    loan_status,
    COUNT(*) AS n_loans,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS share_pct
FROM loans
GROUP BY loan_status
ORDER BY n_loans DESC;

-- Q3: default rate by issue year (resolved loans only)
-- Recent vintages look better partly because only their early defaults have
-- resolved; most 2017-2018 loans are still Current and excluded.
SELECT
    issue_year,
    COUNT(*) AS n_resolved,
    COUNT(*) FILTER (WHERE defaulted = 1) AS n_defaults,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(AVG(int_rate), 2) AS avg_int_rate_pct
FROM resolved
GROUP BY issue_year
ORDER BY issue_year;
