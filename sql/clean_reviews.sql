-- Clean layer, part 3: order reviews.
-- Keeps every review row and marks ONE review per order for analysis (is_order_review).
-- Rule: the lowest score, because the project studies unhappy customers.
-- Needs clean.orders to exist first.
-- Run with:  python -m src.build_sql sql/clean_reviews.sql

-- name: Drop old clean.order_reviews
DROP TABLE IF EXISTS clean.order_reviews CASCADE;

-- name: Build clean.order_reviews
CREATE TABLE clean.order_reviews AS
SELECT r.review_id,
       r.order_id,
       r.review_score::integer              AS review_score,
       r.review_comment_title,
       r.review_comment_message,
       r.review_creation_date::timestamp    AS review_creation_date,     -- when the survey was sent
       r.review_answer_timestamp::timestamp AS review_answer_timestamp,  -- when the customer answered
       r.review_answer_timestamp::date - r.review_creation_date::date AS answer_delay_days,  -- calendar days
       r.review_comment_message IS NOT NULL AS has_comment,
       -- One survey can cover several orders (checked: always the same person and the same score)
       count(*) OVER (PARTITION BY r.review_id) > 1 AS flag_review_id_shared,
       -- Survey sent on an earlier day than the order reached the customer
       coalesce(r.review_creation_date::date < o.order_delivered_customer_date::date, false) AS flag_survey_before_delivery,
       -- The review used for the order: lowest score; ties -> latest answer, then review_id
       row_number() OVER (PARTITION BY r.order_id
                          ORDER BY r.review_score::integer,
                                   r.review_answer_timestamp::timestamp DESC,
                                   r.review_id) = 1 AS is_order_review
FROM raw.order_reviews r
LEFT JOIN clean.orders o ON o.order_id = r.order_id;  -- LEFT: an unknown order is kept, and the foreign key below stops the build

-- name: Rule - one row per review and order (review_id alone repeats, see above)
ALTER TABLE clean.order_reviews ADD PRIMARY KEY (review_id, order_id);

-- name: Rule - every review has a score from 1 to 5, answered after the survey was sent
ALTER TABLE clean.order_reviews
    ALTER COLUMN review_score SET NOT NULL,
    ADD CHECK (review_score BETWEEN 1 AND 5),
    ADD CHECK (review_answer_timestamp >= review_creation_date);

-- name: Rule - reviews point at a real order
ALTER TABLE clean.order_reviews ADD FOREIGN KEY (order_id) REFERENCES clean.orders (order_id);

-- name: Rule - at most one chosen review per order
CREATE UNIQUE INDEX one_review_per_order ON clean.order_reviews (order_id) WHERE is_order_review;
