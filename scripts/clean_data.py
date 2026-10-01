"""
BrightCart data cleaning script.

Reads the three raw exports and produces cleaned, standardized CSVs ready to
load into MySQL. Every cleaning decision is logged to the console (and
mirrored in docs/data_audit_notes.md) rather than applied silently.

Rules followed throughout:
- Never guess/invent values to fill gaps. Missing stays missing (NaN), not 0.
- Never silently delete rows. Anything dropped is flagged and counted.
- Standardize categorical text (trim whitespace, consistent case) before
  any grouping/summary work, since mismatched casing silently fragments
  categories in a pivot or GROUP BY.
"""

import pandas as pd

RAW = "."
CLEAN = "./clean"

# ---------------------------------------------------------------------------
# STORE_LOCATIONS
# ---------------------------------------------------------------------------
stores = pd.read_csv(f"{RAW}/store_locations.csv")

# store_id casing is inconsistent (str-06 vs STR-01..07). Standardize to
# uppercase so it joins cleanly against sales_transactions.store_id.
stores["store_id"] = stores["store_id"].str.upper()

stores.to_csv(f"{CLEAN}/store_locations_clean.csv", index=False)
print(f"[stores] {len(stores)} rows -> store_locations_clean.csv")
print(f"[stores] standardized store_id casing (e.g. str-06 -> STR-06)")

# ---------------------------------------------------------------------------
# INVENTORY
# ---------------------------------------------------------------------------
inv = pd.read_csv(f"{RAW}/inventory.csv")

# Standardize category text: trim whitespace, title-case consistently.
# "beverages" / "Beverages", "Snacks" / "Snacks ", "Personal Care" /
# "Personal care", "household" / "Household" all collapse to one spelling.
inv["category"] = inv["category"].str.strip().str.title()

# Duplicate product_id with conflicting stock (PRD-2004: 40 vs 58).
# Can't resolve which is correct without the client - flag, don't guess.
dup_mask = inv.duplicated("product_id", keep=False)
dup_rows = inv[dup_mask]
if len(dup_rows):
    print(f"[inventory] FLAGGED: {len(dup_rows)} rows share a duplicate "
          f"product_id with conflicting values - kept both, see audit note:")
    print(dup_rows[["product_id", "product_name", "stock_on_hand"]].to_string(index=False))

# Missing stock_on_hand (1 row: PRD-2003) - left as NaN, not assumed to be 0.
missing_stock = inv["stock_on_hand"].isna().sum()
print(f"[inventory] {missing_stock} row(s) with missing stock_on_hand - left blank, not zeroed")

inv.to_csv(f"{CLEAN}/inventory_clean.csv", index=False)
print(f"[inventory] {len(inv)} rows -> inventory_clean.csv (duplicate NOT removed, flagged for client decision)")

# ---------------------------------------------------------------------------
# SALES_TRANSACTIONS
# ---------------------------------------------------------------------------
sales = pd.read_csv(f"{RAW}/sales_transactions.csv")

before = len(sales)

# Drop fully-blank rows (all fields NaN) - these carry zero information,
# not valid "unknown" transactions. Flagged and counted, not silently gone.
blank_mask = sales.isna().all(axis=1)
n_blank = blank_mask.sum()
sales = sales[~blank_mask].copy()
print(f"[sales] dropped {n_blank} fully-blank row(s)")

# Exact duplicate transactions (same transaction_id + all fields identical)
# are almost certainly export duplication, not two separate real sales.
dupe_mask = sales.duplicated(keep="first")
n_dupes = dupe_mask.sum()
sales = sales[~dupe_mask].copy()
print(f"[sales] dropped {n_dupes} exact duplicate row(s) (kept first occurrence)")

# Standardize date formats -> ISO (YYYY-MM-DD). Source mixes YYYY-MM-DD,
# MM/DD/YYYY, and DD-Mon-YYYY. pandas infers each with dayfirst=False since
# the MM/DD pattern confirms US-style for this export.
def parse_date(s):
    for fmt in ("%Y-%m-%d", "%m/%d/%Y", "%d-%b-%Y"):
        try:
            return pd.to_datetime(s, format=fmt)
        except (ValueError, TypeError):
            continue
    return pd.NaT

sales["date"] = sales["date"].apply(parse_date)
unparsed = sales["date"].isna().sum()
if unparsed:
    print(f"[sales] WARNING: {unparsed} date(s) could not be parsed - left as NaT, flag for review")
sales["date"] = sales["date"].dt.strftime("%Y-%m-%d")
print(f"[sales] standardized all dates to YYYY-MM-DD")

# Standardize store_id casing to match cleaned store_locations.
sales["store_id"] = sales["store_id"].str.upper()

# Standardize payment_method, channel, customer_type casing.
sales["payment_method"] = sales["payment_method"].str.strip().str.title()
sales["payment_method"] = sales["payment_method"].replace({"Gcash": "GCash"})
sales["channel"] = sales["channel"].str.strip().str.title()
sales["customer_type"] = sales["customer_type"].str.strip().str.title()
print(f"[sales] standardized payment_method, channel, customer_type casing")

# Negative quantity: 7 rows. This needs a business-rule decision (return vs
# data-entry error) - NOT assumed. We add a flag column rather than altering
# or deleting the value, so the client's answer can be applied later without
# re-deriving which rows were affected.
sales["quantity"] = pd.to_numeric(sales["quantity"], errors="coerce")
sales["flag_negative_quantity"] = sales["quantity"] < 0
n_neg = sales["flag_negative_quantity"].sum()
print(f"[sales] flagged {n_neg} row(s) with negative quantity (NOT altered - "
      f"needs client decision: return vs entry error)")

# Missing quantity / unit_price: left as NaN, not zeroed or guessed.
sales["unit_price"] = pd.to_numeric(sales["unit_price"], errors="coerce")
n_missing_qty = sales["quantity"].isna().sum()
n_missing_price = sales["unit_price"].isna().sum()
print(f"[sales] {n_missing_qty} row(s) missing quantity, {n_missing_price} row(s) "
      f"missing unit_price - left blank")

# Missing customer_type (84 rows) - left as NaN. Likely means "not captured
# at point of sale" rather than a guessable category; do not default to
# "Walk-in", since that would misrepresent membership-driven revenue later.
n_missing_cust = sales["customer_type"].isna().sum()
print(f"[sales] {n_missing_cust} row(s) missing customer_type - left blank, "
      f"NOT defaulted to Walk-in")

after = len(sales)
print(f"[sales] {before} raw rows -> {after} clean rows "
      f"({before - after} removed: {n_blank} blank + {n_dupes} duplicate)")

sales.to_csv(f"{CLEAN}/sales_transactions_clean.csv", index=False)
print(f"[sales] saved -> sales_transactions_clean.csv")

# ---------------------------------------------------------------------------
# Join integrity check - confirm cleaned keys actually match across tables
# ---------------------------------------------------------------------------
print("\n=== JOIN INTEGRITY CHECK (post-clean) ===")
sales_stores = set(sales["store_id"].dropna().unique())
ref_stores = set(stores["store_id"].dropna().unique())
orphan_stores = sales_stores - ref_stores
print(f"store_id in sales but not in store_locations: {orphan_stores or 'none'}")

sales_products = set(sales["product_id"].dropna().unique())
ref_products = set(inv["product_id"].dropna().unique())
orphan_products = sales_products - ref_products
print(f"product_id in sales but not in inventory: {orphan_products or 'none'}")
