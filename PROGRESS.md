# Progress

## Session 1 — 2026-11-01

### Done
- Saved project rules as `CLAUDE.md`; renamed Codex file to `AGENTS.md`
- Found the Codex VS Code extension install was cut off (only the "Codex Audio" helper installed)
- Phase 0, Step 1: created folders (`data/raw`, `sql`, `src`, `notebooks`, `kaggle`, `dashboards`, `docs`, `tests`)
- Phase 0, Step 2: checked tools: Python 3.14.7, Git 2.55, GitHub CLI 2.102 (logged in), PostgreSQL 18.6 (running)
- Phase 0, Step 3: wrote `.gitignore` and `.env.example`
- Phase 0, Step 4: started `PROGRESS.md`, `docs/GLOSSARY.md`, `README.md`
- Phase 0, Step 5: git init, first commit, pushed to public GitHub repo `olist-customer-experience-analytics`
- Phase 0, Step 6: created virtual environment `.venv` (Python 3.14.7); local folder stays `C:\projects\DataAnalysis`
- Phase 0, Step 7: `requirements.txt` with 8 pinned packages, installed in `.venv`, imports checked
- Phase 0, Step 8: psql added to user PATH; `.env` created (by me); database `olist` created via `src/create_database.py`, connection checked
- Phase 0, Step 9: Kaggle CLI 2.2.5 checked; logged in with `kaggle auth login`; can list the 9 Olist files
- Phase 0, Step 10: downloaded 9 Olist CSVs into `data/raw/` (sizes match Kaggle); `src/check_raw_files.py` reads all 9 (orders: 99,441 rows)
- **Phase 0 complete**; README updated with setup steps
- Phase 1, Step 1: wrote the main question in `docs/problem_brief.md` (unhappy = 1-2 stars, working definition)
- Phase 1, Step 2: chose 5 patterns (delivery promise, delivery stages & routes, product & value, seller concentration, business impact); keeping GLOSSARY public

### Next
- Phase 1, Step 3: define the KPIs (section 3 of the brief)

### Open questions
- Is the Codex extension (`openai.chatgpt`) installed now?
- Power BI Desktop isn't installed yet (needed in Phase 5)
