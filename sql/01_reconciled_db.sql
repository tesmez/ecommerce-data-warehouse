-- ============================================================
-- PROJECT  : E-Commerce Sales Data Warehouse
-- DATASET  : ecommerce_dataset_1m.csv (~1,000,000 rows)
-- PHASE    : 1 — Step 3: Reconciled Database Schema
-- DBMS     : PostgreSQL 14+ / 18 compatible
-- ENCODING : UTF-8
--
-- HOW TO RUN:
--   1. Open pgAdmin 4
--   2. Enter your postgres password when prompted → click OK
--   3. Connect to the 'ecommerce_reconciled' database
--   4. Open Query Tool (Tools → Query Tool)
--   5. Open this file (folder icon) or paste all contents
--   6. Press F5 to execute
--
-- EXPECTED RESULT:
--   12 tables created, 11 FK constraints, 6 indexes, all empty
--
-- SAFE TO RE-RUN: Yes — DROP IF EXISTS cleans up first
-- NOTICES about "does not exist, skipping" are NORMAL — ignore them
-- ============================================================


-- ============================================================
-- DROP ALL TABLES (safe re-run — order matters for FK deps)
-- ============================================================

DROP TABLE IF EXISTS sales_order      CASCADE;
DROP TABLE IF EXISTS campaign          CASCADE;
DROP TABLE IF EXISTS payment_method   CASCADE;
DROP TABLE IF EXISTS shipping_method  CASCADE;
DROP TABLE IF EXISTS product           CASCADE;
DROP TABLE IF EXISTS brand             CASCADE;
DROP TABLE IF EXISTS sub_category      CASCADE;
DROP TABLE IF EXISTS category          CASCADE;
DROP TABLE IF EXISTS customer          CASCADE;
DROP TABLE IF EXISTS city              CASCADE;
DROP TABLE IF EXISTS country           CASCADE;
DROP TABLE IF EXISTS warehouse         CASCADE;


-- ============================================================
-- REFERENCE / LOOKUP TABLES (9 tables)
-- ============================================================

-- TABLE 1: COUNTRY
CREATE TABLE country (
    country_id   SERIAL        NOT NULL,
    country_name VARCHAR(100)  NOT NULL,
    CONSTRAINT pk_country      PRIMARY KEY (country_id),
    CONSTRAINT uq_country_name UNIQUE (country_name)
);

-- TABLE 2: CITY
CREATE TABLE city (
    city_id    SERIAL        NOT NULL,
    city_name  VARCHAR(100)  NOT NULL,
    country_id INTEGER       NOT NULL,
    CONSTRAINT pk_city         PRIMARY KEY (city_id),
    CONSTRAINT fk_city_country FOREIGN KEY (country_id)
                               REFERENCES country (country_id),
    CONSTRAINT uq_city         UNIQUE (city_name, country_id)
);

-- TABLE 3: WAREHOUSE
CREATE TABLE warehouse (
    warehouse_id       SERIAL      NOT NULL,
    warehouse_location VARCHAR(50) NOT NULL,
    CONSTRAINT pk_warehouse     PRIMARY KEY (warehouse_id),
    CONSTRAINT uq_warehouse_loc UNIQUE (warehouse_location)
);

-- TABLE 4: CATEGORY
CREATE TABLE category (
    category_id   SERIAL      NOT NULL,
    category_name VARCHAR(50) NOT NULL,
    CONSTRAINT pk_category      PRIMARY KEY (category_id),
    CONSTRAINT uq_category_name UNIQUE (category_name)
);

-- TABLE 5: SUB_CATEGORY
CREATE TABLE sub_category (
    sub_category_id   SERIAL      NOT NULL,
    sub_category_name VARCHAR(80) NOT NULL,
    category_id       INTEGER     NOT NULL,
    CONSTRAINT pk_sub_category     PRIMARY KEY (sub_category_id),
    CONSTRAINT fk_subcat_category  FOREIGN KEY (category_id)
                                   REFERENCES category (category_id),
    CONSTRAINT uq_sub_cat_name     UNIQUE (sub_category_name, category_id)
);

-- TABLE 6: BRAND
CREATE TABLE brand (
    brand_id   SERIAL      NOT NULL,
    brand_name VARCHAR(80) NOT NULL,
    CONSTRAINT pk_brand      PRIMARY KEY (brand_id),
    CONSTRAINT uq_brand_name UNIQUE (brand_name)
);

