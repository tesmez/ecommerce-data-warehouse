# E-Commerce Sales Data Warehouse — Phase 1 Report
**Course**: Data Warehousing | **Instructor**: Prof. Giorgio Terracina  
**Dataset**: ecommerce_dataset_1m.xlsx | **DBMS**: PostgreSQL 14+ | **Viz**: Tableau Public

---

## 1. Data Source Description & Preliminary Requirement Analysis

### 1.1 Dataset Overview

| Property | Detail |
|---|---|
| File | ecommerce_dataset_1m.xlsx |
| Rows | ~1,000,000 (one row = one unique sales order) |
| Original columns | 62 |
| Selected columns | 28 (after column triage — see Section 1.3) |
| Date range | February 2024 → February 2026 |
| Domain | Global B2C e-commerce platform |
| Countries | 10 (Spain, Germany, UK, Italy, Netherlands, France, USA, Canada, Belgium, Australia) |
| Products | 48 distinct products across 5 categories, 22 sub-categories, 20 brands |
| Customers | ~1,000,000 unique customers |

### 1.2 WH-Question Analysis (Requirement Analysis)

A data warehouse must answer specific business questions. We identify the following analytical goals using the WH-framework:

**WHAT do we analyse?**  
Individual sales transactions placed on a global e-commerce platform. The central business event is a **sale** — when a customer purchases a product. The grain of the fact is one row per unique order.

**WHO is involved?**  
Approximately 1 million customers segmented as Regular, Premium, or VIP. Each customer has a gender, age, loyalty score, and geographic location. Key questions: Which segments are most profitable? Do VIP customers return products more?

**WHEN do sales happen?**  
Transactions span February 2024 to February 2026 — two full years. The date hierarchy is Day → Month → Quarter → Year. Key questions: Are there seasonal peaks? How does revenue grow year-over-year? Do weekend orders differ from weekday orders?

**WHERE are orders placed?**  
10 countries across 50 cities, served by 5 warehouse locations (USA-West, USA-East, UK, EU-Central, Asia-Pacific). Geography hierarchy: City → Country. Key questions: Which countries generate the most revenue? Which warehouses have the highest failed delivery rate?

**WHAT is sold?**  
48 products in categories Electronics, Health, Clothing, Sports, Home. Product hierarchy: Product → Sub-Category → Category, with a Brand lateral branch. Key questions: Which categories have the highest profit margin? Which brands underperform?

**WHY do orders get returned?**  
Five return reasons: Better Price Elsewhere, Wrong Item, Defective Product, Not As Described, Changed Mind. Order status tracks the full lifecycle: Completed, Returned, Cancelled, Pending, Processing. Key questions: What is the return rate by category? Does faster shipping reduce returns?

**HOW is it shipped?**  
Four shipping methods (Economy, Standard, Express, Next Day) with delivery times of 1–14 days. Key questions: Does method choice affect delivery failure rate? What is the shipping cost distribution per method?

**HOW are customers acquired?**  
Six campaign sources (Organic, Instagram, Google Ads, Affiliate, Email, Facebook), three device types, five traffic sources. Key questions: Which channel drives the highest-margin orders? Do mobile users apply more coupons?

### 1.3 Column Triage: From 62 to 28

The original 62 columns were classified into three groups:

**Keep (28 columns)**: Raw business facts, natural dimension attributes, and hierarchy levels needed for OLAP operations in Tableau.

**Derive (4 columns)**: `account_creation_date` → `tenure_days` (ETL calculation), `age` → `age_group` (binned into 4 buckets), `order_date` → full DIM_DATE table, `profit_margin_percent` → verified against profit/revenue ratio in data quality step.

**Drop (30 columns)**: Sub-second time granularity (order_hour, order_minute, order_second), fully derivable columns (discount_amount_usd, total_orders_by_customer), web analytics fields that belong in a separate clickstream system (session_duration_minutes, pages_visited, abandoned_cart_before), ML-generated scores (fraud_risk_score, review_sentiment), and redundant/zero-variance columns (currency is always USD, shipping_country almost always equals country, customer_name is PII not used in aggregation).

