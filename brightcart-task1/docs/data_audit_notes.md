# BrightCart Data Audit Notes

**Scope:** `sales_transactions.csv` (410 rows), `inventory.csv` (21 rows),
`store_locations.csv` (7 rows). Raw exports, untouched.

## Join keys

- `sales_transactions.store_id` → `store_locations.store_id`
- `sales_transactions.product_id` → `inventory.product_id`

## store_locations.csv

- 7 rows, one per branch plus the online store (`str-06` / `BrightCart
  Online`).
- **Casing inconsistency:** `str-06` is lowercase while every other
  `store_id` is uppercase (`STR-01`..`STR-07`). In this specific export the
  value happens to still match its counterpart in `sales_transactions`
  exactly, so it wasn't actually join-breaking here — but it's the kind of
  inconsistency that *would* silently break a join (or a `GROUP BY`) the
  moment someone re-exports the data with different casing. Standardized
  to uppercase in cleaning rather than left as a ticking time bomb.
- **Online store has no city/region** (`BrightCart Online` — both blank).
  Legitimate (it's not a physical branch), but worth flagging because any
  `GROUP BY city` or `GROUP BY region` summary will silently drop this
  store's transactions if the grouping isn't done carefully. This bit us
  once already while building the report (see Gotchas below) and is a
  good example of why blank ≠ safe-to-ignore.

## inventory.csv

- 21 rows, 20 distinct products.
- **Category casing inconsistent:** `beverages`/`Beverages`,
  `Snacks`/`Snacks ` (trailing space), `Personal Care`/`Personal care`,
  `household`/`Household` — 10 raw values collapsing to 6 real categories.
  Standardized via trim + title-case.
- **Duplicate product_id:** `PRD-2004` (Crackers Family Pack) appears
  twice, and the two rows conflict on **both** `stock_on_hand` (40 vs
  58) **and** `category` (Household vs School Supplies) — not just
  stock, as I first assumed before checking the raw values directly.
  Same product name, cost, and supplier otherwise. **Question for
  client:** which values are correct, or does this represent two
  genuinely different product records (different batch, different
  category classification) that shouldn't share a product_id at all?
  Not resolved — both rows are preserved in the staging table; the
  modeled layer currently takes `MAX()` of every conflicting field as a
  conservative placeholder, clearly documented in
  `sql/03_build_model.sql`, not silently picked. Grouping the build
  query by `product_id` alone (rather than `product_id` + `product_name`
  + `category`) matters here — grouping by the fuller set would treat
  the two conflicting rows as two different products and fail on
  insert, since `product_id` is the actual primary key.
- **1 missing `stock_on_hand`** (`PRD-2003`, Potato Chips 60g) — left
  blank, not assumed to be 0 (zero stock and "we don't know" are very
  different facts for a reorder decision).
- No negative stock values in this export.

## sales_transactions.csv

- 410 raw rows.
- **2 fully blank rows** — every field empty. Dropped (they carry no
  information; keeping them would just be dead weight in every summary).
- **8 exact duplicate transactions** (16 rows total, in pairs) — same
  `transaction_id` and every other field identical. Almost certainly
  export duplication rather than two real sales sharing an ID. Dropped,
  kept first occurrence.
- **Mixed date formats:** `YYYY-MM-DD`, `MM/DD/YYYY`, and `DD-Mon-YYYY`
  all appear in the same column. Standardized to `YYYY-MM-DD`.
- **store_id casing** inconsistent in the same way as store_locations
  (`str-06` vs `STR-01`..`07`) — standardized to uppercase.
- **payment_method, channel, customer_type** all have casing
  inconsistencies (`CARD`/`Card`/`cash`, `ONLINE`/`Online`/`in-store`,
  `member`/`Member`/`walk-in`) — standardized to Title Case.
- **7 rows with negative quantity.** **Question for client, not assumed:**
  are these returns, or data-entry errors? Flagged with a
  `flag_negative_quantity` column rather than deleted, converted to
  positive, or guessed at — excluded from revenue totals until answered,
  but still visible for review (see `sql/05_reporting_queries.sql` query
  4).
- **25 rows missing quantity, 29 rows missing unit_price** (some overlap)
  — left blank. Combined with the negative-quantity rows, **50 of 400
  cleaned rows (12.5%) can't currently be used to compute revenue.** This
  is worth raising with the client as a point-of-sale data-capture
  problem, not just a cleaning footnote — that's a meaningful chunk of
  transactions with no usable dollar figure attached.
- **84 rows missing customer_type** — left blank, not defaulted to
  "Walk-in." Defaulting would have overstated walk-in traffic and
  understated membership, which matters if the client ever wants to look
  at member vs. non-member behavior.

## Gotcha worth calling out explicitly

When first computing revenue by store, grouping by `(store_name, city)`
silently dropped the Online store entirely, because `BrightCart Online`
has a blank `city`, and `pandas.groupby()` drops rows with a NaN key by
default. The store wasn't in the output and nothing errored — it just
vanished. Caught by checking that transaction counts summed back to the
expected total (343) before trusting the table. Re-grouped by
`(store_id, store_name)` instead, which doesn't depend on a field that's
legitimately blank for one store. Note: MySQL's `GROUP BY` treats `NULL`
as a valid group by default (unlike pandas), so this specific failure
mode is pandas-specific — but the underlying lesson (check your grouping
keys don't include something that can be blank, unless you want it) holds
regardless of tool.

## Questions for the client (James)

1. `PRD-2004` duplicate — which `stock_on_hand` value is correct, 40 or
   58? Or are these genuinely two different stock records that shouldn't
   share a product_id?
2. Negative quantities (7 rows) — returns, or entry errors? Needed before
   these can be included in any revenue number.
3. 50 transactions (12.5%) have no usable quantity and/or price — is this
   a known point-of-sale export gap, or should IT look into why these
   fields aren't being captured consistently?

## Known issues in the load process (for transparency, not hidden)

- **`PRD-2003` (Potato Chips 60g) failed to load via MySQL Workbench's
  Table Data Import Wizard**, along with the rest of `inventory_clean.csv`
  loading as "successful" with no visible error. Root cause: this row's
  `stock_on_hand` field is genuinely blank (see note above — missing, not
  zero), and the Wizard doesn't surface a clear error when a blank numeric
  field breaks a row; it just silently drops it. This was caught because
  `dim_product` had 19 rows instead of the expected 20, which then showed
  up as 7 excluded rows in the `fact_sales` build step (every sale of
  PRD-2003, across different stores). Traced back to the missing staging
  row via `SELECT * FROM stg_product WHERE product_id = 'PRD-2003'`
  returning 0 rows, and fixed with a direct single-row `INSERT` into
  `stg_product` using the values from the cleaned CSV, followed by
  rebuilding `dim_product` and `fact_sales` from the corrected staging
  data.
- **The same class of bug affected `stg_sales`** earlier in the build —
  the Import Wizard also mishandled the `flag_negative_quantity` column
  when it still contained literal Python `True`/`False` text instead of
  `0`/`1` integers. Fixed at the source in `clean_data.py`
  (`.astype(int)`), then loaded via a standalone direct-`INSERT` SQL
  script (`sql/06_insert_stg_sales_direct.sql`) rather than continuing to
  fight the Wizard or `LOAD DATA LOCAL INFILE`, which also proved
  unreliable in this environment.
- **Lesson for a real client engagement:** the Import Wizard's "success"
  message is not sufficient proof that all rows loaded. Always verify row
  counts against the source file after any import step, before building
  on top of it.
