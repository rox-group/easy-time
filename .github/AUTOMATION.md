# Repository automation

This document describes every automated workflow in the repository and explains
how to configure them correctly.

---

## Workflows

### `ci.yml` — Continuous integration

Triggered on every pull request and push to `main`.

- Verifies required project files exist (`README.md`, `SECURITY.md`, etc.)
- Lints Markdown and YAML with `super-linter`

Add new stack checks here as each implementation milestone is completed (see
`MAIN_BRANCH_RULESET.md`).

---

### `auto-merge.yml` — Automatic merge

Triggered when a pull request is opened, synchronised, or labelled.

**How it works**

| Scenario | What happens |
|----------|-------------|
| PR by `dependabot[bot]` | Auto-approved and merged once all checks pass |
| PR labelled `automerge` | Merged (creating a merge commit to preserve full history) once all checks pass |
| All other PRs | No automatic action — merge manually |

**How to enable auto-merge on your PR**

1. Add the `automerge` label to the pull request, **or**
2. Let Dependabot create the PR — it is handled automatically.

GitHub will queue the merge and execute it as soon as every required status
check turns green. If a check fails the merge is cancelled and you must fix
the issue and re-add the label.

> **Prerequisite**: Enable **Allow auto-merge** in
> *Settings → General → Pull requests* before this workflow can function.

---

### `readme-sync.yml` — README milestone auto-update

Triggered on every push to `main` that does not exclusively touch `README.md`
or `.github/`.

**How it works**

The workflow runs `.github/scripts/update_readme_status.py`, which inspects
the repository for key indicator files to decide whether each implementation
milestone is complete:

| Step | Indicator |
|------|-----------|
| 1 — iOS app shell | `ios/EasyTime/Views/ContentView.swift` exists and is non-empty |
| 2 — Backend API contract | `backend/app/main.py` exists and is non-empty |
| 3 — GTFS import | Any file matching `*gtfs*`, `*ingest*`, or `*import*` under `backend/app/` |
| 4 — iOS networking | `ios/EasyTime/Networking/` or `ios/EasyTime/Services/` directory exists |
| 5 — WidgetKit | `ios/EasyTimeWidget/` directory exists |

If the table changes the bot commits
`docs(auto): sync README milestone status [skip ci]` directly to `main`.

---

### `label-pr.yml` — PR size labeller

Triggered on every pull request open or synchronise event.

Applies one of the following labels based on total lines changed:

| Label | Lines changed |
|-------|--------------|
| `xs` | 0 – 10 |
| `s` | 11 – 50 |
| `m` | 51 – 200 |
| `l` | 201 – 500 |
| `xl` | 500+ |

---

### `stale.yml` — Stale pull request cleanup

Runs daily at 09:00 UTC.

- After **30 days** of inactivity on a PR: adds the `stale` label and posts a
  warning comment.
- After **7 more days** with no activity: closes the PR with the `closed-stale`
  label.

PRs labelled `work-in-progress`, `automerge`, or `do-not-merge` are exempt.

---

### `release-drafter.yml` — Automated release notes

Triggered on push to `main` and pull request events.

Maintains a **draft GitHub release** whose body is automatically populated from
merged PR titles, categorised by label:

| Category | Labels |
|----------|--------|
| 🚀 Features | `feat`, `feature` |
| 🐛 Bug Fixes | `fix`, `bug` |
| 📖 Documentation | `docs`, `documentation` |
| 🧹 Maintenance | `chore`, `refactor`, `ci` |
| 🔐 Security | `security` |

Publish the draft release manually when you are ready to tag a version.

---

### `slack-notify.yml` — Slack PR alerts

Triggered whenever a pull request targeting `main` is **opened**, **reopened**, or **marked ready for review**.

Sends a formatted Slack Block Kit card to your team's Slack channel containing:
- PR title & link
- Author username & avatar
- Target and source branches
- One-click "Review Pull Request" action button

### `monday-sync.yml` — monday.com board sync

Triggered on pull request events (`opened`, `reopened`, `ready_for_review`, `closed`), issue events (`opened`, `closed`), or manually via `workflow_dispatch`.

- **PR opened / in review:** Finds or creates the matching task on the `Tasks` board, marks it **Working on it**, and posts the PR link.
- **PR merged:** Automatically updates task status to **Done** and adds a merge update.
- **Issue opened / closed:** Automatically creates new items for issues and marks them **Done** when resolved.

---

## One-time repository settings

The following settings must be configured manually in
**GitHub → Settings** for the automations to work correctly.

### Required for auto-merge

1. *Settings → General → Pull requests* → enable **Allow auto-merge**.
2. *Settings → General → Pull requests* → enable **Automatically delete head
   branches** (keeps the branch list tidy after squash merges).

### Required for Slack notifications

1. Create an Incoming Webhook in Slack (*Slack App Directory → Incoming WebHooks → Add to Slack*).
2. Choose the channel where notifications should be posted and copy the Webhook URL.
3. In GitHub: go to **Settings → Secrets and variables → Actions → New repository secret**.
4. Set Name: `SLACK_WEBHOOK_URL` and Value: your Slack webhook URL.

### Required for monday.com sync

1. Generate a Personal API Token on monday.com (*Profile Avatar → Developers → My Access Tokens*).
2. In GitHub: go to **Settings → Secrets and variables → Actions → New repository secret**.
3. Set Name: `MONDAY_API_KEY` and Value: your monday.com API token.

### Required for the branch ruleset

Follow the steps in `.github/MAIN_BRANCH_RULESET.md` to protect `main` and
require the `Validate repository` check before merging.


---

## Adding a new workflow

1. Create `.github/workflows/<name>.yml`.
2. Document it in this file under **Workflows**.
3. If the workflow produces a required check, add it to the branch ruleset
   (see `MAIN_BRANCH_RULESET.md`).
