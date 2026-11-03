-- Phase 3, Step 4: P3 - product and value.
-- Are categories, thin listings, prices high for their category or big delivery fees linked with
-- unhappiness - for all reviewed orders and for on-time orders only?
-- Uses single-product orders (all items are one product), so each review maps to one product.
-- Every query repeats the same two CTEs: "single" (one row per single-product order) and "base".
-- Run with:  python -m src.run_sql sql/questions/03_p3_product_value.sql

-- name: Exclusion table - which orders P3 uses
WITH single AS (
  SELECT order_id FROM analytics.fact_order_item GROUP BY order_id HAVING count(DISTINCT product_id) = 1
)
SELECT step, orders
FROM (VALUES
  (1, 'orders with items',              (SELECT count(DISTINCT order_id) FROM analytics.fact_order_item)),
  (2, '+ all items are one product',    (SELECT count(*) FROM single)),
  (3, '+ has a review (all comparisons)', (SELECT count(*) FROM single s JOIN analytics.fact_order f
                                           ON f.order_id = s.order_id WHERE f.has_review)),
  (4, '+ delivered on time (on-time comparisons)', (SELECT count(*) FROM single s JOIN analytics.fact_order f
                                           ON f.order_id = s.order_id
                                           WHERE f.has_review AND f.order_status = 'delivered' AND f.days_late <= 0))
) AS t(n, step, orders)
ORDER BY n;

-- name: Categories - the 10 with the highest on-time unhappy rate (categories with 500+ reviewed orders)
WITH single AS (
  SELECT order_id, min(product_id) AS product_id FROM analytics.fact_order_item
  GROUP BY order_id HAVING count(DISTINCT product_id) = 1
), base AS (
  SELECT p.product_category, f.is_unhappy,
         f.order_status = 'delivered' AND f.days_late <= 0 AS on_time
  FROM single s
  JOIN analytics.fact_order f  ON f.order_id = s.order_id
  JOIN analytics.dim_product p ON p.product_id = s.product_id
  WHERE f.has_review
)
SELECT product_category,
       count(*) AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*), 2) AS unhappy_pct,
       count(*) FILTER (WHERE on_time) AS reviewed_on_time,
       round(100.0 * count(*) FILTER (WHERE is_unhappy AND on_time) / count(*) FILTER (WHERE on_time), 2) AS unhappy_on_time_pct
FROM base
GROUP BY product_category
HAVING count(*) >= 500
ORDER BY unhappy_on_time_pct DESC
LIMIT 10;

-- name: Categories - the 5 with the lowest on-time unhappy rate (500+ reviewed orders), and how many qualify
WITH single AS (
  SELECT order_id, min(product_id) AS product_id FROM analytics.fact_order_item
  GROUP BY order_id HAVING count(DISTINCT product_id) = 1
), base AS (
  SELECT p.product_category, f.is_unhappy,
         f.order_status = 'delivered' AND f.days_late <= 0 AS on_time
  FROM single s
  JOIN analytics.fact_order f  ON f.order_id = s.order_id
  JOIN analytics.dim_product p ON p.product_id = s.product_id
  WHERE f.has_review
), per_category AS (
  SELECT product_category, count(*) AS reviewed,
         round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*), 2) AS unhappy_pct,
         round(100.0 * count(*) FILTER (WHERE is_unhappy AND on_time) / count(*) FILTER (WHERE on_time), 2) AS unhappy_on_time_pct
  FROM base
  GROUP BY product_category
  HAVING count(*) >= 500
)
SELECT product_category, reviewed, unhappy_pct, unhappy_on_time_pct,
       count(*) OVER () AS categories_with_500_plus
FROM per_category
ORDER BY unhappy_on_time_pct
LIMIT 5;

-- name: Listings - photos and description length (products with missing listing info shown apart)
WITH single AS (
  SELECT order_id, min(product_id) AS product_id FROM analytics.fact_order_item
  GROUP BY order_id HAVING count(DISTINCT product_id) = 1
), base AS (
  SELECT p.product_photos_qty AS photos, p.product_description_length AS chars, f.is_unhappy,
         f.order_status = 'delivered' AND f.days_late <= 0 AS on_time
  FROM single s
  JOIN analytics.fact_order f  ON f.order_id = s.order_id
  JOIN analytics.dim_product p ON p.product_id = s.product_id
  WHERE f.has_review
)
SELECT 'photos' AS clue,
       CASE WHEN photos IS NULL THEN '5. missing' WHEN photos >= 4 THEN '4. 4+'
            ELSE photos::text || '. ' || photos::text || ' photo(s)' END AS band,
       count(*) AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*), 2) AS unhappy_pct,
       round(100.0 * count(*) FILTER (WHERE is_unhappy AND on_time) / count(*) FILTER (WHERE on_time), 2) AS unhappy_on_time_pct
