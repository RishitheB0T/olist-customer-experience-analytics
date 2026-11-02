-- Checks for analytics.fact_order_item.
-- Run with:  python -m src.run_sql sql/check_analytics_fact_order_item.sql

-- name: One row per item; money matches fact_order
SELECT (SELECT count(*) FROM clean.order_items)                AS clean_items,
       (SELECT count(*) FROM analytics.fact_order_item)        AS fact_items,
       (SELECT sum(price) FROM analytics.fact_order_item)      AS item_price,
       (SELECT sum(price_total) FROM analytics.fact_order)     AS order_price,
       (SELECT sum(freight_value) FROM analytics.fact_order_item) AS item_freight,
       (SELECT sum(freight_total) FROM analytics.fact_order)      AS order_freight;

-- name: Flags (pre-check found 383 zero fees, 12 odd deadlines in 10 orders, 1,194 items never handed over)
SELECT count(*) FILTER (WHERE flag_zero_freight)               AS zero_freight,
       count(*) FILTER (WHERE flag_odd_deadline)               AS odd_deadline_items,
       count(DISTINCT order_id) FILTER (WHERE flag_odd_deadline) AS odd_deadline_orders,
       count(*) FILTER (WHERE handover_late IS NULL)           AS no_handover_answer,
       count(*) FILTER (WHERE freight_share IS NULL)           AS no_fee_share
FROM analytics.fact_order_item;

-- name: Items agree with their order (both mismatches must be 0)
-- IS DISTINCT FROM = "not equal", but treats NULL vs NULL as equal (like Objects.equals in Java).
WITH per_order AS (
  SELECT order_id, count(*) AS n_items, bool_or(handover_late) AS any_item_late
  FROM analytics.fact_order_item
  GROUP BY order_id
)
SELECT count(*) FILTER (WHERE f.n_items <> p.n_items) AS item_count_mismatch,
       count(*) FILTER (WHERE f.has_one_deadline
                          AND f.handover_late IS DISTINCT FROM p.any_item_late) AS handover_mismatch
FROM analytics.fact_order f
JOIN per_order p ON p.order_id = f.order_id;
