-- Clean layer, part 2a: product categories, products and sellers.
-- Fixes types, fixes two misspelled column names, adds English category names.
-- Run with:  python -m src.build_sql sql/clean_products_sellers.sql

-- name: Drop old categories, products and sellers
-- CASCADE also removes links from clean.order_items; that table is rebuilt in part 2b.
DROP TABLE IF EXISTS clean.products, clean.sellers, clean.product_categories CASCADE;

-- name: Build clean.product_categories (Olist list + 2 added)
CREATE TABLE clean.product_categories AS
SELECT product_category_name, product_category_name_english, 'olist' AS translated_by
FROM raw.product_category_name_translation
UNION ALL  -- used by products but missing from Olist's list (found in profiling)
SELECT 'portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_and_food_preparers', 'this project'
UNION ALL
SELECT 'pc_gamer', 'pc_gamer', 'this project';

-- name: Rule - each category appears once
ALTER TABLE clean.product_categories ADD PRIMARY KEY (product_category_name);

-- name: Build clean.products
CREATE TABLE clean.products AS
SELECT p.product_id,
       p.product_category_name,                                                    -- Portuguese, NULL if missing
       coalesce(c.product_category_name_english, 'unknown') AS product_category,  -- English name
       p.product_name_lenght::integer        AS product_name_length,         -- fixes the misspelling "lenght"
       p.product_description_lenght::integer AS product_description_length,  -- fixes the misspelling "lenght"
       p.product_photos_qty::integer         AS product_photos_qty,
       p.product_weight_g::integer           AS product_weight_g,
       p.product_length_cm::integer          AS product_length_cm,
       p.product_height_cm::integer          AS product_height_cm,
       p.product_width_cm::integer           AS product_width_cm,
       p.product_category_name IS NULL       AS flag_no_category,  -- these also lack name, description and photo info
       coalesce(p.product_weight_g::integer = 0, false) AS flag_zero_weight,
       (p.product_weight_g IS NULL OR p.product_length_cm IS NULL
        OR p.product_height_cm IS NULL OR p.product_width_cm IS NULL) AS flag_missing_size
FROM raw.products p
LEFT JOIN clean.product_categories c ON c.product_category_name = p.product_category_name;

-- name: Rule - product_id is unique
ALTER TABLE clean.products ADD PRIMARY KEY (product_id);

-- name: Rule - every named category is in the list (NULL allowed)
-- Unlike orders.customer_id, NULL is fine here: 610 products genuinely have no category.
ALTER TABLE clean.products ADD FOREIGN KEY (product_category_name)
    REFERENCES clean.product_categories (product_category_name);

-- name: Build clean.sellers
CREATE TABLE clean.sellers AS
SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state  -- zip stays text (leading zeros)
FROM raw.sellers;

-- name: Rule - seller_id is unique
ALTER TABLE clean.sellers ADD PRIMARY KEY (seller_id);
