-- Evidence for docs/data_quality_report.md: the numbers that the check files don't print.
-- Every number in the report comes from this file, a check_*.sql or profile_*.sql file, or the tests.
-- Run with:  python -m src.run_sql sql/report_data_quality.sql

-- name: Reviews - orders with 2+ reviews, lowest vs latest score (sensitivity check)
WITH r AS (
  SELECT order_id, review_score, review_answer_timestamp,
         count(*) OVER (PARTITION BY order_id) AS n_reviews,
         min(review_score) OVER (PARTITION BY order_id) AS lowest
  FROM clean.order_reviews
), per_order AS (
  SELECT order_id, min(review_score) AS lowest, max(review_score) AS highest,
         count(*) FILTER (WHERE review_score = lowest) AS reviews_at_lowest,
         (array_agg(review_score ORDER BY review_answer_timestamp DESC))[1] AS latest_score
  FROM r
  WHERE n_reviews > 1
  GROUP BY order_id
)
SELECT count(*) AS multi_review_orders,
       count(*) FILTER (WHERE lowest <> highest)      AS scores_differ,
       count(*) FILTER (WHERE reviews_at_lowest > 1)  AS tie_at_lowest,
       count(*) FILTER (WHERE lowest <= 2)            AS unhappy_by_lowest,
       count(*) FILTER (WHERE latest_score <= 2)      AS unhappy_by_latest,
       count(*) FILTER (WHERE lowest <= 2) - count(*) FILTER (WHERE latest_score <= 2) AS extra_unhappy_from_rule
FROM per_order;

-- name: Reviews - reused review_ids: same person and same score?
WITH reused AS (
  SELECT r.review_id, count(*) AS orders,
         count(DISTINCT r.review_score) AS distinct_scores,
         count(DISTINCT c.customer_unique_id) AS distinct_people
  FROM clean.order_reviews r
  JOIN clean.orders o    ON o.order_id = r.order_id
  JOIN clean.customers c ON c.customer_id = o.customer_id
  GROUP BY r.review_id
  HAVING count(*) > 1
)
SELECT count(*) AS reused_review_ids, sum(orders) AS rows_with_reused_id,
       count(*) FILTER (WHERE distinct_scores > 1) AS ids_with_different_scores,
       count(*) FILTER (WHERE distinct_people > 1) AS ids_across_different_people
FROM reused;

-- name: Reviews - survey dates that carry a time (not midnight)
SELECT count(*) AS reviews,
       count(*) FILTER (WHERE review_creation_date <> review_creation_date::date) AS not_midnight
FROM clean.order_reviews;

-- name: Money - amount paid vs items + fees, and paying in instalments
WITH items AS (
  SELECT order_id, sum(price + freight_value) AS items_total FROM clean.order_items GROUP BY order_id
), pay AS (
  SELECT order_id, sum(payment_value) AS paid_total, max(payment_installments) AS max_installments
  FROM clean.order_payments GROUP BY order_id
), matched AS (   -- orders that have both items and payments
  SELECT p.paid_total - i.items_total AS gap, p.max_installments
  FROM items i JOIN pay p ON p.order_id = i.order_id
)
SELECT count(*) AS orders_with_both,
       count(*) FILTER (WHERE gap > 1)  AS paid_more_by_over_1,
       count(*) FILTER (WHERE gap < -1) AS paid_less_by_over_1,
       round(100.0 * count(*) FILTER (WHERE gap > 1 AND max_installments > 1)
             / count(*) FILTER (WHERE gap > 1), 1) AS pct_paid_more_with_instalments,
       round(100.0 * count(*) FILTER (WHERE max_installments > 1) / count(*), 1) AS pct_all_with_instalments
FROM matched;

-- name: Deadlines - how many different hand-over deadlines each order has
SELECT n_deadlines, count(*) AS orders
FROM (SELECT order_id, count(DISTINCT shipping_limit_date) AS n_deadlines
      FROM clean.order_items GROUP BY order_id) d
GROUP BY n_deadlines
ORDER BY n_deadlines;

-- name: Deadlines - days from purchase to each item's deadline
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY days) AS median_days,
       count(*) FILTER (WHERE days > 60) AS items_over_60_days,
       max(days) AS longest_days
FROM (SELECT i.shipping_limit_date::date - o.order_purchase_timestamp::date AS days
      FROM clean.order_items i JOIN clean.orders o ON o.order_id = i.order_id) d;

-- name: Deadlines - the orders flagged with an odd deadline (over 60 days after purchase)
SELECT f.order_status, f.purchase_date,
       min(i.shipping_limit_date)::date AS deadline,
       min(i.shipping_limit_date)::date - f.purchase_date AS days_to_deadline
FROM analytics.fact_order f
JOIN analytics.fact_order_item i ON i.order_id = f.order_id
WHERE f.flag_odd_deadline
GROUP BY f.order_id, f.order_status, f.purchase_date
ORDER BY days_to_deadline;

-- name: Geolocation - points outside Brazil, and prefixes whose points name several states
WITH p AS (
  SELECT geolocation_zip_code_prefix AS zip,
         NOT (geolocation_lat::float BETWEEN -34 AND 6 AND geolocation_lng::float BETWEEN -74 AND -34) AS outside
  FROM raw.geolocation
)
SELECT count(*) FILTER (WHERE outside)             AS rows_outside_brazil,
       count(DISTINCT zip) FILTER (WHERE outside)  AS prefixes_with_an_outside_point,
       (SELECT count(*) FROM (SELECT zip FROM p GROUP BY zip HAVING bool_and(outside)) x) AS prefixes_all_outside,
       (SELECT count(*) FROM (SELECT geolocation_zip_code_prefix FROM raw.geolocation
                              GROUP BY 1 HAVING count(DISTINCT geolocation_state) > 1) s) AS prefixes_several_states
FROM p;
