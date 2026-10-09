-- Reporting queries for the client summary. These power the plain-language
-- findings in reports/summary.md.

USE brightcart;

-- 1. Revenue and transaction volume by store (completed sales only, i.e.
--    excluding rows flagged negative-quantity until their meaning is
--    confirmed, and excluding rows with missing quantity/price since
--    revenue can't be computed for those).
SELECT
    d.store_name,
    d.city,
    COUNT(*) AS transaction_count,
    SUM(f.quantity * f.unit_price) AS gross_revenue,
    ROUND(AVG(f.quantity * f.unit_price), 2) AS avg_transaction_value
FROM fact_sales f
JOIN dim_store d ON f.store_id = d.store_id
WHERE f.flag_negative_quantity = FALSE
  AND f.quantity IS NOT NULL
  AND f.unit_price IS NOT NULL
GROUP BY d.store_name, d.city
ORDER BY gross_revenue DESC;

-- 2. Revenue by product category.
SELECT
    p.category,
    COUNT(*) AS transaction_count,
    SUM(f.quantity * f.unit_price) AS gross_revenue
FROM fact_sales f
JOIN dim_product p ON f.product_id = p.product_id
WHERE f.flag_negative_quantity = FALSE
  AND f.quantity IS NOT NULL
  AND f.unit_price IS NOT NULL
GROUP BY p.category
ORDER BY gross_revenue DESC;

-- 3. Online vs in-store split.
SELECT
    f.channel,
    COUNT(*) AS transaction_count,
    SUM(f.quantity * f.unit_price) AS gross_revenue
FROM fact_sales f
WHERE f.flag_negative_quantity = FALSE
  AND f.quantity IS NOT NULL
  AND f.unit_price IS NOT NULL
GROUP BY f.channel;

-- 4. Rows needing a client decision before they can be reported on at all:
--    negative quantity (return? entry error?).
SELECT transaction_id, txn_date, store_id, product_id, quantity
FROM fact_sales
WHERE flag_negative_quantity = TRUE
ORDER BY txn_date;

-- 5. Low-stock alert: items at or below their reorder level.
SELECT product_id, product_name, stock_on_hand, reorder_level
FROM dim_product
WHERE stock_on_hand IS NOT NULL
  AND stock_on_hand <= reorder_level
ORDER BY stock_on_hand ASC;

-- 6. Revenue lost to incomplete records: how much sales data can't be
--    used because quantity or price is missing. Worth surfacing to the
--    client as a data-capture problem, not just a cleaning footnote.
SELECT COUNT(*) AS unusable_rows
FROM fact_sales
WHERE quantity IS NULL OR unit_price IS NULL;
