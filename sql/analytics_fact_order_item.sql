-- Analytics layer, part 3: fact_order_item. One row per item in an order.
-- For item-level questions: delivery fee vs price (P3), each seller's own hand-over (P4).
-- Order-level facts (review, lateness, money paid) stay in fact_order: join on order_id.
-- Needs sql/analytics_fact_order.sql first.
-- Run with:  python -m src.build_sql sql/analytics_fact_order_item.sql

-- name: Drop old analytics.fact_order_item
DROP TABLE IF EXISTS analytics.fact_order_item CASCADE;

-- name: Build analytics.fact_order_item (one row per item)
CREATE TABLE analytics.fact_order_item AS
SELECT i.order_id,
       i.order_item_id,
       i.product_id,
       i.seller_id,
       i.price,
       i.freight_value,
       i.price + i.freight_value AS item_total,
       -- delivery fee ÷ price (P3); nullif turns a 0 price into NULL, so the rule below rejects it clearly
       round(i.freight_value / nullif(i.price, 0), 4) AS freight_share,
       i.shipping_limit_date,                                      -- this seller's hand-over deadline
       o.order_delivered_carrier_date::date > i.shipping_limit_date::date AS handover_late,  -- NULL if never handed over
       i.freight_value = 0 AS flag_zero_freight,                   -- 383 items; may be free delivery
       -- same rule as fact_order: deadline more than 60 days after purchase (median is 6)
       i.shipping_limit_date::date - o.order_purchase_timestamp::date > 60 AS flag_odd_deadline
FROM clean.order_items i
JOIN clean.orders o ON o.order_id = i.order_id;

-- name: Rule - one row per item
ALTER TABLE analytics.fact_order_item ADD PRIMARY KEY (order_id, order_item_id);

-- name: Rule - every item has a product, a seller and a price above 0
ALTER TABLE analytics.fact_order_item
    ALTER COLUMN product_id SET NOT NULL,
    ALTER COLUMN seller_id SET NOT NULL,
    ADD CHECK (price > 0);

-- name: Rule - every item links to its order, product and seller
ALTER TABLE analytics.fact_order_item
    ADD FOREIGN KEY (order_id)   REFERENCES analytics.fact_order (order_id),
    ADD FOREIGN KEY (product_id) REFERENCES analytics.dim_product (product_id),
    ADD FOREIGN KEY (seller_id)  REFERENCES analytics.dim_seller (seller_id);
