-- BrightCart retail reporting schema
-- Run after loading cleaned CSVs (see 02_load_notes.md).
--
-- Pattern: staging tables hold data exactly as cleaned (still has the
-- flagged duplicate product_id), so nothing is lost. The dim_/fact_ tables
-- are the final modeled layer used for reporting, built FROM staging with
-- the duplicate resolved. This is standard practice so a data-quality
-- issue in the source never blocks loading, and never gets silently
-- "fixed" before anyone decides how.

CREATE DATABASE IF NOT EXISTS brightcart;
USE brightcart;

-- ---------------------------------------------------------------------
-- STAGING: raw load target, 1:1 with the cleaned CSVs, no constraints
-- that would reject a row. This is where data quality issues live
-- until a decision is made.
-- ---------------------------------------------------------------------

CREATE TABLE stg_store (
    store_id    VARCHAR(10),
    store_name  VARCHAR(100),
    city        VARCHAR(50),
    region      VARCHAR(50)
);

CREATE TABLE stg_product (
    product_id      VARCHAR(10),
    product_name    VARCHAR(150),
    category        VARCHAR(50),
    stock_on_hand   INT NULL,
    reorder_level   INT,
    unit_cost       DECIMAL(10,2),
    supplier        VARCHAR(100)
);

CREATE TABLE stg_sales (
    transaction_id          VARCHAR(15),
    txn_date                DATE NULL,
    store_id                VARCHAR(10),
    product_id              VARCHAR(10),
    quantity                INT NULL,
    unit_price               DECIMAL(10,2) NULL,
    payment_method            VARCHAR(20),
    channel                   VARCHAR(20),
    customer_type             VARCHAR(20) NULL,
    flag_negative_quantity    BOOLEAN DEFAULT FALSE
);

-- ---------------------------------------------------------------------
-- MODELED LAYER: what reports/Power BI actually query against.
-- Built from staging in 03_build_model.sql, after the PRD-2004
-- duplicate is resolved per the client's answer.
-- ---------------------------------------------------------------------

CREATE TABLE dim_store (
    store_id    VARCHAR(10) PRIMARY KEY,
    store_name  VARCHAR(100) NOT NULL,
    city        VARCHAR(50),
    region      VARCHAR(50)
);

CREATE TABLE dim_product (
    product_id      VARCHAR(10) PRIMARY KEY,
    product_name    VARCHAR(150),
    category        VARCHAR(50),
    stock_on_hand   INT NULL,
    reorder_level   INT,
    unit_cost       DECIMAL(10,2),
    supplier        VARCHAR(100)
);

CREATE TABLE fact_sales (
    transaction_id          VARCHAR(15) PRIMARY KEY,
    txn_date                 DATE NOT NULL,
    store_id                 VARCHAR(10) NOT NULL,
    product_id                VARCHAR(10) NOT NULL,
    quantity                   INT NULL,
    unit_price                 DECIMAL(10,2) NULL,
    payment_method              VARCHAR(20),
    channel                     VARCHAR(20),
    customer_type               VARCHAR(20) NULL,
    flag_negative_quantity      BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (store_id) REFERENCES dim_store(store_id),
    FOREIGN KEY (product_id) REFERENCES dim_product(product_id)
);
