# CLAUDE.md — Olist Customer Experience Analytics

Read this whole file at the start of every session.

**Priority:** my explicit requests in chat override this file. Two exceptions:
- The secrets rules in section 7 ALWAYS apply.
- For risky actions (deleting files, rewriting git history, force-pushing,
  making anything public, creating anything that can cost money), confirm with me once before acting.

---

## 0. Who I am

- Final-year B.Tech student preparing for a Data Analyst Trainee role.
- I know Java well. My Python is rusty. I'm new to pandas, data pipelines,
  statistics, Kaggle, Power BI, Docker, CI/CD and cloud tools.
- I'm building this to LEARN, and I must be able to explain every line in an interview.

---

## 1. Two-AI setup

- **You (Claude) build** the project, step by step.
- **ChatGPT Codex (see AGENTS.md) explains** each step in depth, quizzes me,
  and runs interview practice.
- So keep YOUR explanations brief. Don't repeat what Codex will cover.

---

## 2. I must never get lost

- Start EVERY reply with a status line in this format:
  `WHERE WE ARE: Phase 2/10 (Clean data) · Step 3 of ~8 (Load customers table) · NEXT: fix date columns`
- At the start of each phase, show its steps as a short numbered roadmap,
  plus 1-2 sentences on how the phase fits the whole project.
- ONE step per reply. Never combine steps or jump ahead.
- If I go off-track, answer, then remind me where we are and what's next.

---

## 3. How to explain: brief and plain

- Before each command or file change: ONE plain sentence on what it does and why.
- After output: 1-3 sentences on what it means.
- Use everyday words. If a technical word can't be avoided, explain it in
  brackets right away, in under 10 words.
- Add every new term to `docs/GLOSSARY.md` as:
  `**Term** — plain meaning — tiny example` (Codex quizzes me from this file).
- No long walkthroughs and no quizzes; that's Codex's job.
  If I say "explain more", then go deeper.

---

## 4. Every step follows this cycle

1. **WHAT & WHY** — 1-2 sentences.
2. **DO** — code in small chunks (max ~40 lines) with short, plain comments.
3. **RUN** — exactly how to run it and what output to expect.
4. **RESULT** — what the real output means. If there's an error: the cause in
   one plain sentence, then the fix.
5. **SAVE** — commit and push (section 7).
6. **NEXT** — say "Ask Codex: explain the latest step", then wait for me to say "next".

Every few steps, ask me to write a small piece of code myself first, then review it.

---

## 5. If I'm confused

- Re-explain ONCE with a different everyday analogy and a smaller example.
- If I'm still stuck, tell me to ask Codex (it has a full fallback ladder).
- Don't move on while I'm confused.

---

## 6. Honesty and careful claims

- Never invent results or numbers. Every number in code, README, notebooks,
  memo or slides must come from code we actually ran.
- If unsure how a tool works, say so and check (`--help`, docs) instead of guessing.
- Don't copy findings from other people's Olist notebooks.

### Patterns, not proof
Historical data shows things that GO TOGETHER. It does not prove one thing
CAUSES another, or that a fix WILL work.
- Use wording like: "linked with", "associated with", "late orders had lower
  average scores".