-- TABLE 7: SHIPPING_METHOD
CREATE TABLE shipping_method (
    shipping_method_id SERIAL      NOT NULL,
    method_name        VARCHAR(30) NOT NULL,
    CONSTRAINT pk_shipping_method PRIMARY KEY (shipping_method_id),
    CONSTRAINT uq_shipping_method UNIQUE (method_name)
);

-- TABLE 8: PAYMENT_METHOD
CREATE TABLE payment_method (
    payment_method_id SERIAL      NOT NULL,
    method_name       VARCHAR(30) NOT NULL,
    CONSTRAINT pk_payment_method PRIMARY KEY (payment_method_id),
    CONSTRAINT uq_payment_method UNIQUE (method_name)
);

-- TABLE 9: CAMPAIGN
CREATE TABLE campaign (
    campaign_id     SERIAL      NOT NULL,
    campaign_source VARCHAR(30) NOT NULL,
    device_type     VARCHAR(20) NOT NULL,
    traffic_source  VARCHAR(20) NOT NULL,
    CONSTRAINT pk_campaign PRIMARY KEY (campaign_id),
    CONSTRAINT uq_campaign UNIQUE (campaign_source, device_type, traffic_source)
);


-- ============================================================
-- MASTER DATA TABLES (2 tables)
-- ============================================================

-- TABLE 10: PRODUCT
CREATE TABLE product (
    product_id      VARCHAR(20)  NOT NULL,
    product_name    VARCHAR(150) NOT NULL,
    sub_category_id INTEGER      NOT NULL,
    brand_id        INTEGER      NOT NULL,
    rating_avg      NUMERIC(3,1) NOT NULL
                    CHECK (rating_avg BETWEEN 1.0 AND 5.0),
    CONSTRAINT pk_product     PRIMARY KEY (product_id),
    CONSTRAINT fk_prod_subcat FOREIGN KEY (sub_category_id)
                              REFERENCES sub_category (sub_category_id),
    CONSTRAINT fk_prod_brand  FOREIGN KEY (brand_id)
                              REFERENCES brand (brand_id)
);

-- TABLE 11: CUSTOMER
CREATE TABLE customer (
    customer_id   VARCHAR(20)  NOT NULL,
    gender        VARCHAR(10)  NOT NULL,
    age           SMALLINT     NOT NULL CHECK (age BETWEEN 18 AND 75),
    segment       VARCHAR(20)  NOT NULL,
    loyalty_score NUMERIC(5,2) NOT NULL CHECK (loyalty_score BETWEEN 0 AND 100),
    tenure_days   INTEGER      NULL,
    city_id       INTEGER      NOT NULL,
    CONSTRAINT pk_customer  PRIMARY KEY (customer_id),
    CONSTRAINT fk_cust_city FOREIGN KEY (city_id)
                            REFERENCES city (city_id)
);


-- ============================================================
-- CENTRAL TRANSACTION TABLE (1 table)
-- ============================================================

