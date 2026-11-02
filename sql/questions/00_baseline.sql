-- Phase 3, Step 1: baseline - the whole picture before any pattern.
-- Every later result is compared with these numbers. Reads the analytics tables.
-- Run with:  python -m src.run_sql sql/questions/00_baseline.sql

-- name: Orders and dates (all orders, and the main period used for trends)
SELECT count(*) AS orders,
       min(purchase_date) AS first_day,
       max(purchase_date) AS last_day,
       count(*) FILTER (WHERE in_main_period)     AS orders_main_period,
       count(*) FILTER (WHERE NOT in_main_period) AS orders_outside
FROM analytics.fact_order;

-- name: Orders by status
SELECT order_status, count(*) AS orders,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct
FROM analytics.fact_order
GROUP BY order_status
ORDER BY orders DESC;

-- name: Review coverage, and orders with no items
SELECT count(*) AS orders,
       count(*) FILTER (WHERE has_review)     AS reviewed,
       count(*) FILTER (WHERE NOT has_review) AS not_reviewed,
       round(100.0 * count(*) FILTER (WHERE has_review) / count(*), 2) AS pct_reviewed,
       count(*) FILTER (WHERE n_items = 0)    AS no_items
FROM analytics.fact_order;

-- name: Review scores (denominator = reviewed orders)
SELECT review_score, count(*) AS orders,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct
FROM analytics.fact_order
WHERE has_review
GROUP BY review_score
ORDER BY review_score;

-- name: Main KPI - unhappy order rate and average score (denominator = reviewed orders)
SELECT 'all orders' AS orders_group,
       count(*) FILTER (WHERE has_review) AS reviewed_orders,
       count(*) FILTER (WHERE is_unhappy) AS unhappy_orders,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*) FILTER (WHERE has_review), 2) AS unhappy_rate_pct,
       round(avg(review_score), 2) AS avg_score   -- avg skips NULLs, so only reviewed orders count
FROM analytics.fact_order
UNION ALL
SELECT 'main period (Jan 2017 - Aug 2018)',
       count(*) FILTER (WHERE has_review),
       count(*) FILTER (WHERE is_unhappy),
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*) FILTER (WHERE has_review), 2),
       round(avg(review_score), 2)
FROM analytics.fact_order
WHERE in_main_period
ORDER BY orders_group;

-- name: Unhappy rate, delivered vs not delivered (P1-P4 study delivered orders, so this shows what they leave out)
SELECT CASE WHEN order_status = 'delivered' THEN 'delivered' ELSE 'not delivered' END AS status_group,
       count(*) AS orders,
       count(*) FILTER (WHERE has_review) AS reviewed_orders,
       count(*) FILTER (WHERE is_unhappy) AS unhappy_orders,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*) FILTER (WHERE has_review), 2) AS unhappy_rate_pct,
       round(avg(review_score), 2) AS avg_score,
       -- this group's share of ALL unhappy orders
       round(100.0 * count(*) FILTER (WHERE is_unhappy)
             / sum(count(*) FILTER (WHERE is_unhappy)) OVER (), 2) AS share_of_all_unhappy_pct
FROM analytics.fact_order
GROUP BY status_group
ORDER BY status_group;
