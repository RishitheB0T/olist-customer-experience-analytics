-- Checks for clean.orders and clean.customers: nothing lost, types right,
-- flags match the counts found when profiling the raw layer.
-- Run with:  python -m src.run_sql sql/check_clean_orders_customers.sql

-- name: Row counts, raw vs clean (must be equal: the clean layer deletes nothing)
SELECT 'orders' AS table_name,
       (SELECT count(*) FROM raw.orders) AS raw_rows, (SELECT count(*) FROM clean.orders) AS clean_rows
UNION ALL
SELECT 'customers', (SELECT count(*) FROM raw.customers), (SELECT count(*) FROM clean.customers);

-- name: Column types in clean.orders
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'clean' AND table_name = 'orders'
ORDER BY ordinal_position;

-- name: Flag counts (profiling found 8, 6, 166 and 23)
SELECT count(*) FILTER (WHERE flag_delivered_without_date)      AS delivered_without_date,
       count(*) FILTER (WHERE flag_delivery_date_not_delivered) AS delivery_date_not_delivered,
       count(*) FILTER (WHERE flag_handover_before_purchase)    AS handover_before_purchase,
       count(*) FILTER (WHERE flag_delivered_before_handover)   AS delivered_before_handover
FROM clean.orders;

-- name: Orders inside vs outside the main period (Jan 2017 - Aug 2018)
SELECT in_main_period, count(*) AS orders,
       min(order_purchase_timestamp)::date AS first_day, max(order_purchase_timestamp)::date AS last_day
FROM clean.orders
GROUP BY in_main_period
ORDER BY in_main_period DESC;
