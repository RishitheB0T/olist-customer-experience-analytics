-- Analytics layer, part 2: fact_order, the centre of the star schema. One row per order.
-- Brings together dates, items, payments and the chosen review, and adds delivery measures.
-- All "days" are calendar days (time of day ignored), as set in the problem brief.
-- Needs the clean tables and sql/analytics_dims.sql first.
-- Run with:  python -m src.build_sql sql/analytics_fact_order.sql

-- name: Drop old analytics.fact_order
DROP TABLE IF EXISTS analytics.fact_order CASCADE;

-- name: Summarise items per order (temporary table, removed when the build ends)
CREATE TEMP TABLE order_item_summary ON COMMIT DROP AS
SELECT order_id,
       count(*)                  AS n_items,
       count(DISTINCT seller_id) AS n_sellers,
       CASE WHEN count(DISTINCT seller_id) = 1 THEN min(seller_id) END AS seller_id,  -- only if one seller
       count(DISTINCT shipping_limit_date) AS n_deadlines,
       CASE WHEN count(DISTINCT shipping_limit_date) = 1
            THEN min(shipping_limit_date) END AS handover_deadline,              -- only if one shared deadline
       sum(price)                 AS price_total,
       sum(freight_value)         AS freight_total,
       sum(price + freight_value) AS items_total
FROM clean.order_items
GROUP BY order_id;

-- name: Summarise payments per order (temporary)
CREATE TEMP TABLE order_payment_summary ON COMMIT DROP AS
SELECT order_id, count(*) AS n_payments, sum(payment_value) AS paid_total
FROM clean.order_payments
GROUP BY order_id;

-- name: The chosen review per order (temporary; lowest-score rule from Step 6)
CREATE TEMP TABLE order_review_choice ON COMMIT DROP AS
SELECT order_id, review_score, review_answer_timestamp, has_comment, flag_survey_before_delivery
FROM clean.order_reviews
WHERE is_order_review;

-- name: Delivery measures per order (temporary; whole calendar days)
CREATE TEMP TABLE order_delivery ON COMMIT DROP AS
SELECT o.order_id,
       o.order_delivered_customer_date::date - o.order_purchase_timestamp::date     AS delivery_days,  -- purchase -> customer
       o.order_estimated_delivery_date - o.order_purchase_timestamp::date           AS promised_days,  -- days promised
       o.order_delivered_customer_date::date - o.order_estimated_delivery_date      AS days_late,      -- below 0 = early
       o.order_delivered_customer_date::date > o.order_estimated_delivery_date      AS is_late,
       o.order_delivered_carrier_date::date - o.order_purchase_timestamp::date      AS seller_days,    -- purchase -> hand-over
       o.order_delivered_customer_date::date - o.order_delivered_carrier_date::date AS carrier_days,   -- hand-over -> customer
       coalesce(i.n_deadlines = 1, false)                                           AS has_one_deadline,
       o.order_delivered_carrier_date::date > i.handover_deadline::date             AS handover_late,  -- NULL unless one deadline
       -- median deadline is 6 days after purchase; 10 orders have 69-148 days, or ~1,050 (deadlines in 2020)
       coalesce(i.handover_deadline::date - o.order_purchase_timestamp::date > 60, false) AS flag_odd_deadline
FROM clean.orders o
LEFT JOIN order_item_summary i ON i.order_id = o.order_id;

-- name: Build analytics.fact_order (one row per order)
CREATE TABLE analytics.fact_order AS
SELECT o.order_id, o.customer_id,
       i.seller_id,                                      -- only when the order has one seller
       o.order_purchase_timestamp::date AS purchase_date, -- links to dim_date
       o.order_status, o.order_purchase_timestamp, o.order_approved_at,
       o.order_delivered_carrier_date, o.order_delivered_customer_date, o.order_estimated_delivery_date,
       d.delivery_days, d.promised_days, d.days_late, d.is_late,
       d.seller_days, d.carrier_days, d.has_one_deadline, d.handover_late,
       coalesce(i.n_items, 0) AS n_items, coalesce(i.n_sellers, 0) AS n_sellers,
       p.paid_total,                                     -- the order's value (brief, section 3)
       i.items_total, i.price_total, i.freight_total,
       coalesce(abs(p.paid_total - i.items_total) > 1, false) AS flag_paid_mismatch,
       r.order_id IS NOT NULL AS has_review,
       r.review_score,
       r.review_score <= 2    AS is_unhappy,             -- NULL when there is no review
       r.review_answer_timestamp, r.has_comment, r.flag_survey_before_delivery,
       -- straight-line distance seller -> customer over the globe (haversine formula, Earth radius 6,371 km)
       round((2 * 6371 * asin(sqrt(
             power(sin(radians(sl.lat - c.lat) / 2), 2)
           + cos(radians(c.lat)) * cos(radians(sl.lat)) * power(sin(radians(sl.lng - c.lng) / 2), 2)
       )))::numeric, 1) AS distance_km,
       o.flag_delivered_without_date, o.flag_delivery_date_not_delivered,
       o.flag_handover_before_purchase, o.flag_delivered_before_handover, d.flag_odd_deadline,
       o.in_main_period
FROM clean.orders o
JOIN      order_delivery d          ON d.order_id = o.order_id
LEFT JOIN order_item_summary i      ON i.order_id = o.order_id
LEFT JOIN order_payment_summary p   ON p.order_id = o.order_id
LEFT JOIN order_review_choice r     ON r.order_id = o.order_id
LEFT JOIN analytics.dim_customer c  ON c.customer_id = o.customer_id
LEFT JOIN analytics.dim_seller sl   ON sl.seller_id = i.seller_id;

-- name: Rule - one row per order
ALTER TABLE analytics.fact_order ADD PRIMARY KEY (order_id);

-- name: Rule - every order has a customer and a purchase day; links to the dimension tables
ALTER TABLE analytics.fact_order
    ALTER COLUMN customer_id SET NOT NULL,
    ALTER COLUMN purchase_date SET NOT NULL,
    ADD FOREIGN KEY (customer_id)   REFERENCES analytics.dim_customer (customer_id),
    ADD FOREIGN KEY (purchase_date) REFERENCES analytics.dim_date (date_day),
    ADD FOREIGN KEY (seller_id)     REFERENCES analytics.dim_seller (seller_id);  -- NULL allowed (0 or 2+ sellers)
