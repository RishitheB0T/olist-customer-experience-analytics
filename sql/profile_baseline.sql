-- Baseline profile of the raw layer: the whole picture, before any filtering.
-- Run with:  python -m src.run_sql sql/profile_baseline.sql

-- name: Orders by status
SELECT order_status,
       count(*) AS orders,
       round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS pct  -- share of all orders
FROM raw.orders
GROUP BY order_status
ORDER BY orders DESC;

-- name: Purchase date range
SELECT min(order_purchase_timestamp::timestamp) AS first_purchase,  -- ::timestamp turns text into a date-time
       max(order_purchase_timestamp::timestamp) AS last_purchase,
       count(*) AS orders
FROM raw.orders;

-- name: Orders per month (thin months at the edges matter for trends and P5)
SELECT date_trunc('month', order_purchase_timestamp::timestamp)::date AS month,
       count(*) AS orders
FROM raw.orders
GROUP BY 1
ORDER BY 1;

-- name: Reviews per order (review coverage)
WITH per_order AS (
    SELECT o.order_id, count(r.review_id) AS reviews  -- 0 when an order has no review
    FROM raw.orders o
    LEFT JOIN raw.order_reviews r ON r.order_id = o.order_id  -- LEFT JOIN keeps orders without reviews
    GROUP BY o.order_id
)
SELECT reviews AS reviews_per_order, count(*) AS orders
FROM per_order
GROUP BY reviews
ORDER BY reviews;

-- name: Orders with no items, by status
SELECT o.order_status, count(*) AS orders_without_items
FROM raw.orders o
WHERE NOT EXISTS (SELECT 1 FROM raw.order_items i WHERE i.order_id = o.order_id)
GROUP BY o.order_status
ORDER BY orders_without_items DESC;
