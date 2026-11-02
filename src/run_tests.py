"""Run the data quality tests and report PASS or FAIL for each.

Each test is a query that counts "bad rows" (rows breaking a rule): 0 = PASS.
Stops with exit code 1 if any test fails, so the pipeline (Step 12) can stop too.
Usage (from the project root):  python -m src.run_tests
Optional: python -m src.run_tests path/to/other_tests.sql
"""
import sys
from pathlib import Path

from sqlalchemy import text

from src.config import PROJECT_ROOT
from src.db import get_engine
from src.run_sql import read_queries

TESTS_FILE = PROJECT_ROOT / "tests" / "data_quality.sql"


def main(tests_file: Path = TESTS_FILE) -> None:
    tests = read_queries(tests_file)
    failed = []
    with get_engine().connect() as conn:
        for name, sql in tests:
            bad_rows = conn.execute(text(sql)).scalar_one()  # each test returns one number
            if bad_rows != 0:
                failed.append(name)
            print(f"  {'PASS' if bad_rows == 0 else 'FAIL'}  {name}  (bad rows: {bad_rows:,})")
    print(f"\n{len(tests) - len(failed)} of {len(tests)} tests passed.")
    if failed:
        raise SystemExit(f"Stopping: {len(failed)} test(s) failed.")


if __name__ == "__main__":  # run main() only when this file is run directly
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else TESTS_FILE)
