-- Analytics layer, part 1: dimension tables (the "who, what, where, when" around the facts).
-- Built from the clean layer. Fact tables (Steps 9-10) will point at these.
-- Run with:  python -m src.build_sql sql/analytics_dims.sql

-- name: Create schema analytics
CREATE SCHEMA IF NOT EXISTS analytics;

-- name: Drop old dimension tables
-- CASCADE also removes links from the fact tables; they are rebuilt after this file.
DROP TABLE IF EXISTS analytics.dim_customer, analytics.dim_seller,
                     analytics.dim_product, analytics.dim_date CASCADE;

-- name: Build analytics.dim_customer (one row per customer_id = one per order)
CREATE TABLE analytics.dim_customer AS
SELECT c.customer_id,
       c.customer_unique_id,                       -- the real person, for repeat purchases (P5)
       c.customer_zip_code_prefix AS zip_code_prefix,
       c.customer_city            AS city,
       c.customer_state           AS state,
       g.lat, g.lng,                               -- NULL when the prefix has no point (279 customers)
       g.spread_km                AS location_spread_km
FROM clean.customers c
LEFT JOIN clean.geolocation g ON g.zip_code_prefix = c.customer_zip_code_prefix;

-- name: Rule - customer_id is unique
ALTER TABLE analytics.dim_customer ADD PRIMARY KEY (customer_id);

-- name: Build analytics.dim_seller
CREATE TABLE analytics.dim_seller AS
SELECT s.seller_id,
       s.seller_zip_code_prefix AS zip_code_prefix,
       s.seller_city            AS city,
       s.seller_state           AS state,
       g.lat, g.lng,                               -- NULL when the prefix has no point (7 sellers)
       g.spread_km              AS location_spread_km
FROM clean.sellers s
LEFT JOIN clean.geolocation g ON g.zip_code_prefix = s.seller_zip_code_prefix;

-- name: Rule - seller_id is unique
ALTER TABLE analytics.dim_seller ADD PRIMARY KEY (seller_id);

-- name: Build analytics.dim_product
CREATE TABLE analytics.dim_product AS
SELECT product_id,
       product_category,                          -- English; 'unknown' for the 610 with none
       product_category_name AS product_category_pt,
       product_photos_qty,
       product_name_length,
       product_description_length,
       product_weight_g,
       product_length_cm * product_height_cm * product_width_cm AS product_volume_cm3,  -- size of the box (P3)
       flag_no_category, flag_zero_weight, flag_missing_size
FROM clean.products;

-- name: Rule - product_id is unique
ALTER TABLE analytics.dim_product ADD PRIMARY KEY (product_id);

-- name: Build analytics.dim_date (one row per day, whole calendar years)
-- Whole years from the first purchase to the latest delivered or promised day.
-- (4 item shipping deadlines in 2020 are odd values and are left outside on purpose.)
CREATE TABLE analytics.dim_date AS
WITH span AS (
  SELECT date_trunc('year', min(order_purchase_timestamp))::date AS first_day,
         (date_trunc('year', greatest(max(order_delivered_customer_date),
                                      max(order_estimated_delivery_date)::timestamp))
          + interval '1 year')::date - 1 AS last_day   -- 31 December of the last year
  FROM clean.orders
)
SELECT d::date                        AS date_day,
       extract(year FROM d)::integer    AS year,
       extract(quarter FROM d)::integer AS quarter,
       extract(month FROM d)::integer   AS month,
       to_char(d, 'Mon')              AS month_name,
       date_trunc('month', d)::date   AS month_start,     -- for monthly trends
       extract(isodow FROM d)::integer  AS day_of_week,     -- 1 = Monday ... 7 = Sunday
       to_char(d, 'Dy')               AS day_name,
       extract(isodow FROM d) IN (6, 7) AS is_weekend,
       d >= '2017-01-01' AND d < '2018-09-01' AS in_main_period  -- same rule as clean.orders
FROM span, generate_series(span.first_day, span.last_day, interval '1 day') AS d;

-- name: Rule - one row per day
ALTER TABLE analytics.dim_date ADD PRIMARY KEY (date_day);
