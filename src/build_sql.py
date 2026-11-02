"""Run the build steps in a .sql file, in order, inside one transaction.

If any step fails, everything from that file is undone (rolled back), so the
database is never left half-built. Uses the same '-- name:' blocks as run_sql.
Usage (from the project root):  python -m src.build_sql sql/clean_orders_customers.sql
"""
import sys
import time
from pathlib import Path

from sqlalchemy import Connection, text

from src.db import get_engine
from src.run_sql import read_queries


def run_file(conn: Connection, sql_file: str) -> None:
    """Run every block of one .sql file on an open connection; the caller owns the transaction."""
    print(f"Building: {sql_file}")
    for name, sql in read_queries(Path(sql_file)):
        start = time.perf_counter()
        result = conn.execute(text(sql))
        rows = f"{result.rowcount:,} rows" if result.rowcount >= 0 else ""  # -1 = not a row count
        print(f"  {time.perf_counter() - start:5.1f}s {rows:>13}  {name}")  # numbers first, so they line up


def main(sql_file: str) -> None:
    with get_engine().begin() as conn:  # begin(): commit at the end, or undo everything on error
        run_file(conn, sql_file)
    print("Done.")


if __name__ == "__main__":  # run main() only when this file is run directly
    main(sys.argv[1])
