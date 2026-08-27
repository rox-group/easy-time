# Main branch ruleset

Configure this in **GitHub → Settings → Rules → Rulesets → New branch ruleset** before merging this pull request into `main`.

## Target

- Ruleset name: `Protect main`
- Enforcement: `Active`
- Target branches: include the default branch (`main`)

## Rules

- Require a pull request before merging. Keep required approvals at `0` for this single-maintainer repository; increase this to `1` when a second maintainer is available.
- Require conversation resolution before merging.
- Require status checks to pass and require the branch to be up to date. Select:
  - `Validate repository`
  - `Dependency review`
- Block force pushes.
- Block branch deletion.
- Do not allow bypasses except repository administrators when an emergency override is necessary.

## After a technology stack is added

Extend `.github/workflows/ci.yml` with that stack's formatter, linter, tests, build, and coverage checks. Add every new required check to this ruleset before relying on it for merges.
