-- Checks for clean categories, products, sellers, items and payments.
-- Run with:  python -m src.run_sql sql/check_clean_products_items.sql

-- name: Row counts, raw vs clean (equal, except categories = 71 + 2 added)
SELECT 'product_categories' AS table_name,
       (SELECT count(*) FROM raw.product_category_name_translation) AS raw_rows,
       (SELECT count(*) FROM clean.product_categories) AS clean_rows
UNION ALL SELECT 'products', (SELECT count(*) FROM raw.products), (SELECT count(*) FROM clean.products)
UNION ALL SELECT 'sellers', (SELECT count(*) FROM raw.sellers), (SELECT count(*) FROM clean.sellers)
UNION ALL SELECT 'order_items', (SELECT count(*) FROM raw.order_items), (SELECT count(*) FROM clean.order_items)
UNION ALL SELECT 'order_payments', (SELECT count(*) FROM raw.order_payments), (SELECT count(*) FROM clean.order_payments);

-- name: Money totals, raw vs clean (must match exactly - nothing rounded)
SELECT (SELECT sum(price::numeric) FROM raw.order_items)           AS raw_price,
       (SELECT sum(price) FROM clean.order_items)                   AS clean_price,
       (SELECT sum(freight_value::numeric) FROM raw.order_items)   AS raw_freight,
       (SELECT sum(freight_value) FROM clean.order_items)           AS clean_freight,
       (SELECT sum(payment_value::numeric) FROM raw.order_payments) AS raw_paid,
       (SELECT sum(payment_value) FROM clean.order_payments)        AS clean_paid;

-- name: Products (profiling found 610 with no category, 13 untranslated, 4 at 0 g, 2 missing size)
SELECT count(*) FILTER (WHERE flag_no_category)             AS no_category,
       count(*) FILTER (WHERE product_category = 'unknown') AS english_unknown,
       count(*) FILTER (WHERE product_category IS NULL)     AS english_missing,
       count(*) FILTER (WHERE product_category_name IN ('pc_gamer', 'portateis_cozinha_e_preparadores_de_alimentos')) AS translated_by_us,
       count(*) FILTER (WHERE flag_zero_weight)             AS zero_weight,
       count(*) FILTER (WHERE flag_missing_size)            AS missing_size,
       count(DISTINCT product_category)                     AS english_categories
FROM clean.products;

-- name: Odd payments (profiling found 9 with value 0, 2 with 0 instalments, 3 not_defined)
SELECT count(*) FILTER (WHERE flag_odd_payment)            AS odd_payments,
       count(*) FILTER (WHERE payment_value = 0)            AS value_0,
       count(*) FILTER (WHERE payment_installments = 0)     AS installments_0,
       count(*) FILTER (WHERE payment_type = 'not_defined') AS not_defined
FROM clean.order_payments;

-- name: Column names and types in clean.products
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'clean' AND table_name = 'products'
ORDER BY ordinal_position;