FROM base GROUP BY band
UNION ALL
SELECT 'description',
       CASE WHEN chars IS NULL THEN '5. missing' WHEN chars < 300 THEN '1. under 300 chars'
            WHEN chars < 800 THEN '2. 300-799' WHEN chars < 1500 THEN '3. 800-1,499' ELSE '4. 1,500+' END,
       count(*),
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*), 2),
       round(100.0 * count(*) FILTER (WHERE is_unhappy AND on_time) / count(*) FILTER (WHERE on_time), 2)
FROM base GROUP BY 2
ORDER BY clue DESC, band;

-- name: Price within its category - cheapest quarter (1) to most expensive quarter (4), known categories only
WITH single AS (
  SELECT order_id, min(product_id) AS product_id, avg(price) AS unit_price FROM analytics.fact_order_item
  GROUP BY order_id HAVING count(DISTINCT product_id) = 1
), base AS (
  SELECT f.is_unhappy, s.unit_price,
         f.order_status = 'delivered' AND f.days_late <= 0 AS on_time,
         -- ntile(4): split each category's orders, sorted by price, into 4 equal-sized groups
         ntile(4) OVER (PARTITION BY p.product_category ORDER BY s.unit_price) AS price_quarter
  FROM single s
  JOIN analytics.fact_order f  ON f.order_id = s.order_id
  JOIN analytics.dim_product p ON p.product_id = s.product_id
  WHERE f.has_review AND p.product_category <> 'unknown'
)
SELECT price_quarter,
       count(*) AS reviewed,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY unit_price) AS median_price,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*), 2) AS unhappy_pct,
       round(100.0 * count(*) FILTER (WHERE is_unhappy AND on_time) / count(*) FILTER (WHERE on_time), 2) AS unhappy_on_time_pct
FROM base
GROUP BY price_quarter
ORDER BY price_quarter;

-- name: Delivery fee compared with price (fee / price)
WITH single AS (
  SELECT order_id, sum(freight_value) / sum(price) AS fee_share FROM analytics.fact_order_item
  GROUP BY order_id HAVING count(DISTINCT product_id) = 1
), base AS (
  SELECT s.fee_share, f.is_unhappy, f.price_total,
         f.order_status = 'delivered' AND f.days_late <= 0 AS on_time
  FROM single s
  JOIN analytics.fact_order f ON f.order_id = s.order_id
  WHERE f.has_review
)
SELECT CASE WHEN fee_share < 0.10 THEN '1. under 10%'
            WHEN fee_share < 0.25 THEN '2. 10-24%'
            WHEN fee_share < 0.50 THEN '3. 25-49%'
            WHEN fee_share < 1.00 THEN '4. 50-99%'
            ELSE '5. 100%+ (fee at least the price)' END AS fee_vs_price,
       count(*) AS reviewed,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY price_total) AS median_price,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*), 2) AS unhappy_pct,
       round(100.0 * count(*) FILTER (WHERE is_unhappy AND on_time) / count(*) FILTER (WHERE on_time), 2) AS unhappy_on_time_pct
FROM base
GROUP BY fee_vs_price
ORDER BY fee_vs_price;

-- name: Reference - all P3 orders (to compare every row above with)
WITH single AS (
  SELECT order_id FROM analytics.fact_order_item GROUP BY order_id HAVING count(DISTINCT product_id) = 1
), base AS (
  SELECT f.is_unhappy, f.order_status = 'delivered' AND f.days_late <= 0 AS on_time
  FROM single s JOIN analytics.fact_order f ON f.order_id = s.order_id
  WHERE f.has_review
)
SELECT count(*) AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*), 2) AS unhappy_pct,
       count(*) FILTER (WHERE on_time) AS reviewed_on_time,
       round(100.0 * count(*) FILTER (WHERE is_unhappy AND on_time) / count(*) FILTER (WHERE on_time), 2) AS unhappy_on_time_pct
FROM base;
