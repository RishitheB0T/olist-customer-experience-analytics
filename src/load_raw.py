"""Load the 9 raw Olist CSVs into the "raw" schema in PostgreSQL, exactly as they are.

Every column is stored as text, with no guessing of types, so nothing gets changed
(e.g. zip prefix "01409" keeps its leading zero). Types are fixed in the clean layer.
Safe to run again: each table is replaced.
"""
import time
from pathlib import Path

import pandas as pd
from sqlalchemy import text

from src.db import get_engine

RAW_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"
SCHEMA = "raw"


def table_name(csv_name: str) -> str:
    """olist_order_items_dataset.csv -> order_items"""
    return csv_name.removeprefix("olist_").removesuffix(".csv").removesuffix("_dataset")


def main() -> None:
    engine = get_engine()
    with engine.begin() as conn:  # begin() = save (commit) automatically at the end
        conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}"))

    for path in sorted(RAW_DIR.glob("*.csv")):
        start = time.perf_counter()
        # dtype=str: keep every value as text.
        # keep_default_na=False + na_values=[""]: only truly empty cells become NULL,
        #   so a real word like "NA" inside a comment stays as it is.
        # utf-8-sig: drop the invisible BOM mark at the start of one of the files.
        df = pd.read_csv(path, dtype=str, keep_default_na=False, na_values=[""],
                         encoding="utf-8-sig")
        name = table_name(path.name)
        df.to_sql(name, engine, schema=SCHEMA, if_exists="replace", index=False,
                  chunksize=10_000, method="multi")

        # Count rows in the database and compare with the file we just read.
        with engine.connect() as conn:
            db_rows = conn.execute(text(f"SELECT count(*) FROM {SCHEMA}.{name}")).scalar()
        status = "OK" if db_rows == len(df) else f"MISMATCH (file has {len(df):,})"
        print(f"{SCHEMA}.{name:35} {db_rows:>9,} rows  {time.perf_counter() - start:5.1f}s  {status}")


if __name__ == "__main__":  # run main() only when this file is run directly
    main()
