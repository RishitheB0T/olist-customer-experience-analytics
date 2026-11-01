# Glossary

Plain meanings of every new term in this project. Codex quizzes me from this file.

Format: **Term** — plain meaning — tiny example

## Phase 0 — Setup

- **.gitkeep** — an empty file that keeps an empty folder in Git (Git ignores empty folders) — `sql/.gitkeep` makes `sql/` appear on GitHub
- **PATH** — the list of folders Windows searches when you type a command — `psql` fails if its folder isn't on PATH
- **pip** — the tool that downloads and installs Python packages — `pip install pandas`
- **package** — ready-made code someone else wrote that you can install and reuse — pandas is a package for working with tables
- **service** — a program Windows keeps running in the background — PostgreSQL runs as the service `postgresql-x64-18`
- **.gitignore** — a list of files and folders Git must never track or upload — `data/` in it keeps the CSVs off GitHub
- **environment variable** — a setting stored outside the code that a program reads at run time — `PGPASSWORD=...`
- **.env file** — a private file holding environment variables like passwords; never uploaded — `.env` holds my real database password
- **placeholder** — a fake value showing what goes in a spot — `your_password_here` in `.env.example`
- **virtual environment** — a private Python setup for one project, so its packages don't clash with others — the `.venv/` folder
- **Git** — a tool that saves snapshots of your project so you can go back in time — `git commit` saves one snapshot
- **repository (repo)** — a project folder that Git tracks, with its full history — `olist-customer-experience-analytics`
- **commit** — one saved snapshot of the project, with a short message — `chore(setup): add folders...`
- **push** — upload your new commits to GitHub — `git push origin main`
- **remote / origin** — the copy of the repo on GitHub; `origin` is its nickname — `origin` = github.com/RishitheB0T/...
- **branch / main** — a line of history; `main` is the main one — we commit everything to `main`
- **line endings (LF/CRLF)** — the invisible "new line" mark; Windows and Linux use different ones, Git converts them — harmless warning during `git add`
- **activate (a virtual environment)** — switch your terminal to use the project's private Python — `.\.venv\Scripts\Activate.ps1` adds `(.venv)` to the prompt
- **interpreter** — the program that reads and runs Python code — `.venv\Scripts\python.exe`
- **execution policy** — a Windows rule about which PowerShell scripts may run — `RemoteSigned` lets local scripts run
- **requirements.txt** — the shopping list of Python packages a project needs — `pandas==3.1.0`
- **pinning (a version)** — fixing an exact version so everyone installs the same thing — `==3.1.0` instead of just `pandas`
- **driver** — the small piece of code that lets a program speak one database's language — `psycopg2` for PostgreSQL
- **import** — loading a package into your Python code so you can use it (like Java's `import`) — `import pandas`
- **dependency** — a package that another package needs to work, installed automatically — jupyter pulls in IPython
- **database** — an organised store of tables that many programs can read and write — our `olist` database in PostgreSQL
- **engine (SQLAlchemy)** — Python's reusable "phone line" to a database — `create_engine(url)`
- **connection URL** — one line holding where the database is and how to log in — `postgresql+psycopg2://user:***@localhost:5432/olist`
- **transaction** — a group of database changes that all succeed or all get cancelled — like a bank transfer: debit and credit together
- **autocommit** — every command is saved immediately, with no transaction around it — needed for `CREATE DATABASE`
- **idempotent** — safe to run again; a second run changes nothing — `create_database.py` says "already exists"
- **Kaggle** — Google's free website for sharing datasets, notebooks and data competitions — where the Olist data lives
- **CLI (command-line interface)** — a tool you control by typing commands instead of clicking — `kaggle datasets files ...`
- **authentication** — proving to a service who you are — `kaggle auth login` in the browser
- **access token** — a secret "digital key" a tool uses instead of your password; never share or commit it — stored in `C:\Users\<me>\.kaggle\`
- **dataset slug** — a dataset's short ID on Kaggle: owner/name — `olistbr/brazilian-ecommerce`
- **CSV file** — a plain-text table: one row per line, values separated by commas — `order_id,customer_id,...`
- **row / column** — a row is one record (one order); a column is one field (e.g. order date) — orders has 99,441 rows and 8 columns
- **shape** — a table's size as (rows, columns) — `df.shape` gives `(99441, 8)` for orders
- **DataFrame** — pandas' name for a table of data in Python — `df = pd.read_csv(path)`
- **licence (CC BY-NC-SA 4.0)** — the rules for using the data: credit the source, no commercial use, share alike — written in our README
- **unzip** — unpack a compressed .zip file into normal files — `--unzip` in the Kaggle download

## Phase 1 — Business question

- **business question** — the one question the whole analysis must answer for a real decision — "what is linked with unhappy customers?"
- **stakeholder** — the person or team who will use your results to decide something — Olist's customer experience team
- **problem brief** — a short document that pins down the question, what to check and how to measure it — `docs/problem_brief.md`
- **working definition** — a first, provisional meaning we may refine later — "unhappy" = 1 or 2 stars
- **pattern (to check)** — a question about two things that might go together; not proof that one causes the other — "is late delivery linked with low scores?"
- **comparing like with like** — comparing groups that are the same in an important way, so another difference doesn't mislead you — only on-time orders when checking product categories
- **80/20 (Pareto) check** — testing whether a small share of items accounts for most of a result — do 20% of sellers get most bad reviews?
- **repeat purchase** — a customer coming back to order again — the same `customer_unique_id` on two orders
- **carrier** — the delivery company that moves the parcel from seller to customer — `order_delivered_carrier_date` is the hand-over
