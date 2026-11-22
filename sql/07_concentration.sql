-- 07_concentration.sql — where the losses actually sit: a small set of
-- segments usually drives most defaults. That is where tighter criteria pay.

-- Q1: share of all defaults coming from grades D-G
SELECT
    CASE WHEN grade IN ('D', 'E', 'F', 'G') THEN 'grades D-G'
         ELSE 'grades A-C' END AS segment,
    COUNT(*) AS n_loans,
    COUNT(*) FILTER (WHERE defaulted = 1) AS n_defaults,
    ROUND(100.0 * COUNT(*) FILTER (WHERE defaulted = 1) / SUM(COUNT(*) FILTER (WHERE defaulted = 1)) OVER (), 2) AS share_of_all_defaults_pct,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct,
    ROUND(SUM(loan_amnt) FILTER (WHERE defaulted = 1), 0) AS funded_to_defaulted_usd
FROM resolved
GROUP BY segment;

-- Q2: share of defaults from subprime FICO (<670)
SELECT
    CASE WHEN fico < 670 THEN 'FICO <670 (subprime)'
         ELSE 'FICO >=670' END AS segment,
    COUNT(*) AS n_loans,
    COUNT(*) FILTER (WHERE defaulted = 1) AS n_defaults,
    ROUND(100.0 * COUNT(*) FILTER (WHERE defaulted = 1) / SUM(COUNT(*) FILTER (WHERE defaulted = 1)) OVER (), 2) AS share_of_all_defaults_pct,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct
FROM resolved
GROUP BY segment;

-- Q3: share of defaults from the two biggest purposes
SELECT
    CASE WHEN purpose IN ('debt_consolidation', 'credit_card') THEN 'debt consolidation + credit card'
         ELSE 'all other purposes' END AS segment,
    COUNT(*) AS n_loans,
    COUNT(*) FILTER (WHERE defaulted = 1) AS n_defaults,
    ROUND(100.0 * COUNT(*) FILTER (WHERE defaulted = 1) / SUM(COUNT(*) FILTER (WHERE defaulted = 1)) OVER (), 2) AS share_of_all_defaults_pct,
    ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct
FROM resolved
GROUP BY segment;

-- Q4: expected loss by grade — funded $ to defaulted loans minus principal
-- recovered, i.e. the net principal the lender actually lost per grade.
SELECT
    grade,
    COUNT(*) FILTER (WHERE defaulted = 1) AS n_defaults,
    ROUND(SUM(loan_amnt) FILTER (WHERE defaulted = 1), 0) AS funded_to_defaulted_usd,
    ROUND(SUM(total_rec_prncp) FILTER (WHERE defaulted = 1), 0) AS principal_recovered_usd,
    ROUND(SUM(loan_amnt - total_rec_prncp) FILTER (WHERE defaulted = 1), 0) AS net_principal_lost_usd,
    ROUND(100.0 * SUM(loan_amnt - total_rec_prncp) FILTER (WHERE defaulted = 1)
        / NULLIF(SUM(loan_amnt), 0), 2) AS loss_rate_on_funded_pct
FROM resolved
GROUP BY grade
ORDER BY grade;
