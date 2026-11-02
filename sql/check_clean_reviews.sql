-- Checks for clean.order_reviews.
-- Run with:  python -m src.run_sql sql/check_clean_reviews.sql

-- name: Row counts, raw vs clean (must be equal: nothing deleted)
SELECT (SELECT count(*) FROM raw.order_reviews)   AS raw_rows,
       (SELECT count(*) FROM clean.order_reviews) AS clean_rows;

-- name: One chosen review per reviewed order (profiling found 768 orders with no review)
SELECT count(*) FILTER (WHERE is_order_review) AS chosen_reviews,
       count(DISTINCT order_id)                AS reviewed_orders,
       (SELECT count(*) FROM clean.orders o
        WHERE NOT EXISTS (SELECT 1 FROM clean.order_reviews r WHERE r.order_id = o.order_id)) AS orders_without_review
FROM clean.order_reviews;

-- name: The rule on orders with 2+ reviews (rule check found 547 orders, 137 unhappy by lowest score)
WITH lowest AS (
  SELECT order_id, min(review_score) AS lowest_score
  FROM clean.order_reviews GROUP BY order_id HAVING count(*) > 1
)
SELECT count(*)                                         AS multi_review_orders,
       count(*) FILTER (WHERE r.review_score <= 2)       AS unhappy_chosen,
       count(*) FILTER (WHERE r.review_score > l.lowest_score) AS chosen_not_lowest  -- must be 0
FROM clean.order_reviews r
JOIN lowest l ON l.order_id = r.order_id
WHERE r.is_order_review;

-- name: Flags (rule check found 1,603 rows with a shared review_id, 5,127 surveys before delivery day)
SELECT count(*) FILTER (WHERE flag_review_id_shared)       AS shared_review_id,
       count(*) FILTER (WHERE flag_survey_before_delivery) AS survey_before_delivery,
       count(*) FILTER (WHERE has_comment)                 AS has_comment
FROM clean.order_reviews;

-- name: Answer delay in calendar days
SELECT min(answer_delay_days) AS min_days,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY answer_delay_days) AS median_days,
       max(answer_delay_days) AS max_days,
       count(*) FILTER (WHERE answer_delay_days >= 30) AS answered_30_plus_days
FROM clean.order_reviews;
