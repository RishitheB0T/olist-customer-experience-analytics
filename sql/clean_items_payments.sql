-- Clean layer, part 2b: order items and payments.
-- Money becomes numeric with 2 decimals (checked: no raw value has more), counts become integers.
-- Needs clean.orders, clean.products and clean.sellers to exist first.
-- Run with:  python -m src.build_sql sql/clean_items_payments.sql

-- name: Drop old clean.order_items and clean.order_payments
DROP TABLE IF EXISTS clean.order_items, clean.order_payments CASCADE;

-- name: Build clean.order_items
CREATE TABLE clean.order_items AS
SELECT order_id,
       order_item_id::integer         AS order_item_id,        -- 1, 2, 3... within an order
       product_id,
       seller_id,
       shipping_limit_date::timestamp AS shipping_limit_date,  -- seller's hand-over deadline
       price::numeric(12, 2)          AS price,
       freight_value::numeric(12, 2)  AS freight_value         -- delivery fee; 0 for 383 items, kept (may be free delivery)
FROM raw.order_items;

-- name: Rule - one row per order item
ALTER TABLE clean.order_items ADD PRIMARY KEY (order_id, order_item_id);

-- name: Rule - every item has a product and a seller
ALTER TABLE clean.order_items ALTER COLUMN product_id SET NOT NULL,
                              ALTER COLUMN seller_id SET NOT NULL;

-- name: Rule - items point at a real order, product and seller
ALTER TABLE clean.order_items
    ADD FOREIGN KEY (order_id)   REFERENCES clean.orders (order_id),
    ADD FOREIGN KEY (product_id) REFERENCES clean.products (product_id),
    ADD FOREIGN KEY (seller_id)  REFERENCES clean.sellers (seller_id);

-- name: Build clean.order_payments
CREATE TABLE clean.order_payments AS
SELECT order_id,
       payment_sequential::integer   AS payment_sequential,  -- 1st, 2nd... payment for the order
       payment_type,
       payment_installments::integer AS payment_installments,
       payment_value::numeric(12, 2) AS payment_value,
       -- odd payments found in profiling (value 0, 0 instalments, or type not_defined)
       (payment_value::numeric = 0 OR payment_installments::integer = 0
        OR payment_type = 'not_defined') AS flag_odd_payment
FROM raw.order_payments;

-- name: Rule - one row per payment
ALTER TABLE clean.order_payments ADD PRIMARY KEY (order_id, payment_sequential);

-- name: Rule - payments point at a real order
ALTER TABLE clean.order_payments ADD FOREIGN KEY (order_id) REFERENCES clean.orders (order_id);
