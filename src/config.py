"""Shared settings: where the raw files live and which ones the project needs."""
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = PROJECT_ROOT / "data" / "raw"

# The 9 files of the Olist dataset. Every script checks against this one list.
RAW_FILES = [
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


def require_raw_files() -> None:
    """Stop with an error if any required raw file is missing from data/raw."""
    missing = [name for name in RAW_FILES if not (RAW_DIR / name).exists()]
    if missing:
        raise SystemExit(
            f"Stopping: {len(missing)} required file(s) missing from {RAW_DIR}: {missing}"
        )
