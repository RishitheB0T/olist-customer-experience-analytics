-- Checks for the analytics dimension tables.
-- Run with:  python -m src.run_sql sql/check_analytics_dims.sql

-- name: Row counts, clean vs analytics (must be equal)
SELECT 'customer' AS dim, (SELECT count(*) FROM clean.customers) AS clean_rows,
       (SELECT count(*) FROM analytics.dim_customer) AS analytics_rows
UNION ALL SELECT 'seller', (SELECT count(*) FROM clean.sellers), (SELECT count(*) FROM analytics.dim_seller)
UNION ALL SELECT 'product', (SELECT count(*) FROM clean.products), (SELECT count(*) FROM analytics.dim_product);

-- name: No location (Step 7 found 279 customers and 7 sellers)
SELECT (SELECT count(*) FROM analytics.dim_customer WHERE lat IS NULL) AS customers_no_location,
       (SELECT count(*) FROM analytics.dim_seller WHERE lat IS NULL)   AS sellers_no_location,
       (SELECT count(*) FROM analytics.dim_product WHERE product_volume_cm3 IS NULL) AS products_no_volume;

-- name: Date table covers whole years
SELECT count(*) AS days, min(date_day) AS first_day, max(date_day) AS last_day,
       count(*) FILTER (WHERE in_main_period) AS main_period_days
FROM analytics.dim_date;

-- name: Order dates outside the date table (must all be 0)
SELECT count(*) FILTER (WHERE d.date_day IS NULL AND o.purchase_day IS NOT NULL) AS purchase_outside,
       count(*) FILTER (WHERE e.date_day IS NULL AND o.delivered_day IS NOT NULL) AS delivered_outside,
       count(*) FILTER (WHERE p.date_day IS NULL)                                AS promised_outside
FROM (SELECT order_purchase_timestamp::date AS purchase_day,
             order_delivered_customer_date::date AS delivered_day,
             order_estimated_delivery_date AS promised_day
      FROM clean.orders) o
LEFT JOIN analytics.dim_date d ON d.date_day = o.purchase_day
LEFT JOIN analytics.dim_date e ON e.date_day = o.delivered_day
LEFT JOIN analytics.dim_date p ON p.date_day = o.promised_day;
