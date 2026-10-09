# Loading the cleaned CSVs into MySQL

Run `01_schema.sql` first to create the database and tables.

## Option A — MySQL Workbench (easiest if you're new to this)

1. Open MySQL Workbench, connect to your local server.
2. Run `01_schema.sql` as a script (creates the `brightcart` database + tables).
3. Right-click `stg_store` → Table Data Import Wizard → select
   `clean/store_locations_clean.csv` → map columns → import.
4. Repeat for `stg_product` ← `inventory_clean.csv`, and
   `stg_sales` ← `sales_transactions_clean.csv`.
5. Run `03_build_model.sql` to populate the dim_/fact_ tables from staging.
6. Run `04_validation.sql` to confirm row counts and referential integrity.

## Option B — command line (`LOAD DATA`), recommended over the Import Wizard

The Table Data Import Wizard can silently fail or misreport success on
this dataset - it does not handle blank numeric fields cleanly. Use
`LOAD DATA` directly instead:

```sql
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/path/to/data/clean/store_locations_clean.csv'
INTO TABLE stg_store
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/path/to/data/clean/inventory_clean.csv'
INTO TABLE stg_product
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, product_name, category, @stock, reorder_level, unit_cost, supplier)
SET stock_on_hand = NULLIF(@stock, '');

LOAD DATA LOCAL INFILE 'C:/path/to/data/clean/sales_transactions_clean.csv'
INTO TABLE stg_sales
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(transaction_id, txn_date, store_id, product_id, @qty, @price, payment_method, channel, @cust_type, flag_negative_quantity)
SET quantity = NULLIF(@qty, ''),
    unit_price = NULLIF(@price, ''),
    customer_type = NULLIF(@cust_type, '');
```

Use forward slashes in the path even on Windows (MySQL accepts them, and
it avoids backslash-escaping headaches). The `@variable` + `NULLIF(...,
'')` pattern is what makes a truly blank CSV field load as SQL `NULL`
instead of an empty string that a numeric column will reject.

If `LOAD DATA LOCAL INFILE` is refused outright even after `SET GLOBAL
local_infile = 1`, your MySQL client also needs the local-infile
capability enabled (Workbench normally has this on by default, but if
not: Edit Connection > Advanced > check "Enable LOAD DATA LOCAL
INFILE").

Either way, load into the `stg_` tables first, then run
`03_build_model.sql` from `sql/03_build_model.sql` (note: use the
corrected version - see that file's comment about grouping by
`product_id` alone, not `product_id, product_name, category`).