---

## 2. Reconciled Database Schema

### 2.1 Re-Engineering Decisions

The flat Excel file is decomposed into **12 normalised tables in Third Normal Form (3NF)**. The re-engineering follows these principles:

1. **Extract every repeating group**: Country names, city names, category names, brand names, shipping methods, payment methods, and campaign attribute combinations all repeat thousands of times in the flat file. Each is extracted into its own reference table with a surrogate primary key, eliminating redundancy.

2. **Preserve functional dependencies**: `sub_category → category` is a functional dependency that violates 2NF if stored in PRODUCT directly. Separating SUB_CATEGORY and CATEGORY into distinct tables satisfies 3NF.

3. **Separate master data from transaction data**: CUSTOMER and PRODUCT are master entities whose attributes do not change per order. SALES_ORDER is the transactional entity that links them.

4. **Group marketing attributes**: `campaign_source`, `device_type`, and `traffic_source` always describe the acquisition context together. They are grouped in the CAMPAIGN table (up to 90 distinct combinations).

### 2.2 Entity Descriptions

| Table | Type | Key | Description |
|---|---|---|---|
| COUNTRY | Reference | country_id (PK) | 10 distinct countries |
| CITY | Reference | city_id (PK) | 50 cities; FK → COUNTRY |
| WAREHOUSE | Reference | warehouse_id (PK) | 5 fulfilment centres |
| CATEGORY | Reference | category_id (PK) | 5 product categories |
| SUB_CATEGORY | Reference | sub_category_id (PK) | 22 sub-categories; FK → CATEGORY |
| BRAND | Reference | brand_id (PK) | 20 brands |
| SHIPPING_METHOD | Reference | shipping_method_id (PK) | 4 methods |
| PAYMENT_METHOD | Reference | payment_method_id (PK) | 5 methods |
| CAMPAIGN | Reference | campaign_id (PK) | Marketing context combinations |
| PRODUCT | Master data | product_id (PK) | 48 products; FKs → SUB_CATEGORY, BRAND |
| CUSTOMER | Master data | customer_id (PK) | ~1M customers; FK → CITY |
| SALES_ORDER | Transaction | order_id (PK) | Central fact entity; all FK + measures |

### 2.3 Relationships

- `COUNTRY` ─< `CITY` : one country contains many cities
- `CITY` ─< `CUSTOMER` : one city has many customers
- `CUSTOMER` ─< `SALES_ORDER` : one customer places many orders
- `PRODUCT` ─< `SALES_ORDER` : one product appears in many orders
- `WAREHOUSE` ─< `SALES_ORDER` : one warehouse fulfils many orders
- `SHIPPING_METHOD` ─< `SALES_ORDER` : one method is used in many orders
- `PAYMENT_METHOD` ─< `SALES_ORDER` : one method is used in many orders
- `CAMPAIGN` ─< `SALES_ORDER` : one campaign context drives many orders
- `CATEGORY` ─< `SUB_CATEGORY` : one category groups many sub-categories
- `SUB_CATEGORY` ─< `PRODUCT` : one sub-category classifies many products
- `BRAND` ─< `PRODUCT` : one brand manufactures many products

---

## 3. Conceptual Design: Fact Schema (DFM)

### 3.1 Fact Choice and Motivation

**Chosen fact: SALES**

The fact represents a sales order event — a customer purchasing a product at a specific time and place. This is chosen because:

1. It is a **transactional event** (something that happened at a precise point in time).
2. It has **multiple additive measures** (revenue, cost, profit, tax, shipping cost, quantity) that can be meaningfully summed across all dimensions.
3. It connects to **all analytical dimensions** simultaneously — every analytical question in Section 1.2 can be answered by grouping or filtering the sales fact.
4. The **grain is clear and atomic**: one row = one unique order. There is no ambiguity about what constitutes a single fact occurrence.

