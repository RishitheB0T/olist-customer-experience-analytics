-- Phase 3, Step 3: P2 - delivery timing by stage (seller vs carrier) and by route.
-- P2 orders = P1 orders with one shared hand-over deadline and a hand-over date,
-- leaving out odd deadlines and impossible stage dates (flags from Phase 2).
-- Routes use single-seller orders (seller and customer states known).
-- Run with:  python -m src.run_sql sql/questions/02_p2_stages_routes.sql

-- name: Exclusion table - which orders P2 uses
SELECT step, orders
FROM (VALUES
  (1, 'P1 orders (delivered, both dates)', (SELECT count(*) FROM analytics.fact_order
       WHERE order_status = 'delivered' AND days_late IS NOT NULL)),
  (2, '+ one shared hand-over deadline', (SELECT count(*) FROM analytics.fact_order
       WHERE order_status = 'delivered' AND days_late IS NOT NULL AND has_one_deadline)),
  (3, '+ has a hand-over date', (SELECT count(*) FROM analytics.fact_order
       WHERE order_status = 'delivered' AND days_late IS NOT NULL AND has_one_deadline
         AND order_delivered_carrier_date IS NOT NULL)),
  (4, '- odd deadline or impossible stage dates (measurements)', (SELECT count(*) FROM analytics.fact_order
       WHERE order_status = 'delivered' AND days_late IS NOT NULL AND has_one_deadline
         AND order_delivered_carrier_date IS NOT NULL AND NOT flag_odd_deadline
         AND NOT flag_handover_before_purchase AND NOT flag_delivered_before_handover)),
  (5, '+ has a review (score comparisons)', (SELECT count(*) FROM analytics.fact_order
       WHERE order_status = 'delivered' AND days_late IS NOT NULL AND has_one_deadline
         AND order_delivered_carrier_date IS NOT NULL AND NOT flag_odd_deadline
         AND NOT flag_handover_before_purchase AND NOT flag_delivered_before_handover AND has_review))
) AS t(n, step, orders)
ORDER BY n;

-- name: Stages - typical days for each part, and how often each part is late
SELECT count(*) AS orders,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY seller_days)   AS median_seller_days,   -- purchase -> hand-over
       percentile_cont(0.5) WITHIN GROUP (ORDER BY carrier_days)  AS median_carrier_days,  -- hand-over -> customer
       percentile_cont(0.5) WITHIN GROUP (ORDER BY delivery_days) AS median_delivery_days,
       round(100.0 * count(*) FILTER (WHERE handover_late) / count(*), 2) AS seller_late_pct,
       round(100.0 * count(*) FILTER (WHERE is_late) / count(*), 2)       AS delivery_late_pct
FROM analytics.fact_order
WHERE order_status = 'delivered' AND days_late IS NOT NULL AND has_one_deadline
  AND order_delivered_carrier_date IS NOT NULL AND NOT flag_odd_deadline
  AND NOT flag_handover_before_purchase AND NOT flag_delivered_before_handover;

-- name: Seller hand-over x delivery promise - orders, carrier days, unhappy rate
SELECT CASE WHEN handover_late THEN 'seller late' ELSE 'seller on time' END AS hand_over,
       CASE WHEN is_late THEN 'delivery late' ELSE 'delivery on time' END   AS delivery,
       count(*) AS orders,
       -- share within the same delivery group, e.g. "of late deliveries, how many had a late seller"
       round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY CASE WHEN is_late THEN 'delivery late' ELSE 'delivery on time' END), 2)
           AS pct_of_delivery_group,  -- PARTITION BY must repeat the grouped expression exactly
       percentile_cont(0.5) WITHIN GROUP (ORDER BY carrier_days) AS median_carrier_days,
       count(*) FILTER (WHERE has_review) AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*) FILTER (WHERE has_review), 2) AS unhappy_rate_pct
FROM analytics.fact_order
WHERE order_status = 'delivered' AND days_late IS NOT NULL AND has_one_deadline
  AND order_delivered_carrier_date IS NOT NULL AND NOT flag_odd_deadline
  AND NOT flag_handover_before_purchase AND NOT flag_delivered_before_handover
GROUP BY hand_over, delivery
ORDER BY delivery, hand_over;

