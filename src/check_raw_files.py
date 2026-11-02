"""Check that all 9 raw Olist CSVs are present, and show their size and shape."""
import pandas as pd

from src.config import RAW_DIR, RAW_FILES, require_raw_files


def main() -> None:
    require_raw_files()

    print(f"{'file':40} {'MB':>6} {'rows':>9} {'cols':>5}")
    for name in RAW_FILES:
        path = RAW_DIR / name
        df = pd.read_csv(path)  # load the whole file into a table
        size_mb = path.stat().st_size / 1_000_000
        print(f"{name:40} {size_mb:6.1f} {len(df):9,} {df.shape[1]:5}")

    print(f"\nAll {len(RAW_FILES)} files present.")


if __name__ == "__main__":  # run main() only when this file is run directly
    main()
