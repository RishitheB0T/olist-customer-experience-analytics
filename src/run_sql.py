"""Run every query in a .sql file and print each result as a small table.

Each query in the file starts with a line like:  -- name: Orders by status
Usage (from the project root):  python -m src.run_sql sql/profile_baseline.sql
"""
import sys
from pathlib import Path

import pandas as pd
from sqlalchemy import text

from src.db import get_engine


def read_queries(path: Path) -> list[tuple[str, str]]:
    """Split a .sql file into (name, query) pairs, using the '-- name:' lines."""
    queries = []
    for block in path.read_text(encoding="utf-8").split("-- name:")[1:]:
        name, _, sql = block.partition("\n")  # first line = name, rest = the query
        queries.append((name.strip(), sql.strip().rstrip(";")))
    return queries


def main(sql_file: str) -> None:
    with get_engine().connect() as conn:
        for name, sql in read_queries(Path(sql_file)):
            result = pd.read_sql(text(sql), conn)  # run the query, get a table back
            print(f"\n=== {name} ===")
            print(result.to_string(index=False))


if __name__ == "__main__":  # run main() only when this file is run directly
    main(sys.argv[1])