-- name: Routes - same state vs different state (single-seller P2 orders)
SELECT CASE WHEN s.state = c.state THEN 'same state' ELSE 'different state' END AS route,
       count(*) AS orders,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY f.distance_km)  AS median_km,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY f.carrier_days) AS median_carrier_days,
       round(100.0 * count(*) FILTER (WHERE f.is_late) / count(*), 2) AS delivery_late_pct,
       count(*) FILTER (WHERE f.has_review) AS reviewed,
       round(100.0 * count(*) FILTER (WHERE f.is_unhappy) / count(*) FILTER (WHERE f.has_review), 2) AS unhappy_rate_pct
FROM analytics.fact_order f
JOIN analytics.dim_seller s   ON s.seller_id = f.seller_id
JOIN analytics.dim_customer c ON c.customer_id = f.customer_id
WHERE f.order_status = 'delivered' AND f.days_late IS NOT NULL AND f.has_one_deadline
  AND f.order_delivered_carrier_date IS NOT NULL AND NOT f.flag_odd_deadline
  AND NOT f.flag_handover_before_purchase AND NOT f.flag_delivered_before_handover
GROUP BY route
ORDER BY route DESC;

-- name: Routes - by distance (single-seller P2 orders with both map points)
SELECT CASE WHEN distance_km < 100  THEN '1. under 100 km'
            WHEN distance_km < 500  THEN '2. 100-499 km'
            WHEN distance_km < 1000 THEN '3. 500-999 km'
            WHEN distance_km < 2000 THEN '4. 1,000-1,999 km'
            ELSE '5. 2,000+ km' END AS distance,
       count(*) AS orders,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY carrier_days) AS median_carrier_days,
       round(100.0 * count(*) FILTER (WHERE is_late) / count(*), 2) AS delivery_late_pct,
       count(*) FILTER (WHERE has_review) AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*) FILTER (WHERE has_review), 2) AS unhappy_rate_pct
FROM analytics.fact_order
WHERE order_status = 'delivered' AND days_late IS NOT NULL AND has_one_deadline
  AND order_delivered_carrier_date IS NOT NULL AND NOT flag_odd_deadline
  AND NOT flag_handover_before_purchase AND NOT flag_delivered_before_handover
  AND distance_km IS NOT NULL
GROUP BY distance
ORDER BY distance;

-- name: Routes - the 10 state-to-state routes most often late (routes with 500+ orders only)
SELECT s.state || ' -> ' || c.state AS route,
       count(*) AS orders,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY f.distance_km)  AS median_km,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY f.carrier_days) AS median_carrier_days,
       round(100.0 * count(*) FILTER (WHERE f.is_late) / count(*), 2) AS delivery_late_pct,
       round(100.0 * count(*) FILTER (WHERE f.is_unhappy) / count(*) FILTER (WHERE f.has_review), 2) AS unhappy_rate_pct
FROM analytics.fact_order f
JOIN analytics.dim_seller s   ON s.seller_id = f.seller_id
JOIN analytics.dim_customer c ON c.customer_id = f.customer_id
WHERE f.order_status = 'delivered' AND f.days_late IS NOT NULL AND f.has_one_deadline
  AND f.order_delivered_carrier_date IS NOT NULL AND NOT f.flag_odd_deadline
  AND NOT f.flag_handover_before_purchase AND NOT f.flag_delivered_before_handover
GROUP BY s.state, c.state
HAVING count(*) >= 500
ORDER BY delivery_late_pct DESC
LIMIT 10;

-- name: Described separately - P1 orders whose items have 2+ hand-over deadlines (all are multi-seller)
SELECT count(*) AS orders,
       count(*) FILTER (WHERE n_sellers > 1) AS multi_seller,
       max(days_late) AS latest_days_late,   -- below 0 = early
       percentile_cont(0.5) WITHIN GROUP (ORDER BY days_late) AS median_days_late,
       count(*) FILTER (WHERE has_review) AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*) FILTER (WHERE has_review), 2) AS unhappy_rate_pct
FROM analytics.fact_order
WHERE order_status = 'delivered' AND days_late IS NOT NULL AND NOT has_one_deadline;

-- name: Multi-seller P1 orders - almost never "late", yet often unhappy (one delivery date may not cover every parcel)
SELECT CASE WHEN has_one_deadline THEN 'one shared deadline' ELSE '2+ deadlines' END AS deadlines,
       count(*) AS orders,
       round(100.0 * count(*) FILTER (WHERE is_late) / count(*), 2) AS delivery_late_pct,
       count(*) FILTER (WHERE has_review) AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*) FILTER (WHERE has_review), 2) AS unhappy_rate_pct
FROM analytics.fact_order
WHERE order_status = 'delivered' AND days_late IS NOT NULL AND n_sellers > 1
GROUP BY deadlines
ORDER BY deadlines;
