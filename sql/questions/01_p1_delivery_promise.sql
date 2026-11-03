-- Phase 3, Step 2: P1 - delivery promise and speed.
-- Is missing the promised date linked with lower scores, do scores fall the later an order is,
-- and is slow delivery linked with lower scores even when the promise was kept?
-- Measurements: all delivered orders with both dates. Scores: the reviewed ones among them.
-- Run with:  python -m src.run_sql sql/questions/01_p1_delivery_promise.sql

-- name: Exclusion table - which orders P1 uses
SELECT step, orders
FROM (VALUES
  (1, 'all orders',                       (SELECT count(*) FROM analytics.fact_order)),
  (2, 'status delivered',                 (SELECT count(*) FROM analytics.fact_order WHERE order_status = 'delivered')),
  (3, '+ delivery and promised date (measurements)',
       (SELECT count(*) FROM analytics.fact_order WHERE order_status = 'delivered' AND days_late IS NOT NULL)),
  (4, '+ has a review (score comparisons)',
       (SELECT count(*) FROM analytics.fact_order WHERE order_status = 'delivered' AND days_late IS NOT NULL AND has_review))
) AS t(n, step, orders)
ORDER BY n;

-- name: Measurements - promise kept? how long? (all P1 orders, reviewed or not)
SELECT count(*) AS orders,
       round(100.0 * count(*) FILTER (WHERE NOT is_late) / count(*), 2) AS on_time_rate_pct,
       count(*) FILTER (WHERE is_late) AS late_orders,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY delivery_days) AS median_delivery_days,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY promised_days) AS median_promised_days,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY days_late) FILTER (WHERE is_late) AS median_days_late_if_late
FROM analytics.fact_order
WHERE order_status = 'delivered' AND days_late IS NOT NULL;

-- name: By days late - share of orders (all) and unhappy rate (reviewed only)
SELECT CASE WHEN days_late <= 0 THEN '1. on time or early'
            WHEN days_late <= 3 THEN '2. 1-3 days late'
            WHEN days_late <= 7 THEN '3. 4-7 days late'
            ELSE '4. 8+ days late' END AS days_late_band,
       count(*) AS orders,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct_of_orders,
       count(*) FILTER (WHERE has_review) AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*) FILTER (WHERE has_review), 2) AS unhappy_rate_pct,
       round(avg(review_score), 2) AS avg_score
FROM analytics.fact_order
WHERE order_status = 'delivered' AND days_late IS NOT NULL
GROUP BY days_late_band
ORDER BY days_late_band;

-- name: Speed when the promise was kept - unhappy rate by delivery time (on-time orders only)
SELECT CASE WHEN delivery_days <= 7  THEN '1. 0-7 days'
            WHEN delivery_days <= 14 THEN '2. 8-14 days'
            WHEN delivery_days <= 21 THEN '3. 15-21 days'
            ELSE '4. 22+ days' END AS delivery_time,
       count(*) AS orders,
       count(*) FILTER (WHERE has_review) AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*) FILTER (WHERE has_review), 2) AS unhappy_rate_pct,
       round(avg(review_score), 2) AS avg_score
FROM analytics.fact_order
WHERE order_status = 'delivered' AND days_late <= 0
GROUP BY delivery_time
ORDER BY delivery_time;

-- name: Check - does the late vs on-time gap hold without surveys sent before delivery?
SELECT CASE WHEN is_late THEN 'late' ELSE 'on time or early' END AS promise,
       count(*) FILTER (WHERE has_review) AS reviewed_all,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*) FILTER (WHERE has_review), 2) AS unhappy_rate_all_pct,
       count(*) FILTER (WHERE has_review AND NOT flag_survey_before_delivery) AS reviewed_after_delivery,
       round(100.0 * count(*) FILTER (WHERE is_unhappy AND NOT flag_survey_before_delivery)
             / count(*) FILTER (WHERE has_review AND NOT flag_survey_before_delivery), 2) AS unhappy_rate_after_delivery_pct
FROM analytics.fact_order
WHERE order_status = 'delivered' AND days_late IS NOT NULL
GROUP BY promise
ORDER BY promise;

-- name: Check - are late orders surveyed after delivery a different mix (how late were they)?
SELECT CASE WHEN flag_survey_before_delivery THEN 'survey before delivery' ELSE 'survey after delivery' END AS survey_timing,
       count(*) AS reviewed_late_orders,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY days_late) AS median_days_late
FROM analytics.fact_order
WHERE order_status = 'delivered' AND is_late AND has_review
GROUP BY survey_timing
ORDER BY survey_timing;
