-- Validation queries: run these after 03_build_model.sql and sanity-check
-- the numbers before trusting any report built on top of this.

USE brightcart;

-- Row counts should roughly match the cleaned CSVs (400 sales rows, 7
-- stores, 20 distinct products after de-duplication).
SELECT 'dim_store' AS tbl, COUNT(*) AS row_count FROM dim_store
UNION ALL
SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL
SELECT 'fact_sales', COUNT(*) FROM fact_sales;

-- No orphan foreign keys (should return 0 rows each).
SELECT f.transaction_id, f.store_id
FROM fact_sales f
LEFT JOIN dim_store d ON f.store_id = d.store_id
WHERE d.store_id IS NULL;

SELECT f.transaction_id, f.product_id
FROM fact_sales f
LEFT JOIN dim_product d ON f.product_id = d.product_id
WHERE d.product_id IS NULL;

-- No duplicate transaction_id (PRIMARY KEY should already enforce this,
-- but confirm).
SELECT transaction_id, COUNT(*)
FROM fact_sales
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- Sanity check: date range looks right (no dates outside the expected
-- export window).
SELECT MIN(txn_date), MAX(txn_date) FROM fact_sales;
