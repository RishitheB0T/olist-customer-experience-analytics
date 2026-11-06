"""Run the whole pipeline with one command: raw -> clean -> analytics -> tests.

Steps run in build order (each table is built after the tables it points at).
All 9 SQL builds run in ONE transaction: if any of them fails, every clean and
analytics table goes back to how it was before the run (nothing half-built).
Stops at the first failure: a build error, or a failed test (exit code 1).
Usage (from the project root):
    python -m src.pipeline              # everything, including the ~2.5 min raw load
    python -m src.pipeline --skip-raw   # rebuild clean + analytics from the raw tables already loaded
"""
import sys
import time

from src import build_sql, load_raw, run_tests
from src.db import get_engine

# Build order: each file only needs tables built by the files above it.
BUILD_FILES = [
    "sql/clean_orders_customers.sql",     # customers, orders
    "sql/clean_products_sellers.sql",     # categories, products, sellers
    "sql/clean_items_payments.sql",       # items -> orders, products, sellers; payments -> orders
    "sql/clean_reviews.sql",              # reviews -> orders
    "sql/clean_geolocation.sql",          # one map point per zip prefix
    "sql/analytics_dims.sql",             # customer and seller dims use geolocation; product; date
    "sql/analytics_fact_order.sql",       # fact_order -> dims
    "sql/analytics_fact_order_item.sql",  # fact_order_item -> fact_order, dims
    "sql/dashboard_views.sql",            # views for Power BI and Excel (read the analytics tables)
]


def main(skip_raw: bool = False) -> None:
    start = time.perf_counter()
    if skip_raw:
        print("== 1. Raw layer: skipped (--skip-raw) ==")
    else:
        print("== 1. Raw layer: load the 9 CSV files ==")
        load_raw.main()
    print("\n== 2. Clean and analytics layers (one transaction: all or nothing) ==")
    with get_engine().begin() as conn:  # commit once at the end, or undo all 9 files on any error
        for sql_file in BUILD_FILES:
            build_sql.run_file(conn, sql_file)
    print("All builds committed.")
    print("\n== 3. Data quality tests ==")
    run_tests.main()
    print(f"\nPipeline finished in {time.perf_counter() - start:.0f}s.")


if __name__ == "__main__":  # run main() only when this file is run directly
    main(skip_raw="--skip-raw" in sys.argv)