-- TABLE 12: SALES_ORDER
CREATE TABLE sales_order (

    order_id            VARCHAR(20)   NOT NULL,

    order_date          TIMESTAMP     NOT NULL,
    order_year          SMALLINT      NOT NULL,
    order_month         SMALLINT      NOT NULL CHECK (order_month BETWEEN 1 AND 12),
    order_day           SMALLINT      NOT NULL CHECK (order_day   BETWEEN 1 AND 31),
    is_weekend          BOOLEAN       NOT NULL,

    customer_id         VARCHAR(20)   NOT NULL,
    product_id          VARCHAR(20)   NOT NULL,
    warehouse_id        INTEGER       NOT NULL,
    shipping_method_id  INTEGER       NOT NULL,
    payment_method_id   INTEGER       NOT NULL,
    campaign_id         INTEGER       NOT NULL,

    quantity            SMALLINT      NOT NULL CHECK (quantity BETWEEN 1 AND 10),
    unit_price_usd      NUMERIC(10,2) NOT NULL CHECK (unit_price_usd > 0),
    discount_percent    NUMERIC(5,2)  NOT NULL CHECK (discount_percent BETWEEN 0 AND 25),
    total_price_usd     NUMERIC(12,2) NOT NULL CHECK (total_price_usd > 0),
    cost_usd            NUMERIC(12,2) NOT NULL CHECK (cost_usd > 0),
    profit_usd          NUMERIC(12,2) NOT NULL,
    tax_usd             NUMERIC(10,2) NOT NULL CHECK (tax_usd >= 0),
    profit_margin_pct   NUMERIC(6,2)  NOT NULL,
    shipping_cost_usd   NUMERIC(8,2)  NOT NULL CHECK (shipping_cost_usd >= 0),

    delivery_days       SMALLINT      NOT NULL CHECK (delivery_days BETWEEN 1 AND 14),
    delivery_status     VARCHAR(20)   NOT NULL,

    payment_status      VARCHAR(20)   NOT NULL,
    installment_plan    BOOLEAN       NOT NULL,

    order_status        VARCHAR(20)   NOT NULL,
    order_priority      VARCHAR(10)   NOT NULL,
    return_reason       VARCHAR(60)   NULL,
    support_ticket      BOOLEAN       NOT NULL,

    coupon_used         BOOLEAN       NOT NULL,

    CONSTRAINT pk_sales_order        PRIMARY KEY (order_id),

    CONSTRAINT fk_so_customer        FOREIGN KEY (customer_id)
                                     REFERENCES customer (customer_id),
    CONSTRAINT fk_so_product         FOREIGN KEY (product_id)
                                     REFERENCES product (product_id),
    CONSTRAINT fk_so_warehouse       FOREIGN KEY (warehouse_id)
                                     REFERENCES warehouse (warehouse_id),
    CONSTRAINT fk_so_shipping_method FOREIGN KEY (shipping_method_id)
                                     REFERENCES shipping_method (shipping_method_id),
    CONSTRAINT fk_so_payment_method  FOREIGN KEY (payment_method_id)
                                     REFERENCES payment_method (payment_method_id),
    CONSTRAINT fk_so_campaign        FOREIGN KEY (campaign_id)
                                     REFERENCES campaign (campaign_id),

    CONSTRAINT chk_return_reason CHECK (
        (order_status = 'Returned'  AND return_reason IS NOT NULL) OR
        (order_status <> 'Returned' AND return_reason IS NULL)
    )
);


-- ============================================================
-- COMMENTS (documentation — all on correct tables)
-- ============================================================

COMMENT ON TABLE  country          IS 'Reference: 10 customer countries.';
COMMENT ON TABLE  city             IS 'Reference: 50 cities across 10 countries.';
COMMENT ON TABLE  warehouse        IS 'Reference: 5 global fulfilment centres.';
COMMENT ON TABLE  category         IS 'Reference: 5 top-level product categories.';
COMMENT ON TABLE  sub_category     IS 'Reference: 22 sub-categories under 5 categories.';
COMMENT ON TABLE  brand            IS 'Reference: 20 product brands.';
COMMENT ON TABLE  shipping_method  IS 'Reference: 4 shipping types.';
COMMENT ON TABLE  payment_method   IS 'Reference: 5 payment types.';
COMMENT ON TABLE  campaign         IS 'Reference: marketing acquisition combinations (source x device x traffic).';
COMMENT ON TABLE  product          IS 'Master: 48 products with 3-level hierarchy.';
COMMENT ON TABLE  customer         IS 'Master: ~1M unique customers.';
COMMENT ON TABLE  sales_order      IS 'Fact: central transaction entity. One row = one unique sales order. ~1M rows.';

COMMENT ON COLUMN customer.tenure_days
    IS 'Derived in Phase 2 ETL from account_creation_date in source CSV. Days since account creation.';

COMMENT ON COLUMN sales_order.profit_usd
    IS 'total_price_usd minus cost_usd. Verified in Phase 2 data quality step.';

COMMENT ON COLUMN sales_order.return_reason
    IS 'NULL for non-returned orders. Populated only when order_status = Returned. Enforced by chk_return_reason.';


-- ============================================================
-- INDEXES (for efficient ETL queries in Phase 2)
-- ============================================================

CREATE INDEX idx_so_customer     ON sales_order (customer_id);
CREATE INDEX idx_so_product      ON sales_order (product_id);
CREATE INDEX idx_so_date         ON sales_order (order_date);
CREATE INDEX idx_so_order_status ON sales_order (order_status);
CREATE INDEX idx_so_warehouse    ON sales_order (warehouse_id);
CREATE INDEX idx_so_campaign     ON sales_order (campaign_id);


-- ============================================================
-- END OF SCRIPT
-- Tables  : 12  (9 reference + 2 master + 1 central fact)
-- FKs     : 11
-- Indexes : 6
-- ============================================================
