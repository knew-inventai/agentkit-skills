# Workflow architecture — `.github/workflows/codeql.yml`

Three jobs, three reasons.

## `analyze` (every push, pull_request, schedule)

The standard CodeQL action. Configured with the repo-local model pack so `barrierModel` YAML rows in `.github/codeql/extensions/*.yml` are loaded.

```yaml
- uses: github/codeql-action/init@v3
  with:
    languages: actions, javascript-typescript, python
    packs:
      python:
        - ./.github/codeql                                # ← critical
- uses: github/codeql-action/analyze@v3
```

**Don't remove the `packs.python` block** — without it, `analyze.sh` and the GitHub-run analysis would silently disagree (local sees barriers, GitHub doesn't, or vice versa).

## `main-report` (push to default branch or schedule)

Full reporting: PDF (Puppeteer), CSV (Node), Teams adaptive card. Runs only on the default branch so PRs don't trigger an expensive PDF render every commit.

Key dynamic config:

```yaml
env:
  DEFAULT_BRANCH: ${{ github.event.repository.default_branch || 'main' }}
```

**Avoid hardcoded `refs/heads/main`** in the report job — many repos use `dev`, `develop`, `master`, or rename their default; the dynamic form keeps the report aligned with whatever GitHub considers default.

Alert fetching filter:

```bash
gh api repos/${{ github.repository }}/code-scanning/alerts \
  --jq '[.[] | select(.tool.name == "CodeQL")]'         # exclude Trivy etc.
```

## `pr-comment` (pull_request)

Lightweight severity summary posted to the PR. Two important details:

1. **Uses merge-preview ref**, not the default branch:

   ```yaml
   ref: refs/pull/${{ github.event.pull_request.number }}/merge
   ```

   Without this, the comment reports stale main-branch alerts and PR authors get misled about whether their PR makes things better or worse.

1. **Updates existing comment instead of duplicating** via the marker:

   ```html
   <!-- codeql-pr-security-comment -->
   ```

   On each PR sync push, the bot finds the prior comment by marker and edits it in place.

## Why the split

A common antipattern: a single `generate-report` job that runs on every event and always reads `refs/heads/main` alerts. Symptoms:

- PRs get stale default-branch numbers (don't reflect the PR's actual delta)
- Default branch can't be renamed without also editing the workflow
- Expensive reporting (PDF, CSV, Teams card) runs on every PR push

After splitting:

- PRs run only `analyze` + `pr-comment` (fast, accurate to merge preview)
- Push/schedule run only `analyze` + `main-report` (heavy reporting, only when warranted)

## When you change `.github/codeql/extensions/*.yml`, also check

- The `analyze` job's `packs.python` block still points at `./.github/codeql`
- The pack `name:` in `.github/codeql/qlpack.yml` matches whatever the workflow / local CLI passes to `--model-packs`
- No new validator helper was added without a matching `barrierModel` entry — verify via repo-wide grep for the function name in YAML
