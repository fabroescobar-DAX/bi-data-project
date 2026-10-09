-- Fix for PRD-2003 missing from stg_product after the Table Data Import
-- Wizard silently dropped it (blank stock_on_hand field broke the row with
-- no visible error in the Wizard's log). See docs/data_audit_notes.md,
-- "Known issues in the load process", for the full diagnosis.
--
-- Run this AFTER loading inventory_clean.csv into stg_product and BEFORE
-- (re)running sql/03_build_model.sql.

USE brightcart;

-- Confirm the row is actually missing before inserting (expect 0 rows).
SELECT * FROM stg_product WHERE product_id = 'PRD-2003';

INSERT INTO stg_product (product_id, product_name, category, stock_on_hand, reorder_level, unit_cost, supplier)
VALUES ('PRD-2003', 'Potato Chips 60g', 'Snacks', NULL, 50, 12.50, 'SnackCo Distributors');

-- Expect 21 (20 distinct products + 1 duplicate PRD-2004 row still in staging).
SELECT COUNT(*) AS total_stg_product_rows FROM stg_product;
