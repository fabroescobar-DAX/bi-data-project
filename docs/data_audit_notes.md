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
  twice with conflicting `stock_on_hand` — 40 in one row, 58 in the
  other. Same product name, category, cost, and supplier otherwise.
  **Question for client:** which stock figure is correct, or does this
  represent two different batches/locations that shouldn't have been
  merged into one product_id? Not resolved — both rows are preserved in
  the staging table; the reporting layer currently uses the higher value
  (58) as a conservative placeholder, clearly documented in
  `sql/03_build_model.sql`, not silently picked.
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
