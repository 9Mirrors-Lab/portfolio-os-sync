# Portfolio OS sync

One GitHub Actions workflow and one PAT update **Portfolio OS** from several **per-repo roadmap** projects. You keep secrets and automation here only, not in every application repo.

## How it works

- **Config:** `config/repos.json` lists each source roadmap (owner + project number) and the **Portfolio OS** project item id to update (`portfolio_item_id`).
- **Behavior:** For each enabled source, the sync reads items in **Next up** and **In progress** on that roadmap, builds one line of text, and writes it to the **Next Action** field on the matching Portfolio OS card.
- **Token:** Repository secret `PORTFOLIO_SYNC_TOKEN` must be a PAT with **Account → Projects → Read and write** (fine-grained) or classic **`project`** scope. `GITHUB_TOKEN` cannot update user-owned Projects v2 in most cases.

## Setup

1. Create a new empty GitHub repository (for example `9Mirrors-Lab/portfolio-os-sync`) and push this repo.
2. In that repo: **Settings → Secrets and variables → Actions → New repository secret** → `PORTFOLIO_SYNC_TOKEN`. If you already added this secret on another repo (for example Notebook-optimizer), **remove it there** and add it **only** here so one PAT stays in one place.
3. Edit `config/repos.json`: set `portfolio.*` ids from your Portfolio OS project (GraphQL or browser devtools), and add one `sources[]` entry per repo roadmap + Portfolio card mapping.
4. Run **Actions → Sync Portfolio OS → Run workflow**, or wait for the daily schedule.

## Adding another repo

1. Create or reuse a **roadmap** GitHub Project for that repository (columns should include status values **Next Up** and **In Progress** like the Notebook Optimizer Roadmap).
2. Add a draft/issue row on **Portfolio OS** for that repo; copy its **project item id** (`PVTI_...`) from the Project API or URL.
3. Append a new object to `sources[]` in `config/repos.json` (see `config/repos.example.json`).
4. Commit and run the workflow.

## Local run

Requires `gh` and `jq`, and a token that can write Projects (same as CI):

```bash
export GH_TOKEN=ghp_...   # or: gh auth login
./scripts/sync-all.sh
```

## Related repos

- Application repos (for example **Notebook-optimizer**) do **not** need `PORTFOLIO_SYNC_TOKEN` or a sync workflow; only this repo does.
