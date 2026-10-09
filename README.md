# BrightCart Sales & Inventory Data Pipeline

End-to-end data cleaning, relational modeling, and reporting project built
from raw retail exports — sales transactions, inventory, and store
locations for a fictional multi-branch retailer (BrightCart) in Cagayan de
Oro, Philippines.

**Stack:** Python (pandas) for cleaning → MySQL for staging/modeling →
SQL for validation and reporting.

## What this project demonstrates

Raw exports are never clean. This project works through the kind of
messy, ambiguous data an analyst actually gets handed — not a
pre-cleaned tutorial dataset — and documents every decision instead of
silently fixing or guessing:

- **Mixed formats and inconsistent casing** across dates, store IDs, and
  categorical fields, standardized before any grouping or joins.
- **A genuine data conflict**: a duplicate product record with two
  different `stock_on_hand` *and* `category` values, with no way to know
  which is correct — flagged for the client rather than silently picked.
- **Ambiguous values treated as questions, not errors**: negative
  quantities (returns? entry errors?) and missing customer types are
  flagged and preserved, not deleted or defaulted.
- **A real import failure caught by validation, not luck**: one inventory
  row silently failed to load through MySQL Workbench's Import Wizard
  (no error shown) because of a blank numeric field. It was only caught
  because the staging→model row counts didn't reconcile — see
  [`brightcart-task1/docs/data_audit_notes.md`](brightcart-task1/docs/data_audit_notes.md)
  for the full diagnosis and fix.
- **Referential integrity enforced, not assumed**: a staging layer with no
  constraints feeds a modeled layer (`dim_`/`fact_`) with primary/foreign
  keys, and every load is validated with orphan-key and duplicate checks
  before being trusted.

## Pipeline

```
raw CSVs (brightcart-task1/data/raw/)
   → clean_data.py (pandas: standardize, flag, never silently alter)
   → clean CSVs (brightcart-task1/data/clean/)
   → stg_* tables (no constraints, MySQL)
   → dim_*/fact_* tables (constrained model, MySQL)
   → validation checks (row counts, orphan FKs, duplicates)
   → reporting queries
```

Full run order is documented in
[`brightcart-task1/sql/02_load_notes.md`](brightcart-task1/sql/02_load_notes.md).

## Structure

All project files live under [`brightcart-task1/`](brightcart-task1/):

| Path | What's in it |
|---|---|
| `data/raw/` | Original, untouched exports |
| `data/clean/` | Cleaned CSVs, output of `clean_data.py` |
| `scripts/clean_data.py` | Cleaning logic, with every decision logged |
| `sql/01_schema.sql` | Staging + modeled table definitions |
| `sql/02_load_notes.md` | How to load the data (and what went wrong) |
| `sql/03_build_model.sql` | Staging → modeled table build |
| `sql/04_validation.sql` | Row count, orphan-key, duplicate checks |
| `sql/05_reporting_queries.sql` | Revenue, category, low-stock queries |
| `sql/06_insert_stg_sales_direct.sql` | Fix for a failed sales CSV import |
| `sql/07_fix_stg_product_prd2003.sql` | Fix for a failed inventory row |
| `docs/data_audit_notes.md` | Full data audit — every issue found, and why each decision was made |
| `reports/summary.md` | Findings written for a non-technical stakeholder |

## Key findings

See [`brightcart-task1/reports/summary.md`](brightcart-task1/reports/summary.md) for the full write-up.
Headline: 12.5% of transactions (50 of 400) have no usable quantity
and/or price — a systematic point-of-sale capture gap, not random noise,
worth escalating before trusting any revenue figure from this data.

## Why document the mistakes too

The `sql/06_*` and `sql/07_*` fix scripts exist because the Import Wizard
reported success while silently dropping rows. Catching that wasn't
luck — it came from validating row counts after every load step instead
of trusting a green checkmark. That habit is the actual point of this
project.