### 3.2 Attribute Tree Construction (Data-Driven Approach)

Starting from the SALES_ORDER entity in the reconciled database, we trace all functional dependencies outward:

**From order_id (the fact key):**
- → `order_date` → day_of_month → month → quarter → year *(DATE hierarchy)*
- → `order_date` → is_weekend *(leaf attribute of DATE)*
- → `product_id` → product_name → sub_category → category *(PRODUCT hierarchy)*
- → `product_id` → brand *(lateral branch on product)*
- → `product_id` → rating_avg *(leaf attribute of PRODUCT)*
- → `customer_id` → segment, gender, age_group, loyalty_score, tenure_days *(CUSTOMER attributes)*
- → `city_id` → city → country *(GEOGRAPHY hierarchy)*
- → `warehouse_id` → warehouse_location *(GEOGRAPHY branch)*
- → `shipping_method_id` → method → days_band → delivery_status *(SHIPPING)*
- → `payment_method_id` → payment_method → payment_status → installment_plan *(PAYMENT)*
- → `order_status` → return_reason *(ORDER hierarchy)*
- → `order_status` → order_priority, support_ticket *(ORDER attributes)*
- → `campaign_id` → campaign_source → device_type, traffic_source, coupon_used *(MARKETING)*

**Editing steps applied to the raw attribute tree:**
1. `order_hour`, `order_minute`, `order_second` removed — sub-day granularity not needed for OLAP.
2. `delivery_days` (integer 1–14) binned into `days_band` — avoids 14 separate dimension rows per shipping instance.
3. `age` (continuous 18–75) binned into `age_group` — 4 categorical buckets behave better as a OLAP dimension than a continuous integer.
4. `return_reason` placed as a sub-level under `order_status` — it is only meaningful when status = Returned (hierarchy dependency).
5. `discount_amount_usd` and `total_orders_by_customer` removed — derivable from other measures at query time.
6. `fraud_risk_score`, `review_sentiment`, `rating` removed — ML/NLP outputs, not raw business facts.

### 3.3 DFM Schema Summary

**Fact**: SALES  
**Grain**: One row = one unique sales order  
**Dimensions**: 8  
**Hierarchies**: 3 strict hierarchies (Date, Product, Geography) + 5 flat dimensions  

| Dimension | Levels / Attributes | Hierarchy depth |
|---|---|---|
| Date | day → month → quarter → year + is_weekend | 4 levels |
| Product | product → sub_category → category + brand + rating | 3 levels |
| Customer | segment, age_group, gender, loyalty_score, tenure_days | Flat (no strict hierarchy) |
| Geography | city → country + warehouse_location | 2 levels |
| Shipping | method + days_band + delivery_status | Flat |
| Payment | payment_method + payment_status + installment_plan | Flat |
| Order | order_status → return_reason + priority + support_ticket | 2 levels |
| Marketing | campaign_source + device_type + traffic_source + coupon_used | Flat |

---

## 4. Logical Design: Star Schema

### 4.1 DFM → Star Schema Translation Rules

1. **Each DFM dimension becomes one flat DIM_ table** (star schema, not snowflake). All hierarchy levels are denormalised into a single table row. This is required for Tableau Public compatibility and simplifies JOIN operations.

2. **Surrogate integer keys** replace all natural keys in dimension tables. The fact table references only surrogate keys — never natural keys. Exception: `dim_product.product_key` retains the source VARCHAR ID (PRD-XXXX) to simplify ETL lookups.

3. **DIM_DATE** uses an integer surrogate key in YYYYMMDD format (e.g. 20240315) — faster than DATE joins at 1M row scale, and universally compatible with Tableau date filters.

4. **Non-additive measures** (`profit_margin_pct`, `discount_pct`) are stored in the fact table but documented with a warning: they must be aggregated with AVG(), never SUM(), across multiple rows.

