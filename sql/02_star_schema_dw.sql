-- ============================================================
-- PROJECT  : E-Commerce Sales Data Warehouse
-- DATASET  : ecommerce_dataset_1m.csv (~1,000,000 rows)
-- PHASE    : 1 — Step 5: Star Schema (Data Warehouse)
-- DBMS     : PostgreSQL 14+ / 18 compatible
--
-- LOGICAL DESIGN SUMMARY
-- DFM → Star Schema translation rules applied:
--   1. Each DFM dimension → one flat DIM_ table (denormalised)
--   2. Hierarchies are flattened inside the dimension table
--      (star, not snowflake) for Tableau compatibility
--   3. Surrogate integer keys replace all natural keys
--   4. FACT_SALES holds only FK references + raw measures
--
-- STRUCTURE : 1 fact table + 8 dimension tables
-- GRAIN     : One row = One unique sales order
-- ============================================================

DROP TABLE IF EXISTS fact_sales    CASCADE;
DROP TABLE IF EXISTS dim_date      CASCADE;
DROP TABLE IF EXISTS dim_product   CASCADE;
DROP TABLE IF EXISTS dim_customer  CASCADE;
DROP TABLE IF EXISTS dim_geography CASCADE;
DROP TABLE IF EXISTS dim_shipping  CASCADE;
DROP TABLE IF EXISTS dim_payment   CASCADE;
DROP TABLE IF EXISTS dim_order     CASCADE;
DROP TABLE IF EXISTS dim_marketing CASCADE;

-- ============================================================
-- DIMENSION TABLES
-- ============================================================

-- ------------------------------------------------------------
-- DIM_DATE
-- Source: order_date, order_year, order_month, order_day,
--         is_weekend from SALES_ORDER.
-- Hierarchy exposed: day → month → quarter → year
-- Key: YYYYMMDD integer (e.g. 20240315 for 15 Mar 2024).
--      Integer keys are faster than DATE joins at 1M+ scale.
-- Extra attribute: is_weekend for weekday/weekend slicing.
-- ------------------------------------------------------------
CREATE TABLE dim_date (
    date_key     INTEGER      NOT NULL,   -- YYYYMMDD integer surrogate key
    full_date    DATE         NOT NULL,
    day_of_month SMALLINT     NOT NULL CHECK (day_of_month BETWEEN 1 AND 31),
    month_num    SMALLINT     NOT NULL CHECK (month_num    BETWEEN 1 AND 12),
    month_name   VARCHAR(10)  NOT NULL,   -- January … December
    quarter      SMALLINT     NOT NULL CHECK (quarter      BETWEEN 1 AND 4),
    year         SMALLINT     NOT NULL,
    is_weekend   BOOLEAN      NOT NULL,   -- TRUE for Saturday / Sunday
    CONSTRAINT pk_dim_date PRIMARY KEY (date_key)
);

COMMENT ON TABLE  dim_date           IS 'Date dimension. Hierarchy: day → month → quarter → year.';
COMMENT ON COLUMN dim_date.date_key  IS 'Surrogate key: YYYYMMDD integer (e.g. 20240315).';
COMMENT ON COLUMN dim_date.is_weekend IS 'TRUE when the order was placed on a Saturday or Sunday.';

-- ------------------------------------------------------------
-- DIM_PRODUCT
-- Source: product_id, product_name, sub_category, category,
--         brand, product_rating_avg from PRODUCT in reconciled DB.
-- Hierarchy exposed: product → sub_category → category
-- Additional branch: brand (lateral attribute, not a strict
--   hierarchy level — one brand spans multiple categories).
-- Denormalised: sub_category and category are stored as
--   VARCHAR columns (not FK references) per star schema rules.
-- ------------------------------------------------------------
CREATE TABLE dim_product (
    product_key   VARCHAR(20)   NOT NULL,   -- natural key from source (e.g. PRD-1FPK)
    product_name  VARCHAR(150)  NOT NULL,
    sub_category  VARCHAR(80)   NOT NULL,   -- 22 values
    category      VARCHAR(50)   NOT NULL,   -- 5 values: Electronics/Health/Clothing/Sports/Home
    brand         VARCHAR(80)   NOT NULL,   -- 20 brands
    rating_avg    NUMERIC(3,1)  NOT NULL,   -- product average rating 3.0–5.0
    CONSTRAINT pk_dim_product PRIMARY KEY (product_key)
);

COMMENT ON TABLE dim_product IS 'Product dimension. Hierarchy: product → sub_category → category. Branch: brand.';

