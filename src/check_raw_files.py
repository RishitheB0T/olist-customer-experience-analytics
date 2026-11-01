"""Check that all 9 raw Olist CSVs are present, and show their size and shape."""
from pathlib import Path

import pandas as pd

RAW_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"

EXPECTED_FILES = [
    "olist_customers_dataset.csv",
    "olist_geolocation_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "product_category_name_translation.csv",
]

missing = [name for name in EXPECTED_FILES if not (RAW_DIR / name).exists()]
if missing:
    raise SystemExit(f"Missing files in {RAW_DIR}: {missing}")

print(f"{'file':40} {'MB':>6} {'rows':>9} {'cols':>5}")
for name in EXPECTED_FILES:
    path = RAW_DIR / name
    df = pd.read_csv(path)  # load the whole file into a table
    size_mb = path.stat().st_size / 1_000_000
    print(f"{name:40} {size_mb:6.1f} {len(df):9,} {df.shape[1]:5}")

print(f"\nAll {len(EXPECTED_FILES)} files present.")