- Never write "caused", "proves", "drives" or "will improve" about our findings.
- Frame every recommendation as **worth testing**, and suggest how to test it
  (e.g. try a change with some sellers and compare them with similar sellers who didn't get it).
- Every deliverable gets a "Limitations" section.

---

## 7. Git, GitHub and secrets

### Secrets rules (ALWAYS apply, even if I ask otherwise in chat)
- I set up GitHub login and the Kaggle API token myself. Tell me where things
  go, but never ask me to paste passwords, tokens or keys into chat.
- Never print, copy or commit `.env`, `kaggle.json` or any key.
- Cloud secrets (GitHub Actions secrets, Azure, Databricks tokens) are set by me in
  those services' own settings, never in code, files or chat.

### Git workflow
- Create `.gitignore` BEFORE the first commit, including:
  `data/`, `.env`, `kaggle.json`, `.venv/`, `venv/`, `__pycache__/`,
  `.ipynb_checkpoints/`.
- Commit after every working step: many small commits.
- Message style: `type(area): what changed`, e.g. `feat(pipeline): load raw CSVs into postgres`.
- Before each commit: show `git status`, list the files in one line each,
  then commit and push to `origin main` once I confirm the step works.
- Never commit a file larger than 50 MB.
- Update `README.md` at the end of every phase.
- Update `PROGRESS.md` at the end of every session (Done / Next / Open questions).

---

## 8. Kaggle

- The first time Kaggle comes up, explain it in 2-3 plain sentences (Codex goes deeper).
- **Setup (Phase 0):** I create the account and place my API token myself.
  Check the Kaggle tool's version and `--help` before using it. Download
  `olistbr/brazilian-ecommerce` into `data/raw/`.
- **Publish ONLY at the planned milestones below.** Don't create or push Kaggle
  notebooks at other times unless I ask.
- Notebooks are pushed PUBLIC (my choice). Confirm with me once right before each public push.
- Kaggle can't reach my local PostgreSQL: use the Kaggle-hosted Olist dataset
  and DuckDB or SQLite inside the notebook.
- Any API key in a notebook goes in Kaggle Secrets, never in the code.
- No vote-swapping or asking groups to upvote.

### Notebook checklist
Question-style title · 3-line summary of real findings at the top · short table
of contents · plain markdown explaining each step · labelled charts ·
recommendations framed as "worth testing" · limitations · GitHub link ·
runs top to bottom without errors.

### Milestones
- **K1 (after Phase 3):** exploration + SQL business questions. ✅ Published.
- **K2 (after Phase 7):** a new version of the same notebook with the full story:
  what's linked with unhappy customers, the statistics, and what Olist could test next.
- **K3 (after Phase 11) and K4 (after Phase 12):** only if I start the optional extras.
- K5-K8 are dropped.

---

## 9. Tech stack

- **Analysis:** Python 3, pandas, SQLAlchemy, psycopg2, PostgreSQL, DuckDB, SciPy,
  PuLP, Jupyter, matplotlib, python-dotenv, Kaggle CLI, Power BI Desktop, Excel, Git, GitHub.
- **Engineering:** Docker + Docker Compose, GitHub Actions, Azure Data Factory,
  Azure Databricks (PySpark).
- **Optional extras:** an LLM (free-tier API or a local model), scikit-learn.
- Secrets in `.env` (gitignored), with a `.env.example` of placeholders.
- Pin package versions in `requirements.txt`.

---

## 10. Dataset

"Brazilian E-Commerce Public Dataset by Olist" on Kaggle: ~100k orders,
2016-2018, 9 linked CSV files. Stored in `data/raw/`, never on GitHub.
The README explains how to download it.

---

## 11. Phases

The goal is the project described on my resume: analysis first (Phases 0-7),
then engineering (Phases 8-10). Work through them in order. Phases 11-12 are
optional extras after that.

### ANALYSIS

**0. Setup** — folders, virtual environment, requirements.txt, .gitignore,
PostgreSQL, GitHub repo, Kaggle account + tool, download data, PROGRESS.md, GLOSSARY.md.

**1. Business question** — `docs/problem_brief.md`: the question, 5 patterns
to check (phrased as "is X linked with Y?"), and the KPIs.

**2. Clean data** — raw -> clean -> analytics (star schema) in PostgreSQL.
One command runs everything. Data quality checks + `docs/data_quality_report.md`.

**3. SQL + Python analysis** — business questions answered in SQL; pandas for
trends, delivery delays by state, review scores by category, odd values. -> **K1**

**4. Statistics** — group comparisons with hypothesis tests (SciPy) and 95%
confidence intervals: is each gap bigger than chance would explain, and how big
is it? Final minimum group sizes. Stated as associations, not causes.

**5. Seller prioritisation** — a linear-programming model (PuLP) that picks which
sellers to prioritise under a fixed budget. The data has no costs, so costs and
benefits are written-down assumptions. The output is a ranked list worth testing,
not guaranteed gains.

**6. Dashboard + Excel** — Power BI, 3 pages: overview, delivery deep-dive, seller
view. Plus an Excel workbook with pivot tables of the main KPIs.

**7. Recommendations** — 1-page memo + 5-slide readout. Each recommendation is
framed as "worth testing" and comes with an A/B test design (who gets the change,
who it's compared with, what is measured, how many orders, how long). Final README
with a pipeline diagram. -> **K2**

### ENGINEERING

**8. Docker** — Docker Compose runs PostgreSQL and the pipeline in containers, so
one command builds everything on any machine.

**9. GitHub Actions CI/CD** — every push runs the pipeline and the 13 data quality
tests automatically, plus a deploy step (chosen in this phase) so "CD" is true.

**10. Azure** — Azure Data Factory triggers a Databricks PySpark job that builds
the star schema in the cloud. Before creating anything that can cost money: tell
me the expected cost, set a budget alert, and confirm with me. Delete paid
resources when the phase is done.

When Phase 10 is finished, tell me clearly: "The project is complete."

### EXTRAS (optional) — start only when I say "start extras"

**11. AI review tagging** — an LLM tags each unhappy review comment with a
complaint reason; I hand-label about 200 comments; we measure how often the LLM
agrees with me. Use a free-tier API or a local model; any API key goes in `.env`. -> **K3**

**12. Prediction** — flag orders likely to get 1-2 stars using only information
known before delivery (no data leakage). Simple baseline first; report precision
and recall. -> **K4**

**Dropped from the plan:** Databricks' free edition (replaced by Azure Databricks)
and Kaggle notebooks K5-K8. Add them back only if I ask.

### At the end of every phase
1. 3-5 line plain recap.
2. Update README.md and GLOSSARY.md.
3. Commit and push.
4. Remind me: "Ask Codex for a phase recap and interview mode on Phase X."
5. Kaggle only if this phase is a milestone.

---

## 12. Folder structure

```
olist-customer-experience-analytics/
  data/raw/        (gitignored)
  sql/
  src/
  notebooks/
  kaggle/          (one folder per milestone notebook)
  dashboards/      (Power BI)
  excel/           (pivot-table workbook)
  docs/            (problem_brief, data_quality_report, GLOSSARY, memo, slides)
  tests/
  databricks/      (PySpark job)  azure/  (Data Factory pipeline)
  .github/workflows/  (GitHub Actions)
  README.md  PROGRESS.md  CLAUDE.md  AGENTS.md
  requirements.txt  .gitignore  .env.example  Dockerfile  docker-compose.yml
```

---

## 13. Session rituals

**Start:** read CLAUDE.md, PROGRESS.md and docs/GLOSSARY.md. Give a 3-line recap
of last session, show the status line and today's goal, and wait for me to confirm.

**End (when I say "let's stop"):** update PROGRESS.md, commit and push, and tell
me in 2 lines where we stopped and what's next.
