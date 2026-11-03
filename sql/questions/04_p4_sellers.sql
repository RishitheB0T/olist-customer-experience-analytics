-- Phase 3, Step 5: P4 - seller concentration.
-- Do a few sellers hold most unhappy reviews (count), and which do worst for their size (rate),
-- even on time? Single-seller orders only; multi-seller orders are "shared".
-- Rates only for sellers with 50+ reviewed orders (provisional; Phase 4 sets the minimum).
-- Run with:  python -m src.run_sql sql/questions/04_p4_sellers.sql

-- name: Exclusion table - which reviewed orders P4 uses
SELECT step, orders
FROM (VALUES
  (1, 'reviewed orders',                    (SELECT count(*) FROM analytics.fact_order WHERE has_review)),
  (2, '+ has items',                        (SELECT count(*) FROM analytics.fact_order WHERE has_review AND n_items > 0)),
  (3, '+ one seller (P4 orders)',           (SELECT count(*) FROM analytics.fact_order WHERE has_review AND n_sellers = 1)),
  (4, 'shared: 2+ sellers (described apart)', (SELECT count(*) FROM analytics.fact_order WHERE has_review AND n_sellers > 1))
) AS t(n, step, orders)
ORDER BY n;

-- name: By count - share of unhappy reviews held by the top sellers (ranked by unhappy reviews)
WITH per_seller AS (
  SELECT seller_id, count(*) AS reviewed, count(*) FILTER (WHERE is_unhappy) AS unhappy
  FROM analytics.fact_order
  WHERE n_sellers = 1 AND has_review
  GROUP BY seller_id
), ranked AS (
  SELECT *, row_number() OVER (ORDER BY unhappy DESC, reviewed DESC, seller_id) AS seller_rank,
         count(*)      OVER () AS all_sellers,
         sum(unhappy)  OVER () AS all_unhappy,
         sum(reviewed) OVER () AS all_reviewed
  FROM per_seller
)
SELECT 'top ' || t.top_pct || '%' AS sellers_group,
       count(*) AS sellers,
       round(100.0 * sum(unhappy) / max(all_unhappy), 2)   AS share_of_unhappy_pct,
       round(100.0 * sum(reviewed) / max(all_reviewed), 2) AS share_of_reviewed_orders_pct
FROM ranked
JOIN (VALUES (1), (5), (10), (20)) AS t(top_pct) ON seller_rank <= ceil(all_sellers * t.top_pct / 100.0)
GROUP BY t.top_pct
ORDER BY t.top_pct;

-- name: By count - all sellers, and how many have no unhappy review at all
WITH per_seller AS (
  SELECT seller_id, count(*) FILTER (WHERE is_unhappy) AS unhappy
  FROM analytics.fact_order
  WHERE n_sellers = 1 AND has_review
  GROUP BY seller_id
)
SELECT count(*) AS sellers,
       count(*) FILTER (WHERE unhappy = 0) AS sellers_with_no_unhappy_review
FROM per_seller;

-- name: By rate - sellers with 50+ reviewed orders: how many are at least twice the usual rate?
WITH per_seller AS (
  SELECT seller_id,
         count(*) AS reviewed,
         count(*) FILTER (WHERE is_unhappy) AS unhappy,
         count(*) FILTER (WHERE order_status = 'delivered' AND days_late <= 0) AS reviewed_on_time,
         count(*) FILTER (WHERE is_unhappy AND order_status = 'delivered' AND days_late <= 0) AS unhappy_on_time
  FROM analytics.fact_order
  WHERE n_sellers = 1 AND has_review
  GROUP BY seller_id
), reference AS (   -- usual rates across all P4 orders
  SELECT 1.0 * sum(unhappy) / sum(reviewed) AS rate_all,
         1.0 * sum(unhappy_on_time) / sum(reviewed_on_time) AS rate_on_time
  FROM per_seller
)
SELECT round(100 * r.rate_all, 2)     AS usual_rate_pct,
       round(100 * r.rate_on_time, 2) AS usual_on_time_rate_pct,
       count(*) FILTER (WHERE p.reviewed >= 50) AS sellers_50_plus,
       count(*) FILTER (WHERE p.reviewed >= 50 AND 1.0 * p.unhappy / p.reviewed >= 2 * r.rate_all) AS twice_usual_rate,
       count(*) FILTER (WHERE p.reviewed_on_time >= 50) AS sellers_50_plus_on_time,
       count(*) FILTER (WHERE p.reviewed_on_time >= 50
                          AND 1.0 * p.unhappy_on_time / p.reviewed_on_time >= 2 * r.rate_on_time) AS twice_usual_on_time
FROM per_seller p, reference r
GROUP BY r.rate_all, r.rate_on_time;

-- name: By rate - the 10 sellers with the highest unhappy rate on ON-TIME orders (50+ on-time reviewed orders)
WITH per_seller AS (
  SELECT f.seller_id, s.state,
         count(*) AS reviewed,
         round(100.0 * count(*) FILTER (WHERE f.is_unhappy) / count(*), 2) AS unhappy_pct,
         round(100.0 * count(*) FILTER (WHERE f.is_late) / count(*), 2)    AS late_pct,
         count(*) FILTER (WHERE f.order_status = 'delivered' AND f.days_late <= 0) AS reviewed_on_time,
         count(*) FILTER (WHERE f.is_unhappy AND f.order_status = 'delivered' AND f.days_late <= 0) AS unhappy_on_time
  FROM analytics.fact_order f
  JOIN analytics.dim_seller s ON s.seller_id = f.seller_id
  WHERE f.n_sellers = 1 AND f.has_review
  GROUP BY f.seller_id, s.state
)
SELECT left(seller_id, 8) AS seller,   -- first 8 characters of the (already anonymous) ID
       state, reviewed, unhappy_pct, late_pct, reviewed_on_time,
       round(100.0 * unhappy_on_time / reviewed_on_time, 2) AS unhappy_on_time_pct
FROM per_seller
WHERE reviewed_on_time >= 50
ORDER BY unhappy_on_time_pct DESC
LIMIT 10;

-- name: Shared orders (2+ sellers) - can't be given to one seller
SELECT count(*) AS reviewed,
       round(100.0 * count(*) FILTER (WHERE is_unhappy) / count(*), 2) AS unhappy_pct
FROM analytics.fact_order
WHERE n_sellers > 1 AND has_review;