-- ------------------------------------------------------------
-- DIM_CUSTOMER
-- Source: customer_id, gender, age (→ age_group),
--         customer_segment, customer_loyalty_score,
--         tenure_days (derived from account_creation_date).
-- Note: city and country are separated into DIM_GEOGRAPHY to
--       allow independent geographic slicing without coupling
--       it to the customer profile.
-- age_group is engineered in ETL from raw age:
--   18–25 = Young Adults, 26–35 = Adults, 36–50 = Mid-Career,
--   51–75 = Mature Customers.
-- ------------------------------------------------------------
CREATE TABLE dim_customer (
    customer_key        INTEGER      NOT NULL,   -- surrogate key (auto-generated in ETL)
    source_customer_id  VARCHAR(20)  NOT NULL,   -- original customer_id from source for traceability
    gender              VARCHAR(10)  NOT NULL,   -- Male | Female
    age_group           VARCHAR(20)  NOT NULL,   -- engineered: Young Adults | Adults | Mid-Career | Mature
    segment             VARCHAR(20)  NOT NULL,   -- Regular | Premium | VIP
    loyalty_score       NUMERIC(5,2) NOT NULL,   -- 0.00–100.00 continuous
    tenure_days         INTEGER,                 -- days since account creation; NULL if unknown
    CONSTRAINT pk_dim_customer    PRIMARY KEY (customer_key),
    CONSTRAINT uq_dim_customer_id UNIQUE (source_customer_id)
);

COMMENT ON TABLE  dim_customer            IS 'Customer dimension (demographic & behavioural profile, ~1M customers).';
COMMENT ON COLUMN dim_customer.age_group  IS 'Derived from raw age in ETL. Bins: 18-25, 26-35, 36-50, 51-75.';
COMMENT ON COLUMN dim_customer.tenure_days IS 'Days between account_creation_date and order_date.';

-- ------------------------------------------------------------
-- DIM_GEOGRAPHY
-- Source: city, country, warehouse_location from reconciled DB.
-- Hierarchy exposed: city → country
-- Additional attribute: warehouse_location (the fulfilment
--   centre that served the order — not a geographic roll-up
--   but a supply-chain attribute).
-- Denormalised: all levels in one table (star schema rule).
-- 10 countries × 50 cities × 5 warehouses = 500 combinations.
-- ------------------------------------------------------------
CREATE TABLE dim_geography (
    geo_key            INTEGER      NOT NULL,
    city               VARCHAR(100) NOT NULL,
    country            VARCHAR(100) NOT NULL,
    warehouse_location VARCHAR(50)  NOT NULL,   -- USA-West | USA-East | UK | EU-Central | Asia-Pacific
    CONSTRAINT pk_dim_geography PRIMARY KEY (geo_key)
);

COMMENT ON TABLE dim_geography IS 'Geography dimension. Hierarchy: city → country. Branch: warehouse_location.';

-- ------------------------------------------------------------
-- DIM_SHIPPING
-- Source: shipping_method, delivery_days (→ days_band),
--         delivery_status from SALES_ORDER.
-- delivery_days is binned into days_band in ETL:
--   1–3 days = Fast, 4–7 days = Standard, 8–14 days = Slow.
-- This enables roll-up analysis on delivery speed without
--   treating each of the 14 integer values as a separate slice.
-- ------------------------------------------------------------
CREATE TABLE dim_shipping (
    shipping_key    INTEGER     NOT NULL,
    method          VARCHAR(30) NOT NULL,   -- Economy | Standard | Express | Next Day
    days_band       VARCHAR(20) NOT NULL,   -- Fast (1-3) | Standard (4-7) | Slow (8-14)
    delivery_status VARCHAR(20) NOT NULL,   -- Delivered | In Transit | Failed | Pending
    CONSTRAINT pk_dim_shipping PRIMARY KEY (shipping_key)
);

COMMENT ON TABLE  dim_shipping          IS 'Shipping dimension (method, speed band, fulfilment status).';
COMMENT ON COLUMN dim_shipping.days_band IS 'Derived from delivery_days: Fast=1-3, Standard=4-7, Slow=8-14.';

-- ------------------------------------------------------------
-- DIM_PAYMENT
-- Source: payment_method, payment_status, installment_plan
--         from SALES_ORDER.
-- Enables slice/dice by payment type and financial outcome.
-- ------------------------------------------------------------
CREATE TABLE dim_payment (
    payment_key      INTEGER     NOT NULL,
    payment_method   VARCHAR(30) NOT NULL,   -- Apple Pay | Debit Card | PayPal | Credit Card | Bank Transfer
    payment_status   VARCHAR(20) NOT NULL,   -- Paid | Failed | Pending
    installment_plan BOOLEAN     NOT NULL,   -- TRUE = customer paying in instalments
    CONSTRAINT pk_dim_payment PRIMARY KEY (payment_key)
);

