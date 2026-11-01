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
