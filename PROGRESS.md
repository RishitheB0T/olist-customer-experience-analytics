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
- Phase 2, Step 4 (revised): `clean.orders.customer_id` is NOT NULL as well as a foreign key; both tested by inserting bad rows on purpose (rejected, rolled back)
- Phase 2, Step 5: `sql/clean_products_sellers.sql` + `sql/clean_items_payments.sql` (+ checks). Misspelled columns renamed, English categories (2 translated by us: 13 products; 610 "unknown"), money numeric(12,2) with totals identical to raw, keys + NOT NULL + foreign keys, flags (no category 610, 0 g 4, missing size 2, odd payments 11). Order totals (paid vs charged) decided in the analytics step (Step 8)
- Phase 2, Step 6: `sql/clean_reviews.sql` (+ `sql/check_clean_reviews.sql`). My rule for orders with 2+ reviews: **lowest score** (ties: latest answer, then review_id), marked by `is_order_review` (98,673 chosen = reviewed orders; all 99,224 rows kept). Sensitivity check: lowest vs latest = 137 vs 98 unhappy among the 547 multi-review orders. Reused review_ids (789 ids, 1,603 rows) always same person + same score, flagged. 5,127 surveys sent before delivery day, flagged. CHECK (score 1-5, answer after survey) + partial unique index (one chosen review per order), both tested by breaking them on purpose
- Phase 2, Step 7: `sql/clean_geolocation.sql` (+ check). One point per zip prefix = median of distinct points inside Brazil's box. 1,000,163 rows -> 720,154 distinct points -> 720,121 used; 19,015 -> 19,010 prefixes (5 had every point outside Brazil). `spread_km` per prefix: median 1.5 km, 428 over 50 km, 88 over 500 km, 1,233 with one point. Correction: profiling's "278 customer zips" = 278 customers in 157 prefixes (sellers: 7 in 7); after cleaning 279 customers in 158 prefixes have no location (1 lost with the 5 outside-Brazil prefixes). Found 4 items with a shipping deadline in 2020 (flag later)
- Phase 2, Step 8: `sql/analytics_dims.sql` (+ check). Schema `analytics` with dim_customer (99,441), dim_seller (3,095), dim_product (32,951, adds volume), dim_date (1,096 days = whole years 2016-2018; 608 in main period). Locations joined from clean.geolocation (279 customers, 7 sellers without). All purchase / delivered / promised days fall inside dim_date
- Phase 2, Step 9: `sql/analytics_fact_order.sql` (+ check). One row per order (99,441), money totals identical to clean. Order value = `paid_total` (items_total kept for P3; 249 mismatches flagged; of the 232 that paid more, 98.7% used instalments vs 51.5% overall). Delivery measures in calendar days (delivery, promised, days late, seller part, carrier part), hand-over late only for the 98,330 one-deadline orders, `flag_odd_deadline` for 10 orders (deadline 69+ days after purchase; median 6). Distance seller -> customer (haversine) for 96,904 single-seller orders: median 433.9 km, max 3,579.3 km. Negative days: seller 2 and carrier 20 (vs 166 and 23 flags, which use times, not days)
- Phase 2, Step 10: `sql/analytics_fact_order_item.sql` (+ check). One row per item (112,650), price and fee totals equal fact_order. freight_share (fee ÷ price; no price is 0, min 0.85, CHECK price > 0), handover_late per item (each seller's own deadline; 1,194 items never handed over), flags: zero fee 383, odd deadline 12 items in the same 10 orders. Items agree with fact_order (item counts and one-deadline hand-over: 0 mismatches)
- Phase 2, Step 11: `tests/data_quality.sql` (12 tests, each counts bad rows; 0 = PASS) + `src/run_tests.py` (PASS/FAIL per test, exit code 1 on any failure; failure path tested with a deliberately wrong test). 12 of 12 pass in ~3 s. Test 13 written with me: is_unhappy matches review_score (my AND/OR version missed rows where one side is NULL; final uses IS DISTINCT FROM). 13 of 13 pass. A correlated subquery made one test take minutes; rewritten as GROUP BY + join
- Phase 2, Step 12: `src/pipeline.py` runs load_raw → 8 SQL builds in build order → 13 tests with one command. Full run 148 s, `--skip-raw` 35 s, both exit 0 and 13/13 pass. Stops at the first failure (tested with a missing file: exit 1, tests never ran)
- Phase 2, fixes: SQL builds now run in ONE transaction from `src/pipeline.py` (tested: a deliberate failure after dropping a table changed nothing); build output aligned; `.gitattributes` stops line-ending warnings; scratch evidence saved as `sql/report_data_quality.sql`; restored the lost "Open questions" section
- Phase 2, Step 13: `docs/data_quality_report.md` (every problem, count and rule; numbers from saved code, checked automatically against fresh output), README pipeline section + diagram, brief updated (date range, data issues link)
- **Phase 2 complete**: full pipeline from raw 156 s, 13 of 13 tests pass
- Phase 3, Step 1: roadmap (10 steps) + `sql/questions/00_baseline.sql`. 99,441 orders (99,092 in main period), 98,673 reviewed (99.23%). Main KPI: unhappy rate 14.73% (14,533 of 98,673), avg score 4.08; main period 14.67%. Delivered 12.85% vs not delivered 78.21%; not-delivered orders hold 15.29% of all unhappy orders
- Phase 3, Step 2: `sql/questions/01_p1_delivery_promise.sql`. 96,470 delivered orders with both dates (95,824 reviewed). On time 93.23%; median 10 days to deliver vs 24 promised. Unhappy: on time 9.31%, 1-3 days late 32.18%, 4-7 67.68%, 8+ 79.36%. On-time orders: 7.56% (0-7 days) up to 16.03% (22+ days). Late orders surveyed after delivery: 25.11% unhappy vs 62.47% for all late, but they were less late (median 2 vs 9 days) - mixed-up groups

### Next
- Phase 3, Step 3: P2 delivery stages and routes (seller part vs carrier part)
