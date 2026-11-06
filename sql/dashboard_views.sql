-- Dashboard layer: views (saved queries) for Power BI and the Excel workbook (Phase 6).
-- One flat row per order and one per seller, with the same bands and labels as Phases 3-5,
-- so the dashboard needs no extra logic. Views hold no data: they read the analytics tables.
-- Needs the analytics layer first (the pipeline runs this file last).
-- Run with:  python -m src.build_sql sql/dashboard_views.sql

-- name: Create schema dashboard
CREATE SCHEMA IF NOT EXISTS dashboard;

-- name: Drop old views
DROP VIEW IF EXISTS dashboard.orders, dashboard.sellers CASCADE;

-- name: Build dashboard.orders (one row per order)
CREATE VIEW dashboard.orders AS
WITH order_category AS (           -- the category, only when the order has one distinct product
  SELECT i.order_id,
         CASE WHEN count(DISTINCT i.product_id) = 1 THEN min(p.product_category)
              ELSE 'several products' END AS category
  FROM analytics.fact_order_item i
  JOIN analytics.dim_product p ON p.product_id = i.product_id
  GROUP BY i.order_id
)
SELECT f.order_id,
       f.purchase_date,
       date_trunc('month', f.purchase_date)::date AS purchase_month,
       f.order_status,
       f.order_status = 'delivered' AND f.order_delivered_customer_date IS NOT NULL AS is_delivered,
       c.state                         AS customer_state,
       f.seller_id,                                   -- NULL when the order has several sellers
       s.state                         AS seller_state,
       CASE WHEN s.state IS NULL THEN NULL
            WHEN s.state = c.state THEN 'same state' ELSE 'other state' END AS route,
       coalesce(oc.category, 'no items') AS category,
       f.delivery_days, f.days_late, f.is_late, f.handover_late, f.distance_km,
       CASE WHEN f.days_late IS NULL OR f.order_status <> 'delivered' THEN NULL    -- bands for delivered orders only
            WHEN f.days_late <= 0 THEN '1. on time or early'
            WHEN f.days_late <= 3 THEN '2. 1-3 days late'
            WHEN f.days_late <= 7 THEN '3. 4-7 days late'
            ELSE '4. 8+ days late' END AS days_late_band,
       CASE WHEN f.delivery_days IS NULL OR f.order_status <> 'delivered' THEN NULL
            WHEN f.delivery_days <= 7  THEN '1. 0-7 days'
            WHEN f.delivery_days <= 14 THEN '2. 8-14 days'
            WHEN f.delivery_days <= 21 THEN '3. 15-21 days'
            ELSE '4. 22+ days' END AS delivery_time_band,
       f.has_review,
       f.review_score,
       f.is_unhappy,
       CASE WHEN f.has_review THEN f.is_unhappy::int END AS unhappy_flag,  -- 1/0 for reviewed, NULL otherwise
       f.flag_survey_before_delivery   AS rated_before_arrival,
       f.paid_total,
       f.in_main_period
FROM analytics.fact_order f
JOIN analytics.dim_customer c     ON c.customer_id = f.customer_id
LEFT JOIN analytics.dim_seller s  ON s.seller_id = f.seller_id
LEFT JOIN order_category oc       ON oc.order_id = f.order_id;

-- name: Build dashboard.sellers (one row per seller, single-seller orders)
CREATE VIEW dashboard.sellers AS
SELECT o.seller_id,
       min(o.seller_state)                                              AS seller_state,
       count(*)                                                         AS orders,
       count(*) FILTER (WHERE o.is_delivered)                           AS delivered,
       count(*) FILTER (WHERE o.is_late AND o.is_delivered)             AS late,   -- among delivered
       count(*) FILTER (WHERE o.has_review)                             AS reviewed,
       count(*) FILTER (WHERE o.is_unhappy)                             AS unhappy,
       -- the Phase 4-5 seller measure: reviewed, delivered, on-time orders only
       count(*) FILTER (WHERE o.has_review AND o.is_delivered AND o.days_late <= 0)                  AS reviewed_on_time,
       count(*) FILTER (WHERE o.is_unhappy AND o.is_delivered AND o.days_late <= 0)                  AS unhappy_on_time,
       sum(o.paid_total)                                                AS paid_total
FROM dashboard.orders o
WHERE o.seller_id IS NOT NULL
GROUP BY o.seller_id;