COMMENT ON TABLE dim_payment IS 'Payment dimension (5 payment methods, status, instalment flag).';

-- ------------------------------------------------------------
-- DIM_ORDER
-- Source: order_status, order_priority, return_reason,
--         support_ticket_created from SALES_ORDER.
-- Hierarchy exposed: order_status → return_reason
--   (return_reason is only meaningful when status = Returned;
--    NULL for all other statuses — preserved as "N/A" in ETL).
-- Enables return root-cause analysis and support ticket
--   correlation with order outcomes.
-- ------------------------------------------------------------
CREATE TABLE dim_order (
    order_key      INTEGER     NOT NULL,
    order_status   VARCHAR(20) NOT NULL,   -- Completed | Returned | Cancelled | Pending | Processing
    order_priority VARCHAR(10) NOT NULL,   -- Low | Medium | High
    return_reason  VARCHAR(60) NOT NULL,   -- return cause or 'N/A' for non-returned orders
    support_ticket BOOLEAN     NOT NULL,   -- TRUE = customer opened a support ticket
    CONSTRAINT pk_dim_order PRIMARY KEY (order_key)
);

COMMENT ON TABLE  dim_order              IS 'Order lifecycle dimension (status, priority, return cause, support).';
COMMENT ON COLUMN dim_order.return_reason IS 'Set to N/A (not NULL) for non-returned orders to simplify Tableau filtering.';

-- ------------------------------------------------------------
-- DIM_MARKETING
-- Source: campaign_source, device_type, traffic_source,
--         coupon_used from SALES_ORDER / CAMPAIGN table.
-- Enables analysis of which channel + device combination
--   drives the highest-value and highest-margin orders.
-- Max 6 × 3 × 5 × 2 = 180 distinct combinations.
-- ------------------------------------------------------------
CREATE TABLE dim_marketing (
    marketing_key   INTEGER     NOT NULL,
    campaign_source VARCHAR(30) NOT NULL,   -- Organic | Instagram | Google Ads | Affiliate | Email | Facebook
    device_type     VARCHAR(20) NOT NULL,   -- Desktop | Mobile | Tablet
    traffic_source  VARCHAR(20) NOT NULL,   -- Direct | Email | Social | Search | Referral
    coupon_used     BOOLEAN     NOT NULL,   -- TRUE = a discount coupon was applied
    CONSTRAINT pk_dim_marketing PRIMARY KEY (marketing_key)
);

COMMENT ON TABLE dim_marketing IS 'Marketing acquisition dimension (channel × device × traffic × coupon).';

-- ============================================================
-- FACT TABLE
-- ============================================================

-- ------------------------------------------------------------
-- FACT_SALES
-- Grain : One row = One unique sales order.
-- All FK columns reference dimension surrogate keys.
-- Measures are raw values from the reconciled database;
--   no pre-aggregation is applied here.
--
-- ADDITIVE measures (can be SUMmed across any dimension):
--   quantity_sold, total_revenue_usd, total_cost_usd,
--   profit_usd, tax_usd, shipping_cost_usd, order_count
--
-- NON-ADDITIVE measures (must be AVGed, not SUMmed):
--   profit_margin_pct, discount_pct
-- ------------------------------------------------------------
CREATE TABLE fact_sales (
    -- Surrogate key
    sale_id             SERIAL         NOT NULL,

    -- Dimension foreign keys
    date_key            INTEGER        NOT NULL,
    product_key         VARCHAR(20)    NOT NULL,
    customer_key        INTEGER        NOT NULL,
    geo_key             INTEGER        NOT NULL,
    shipping_key        INTEGER        NOT NULL,
    payment_key         INTEGER        NOT NULL,
    order_key           INTEGER        NOT NULL,
    marketing_key       INTEGER        NOT NULL,

    -- Traceability back to source
    source_order_id     VARCHAR(20)    NOT NULL,

    -- ---- ADDITIVE MEASURES ----
    quantity_sold       SMALLINT       NOT NULL,   -- units purchased (1–10)
    total_revenue_usd   NUMERIC(12,2)  NOT NULL,   -- net revenue after discount
    total_cost_usd      NUMERIC(12,2)  NOT NULL,   -- cost of goods sold
    profit_usd          NUMERIC(12,2)  NOT NULL,   -- revenue - cost
    tax_usd             NUMERIC(10,2)  NOT NULL,   -- tax charged on the order
    shipping_cost_usd   NUMERIC(8,2)   NOT NULL,   -- logistics cost
    order_count         SMALLINT       NOT NULL DEFAULT 1,  -- always 1; allows COUNT(*) aggregation

    -- ---- NON-ADDITIVE MEASURES (ratios) ----
    profit_margin_pct   NUMERIC(6,2)   NOT NULL,   -- profit_usd / total_revenue_usd * 100
    discount_pct        NUMERIC(5,2)   NOT NULL,   -- discount applied as a percentage

    -- Primary key
    CONSTRAINT pk_fact_sales        PRIMARY KEY (sale_id),

    -- Foreign key constraints
    CONSTRAINT fk_fs_date           FOREIGN KEY (date_key)      REFERENCES dim_date      (date_key),
    CONSTRAINT fk_fs_product        FOREIGN KEY (product_key)   REFERENCES dim_product   (product_key),
    CONSTRAINT fk_fs_customer       FOREIGN KEY (customer_key)  REFERENCES dim_customer  (customer_key),
    CONSTRAINT fk_fs_geography      FOREIGN KEY (geo_key)       REFERENCES dim_geography (geo_key),
    CONSTRAINT fk_fs_shipping       FOREIGN KEY (shipping_key)  REFERENCES dim_shipping  (shipping_key),
    CONSTRAINT fk_fs_payment        FOREIGN KEY (payment_key)   REFERENCES dim_payment   (payment_key),
    CONSTRAINT fk_fs_order          FOREIGN KEY (order_key)     REFERENCES dim_order     (order_key),
    CONSTRAINT fk_fs_marketing      FOREIGN KEY (marketing_key) REFERENCES dim_marketing (marketing_key)
);

