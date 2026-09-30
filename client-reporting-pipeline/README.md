# BI Client Reporting Pipeline

Practice portfolio project simulating a freelance client engagement: raw multi-table
business data (sales, inventory, customer communications) → cleaned and validated →
loaded into MySQL → modeled and reported in Power BI.

## Structure

```
data/raw/       Untouched source exports. Never edited in place.
data/clean/     Output of cleaning scripts only — never hand-edited.
scripts/        Python (pandas) cleaning and transformation scripts.
sql/            MySQL schema, load scripts, validation/QA queries.
dashboards/     Power BI (.pbix) files.
docs/           ERDs, flowcharts, business-rule notes, assumptions logs.
reports/        Final client-facing summaries (plain-language findings).
```

## Workflow

1. Raw data lands in `data/raw/` — treated as read-only.
2. `scripts/` clean and standardize it (formats, duplicates, missing values,
   category normalization), writing results to `data/clean/`.
3. `sql/` loads the cleaned data into MySQL and models it (fact/dimension tables),
   plus validation queries (row counts, duplicate checks, referential integrity).
4. `dashboards/` holds the Power BI file built on top of the modeled data.
5. `reports/` holds the plain-language write-up: findings + one recommendation,
   written for a non-technical stakeholder.

## Log

- 2026-09-30: Project scaffolded. Replaces the earlier Riot Games API project as
  the active portfolio piece — this one mirrors real freelance client work
  (data cleaning, SQL modeling, Power BI reporting, client-facing summaries).