5. **`order_count = 1`** is stored as a constant measure so that Tableau can use `SUM(order_count)` instead of `COUNT(*)` — more robust in calculated fields.

6. **`source_order_id`** is kept in the fact table as a traceability column — enables lineage tracing from a fact row back to the original source record during quality checks.

### 4.2 Star Schema Tables

| Table | Type | Rows (estimated) | Description |
|---|---|---|---|
| FACT_SALES | Fact | ~1,000,000 | Central fact table, 8 FK + 9 measures |
| DIM_DATE | Dimension | ~730 | One row per calendar day (Feb 2024–Feb 2026) |
| DIM_PRODUCT | Dimension | 48 | One row per unique product |
| DIM_CUSTOMER | Dimension | ~1,000,000 | One row per unique customer |
| DIM_GEOGRAPHY | Dimension | ≤500 | city × country × warehouse combinations |
| DIM_SHIPPING | Dimension | ≤48 | method × days_band × delivery_status combinations |
| DIM_PAYMENT | Dimension | ≤30 | method × status × installment combinations |
| DIM_ORDER | Dimension | ≤40 | status × priority × return_reason combinations |
| DIM_MARKETING | Dimension | ≤180 | campaign × device × traffic × coupon combinations |

### 4.3 Glossary of Measures

| Measure | Data type | Additivity | Formula / Source | Description |
|---|---|---|---|---|
| `quantity_sold` | SMALLINT | Additive | `quantity` from source | Number of units purchased in the order |
| `total_revenue_usd` | NUMERIC(12,2) | Additive | `total_price_usd` from source | Net revenue after discount, in USD |
| `total_cost_usd` | NUMERIC(12,2) | Additive | `cost_usd` from source | Cost of goods sold, in USD |
| `profit_usd` | NUMERIC(12,2) | Additive | `profit_usd` from source (= revenue − cost) | Gross profit per order, in USD |
| `tax_usd` | NUMERIC(10,2) | Additive | `tax_usd` from source | Tax charged on the order, in USD |
| `shipping_cost_usd` | NUMERIC(8,2) | Additive | `shipping_cost_usd` from source | Logistics cost borne by the platform, in USD |
| `order_count` | SMALLINT | Additive | Always 1 | Convenience measure — use SUM for order count |
| `profit_margin_pct` | NUMERIC(6,2) | **Non-additive** | `profit_margin_percent` from source | Profit as % of revenue. Use AVG() not SUM() |
| `discount_pct` | NUMERIC(5,2) | **Non-additive** | `discount_percent` from source | Discount rate applied. Use AVG() not SUM() |

### 4.4 OLAP Operations Supported

| Operation | Dimension | Example |
|---|---|---|
| Roll-up | Date: Day → Month → Quarter → Year | Monthly revenue → Quarterly total |
| Roll-up | Product: Product → Sub-Category → Category | Product profit → Category profit |
| Roll-up | Geography: City → Country | City revenue → Country revenue |
| Drill-down | All of the above in reverse | Country profit → City breakdown |
| Slice | Order status = 'Returned' | Analyse only returned orders |
| Slice | Category = 'Electronics' | Revenue for electronics only |
| Dice | Country = 'Germany' AND Category = 'Electronics' | German electronics revenue |
| Dice | Segment = 'VIP' AND Quarter = 'Q4' | VIP customer Q4 behaviour |

---

## 5. Deliverable Files

| File | Contents |
|---|---|
| `01_reconciled_db.sql` | PostgreSQL DDL for 12-table reconciled database (3NF) |
| `02_star_schema_dw.sql` | PostgreSQL DDL for star schema (1 fact + 8 dimensions) |
| `Phase1_Report.md` | This documentation report |

---

*Phase 2 (Data Management) will cover: populating the reconciled database from the Excel source, data quality assessment and cleaning in Python/Jupyter, and the full ETL pipeline from reconciled database to data warehouse.*