COMMENT ON TABLE  fact_sales                  IS 'Central fact table. Grain: one row = one sales order. ~1M rows.';
COMMENT ON COLUMN fact_sales.source_order_id  IS 'Original order_id from source file — for lineage tracing.';
COMMENT ON COLUMN fact_sales.order_count      IS 'Always 1; stored to allow SUM(order_count) instead of COUNT(*) in Tableau.';
COMMENT ON COLUMN fact_sales.profit_margin_pct IS 'NON-ADDITIVE: use AVG(), not SUM(), when aggregating across orders.';
COMMENT ON COLUMN fact_sales.discount_pct      IS 'NON-ADDITIVE: use AVG(), not SUM(), when aggregating across orders.';

-- ============================================================
-- INDEXES (for fast JOIN and filter at 1M row scale)
-- ============================================================
CREATE INDEX idx_fs_date_key      ON fact_sales (date_key);
CREATE INDEX idx_fs_product_key   ON fact_sales (product_key);
CREATE INDEX idx_fs_customer_key  ON fact_sales (customer_key);
CREATE INDEX idx_fs_geo_key       ON fact_sales (geo_key);
CREATE INDEX idx_fs_shipping_key  ON fact_sales (shipping_key);
CREATE INDEX idx_fs_payment_key   ON fact_sales (payment_key);
CREATE INDEX idx_fs_order_key     ON fact_sales (order_key);
CREATE INDEX idx_fs_marketing_key ON fact_sales (marketing_key);
CREATE INDEX idx_fs_order_id      ON fact_sales (source_order_id);

-- ============================================================
-- GLOSSARY OF MEASURES
-- ============================================================
--
-- MEASURE              | TYPE         | FORMULA / SOURCE
-- ---------------------|--------------|---------------------------
-- quantity_sold        | Additive     | quantity from source
-- total_revenue_usd    | Additive     | total_price_usd from source (after discount)
-- total_cost_usd       | Additive     | cost_usd from source
-- profit_usd           | Additive     | profit_usd from source (= revenue - cost)
-- tax_usd              | Additive     | tax_usd from source
-- shipping_cost_usd    | Additive     | shipping_cost_usd from source
-- order_count          | Additive     | always 1 per row (COUNT surrogate)
-- profit_margin_pct    | Non-additive | profit_margin_percent from source; AVG across rows
-- discount_pct         | Non-additive | discount_percent from source; AVG across rows
--
-- OLAP OPERATIONS SUPPORTED
-- Roll-up   : Day → Month → Quarter → Year on DIM_DATE
-- Roll-up   : Product → Sub-Category → Category on DIM_PRODUCT
-- Roll-up   : City → Country on DIM_GEOGRAPHY
-- Drill-down: Reverse of all roll-ups above
-- Slice     : Filter FACT_SALES on any single dimension value
--             e.g. WHERE order_status = 'Returned'
-- Dice      : Filter on multiple dimension values simultaneously
--             e.g. WHERE country = 'Germany' AND category = 'Electronics'
-- ============================================================
