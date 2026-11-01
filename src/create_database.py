"""Create the project's PostgreSQL database (safe to run more than once)."""
import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

load_dotenv()  # read settings from .env into environment variables
db_name = os.environ["PGDATABASE"]

# Connect to the built-in "postgres" database first: ours doesn't exist yet.
# URL.create handles special characters in the password safely.
url = URL.create(
    "postgresql+psycopg2",
    username=os.environ["PGUSER"],
    password=os.environ["PGPASSWORD"],
    host=os.environ["PGHOST"],
    port=int(os.environ["PGPORT"]),
    database="postgres",
)

# CREATE DATABASE can't run inside a transaction, so turn on autocommit.
engine = create_engine(url, isolation_level="AUTOCOMMIT")

with engine.connect() as conn:
    exists = conn.execute(
        text("SELECT 1 FROM pg_database WHERE datname = :name"), {"name": db_name}
    ).scalar()
    if exists:
        print(f"Database '{db_name}' already exists - nothing to do.")
    else:
        conn.execute(text(f'CREATE DATABASE "{db_name}"'))
        print(f"Created database '{db_name}'.")
