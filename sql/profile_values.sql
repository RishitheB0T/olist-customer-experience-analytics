-- Data quality, part 2: missing values, impossible dates and odd numbers.
-- Run with:  python -m src.run_sql sql/profile_values.sql

-- name: Missing values (only columns with at least one NULL)
-- to_jsonb + jsonb_each turn every row into (column, value) pairs,
-- so one query can count NULLs in every column of every table.
WITH cells AS (
              SELECT 'customers' AS table_name, kv.key AS column_name, kv.value FROM raw.customers t, jsonb_each(to_jsonb(t)) kv
    UNION ALL SELECT 'geolocation', kv.key, kv.value FROM raw.geolocation t, jsonb_each(to_jsonb(t)) kv
    UNION ALL SELECT 'order_items', kv.key, kv.value FROM raw.order_items t, jsonb_each(to_jsonb(t)) kv
    UNION ALL SELECT 'order_payments', kv.key, kv.value FROM raw.order_payments t, jsonb_each(to_jsonb(t)) kv
    UNION ALL SELECT 'order_reviews', kv.key, kv.value FROM raw.order_reviews t, jsonb_each(to_jsonb(t)) kv
    UNION ALL SELECT 'orders', kv.key, kv.value FROM raw.orders t, jsonb_each(to_jsonb(t)) kv
    UNION ALL SELECT 'products', kv.key, kv.value FROM raw.products t, jsonb_each(to_jsonb(t)) kv
    UNION ALL SELECT 'sellers', kv.key, kv.value FROM raw.sellers t, jsonb_each(to_jsonb(t)) kv
    UNION ALL SELECT 'category_translation', kv.key, kv.value FROM raw.product_category_name_translation t, jsonb_each(to_jsonb(t)) kv
)
SELECT table_name, column_name,
       count(*) FILTER (WHERE value = 'null'::jsonb) AS missing,
       count(*) AS total_rows,
       round(100.0 * count(*) FILTER (WHERE value = 'null'::jsonb) / count(*), 2) AS pct_missing
FROM cells
GROUP BY table_name, column_name
HAVING count(*) FILTER (WHERE value = 'null'::jsonb) > 0
ORDER BY table_name, missing DESC;

-- name: Order status vs delivery date (do they agree?)
SELECT order_status, count(*) AS orders,
       count(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS no_delivery_date,
       count(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL) AS has_delivery_date
FROM raw.orders
GROUP BY order_status
ORDER BY orders DESC;

-- name: Dates in an impossible order (rows where both dates exist)
SELECT count(*) FILTER (WHERE order_approved_at::timestamp < order_purchase_timestamp::timestamp) AS approved_before_purchase,
       count(*) FILTER (WHERE order_delivered_carrier_date::timestamp < order_purchase_timestamp::timestamp) AS handed_over_before_purchase,
       count(*) FILTER (WHERE order_delivered_customer_date::timestamp < order_delivered_carrier_date::timestamp) AS delivered_before_handover,
       count(*) FILTER (WHERE order_delivered_customer_date::timestamp < order_purchase_timestamp::timestamp) AS delivered_before_purchase,
       count(*) FILTER (WHERE order_estimated_delivery_date::timestamp < order_purchase_timestamp::timestamp) AS promised_before_purchase
FROM raw.orders;

-- name: Odd numbers (zero, negative or out of range)
SELECT 'order_items: price <= 0' AS check_name, count(*) AS rows FROM raw.order_items WHERE price::numeric <= 0
UNION ALL SELECT 'order_items: freight_value = 0', count(*) FROM raw.order_items WHERE freight_value::numeric = 0
UNION ALL SELECT 'order_items: freight_value < 0', count(*) FROM raw.order_items WHERE freight_value::numeric < 0
UNION ALL SELECT 'order_payments: payment_value = 0', count(*) FROM raw.order_payments WHERE payment_value::numeric = 0
UNION ALL SELECT 'order_payments: payment_installments = 0', count(*) FROM raw.order_payments WHERE payment_installments::numeric = 0
UNION ALL SELECT 'order_payments: payment_type not_defined', count(*) FROM raw.order_payments WHERE payment_type = 'not_defined'
UNION ALL SELECT 'order_reviews: score outside 1-5', count(*) FROM raw.order_reviews WHERE review_score::numeric NOT BETWEEN 1 AND 5
UNION ALL SELECT 'products: weight = 0 g', count(*) FROM raw.products WHERE product_weight_g::numeric = 0
ORDER BY 2 DESC, 1;  -- biggest first

-- name: Paid vs charged (orders where payments differ from items + delivery fees by more than 1 BRL)
WITH paid AS (SELECT order_id, sum(payment_value::numeric) AS paid FROM raw.order_payments GROUP BY order_id),
     charged AS (SELECT order_id, sum(price::numeric + freight_value::numeric) AS charged FROM raw.order_items GROUP BY order_id)
SELECT count(*) AS orders_with_both,
       count(*) FILTER (WHERE abs(paid - charged) > 1) AS differ_by_more_than_1,
       count(*) FILTER (WHERE paid - charged > 1) AS paid_more,
       count(*) FILTER (WHERE charged - paid > 1) AS paid_less
FROM paid JOIN charged USING (order_id);

-- name: Days from survey sent to answered
-- Problem rows get their own bands FIRST, so they can't slip into a normal band:
-- a missing timestamp gives a NULL gap, and NULL would otherwise fall into the ELSE band.
-- The VALUES list shows every band, even ones with 0 reviews.
WITH gaps AS (
    SELECT extract(epoch FROM review_answer_timestamp::timestamp - review_creation_date::timestamp) / 86400 AS gap
    FROM raw.order_reviews
), banded AS (
    SELECT CASE WHEN gap IS NULL THEN 1  -- either timestamp missing
                WHEN gap < 0     THEN 2  -- answered before the survey was sent
                WHEN gap < 1     THEN 3
                WHEN gap < 7     THEN 4
                WHEN gap < 30    THEN 5
                WHEN gap < 90    THEN 6
                ELSE                  7 END AS band
    FROM gaps
)
SELECT b.label AS answered_after, count(banded.band) AS reviews
FROM (VALUES (1, 'missing timestamp'), (2, 'answered before survey sent'), (3, 'under 1 day'),
             (4, '1-6 days'), (5, '7-29 days'), (6, '30-89 days'), (7, '90+ days')) AS b(band, label)
LEFT JOIN banded ON banded.band = b.band
GROUP BY b.band, b.label
ORDER BY b.band;
