# Progress

## Session 1 — 2026-11-01

### Done
- Phase 0, Step 1: created folders (`data/raw`, `sql`, `src`, `notebooks`, `kaggle`, `dashboards`, `docs`, `tests`)
- Phase 0, Step 2: checked tools: Python 3.14.7, Git 2.55, GitHub CLI 2.102 (logged in), PostgreSQL 18.6 (running)
- Phase 0, Step 3: wrote `.gitignore` and `.env.example`
- Phase 0, Step 4: started `PROGRESS.md`, `docs/GLOSSARY.md`, `README.md`
- Phase 0, Step 5: git init, first commit, pushed to public GitHub repo `olist-customer-experience-analytics`
- Phase 0, Step 6: created virtual environment `.venv` (Python 3.14.7); local folder stays `C:\projects\DataAnalysis`
- Phase 0, Step 7: `requirements.txt` with 8 pinned packages, installed in `.venv`, imports checked
- Phase 0, Step 8: psql added to user PATH; `.env` created (by me); database `olist` created via `src/create_database.py`, connection checked
- Phase 0, Step 9: Kaggle CLI 2.2.5 checked; logged in with `kaggle auth login`; can list the 9 Olist files
- Phase 0, Step 10: downloaded 9 Olist CSVs into `data/raw/` (sizes match Kaggle); `src/check_raw_files.py` reads all 9 (orders: 99,441 rows)
- **Phase 0 complete**; README updated with setup steps
- Phase 1, Step 1: wrote the main question in `docs/problem_brief.md` (unhappy = 1-2 stars, working definition)
- Phase 1, Step 2: chose 5 patterns (delivery promise, delivery stages & routes, product & value, seller concentration, business impact); keeping GLOSSARY public
- Phase 1, Step 2 (revised): checked a second AI's critique against the data and accepted most of it (delivery speed in P1, single-seller orders for P2/P4, prices within category, voucher dropped, careful P5 repeat window, baseline in scope)
- Phase 1, Step 2 (verified): P2 filters on "one shared deadline" directly (0 single-seller orders had 2+ deadlines); P5 anchors on review_answer_timestamp; found duplicate reviews per order for Phase 2
- Phase 1, Step 3: defined 11 KPIs (main: unhappy order rate = 1-2 stars ÷ reviewed orders) plus rules for counting
- Phase 1, Step 4: wrote scope (who is in each pattern), baseline plan, out of scope, 9 limitations
- Phase 1, Step 4 (revised): split each pattern into measurements (all eligible orders) and rating comparisons (reviewed subset), both denominators stated
- Phase 1, Step 5: final review of the brief (no cause-and-effect wording), project pitch added to README
- **Phase 1 complete**
- Phase 2, Step 1: shared connection helper `src/db.py` (`get_engine()`); scripts now run with `python -m src.<name>`
- Phase 2, Step 2: `src/load_raw.py` loads all 9 CSVs into schema `raw` as text (52 columns), row counts match files; takes ~2.5 min (geolocation ~85s)
- Phase 2, Step 2 (revised): shared `src/config.py` (9 required files); load_raw checks all files first and stops with exit code 1 on any row-count mismatch (both stops tested on purpose)
- Phase 2, Step 3A: reusable `src/run_sql.py` + `sql/profile_baseline.sql`; purchases 2016-09-04 to 2018-10-17 but months outside 2017-01..2018-08 are near-empty (Nov 2016 has none); 768 orders no review, 547 with 2-3; 775 orders without items (mostly unavailable/canceled)
- Phase 2, Step 3B: `sql/profile_keys.sql` + `sql/profile_values.sql`. All IDs unique except review_id (814 extra rows; review_id+order_id unique). 96,096 people for 99,441 customer_ids. Issues: 610 products no category, 13 with untranslated category, 278 customer + 7 seller zips not in geolocation, 1 order no payment, 8 delivered orders no delivery date, 6 canceled with one, 166 handed over before purchase, 23 delivered before handover, 249 orders paid != items+fees by >1 BRL, 682 surveys answered 30+ days later
- Phase 2, Step 3B (revised): key check now tests every part of two-column IDs and separates missing keys from duplicates; survey bands get "missing timestamp" + "answered before survey sent" first. Re-run: both 0, all recorded numbers unchanged
- Phase 2, Step 4: `src/build_sql.py` (one transaction, rollback tested) + `sql/clean_orders_customers.sql`: real types, primary + foreign keys, 4 flags (8/6/166/23 = profiling), `in_main_period` (99,092 in, 349 out). Checks in `sql/check_clean_orders_customers.sql`

### Next
- Phase 2, Step 5: clean layer for items, payments, products, sellers (fix misspelled columns, English categories, order totals)


