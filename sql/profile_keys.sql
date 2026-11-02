-- Data quality, part 1: are the IDs unique, and do the links between tables hold?
-- Run with:  python -m src.run_sql sql/profile_keys.sql

-- name: Missing and duplicate IDs (kept apart, so one can't hide the other)
-- rows_missing_key: rows where ANY part of the ID is empty (NULL).
-- duplicate_rows:   among rows with a complete ID, rows beyond the first one per ID.
-- One-column IDs: count(col) and count(DISTINCT col) both skip NULLs, so their gap = duplicates.
SELECT 'orders' AS table_name, 'order_id' AS id_columns, count(*) AS total_rows,
       count(*) FILTER (WHERE order_id IS NULL) AS rows_missing_key,
       count(order_id) - count(DISTINCT order_id) AS duplicate_rows FROM raw.orders
UNION ALL SELECT 'customers', 'customer_id', count(*),
       count(*) FILTER (WHERE customer_id IS NULL),
       count(customer_id) - count(DISTINCT customer_id) FROM raw.customers
UNION ALL SELECT 'products', 'product_id', count(*),
       count(*) FILTER (WHERE product_id IS NULL),
       count(product_id) - count(DISTINCT product_id) FROM raw.products
UNION ALL SELECT 'sellers', 'seller_id', count(*),
       count(*) FILTER (WHERE seller_id IS NULL),
       count(seller_id) - count(DISTINCT seller_id) FROM raw.sellers
UNION ALL SELECT 'category_translation', 'product_category_name', count(*),
       count(*) FILTER (WHERE product_category_name IS NULL),
       count(product_category_name) - count(DISTINCT product_category_name) FROM raw.product_category_name_translation
UNION ALL SELECT 'order_reviews', 'review_id', count(*),
       count(*) FILTER (WHERE review_id IS NULL),
       count(review_id) - count(DISTINCT review_id) FROM raw.order_reviews
-- Two-column IDs: check EACH part for NULLs, and count duplicates only among complete IDs.
UNION ALL SELECT 'order_items', 'order_id + order_item_id', count(*),
       count(*) FILTER (WHERE order_id IS NULL OR order_item_id IS NULL),
       count(*) FILTER (WHERE order_id IS NOT NULL AND order_item_id IS NOT NULL)
     - count(DISTINCT (order_id, order_item_id)) FILTER (WHERE order_id IS NOT NULL AND order_item_id IS NOT NULL)
FROM raw.order_items
UNION ALL SELECT 'order_payments', 'order_id + payment_sequential', count(*),
       count(*) FILTER (WHERE order_id IS NULL OR payment_sequential IS NULL),
       count(*) FILTER (WHERE order_id IS NOT NULL AND payment_sequential IS NOT NULL)
     - count(DISTINCT (order_id, payment_sequential)) FILTER (WHERE order_id IS NOT NULL AND payment_sequential IS NOT NULL)
FROM raw.order_payments
UNION ALL SELECT 'order_reviews', 'review_id + order_id', count(*),
       count(*) FILTER (WHERE review_id IS NULL OR order_id IS NULL),
       count(*) FILTER (WHERE review_id IS NOT NULL AND order_id IS NOT NULL)
     - count(DISTINCT (review_id, order_id)) FILTER (WHERE review_id IS NOT NULL AND order_id IS NOT NULL)
FROM raw.order_reviews
ORDER BY duplicate_rows DESC, rows_missing_key DESC, table_name;  -- UNION ALL has no fixed order, so sort

-- name: One person, several customer IDs (customer_unique_id = the real person)
SELECT count(*) AS customer_ids, count(DISTINCT customer_unique_id) AS people
FROM raw.customers;

-- name: Geolocation: rows per zip prefix (many rows per prefix are expected)
SELECT count(*) AS rows, count(DISTINCT geolocation_zip_code_prefix) AS zip_prefixes,
       round(count(*)::numeric / count(DISTINCT geolocation_zip_code_prefix), 1) AS avg_rows_per_prefix
FROM raw.geolocation;

-- name: Broken links (rows pointing at something that doesn't exist)
SELECT 'orders.customer_id -> customers' AS link, count(*) AS broken_rows FROM raw.orders o
  WHERE NOT EXISTS (SELECT 1 FROM raw.customers c WHERE c.customer_id = o.customer_id)
UNION ALL SELECT 'order_items.order_id -> orders', count(*) FROM raw.order_items i
  WHERE NOT EXISTS (SELECT 1 FROM raw.orders o WHERE o.order_id = i.order_id)
UNION ALL SELECT 'order_items.product_id -> products', count(*) FROM raw.order_items i
  WHERE NOT EXISTS (SELECT 1 FROM raw.products p WHERE p.product_id = i.product_id)
UNION ALL SELECT 'order_items.seller_id -> sellers', count(*) FROM raw.order_items i
  WHERE NOT EXISTS (SELECT 1 FROM raw.sellers s WHERE s.seller_id = i.seller_id)
UNION ALL SELECT 'order_payments.order_id -> orders', count(*) FROM raw.order_payments p
  WHERE NOT EXISTS (SELECT 1 FROM raw.orders o WHERE o.order_id = p.order_id)
UNION ALL SELECT 'order_reviews.order_id -> orders', count(*) FROM raw.order_reviews r
  WHERE NOT EXISTS (SELECT 1 FROM raw.orders o WHERE o.order_id = r.order_id)
UNION ALL SELECT 'products.category -> translation', count(*) FROM raw.products p
  WHERE p.product_category_name IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM raw.product_category_name_translation t WHERE t.product_category_name = p.product_category_name)
UNION ALL SELECT 'customers.zip -> geolocation', count(*) FROM raw.customers c
  WHERE NOT EXISTS (SELECT 1 FROM raw.geolocation g WHERE g.geolocation_zip_code_prefix = c.customer_zip_code_prefix)
UNION ALL SELECT 'sellers.zip -> geolocation', count(*) FROM raw.sellers s
  WHERE NOT EXISTS (SELECT 1 FROM raw.geolocation g WHERE g.geolocation_zip_code_prefix = s.seller_zip_code_prefix)
UNION ALL SELECT 'orders with no payment rows', count(*) FROM raw.orders o
  WHERE NOT EXISTS (SELECT 1 FROM raw.order_payments p WHERE p.order_id = o.order_id)
ORDER BY broken_rows DESC, link;
