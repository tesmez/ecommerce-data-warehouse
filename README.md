# 🛒 E-Commerce Sales Data Warehouse

> **Data Warehousing and Visualization Project**  
> Università della Calabria (UNICAL) — Academic Year 2024/2025  
> Prof. Giorgio Terracina  

---

## 👤 Author

| Field | Value |
|-------|-------|
| **Name** | Tesfay Mezgebe Weldemihret |
| **Matricola** | 280301 |
| **Email** | wldtfy93r15z315g@studenti.unical.it |
| **Course** | Data Warehousing and Visualization |

---

## 📋 Project Summary

This project implements a full **data warehousing lifecycle** — from raw CSV to interactive Tableau dashboards — on a 1-million-row e-commerce dataset. It covers three phases:

| Phase | Description | Key Output |
|-------|-------------|------------|
| **Phase 1** | Conceptual and Logical Design | Reconciled DB schema, DFM diagram, Star schema |
| **Phase 2** | Data Management | ETL pipeline, DQA, Data Cleaning, LLM audit |
| **Phase 3** | Data Visualization | 5 Tableau dashboards, 15 sheets, OLAP operations |

---

## 📊 Dataset

| Property | Value |
|----------|-------|
| **File** | `ecommerce_dataset__1m.csv` |
| **Rows** | 1,000,123 |
| **Source columns** | 62 |
| **Selected columns** | 45 |
| **Date range** | February 2024 — February 2026 |
| **Countries** | 10 (EU, North America, Australia) |
| **Products** | 48 across 5 categories |
| **Source** | https://www.kaggle.com/datasets/akrambelha/global-e-commerce-dataset-1m-records-20242026 | 

---

## 🏗️ Architecture

```
CSV Dataset (1M rows, 62 cols)
        │
        ▼
┌──────────────────────┐
│  Reconciled Database  │  PostgreSQL 18
│  ecommerce_reconciled │  12 tables, 3NF
│  (Phase 1 + Phase 2) │  991,930 orders loaded
└──────────┬───────────┘
           │  ETL (notebook 05)
           ▼
┌──────────────────────┐
│   Data Warehouse      │  PostgreSQL 18
│   ecommerce_dw        │  9 tables, Star Schema
│   (Phase 1 + Phase 2) │  991,930 fact rows
└──────────┬───────────┘
           │  CSV export
           ▼
┌──────────────────────┐
│  Tableau Public       │  5 Dashboards
│  (Phase 3)            │  15 Sheets
│                       │  OLAP Operations
└──────────────────────┘
```

---

## 📁 Repository Structure

```
ecommerce-data-warehouse/
│
├── 📂 data/
│   └── ecommerce_dataset__1m.csv          # Source dataset (not in repo — see note)
│
├── 📂 sql/
│   ├── 01_reconciled_db.sql               # Phase 1: Reconciled DB DDL (12 tables)
│   └── 02_star_schema_dw.sql              # Phase 1: Star schema DDL (9 tables)
│
├── 📂 notebooks/
│   ├── 01_requirement_analysis.ipynb      # Phase 1: Dataset exploration
│   ├── 02_data_loading.ipynb              # Phase 2: Load CSV → reconciled DB
│   ├── 03_data_quality_assessment.ipynb   # Phase 2: ISO 25012 DQA + Groq LLM
│   ├── 04_data_cleaning.ipynb             # Phase 2: CleaningPipeline + AuditLog
│   └── 05_etl_to_star_schema.ipynb        # Phase 2: ETL reconciled → DW
│
├── 📂 diagrams/
│   ├── er_schema.drawio                   # Phase 1: E/R diagram (draw.io)
│   ├── dfm_schema.drawio                  # Phase 1: DFM fact schema (draw.io)
│   └── star_schema.drawio                 # Phase 1: Star schema diagram (draw.io)
│
├── 📂 reports/
│   ├── dq_scorecard_sales_order.csv       # Phase 2: ISO 25012 DQ scorecard
│   ├── cleaning_audit_log.csv             # Phase 2: 118,543 cell-level changes
│   ├── cleaning_audit_summary.csv         # Phase 2: Pipeline step summary
│   ├── before_cleaning_scores.json        # Phase 2: Pre-cleaning baseline scores
│   ├── winsorize_fences.json              # Phase 2: Winsorization fence values
│   ├── dq_profile_sales_order.html        # Phase 2: ydata-profiling full report
│   ├── llm_dqa_audit_report.txt           # Phase 2: LLM DQA audit (Groq/Llama 3.1)
│   └── llm_cleaning_narrative.txt         # Phase 2: LLM cleaning validation
│
├── 📂 tableau/
│   └── ecommerce_dw_dashboards.twbx       # Phase 3: Tableau workbook (packaged)
│
├── 📄 EcommerceDW_Report_Tesfay.pdf       # Final project report (PDF)
├── 📄 EcommerceDW_Report_Tesfay.tex       # LaTeX source of the report
├── 📄 requirements.txt                    # Python dependencies
└── 📄 README.md                           # This file
```

