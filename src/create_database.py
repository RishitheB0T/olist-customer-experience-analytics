"""Create the project's PostgreSQL database (safe to run more than once)."""
import os

from sqlalchemy import text

from src.db import get_engine

db_name = os.environ["PGDATABASE"]

# Connect to the built-in "postgres" database first: ours may not exist yet.
# CREATE DATABASE can't run inside a transaction, so turn on autocommit.
engine = get_engine("postgres", isolation_level="AUTOCOMMIT")

with engine.connect() as conn:
    exists = conn.execute(
        text("SELECT 1 FROM pg_database WHERE datname = :name"), {"name": db_name}
    ).scalar()
    if exists:
        print(f"Database '{db_name}' already exists - nothing to do.")
    else:
        conn.execute(text(f'CREATE DATABASE "{db_name}"'))
        print(f"Created database '{db_name}'.")
