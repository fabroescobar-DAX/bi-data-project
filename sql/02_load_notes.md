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

## Option B — command line (`LOAD DATA INFILE`)

Faster once you're comfortable with it, but MySQL's `secure_file_priv`
setting restricts which folders it can read from — check
`SHOW VARIABLES LIKE 'secure_file_priv';` first and put the CSVs there,
or use `LOAD DATA LOCAL INFILE` with `--local-infile=1` on the client.

```sql
LOAD DATA LOCAL INFILE 'clean/store_locations_clean.csv'
INTO TABLE stg_store
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
-- repeat for stg_product and stg_sales with their respective files
```

Either way, load into the `stg_` tables first, then run
`03_build_model.sql`.
