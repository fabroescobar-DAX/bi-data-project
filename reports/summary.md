# BrightCart Sales & Inventory — Summary (for James)

**Covers:** 343 usable transactions out of 410 raw / 400 cleaned
(June–October 2025 export), across 7 stores (6 physical + online).

## Three things that matter

1. **Divisoria is your top branch, but Bugo moves the most volume.**
   Divisoria leads on revenue (₱47.7K) despite fewer transactions (53)
   than Bugo (62 transactions, ₱44.4K) — its average sale is higher.
   Worth checking whether Divisoria is upselling better or just has a
   pricier product mix; that's replicable if it's the former.

2. **Snacks and School Supplies are your two biggest categories by a
   wide margin** (₱65K and ₱62K respectively), together accounting for
   about 44% of usable revenue. Beverages and Frozen Goods are the
   smallest (~₱32-35K each). If shelf space or promo budget is being
   split evenly across categories, it isn't matching where the revenue
   actually comes from.

3. **12.5% of your transactions (50 of 400) have no usable quantity
   and/or price — meaning your real revenue picture is undercounted,
   not just imprecise.** This isn't a one-off; it's roughly 1 in 8
   transactions. Before trusting any revenue number from this data
   (including the ones above), I'd flag this to whoever runs your
   point-of-sale exports — it looks like a systematic capture gap, not
   random noise.

## One recommendation

Get an answer on the two open data questions (duplicate product record
for Crackers Family Pack, and what the negative-quantity transactions
mean) before this becomes a recurring report. Right now both are handled
conservatively (flagged, not guessed), but neither should stay
unresolved if this data is going to drive actual restocking or revenue
decisions — a wrong guess compounds every time the report reruns.

## Revenue by store

| Store | Transactions | Revenue |
|---|---|---|
| BrightCart Divisoria | 53 | ₱47,721.91 |
| BrightCart Bugo | 62 | ₱44,381.46 |
| BrightCart Centrio | 49 | ₱44,030.15 |
| BrightCart Carmen | 51 | ₱43,510.44 |
| BrightCart Online | 42 | ₱35,804.01 |
| BrightCart Uptown (Iligan) | 42 | ₱35,012.72 |
| BrightCart Butuan | 44 | ₱33,780.12 |

## Revenue by category

| Category | Transactions | Revenue |
|---|---|---|
| Snacks | 75 | ₱65,008.73 |
| School Supplies | 70 | ₱61,951.79 |
| Personal Care | 75 | ₱55,369.56 |
| Household | 47 | ₱35,042.87 |
| Frozen Goods | 39 | ₱34,976.93 |
| Beverages | 37 | ₱31,890.93 |

## Channel split

| Channel | Transactions | Revenue |
|---|---|---|
| In-Store | 168 | ₱151,677.55 |
| Online | 175 | ₱132,563.26 |

Online edges out In-Store on transaction count (175 vs 168) but trails
on revenue — in-store transactions are worth more on average. Worth a
look if there's a mix-shift opportunity (pushing higher-value categories
online) rather than treating the two channels as interchangeable.

## Low stock (at or below reorder level)

| Product | Stock on hand | Reorder level |
|---|---|---|
| Shampoo Sachet | 47 | 50 |
| Toothpaste 150g | 27 | 49 |
| Crackers Family Pack | 40* | 50 |

*Crackers Family Pack is the duplicate-record item — this number is one
of two conflicting values in the raw export (40 or 58) and isn't
confirmed. Treat as provisional until resolved.

## Open questions (see full audit note for detail)

1. Duplicate inventory record for Crackers Family Pack — which stock
   figure is right?
2. 7 transactions with negative quantity — returns or entry errors?
3. 50 transactions with missing quantity/price — known gap or something
   IT should look into?
