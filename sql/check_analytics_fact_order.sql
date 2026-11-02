-- Checks for analytics.fact_order.
-- Run with:  python -m src.run_sql sql/check_analytics_fact_order.sql

-- name: One row per order (joins must not add or lose rows)
SELECT (SELECT count(*) FROM clean.orders)         AS clean_orders,
       (SELECT count(*) FROM analytics.fact_order) AS fact_rows;

-- name: Money totals, clean vs fact (must match: no order counted twice)
SELECT (SELECT sum(payment_value) FROM clean.order_payments) AS clean_paid,
       (SELECT sum(paid_total) FROM analytics.fact_order)    AS fact_paid,
       (SELECT sum(price) FROM clean.order_items)            AS clean_price,
       (SELECT sum(price_total) FROM analytics.fact_order)   AS fact_price,
       (SELECT sum(freight_value) FROM clean.order_items)    AS clean_freight,
       (SELECT sum(freight_total) FROM analytics.fact_order) AS fact_freight;

-- name: Coverage (earlier steps found 98,673 reviewed, 775 without items, 1 without payment, 249 mismatches)
SELECT count(*) FILTER (WHERE has_review)          AS reviewed,
       count(*) FILTER (WHERE n_items = 0)         AS no_items,
       count(*) FILTER (WHERE paid_total IS NULL)  AS no_payment,
       count(*) FILTER (WHERE flag_paid_mismatch)  AS paid_mismatch,
       count(*) FILTER (WHERE has_one_deadline)    AS one_deadline,
       count(*) FILTER (WHERE flag_odd_deadline)   AS odd_deadline,
       count(*) FILTER (WHERE seller_id IS NOT NULL)   AS single_seller,
       count(*) FILTER (WHERE distance_km IS NOT NULL) AS with_distance
FROM analytics.fact_order;

-- name: Impossible day counts (should line up with the clean-layer flags)
SELECT count(*) FILTER (WHERE delivery_days < 0) AS negative_delivery_days,
       count(*) FILTER (WHERE seller_days < 0)   AS negative_seller_days,
       count(*) FILTER (WHERE carrier_days < 0)  AS negative_carrier_days,
       count(*) FILTER (WHERE flag_handover_before_purchase)  AS flag_handover_before_purchase,
       count(*) FILTER (WHERE flag_delivered_before_handover) AS flag_delivered_before_handover
FROM analytics.fact_order;

-- name: Distance sanity (Brazil is about 4,300 km across)
SELECT min(distance_km) AS min_km,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY distance_km) AS median_km,
       max(distance_km) AS max_km
FROM analytics.fact_order;
