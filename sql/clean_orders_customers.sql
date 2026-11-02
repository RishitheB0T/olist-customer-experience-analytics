-- Clean layer, part 1: customers and orders.
-- Fixes data types and adds flags for the problems found in profiling.
-- Nothing is deleted: odd rows are flagged, so each analysis decides what to leave out.
-- Run with:  python -m src.build_sql sql/clean_orders_customers.sql

-- name: Create schema clean
CREATE SCHEMA IF NOT EXISTS clean;

-- name: Drop old clean.orders
-- CASCADE also removes links from other clean tables that point here; they are rebuilt with those tables.
DROP TABLE IF EXISTS clean.orders CASCADE;

-- name: Drop old clean.customers
DROP TABLE IF EXISTS clean.customers CASCADE;

-- name: Build clean.customers
CREATE TABLE clean.customers AS
SELECT customer_id,
       customer_unique_id,        -- the real person; one person can have several customer_ids
       customer_zip_code_prefix,  -- stays text: the leading zeros matter
       customer_city,
       customer_state
FROM raw.customers;

-- name: Rule - customer_id is unique
ALTER TABLE clean.customers ADD PRIMARY KEY (customer_id);

-- name: Build clean.orders
CREATE TABLE clean.orders AS
SELECT order_id,
       customer_id,
       order_status,
       order_purchase_timestamp::timestamp      AS order_purchase_timestamp,
       order_approved_at::timestamp             AS order_approved_at,
       order_delivered_carrier_date::timestamp  AS order_delivered_carrier_date,
       order_delivered_customer_date::timestamp AS order_delivered_customer_date,
       order_estimated_delivery_date::date      AS order_estimated_delivery_date,  -- the promised day (always midnight in raw)
       -- Flags: true = this order has the problem. coalesce(..., false) = if a date is missing, the check can't fail.
       coalesce(order_status = 'delivered' AND order_delivered_customer_date IS NULL, false)       AS flag_delivered_without_date,
       coalesce(order_status <> 'delivered' AND order_delivered_customer_date IS NOT NULL, false)  AS flag_delivery_date_not_delivered,
       coalesce(order_delivered_carrier_date::timestamp < order_purchase_timestamp::timestamp, false)       AS flag_handover_before_purchase,
       coalesce(order_delivered_customer_date::timestamp < order_delivered_carrier_date::timestamp, false)  AS flag_delivered_before_handover,
       -- Months with enough orders for trends: outside Jan 2017 - Aug 2018, months are near-empty
       order_purchase_timestamp::timestamp >= '2017-01-01'
           AND order_purchase_timestamp::timestamp < '2018-09-01'                                  AS in_main_period
FROM raw.orders;

-- name: Rule - order_id is unique
ALTER TABLE clean.orders ADD PRIMARY KEY (order_id);

-- name: Rule - every order points at a real customer
ALTER TABLE clean.orders ADD FOREIGN KEY (customer_id) REFERENCES clean.customers (customer_id);
