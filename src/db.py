"""One place to build the database connection, so every script connects the same way."""
import os

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import URL, Engine

load_dotenv()  # read settings from .env into environment variables


def get_engine(database: str | None = None, **options) -> Engine:
    """Return a connection engine for our PostgreSQL server.

    database: which database to open (default: PGDATABASE from .env).
    options:  extra settings for create_engine, e.g. isolation_level="AUTOCOMMIT".
    """
    # URL.create handles special characters in the password safely.
    url = URL.create(
        "postgresql+psycopg2",
        username=os.environ["PGUSER"],
        password=os.environ["PGPASSWORD"],
        host=os.environ["PGHOST"],
        port=int(os.environ["PGPORT"]),
        database=database or os.environ["PGDATABASE"],
    )
    return create_engine(url, **options)
