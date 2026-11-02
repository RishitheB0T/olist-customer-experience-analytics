-- Data quality, part 1: are the IDs unique, and do the links between tables hold?
-- Run with:  python -m src.run_sql sql/profile_keys.sql

-- name: Duplicate or missing IDs (extra_rows = rows beyond one per ID)
-- Same pattern as my first query: count(*) vs count(DISTINCT id), plus NULL IDs.
SELECT 'orders' AS table_name, 'order_id' AS id_column, count(*) AS total_rows,
       count(*) - count(order_id) AS null_ids, count(DISTINCT order_id) AS distinct_ids,
       count(*) - count(DISTINCT order_id) AS extra_rows FROM raw.orders
UNION ALL SELECT 'customers', 'customer_id', count(*), count(*) - count(customer_id),
       count(DISTINCT customer_id), count(*) - count(DISTINCT customer_id) FROM raw.customers
UNION ALL SELECT 'order_items', 'order_id + order_item_id', count(*), count(*) - count(order_item_id),
       count(DISTINCT (order_id, order_item_id)), count(*) - count(DISTINCT (order_id, order_item_id)) FROM raw.order_items
UNION ALL SELECT 'order_payments', 'order_id + payment_sequential', count(*), count(*) - count(payment_sequential),
       count(DISTINCT (order_id, payment_sequential)), count(*) - count(DISTINCT (order_id, payment_sequential)) FROM raw.order_payments
UNION ALL SELECT 'order_reviews', 'review_id', count(*), count(*) - count(review_id),
       count(DISTINCT review_id), count(*) - count(DISTINCT review_id) FROM raw.order_reviews
UNION ALL SELECT 'order_reviews', 'review_id + order_id', count(*), count(*) - count(review_id),
       count(DISTINCT (review_id, order_id)), count(*) - count(DISTINCT (review_id, order_id)) FROM raw.order_reviews
UNION ALL SELECT 'products', 'product_id', count(*), count(*) - count(product_id),
       count(DISTINCT product_id), count(*) - count(DISTINCT product_id) FROM raw.products
UNION ALL SELECT 'sellers', 'seller_id', count(*), count(*) - count(seller_id),
       count(DISTINCT seller_id), count(*) - count(DISTINCT seller_id) FROM raw.sellers
UNION ALL SELECT 'category_translation', 'product_category_name', count(*), count(*) - count(product_category_name),
       count(DISTINCT product_category_name), count(*) - count(DISTINCT product_category_name) FROM raw.product_category_name_translation
ORDER BY extra_rows DESC, table_name;  -- UNION ALL has no fixed order, so sort the result

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
