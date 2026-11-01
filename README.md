# Olist Customer Experience Analytics

Olist is a Brazilian online marketplace. Acting as an analyst for its customer
experience team, this project uses 99,441 real orders to find what goes together
with unhappy customers (1-2 star reviews) across delivery, products, sellers and
price, and whether unhappy customers are less likely to order again. The end result
is a short list of changes **worth testing**, each with a suggested way to test it.

**Question:** what is linked with unhappy customers on Olist, and which of those
things would be worth testing a fix for first?
Full plan: patterns, KPIs, scope and limitations in [docs/problem_brief.md](docs/problem_brief.md).

> 🚧 Work in progress: Phases 0-1 done; next is **Phase 2 (Clean data)**.

## Data

"Brazilian E-Commerce Public Dataset by Olist" on Kaggle
([`olistbr/brazilian-ecommerce`](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)),
licence CC BY-NC-SA 4.0. The data is **not** stored in this repo: you download it yourself (below).

9 CSV files, ~126 MB in total. The orders table has 99,441 rows
(counted with `src/check_raw_files.py`).

## How to set it up (Windows, PowerShell)

Needs Python 3.14, PostgreSQL 18 and a free Kaggle account.

```powershell
# 1. Get the code and build the private Python setup
git clone https://github.com/RishitheB0T/olist-customer-experience-analytics.git
cd olist-customer-experience-analytics
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt

# 2. Database settings: copy the template, then type your own password into .env
Copy-Item .env.example .env
.\.venv\Scripts\python.exe src\create_database.py

# 3. Log in to Kaggle (opens a browser), then download the data
.\.venv\Scripts\kaggle.exe auth login
.\.venv\Scripts\kaggle.exe datasets download olistbr/brazilian-ecommerce -p data/raw --unzip

# 4. Check all 9 files arrived
.\.venv\Scripts\python.exe src\check_raw_files.py
```

## Tech stack

Python, pandas, PostgreSQL, SQLAlchemy, DuckDB, scipy, Jupyter, Power BI, Git/GitHub, Kaggle.

## Project plan

| Phase | What | Status |
|---|---|---|
| 0 | Setup | ✅ Done |
| 1 | Business question & KPIs | ✅ Done |
| 2 | Clean data (raw → clean → star schema) | Next |
| 3 | SQL + Python analysis | — |
| 4 | Basic statistics | — |
| 5 | Power BI dashboard | — |
| 6 | Recommendations (memo + slides) | — |

## Folder structure

```
data/raw/     raw CSVs (not on GitHub)
sql/          SQL scripts
src/          Python pipeline code
notebooks/    Jupyter notebooks
kaggle/       Kaggle notebooks, one folder per milestone
dashboards/   Power BI files
docs/         problem brief, data quality report, glossary, memo
tests/        data and code checks
```
