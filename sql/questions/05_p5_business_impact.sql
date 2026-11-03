-- Phase 3, Step 6: P5 - business impact.
-- How much order value goes through unhappy orders, and are unhappy customers less likely to order again?
-- Repeat purchases: per person (customer_unique_id), starting when they answered the review of their
-- FIRST order; only orders placed after that count. The data is treated as ending 2018-08-31, because
-- it has almost no orders after that (16 in Sep, 4 in Oct 2018). Only people with a full window count.
-- Chosen window: 180 days (sees the most people order again: 929); 30, 90 and 365 days are shown as checks.
-- Run with:  python -m src.run_sql sql/questions/05_p5_business_impact.sql

-- name: Order value in unhappy orders (reviewed orders with a payment) - value linked with, not money lost
SELECT count(*) AS reviewed_orders,
       sum(paid_total) AS reviewed_value,
       sum(paid_total) FILTER (WHERE is_unhappy) AS unhappy_value,
       round(100.0 * sum(paid_total) FILTER (WHERE is_unhappy) / sum(paid_total), 2) AS unhappy_share_of_value_pct,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*), 2) AS unhappy_share_of_orders_pct,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY paid_total) FILTER (WHERE is_unhappy)     AS median_value_unhappy,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY paid_total) FILTER (WHERE NOT is_unhappy) AS median_value_other
FROM analytics.fact_order
WHERE has_review AND paid_total IS NOT NULL;

-- name: How many people ever order more than once? (whole dataset)
WITH people AS (
  SELECT c.customer_unique_id, count(*) AS orders
  FROM analytics.fact_order f
  JOIN analytics.dim_customer c ON c.customer_id = f.customer_id
  GROUP BY c.customer_unique_id
)
SELECT count(*) AS people,
       count(*) FILTER (WHERE orders >= 2) AS ordered_2_plus_times,
       round(100.0 * count(*) FILTER (WHERE orders >= 2) / count(*), 2) AS pct_2_plus
FROM people;

-- name: Ordered again within the window? Unhappy vs other customers, for 4 window lengths
WITH person_orders AS (
  SELECT c.customer_unique_id AS person, f.order_purchase_timestamp AS purchased,
         f.has_review, f.is_unhappy, f.review_answer_timestamp,
         row_number() OVER (PARTITION BY c.customer_unique_id
                            ORDER BY f.order_purchase_timestamp, f.order_id) AS nth_order
  FROM analytics.fact_order f
  JOIN analytics.dim_customer c ON c.customer_id = f.customer_id
), anchors AS (      -- each person's first order, if reviewed: the clock starts when they answered
  SELECT person, is_unhappy, review_answer_timestamp AS anchor
  FROM person_orders
  WHERE nth_order = 1 AND has_review
), next_order AS (   -- each person's first order placed AFTER that moment (GROUP BY + join, not a subquery per row)
  SELECT a.person, min(o.purchased) AS next_purchase
  FROM anchors a
  JOIN person_orders o ON o.person = a.person AND o.purchased > a.anchor
  GROUP BY a.person
), windows AS (
  SELECT a.is_unhappy, w.days,
         a.anchor + w.days * interval '1 day' < timestamp '2018-09-01' AS full_window,
         coalesce(n.next_purchase <= a.anchor + w.days * interval '1 day', false) AS ordered_again
  FROM anchors a
  LEFT JOIN next_order n ON n.person = a.person
  CROSS JOIN (VALUES (30), (90), (180), (365)) AS w(days)
)
SELECT days AS window_days,
       count(*) FILTER (WHERE full_window) AS people_full_window,
       count(*) FILTER (WHERE full_window AND is_unhappy) AS unhappy_people,
       count(*) FILTER (WHERE full_window AND is_unhappy AND ordered_again) AS unhappy_who_ordered_again,
       round(100.0 * count(*) FILTER (WHERE full_window AND is_unhappy AND ordered_again)
             / count(*) FILTER (WHERE full_window AND is_unhappy), 2) AS repeat_pct_unhappy,
       count(*) FILTER (WHERE full_window AND NOT is_unhappy) AS other_people,
       round(100.0 * count(*) FILTER (WHERE full_window AND NOT is_unhappy AND ordered_again)
             / count(*) FILTER (WHERE full_window AND NOT is_unhappy), 2) AS repeat_pct_other,
       count(*) FILTER (WHERE full_window AND ordered_again) AS people_who_ordered_again
FROM windows
GROUP BY days
ORDER BY days;
