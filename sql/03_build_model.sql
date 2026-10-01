-- Build the modeled (dim_/fact_) tables from staging.
-- Run after loading CSVs into stg_store, stg_product, stg_sales.

USE brightcart;

-- dim_store: straight copy, no conflicts found here after cleaning.
INSERT INTO dim_store (store_id, store_name, city, region)
SELECT DISTINCT store_id, store_name, city, region
FROM stg_store;

-- dim_product: resolve the PRD-2004 duplicate.
-- DECISION NEEDED FROM CLIENT: stg_product has two PRD-2004 rows with
-- different stock_on_hand (40 vs 58). Until James confirms which is
-- correct, this keeps the HIGHER value as a conservative placeholder
-- (documented here, not hidden) and both original rows remain visible
-- in stg_product for audit purposes.
INSERT INTO dim_product (product_id, product_name, category, stock_on_hand, reorder_level, unit_cost, supplier)
SELECT product_id, product_name, category, MAX(stock_on_hand), MAX(reorder_level), MAX(unit_cost), MAX(supplier)
FROM stg_product
GROUP BY product_id, product_name, category;

-- fact_sales: only load rows whose store_id and product_id actually exist
-- in the dimension tables (protects referential integrity). Anything that
-- fails this should be zero post-cleaning per our join-integrity check,
-- but the WHERE clause is a safety net, not an assumption.
INSERT INTO fact_sales
SELECT s.*
FROM stg_sales s
WHERE s.store_id IN (SELECT store_id FROM dim_store)
  AND s.product_id IN (SELECT product_id FROM dim_product);

-- Report anything that got excluded by the safety net above (should be 0 rows).
SELECT COUNT(*) AS excluded_sales_rows
FROM stg_sales s
WHERE s.store_id NOT IN (SELECT store_id FROM dim_store)
   OR s.product_id NOT IN (SELECT product_id FROM dim_product);
