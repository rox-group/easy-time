# Repository automation

This document describes every automated workflow in the repository and explains
how to configure them correctly.

---

## Workflows

### `ci.yml` — Continuous integration

Triggered on every pull request and push to `main`.

- Verifies required project files exist (`README.md`, `SECURITY.md`, etc.)
- Lints Markdown and YAML with `super-linter`
- Runs backend unit and integration tests and Ruff linting
- Automatically posts a summary comment and grants approval on the pull request when all checks pass

Add new stack checks here as each implementation milestone is completed (see
`MAIN_BRANCH_RULESET.md`).

---

### `auto-merge.yml` — Automatic merge

Triggered when a pull request is opened, synchronised, or labelled.

**How it works**

| Scenario                | What happens                                                                   |
| ----------------------- | ------------------------------------------------------------------------------ |
| PR by `dependabot[bot]` | Auto-approved and merged once all checks pass                                  |
| PR labelled `automerge` | Merged (creating a merge commit to preserve full history) once all checks pass |
| All other PRs           | No automatic action — merge manually                                           |

**How to enable auto-merge on your PR**

1. Add the `automerge` label to the pull request, **or**
2. Let Dependabot create the PR — it is handled automatically.

GitHub will queue the merge and execute it as soon as every required status
check turns green. If a check fails the merge is cancelled and you must fix
the issue and re-add the label.

> **Prerequisite**: Enable **Allow auto-merge** in
> _Settings → General → Pull requests_ before this workflow can function.

---

### `readme-sync.yml` — README milestone auto-update

Triggered on every push to `main` that does not exclusively touch `README.md`
or `.github/`.

**How it works**

The workflow runs `.github/scripts/update_readme_status.py`, which inspects
the repository for key indicator files to decide whether each implementation
milestone is complete:

| Step                     | Indicator                                                                  |
| ------------------------ | -------------------------------------------------------------------------- |
| 1 — iOS app shell        | `ios/EasyTime/Views/ContentView.swift` exists and is non-empty             |
| 2 — Backend API contract | `backend/app/main.py` exists and is non-empty                              |
| 3 — GTFS import          | Any file matching `*gtfs*`, `*ingest*`, or `*import*` under `backend/app/` |
| 4 — iOS networking       | `ios/EasyTime/Networking/` or `ios/EasyTime/Services/` directory exists    |
| 5 — WidgetKit            | `ios/EasyTimeWidget/` directory exists                                     |

If the table changes, the workflow automatically opens an `automerge`-labelled
pull request (`docs/auto-sync-readme`) which is merged once repository validation passes.

---

### `label-pr.yml` — PR size labeller and author assignment

Triggered on every pull request open, synchronize, or reopen event.

- Automatically assigns the pull request to the author who created it.
- Applies one of the following labels based on total lines changed:

| Label | Lines changed |
| ----- | ------------- |
| `xs`  | 0 – 10        |
| `s`   | 11 – 50       |
| `m`   | 51 – 200      |
| `l`   | 201 – 500     |
| `xl`  | 500+          |

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

| Category         | Labels                    |
| ---------------- | ------------------------- |
| 🚀 Features      | `feat`, `feature`         |
| 🐛 Bug Fixes     | `fix`, `bug`              |
| 📖 Documentation | `docs`, `documentation`   |
| 🧹 Maintenance   | `chore`, `refactor`, `ci` |
| 🔐 Security      | `security`                |

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

### `auto-update-branch.yml` — Auto-update open PRs with main

Triggered on every `push` to `main` and manually via `workflow_dispatch`.

- Finds all open, non-draft pull requests targeting `main`.
- Calls GitHub's `updateBranch` API to automatically merge or rebase the latest `main` into the PR branch so pull requests never fall behind `main`.

---

### `delete-pr-branch.yml` — Auto-delete PR head branch

Triggered whenever a pull request is **closed** (including when merged).

- Checks that the PR head branch belongs to the internal repository (not an external fork).
- Verifies that the branch is not protected or a critical default branch (`main`, `master`, `release/*`, etc.).
- Automatically deletes the remote head branch reference to keep the branch list clean.

---

### `clean-stale-branches.yml` — Stale and merged branch cleanup

Triggered daily at 08:00 UTC and manually via `workflow_dispatch`.

- Scans all remote branches across the repository.
- Safely excludes protected and default branches (`main`, `master`, `release/*`, etc.).
- Safely excludes branches that have open pull requests.
- Identifies and deletes branches that are already fully merged into `main`.
- Identifies and deletes unmerged branches that have been inactive (no commits) for 30+ days.
- Supports a `dry_run` manual dispatch option to preview cleanable branches without deleting them.

---

## One-time repository settings

The following settings must be configured manually in
**GitHub → Settings** for the automations to work correctly.

### Required for auto-merge

1. _Settings → General → Pull requests_ → enable **Allow auto-merge**.
2. _Settings → General → Pull requests_ → enable **Automatically delete head
   branches** (keeps the branch list tidy after squash merges).

### Required for Slack notifications

1. Create an Incoming Webhook in Slack (_Slack App Directory → Incoming WebHooks → Add to Slack_).
2. Choose the channel where notifications should be posted and copy the Webhook URL.
3. In GitHub: go to **Settings → Secrets and variables → Actions → New repository secret**.
4. Set Name: `SLACK_WEBHOOK_URL` and Value: your Slack webhook URL.

### Required for monday.com sync

1. Generate a Personal API Token on monday.com (_Profile Avatar → Developers → My Access Tokens_).
2. In GitHub: go to **Settings → Secrets and variables → Actions → New repository secret**.
3. Set Name: `MONDAY_API_KEY` and Value: your monday.com API token.

### Optional for posting CI comments as your personal GitHub account

1. Generate a Personal Access Token on GitHub (_Profile Avatar → Settings → Developer Settings → Personal access tokens_ with `repo` scope).
2. In GitHub: go to **Settings → Secrets and variables → Actions → New repository secret**.
3. Set Name: `USER_PAT` and Value: your personal access token.
4. If omitted, CI comments and reviews are posted by `github-actions[bot]`.

### Required for the branch ruleset

Follow the steps in `.github/MAIN_BRANCH_RULESET.md` to protect `main` and
require the `Validate repository` check before merging.

---

## Adding a new workflow

1. Create `.github/workflows/<name>.yml`.
2. Document it in this file under **Workflows**.
3. If the workflow produces a required check, add it to the branch ruleset
   (see `MAIN_BRANCH_RULESET.md`).