> **Note on the dataset:** The source CSV (400 MB) is not stored in this repository due to GitHub file size limits. See the [Dataset](#-dataset) section for the source.

---

## ⚙️ Technology Stack

| Layer | Technology |
|-------|-----------|
| **Language** | Python 3.11 |
| **Notebooks** | Jupyter Notebook |
| **Database** | PostgreSQL 18 + pgAdmin 4 v9.8 |
| **DB Driver** | psycopg2 |
| **Data manipulation** | pandas 2.x, NumPy |
| **ML / Outlier detection** | scikit-learn (Isolation Forest, LOF) |
| **Statistics** | scipy, statsmodels |
| **DQ Profiling** | ydata-profiling, missingno |
| **Visualisation** | matplotlib, Tableau Public |
| **LLM Integration** | Groq API (Llama 3.1 8B Instant) |
| **Diagramming** | draw.io |
| **Report** | LaTeX (Overleaf) |

---

## 🚀 How to Run

### Prerequisites

```bash
# 1. Clone the repository
git clone https://github.com/tesmez/ecommerce-data-warehouse.git
cd ecommerce-data-warehouse

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Set up PostgreSQL
# Create two databases:
#   psql -U postgres -c "CREATE DATABASE ecommerce_reconciled;"
#   psql -U postgres -c "CREATE DATABASE ecommerce_dw;"

# 4. Run the DDL scripts
psql -U postgres -d ecommerce_reconciled -f sql/01_reconciled_db.sql
psql -U postgres -d ecommerce_dw -f sql/02_star_schema_dw.sql
```

### Run the Pipeline

Execute the notebooks **in order**:

| Step | Notebook | What it does | 
|------|----------|-------------|
| 1 | `01_requirement_analysis.ipynb` | Explore dataset, verify grain | 
| 2 | `02_data_loading.ipynb` | Load CSV into reconciled DB | ~5 min |
| 3 | `03_data_quality_assessment.ipynb` | ISO 25012 DQA + outlier detection + LLM audit | 
| 4 | `04_data_cleaning.ipynb` | CleaningPipeline + write-back to DB | 
| 5 | `05_etl_to_star_schema.ipynb` | ETL to star schema | 

### Environment Variables

```bash
# Required for LLM integration (optional — pipeline runs without it)
# Get your free key at: console.groq.com
export GROQ_API_KEY="your_gsk_key_here"
```

---

## 📐 Phase 1 — Design

### Reconciled Database (3NF)
- **12 tables:** country, city, warehouse, category, sub_category, brand, shipping_method, payment_method, campaign, product, customer, sales_order
- **11 FK constraints** with CASCADE rules
- **sales_order** is the central table with 30 columns and 6 foreign keys

### DFM Conceptual Schema
- **Fact:** SALES — grain = one unique sales order
- **8 Dimensions:** Date (4-level hierarchy), Product (3-level), Customer, Geography (2-level), Shipping, Payment, Order (2-level), Marketing
- **9 Measures:** 7 additive ★ (revenue, cost, profit, tax, shipping, quantity, order count) + 2 non-additive ◆ (profit margin %, discount %)
- **8 Editing steps** each fully motivated

### Star Schema
- **9 tables:** 8 DIM + FACT_SALES
- **Denormalised** (star, not snowflake) for Tableau performance
- Integer surrogate keys, YYYYMMDD date key format

---

## 🧹 Phase 2 — Data Management

### Data Quality Assessment (ISO 25012)

| Dimension | Score | Status |
|-----------|-------|--------|
| Completeness | 100.00% | 🟢 |
| Uniqueness | 100.00% | 🟢 |
| Validity | 100.00% | 🟢 |
| Consistency | 96.33% | 🟢 |
| Timeliness | 100.00% | 🟢 |
| Accuracy | 98.01% → **99.67%** | 🟢 +1.66pp after cleaning |

### Outlier Detection (5-Method Consensus)

| Method | Flagged | Type |
|--------|---------|------|
| IQR Fence (k=1.5) | 9,843 (9.84%) | Univariate |
| Z-Score (|z|>3) | 4,412 (4.41%) | Univariate |
| Modified Z-Score (|m|>3.5) | 7,215 (7.22%) | Univariate |
| Isolation Forest (contam=4%) | 4,000 (4.00%) | Multivariate |
| LOF (k=20, contam=4%) | 4,000 (4.00%) | Multivariate |
| **CONSENSUS (≥2 methods)** | **8,883 (8.9%)** | **Combined** |

### Cleaning Pipeline

| Step | Operation | Changes |
|------|-----------|---------|
| 1-6 | Winsorize 6 numeric measures at [p01, p99] | 118,542 |
| 7 | MNAR flag for return_reason | 1 |
| 8 | MAR impute tenure_days by segment median | 0 |
| **Total** | | **118,543** |

### LLM Integration (Lab 1 + Lab 3 Colab 2)

- **Model:** Llama 3.1 8B Instant via Groq API
- **Notebook 03:** LLM generates 7-section DQA audit report from scorecard
- **Notebook 04:** LLM validates cleaning decisions + writes academic narrative
- **Reports saved:** `reports/llm_dqa_audit_report.txt`, `reports/llm_cleaning_narrative.txt`
- **LLM never modifies data** — interpretive layer only

### ETL Results

| Table | Rows |
|-------|------|
| dim_date | 731 |
| dim_product | 48 |
| dim_customer | 983,876 |
| dim_geography | 250 |
| dim_shipping | 48 |
| dim_payment | 30 |
| dim_order | 54 |
| dim_marketing | 180 |
| **fact_sales** | **991,930** |

---

## 📊 Phase 3 — Tableau Dashboards

### Dashboards

| Dashboard | OLAP Operations | Key Insight |
|-----------|----------------|-------------|
| **1 — Sales Overview** | Roll-up: Month → Quarter → Year | $397M total revenue, 39.5% avg margin |
| **2 — Product Performance** | Drill-down: Category → Sub-Category → Product | Electronics leads at $136M |
| **3 — Customer Segmentation** | Slice: Segment · Dice: Segment × Age × Gender | Mature customers generate most revenue |
| **4 — Geographic Analysis** | Roll-up: City → Country · Map slice | Revenue uniformly distributed across 10 countries |
| **5 — Marketing & Returns** | Dice: Campaign × Coupon × Device | Returns driven equally across all categories |


---

## 📄 Requirements

```
pandas>=2.0.0
numpy>=1.24.0
psycopg2-binary>=2.9.0
scikit-learn>=1.3.0
scipy>=1.11.0
statsmodels>=0.14.0
ydata-profiling>=4.5.0
missingno>=0.5.2
matplotlib>=3.7.0
openai>=1.0.0
jupyter>=1.0.0
```

---

## 📖 Report

The full project report (PDF) is included in the repository root:
- `Data_warehouse_final_project_proposal.pdf` — compiled PDF
---

## 📜 License

This project was developed for academic purposes at Università della Calabria. All code and documentation authored by Tesfay Mezgebe Weldemihret.
