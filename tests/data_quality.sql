-- Data quality tests. Each test counts "bad rows": rows (or totals) that break a rule.
-- 0 bad rows = PASS, anything else = FAIL.
-- Run with:  python -m src.run_tests

-- name: Layers - clean tables have the same row counts as raw
SELECT count(*) AS bad_rows   -- number of tables whose counts differ
FROM (VALUES
  ((SELECT count(*) FROM raw.orders),         (SELECT count(*) FROM clean.orders)),
  ((SELECT count(*) FROM raw.customers),      (SELECT count(*) FROM clean.customers)),
  ((SELECT count(*) FROM raw.order_items),    (SELECT count(*) FROM clean.order_items)),
  ((SELECT count(*) FROM raw.order_payments), (SELECT count(*) FROM clean.order_payments)),
  ((SELECT count(*) FROM raw.order_reviews),  (SELECT count(*) FROM clean.order_reviews)),
  ((SELECT count(*) FROM raw.products),       (SELECT count(*) FROM clean.products)),
  ((SELECT count(*) FROM raw.sellers),        (SELECT count(*) FROM clean.sellers))
) AS t(raw_rows, clean_rows)
WHERE raw_rows <> clean_rows;

-- name: Layers - fact tables have one row per order and one per item
SELECT abs((SELECT count(*) FROM clean.orders)      - (SELECT count(*) FROM analytics.fact_order))
     + abs((SELECT count(*) FROM clean.order_items) - (SELECT count(*) FROM analytics.fact_order_item)) AS bad_rows;

-- name: Layers - money totals are the same in raw and analytics
SELECT count(*) AS bad_rows   -- number of totals that differ
FROM (VALUES
  ((SELECT sum(payment_value::numeric) FROM raw.order_payments), (SELECT sum(paid_total) FROM analytics.fact_order)),
  ((SELECT sum(price::numeric) FROM raw.order_items),            (SELECT sum(price) FROM analytics.fact_order_item)),
  ((SELECT sum(freight_value::numeric) FROM raw.order_items),    (SELECT sum(freight_value) FROM analytics.fact_order_item))
) AS t(raw_total, analytics_total)
WHERE raw_total <> analytics_total;

-- name: Reviews - every reviewed order has exactly one chosen review
SELECT count(*) AS bad_rows
FROM (SELECT order_id
      FROM clean.order_reviews
      GROUP BY order_id
      HAVING count(*) FILTER (WHERE is_order_review) <> 1) x;

-- name: Reviews - the chosen review has the order's lowest score
-- Lowest score per order worked out once, then joined (a subquery per row took minutes).
SELECT count(*) AS bad_rows
FROM clean.order_reviews r
JOIN (SELECT order_id, min(review_score) AS lowest_score
      FROM clean.order_reviews
      GROUP BY order_id) m ON m.order_id = r.order_id
WHERE r.is_order_review
  AND r.review_score > m.lowest_score;

-- name: Dates - in_main_period agrees in fact_order and dim_date
SELECT count(*) AS bad_rows
FROM analytics.fact_order f
JOIN analytics.dim_date d ON d.date_day = f.purchase_date
WHERE f.in_main_period IS DISTINCT FROM d.in_main_period;

-- name: Dates - every delivered and promised day is in dim_date
SELECT count(*) AS bad_rows
FROM analytics.fact_order f
WHERE (f.order_delivered_customer_date IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM analytics.dim_date d WHERE d.date_day = f.order_delivered_customer_date::date))
   OR NOT EXISTS (SELECT 1 FROM analytics.dim_date d WHERE d.date_day = f.order_estimated_delivery_date);

-- name: Delivery - no order arrives before it was bought
SELECT count(*) AS bad_rows FROM analytics.fact_order WHERE delivery_days < 0;

-- name: Locations - every map point is inside Brazil's box
SELECT count(*) AS bad_rows
FROM clean.geolocation
WHERE NOT (lat BETWEEN -34 AND 6 AND lng BETWEEN -74 AND -34);

-- name: Locations - no seller-to-customer distance is longer than Brazil is wide (~4,500 km)
SELECT count(*) AS bad_rows FROM analytics.fact_order WHERE distance_km > 4500;

-- name: Items - item counts and one-deadline hand-over agree with fact_order
WITH per_order AS (
  SELECT order_id, count(*) AS n_items, bool_or(handover_late) AS any_item_late
  FROM analytics.fact_order_item
  GROUP BY order_id
)
SELECT count(*) AS bad_rows
FROM analytics.fact_order f
JOIN per_order p ON p.order_id = f.order_id
WHERE f.n_items <> p.n_items
   OR (f.has_one_deadline AND f.handover_late IS DISTINCT FROM p.any_item_late);

-- name: Known counts - numbers recorded in earlier steps still hold
-- A "regression test": it fails if a rule changes the results by accident.
SELECT count(*) AS bad_rows   -- number of counts that changed
FROM (VALUES
  ('reviewed orders',            98673, (SELECT count(*) FROM analytics.fact_order WHERE has_review)),
  ('orders without items',         775, (SELECT count(*) FROM analytics.fact_order WHERE n_items = 0)),
  ('paid vs items mismatch',       249, (SELECT count(*) FROM analytics.fact_order WHERE flag_paid_mismatch)),
  ('orders with odd deadline',      10, (SELECT count(*) FROM analytics.fact_order WHERE flag_odd_deadline)),
  ('customers without location',   279, (SELECT count(*) FROM analytics.dim_customer WHERE lat IS NULL)),
  ('orders in main period',      99092, (SELECT count(*) FROM analytics.fact_order WHERE in_main_period))
) AS t(what, expected, actual)
WHERE expected <> actual;
