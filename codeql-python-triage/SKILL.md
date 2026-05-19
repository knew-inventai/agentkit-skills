---
name: codeql-python-triage
description: Triage and remediate CodeQL Python code-scanning alerts end-to-end. Use this skill when the user mentions CodeQL, code scanning, GitHub Security tab, a CodeQL rule id like py/path-injection, py/command-injection, py/clear-text-storage-sensitive-data, py/weak-sensitive-data-hashing, py/stack-trace-exposure, py/url-redirection, py/overly-large-range, py/incomplete-url-substring-sanitization, ModelsAsData, barrierModel, sanitizer, validator, SARIF, suppression, # lgtm, or any Python static-analysis remediation work. The skill inventories open alerts, classifies each rule by whether the query accepts external sanitizers (Level 1/2/3 taxonomy verified against codeql/python-all source), picks an appropriate fix strategy (validator helper + barrierModel YAML, inline # lgtm[] suppression with documented rationale, or refactor), and verifies locally with the full python-code-scanning suite. Repo-agnostic; auto-detects any local .github/codeql/ pack and respects the user's PR conventions stored in their CLAUDE.md or memory.
---

# CodeQL Python Triage

## When this skill activates

**Triggers**: any CodeQL Python alert work — fixing alerts, classifying a rule, adding a barrier, writing a suppression, auditing a query's QL source.

**Out of scope**: JavaScript / Java / Go CodeQL rules (the Level 1/2/3 taxonomy here is Python-specific; the workflow generalises but the QL paths differ). Non-CodeQL static analysis tools (ruff, mypy, bandit).

## Prerequisites

Verify before starting:

```bash
codeql version                                          # expect 2.25.x+
jq --version
gh auth status                                          # gh must be logged in
ls ~/.codeql/packages/codeql/python-all                 # need at least one version installed
```

Install if missing:
- `codeql`: `brew install codeql` (macOS) — see `references/codeql-cli.md`
- Pull the Python pack: `codeql pack download codeql/python-queries`

## The 5 phases

Follow these in order. Each phase has a script; don't skip the inventory step even if the user names the rule directly.

### Phase 1 — Inventory current alerts

```bash
bash $SKILL_DIR/scripts/inventory.sh <owner>/<repo>
```

Outputs a Markdown table grouped by rule. Capture this — it goes in the PR body later.

**Decision rule**: if more than 5 distinct rules are open, **propose splitting the work into multiple PRs** (one PR per rule family). Do not bundle unrelated rules.

### Phase 2 — Classify each rule by sanitizer support

This is the step previous sessions kept getting wrong. **Do not assume** that "the obvious sanitizer" works.

1. **First**, check `references/known-rules-ledger.md` — if the rule is already classified, use the stored Level and skip to Phase 3.
2. **Otherwise**, audit the query source:
   ```bash
   bash $SKILL_DIR/scripts/audit_query.sh py/<rule-id>
   ```
   This prints the relevant `Customizations.qll` and `Query.qll` excerpts plus a Level verdict.
3. **Decision tree**:
   - Customizations.qll contains `class SanitizerFromModel` (or equivalent ModelsAsData consumer) → **Level 1**. External `barrierModel` YAML works.
   - Only `abstract class Sanitizer` with zero concrete subclasses → **Level 2**. External sanitizers cannot be injected; only inline suppression / refactor / rename-source work.
   - The relevant framework model in `Stdlib.qll` (or similar) ignores the kwarg / API surface that would naturally express "this is not security-sensitive" → **Level 3**. Even local code-level hints don't help; suppression or refactor only.
4. **Persist**: if you ran an audit, append the verdict + date + evidence link to `references/known-rules-ledger.md`. The ledger is the skill's growing memory.

See `references/rule-levels.md` for the full taxonomy with QL source proof for every Level.

### Phase 3 — Pick fix strategy per Level

| Level | Recommended | Fallback | Don't do |
|---|---|---|---|
| 1 | `barrierModel` YAML entry pointing at a tested validator helper return value | Inline `ConstCompareBarrier` (`if x == ALLOWLIST: ...`) | Adding regex sanitizer with no QL hook |
| 2 | Inline `# lgtm[py/<rule>]` with **3-field comment** (Reason / Reviewer / Re-audit if) | Rename the sensitive variable to drop the source; or refactor data flow | Adding encryption "for CodeQL" — it does not recognise crypto |
| 3 | Inline `# lgtm[py/<rule>]` with comment | Wait for CodeQL pack upgrade; track in `references/known-rules-ledger.md` | Adding kwarg hints (e.g., `usedforsecurity=False`) thinking they sanitise |

For Level 1, write the validator to the project's `utils.*_validators` (or appropriate package — see `references/per-repo-setup.md`), then add the YAML entry — see `assets/barrierModel-entry-template.yml`.

For Level 2/3 suppressions, use `assets/lgtm-comment-template.py` for the 3-field comment, and update the repo-root `SECURITY_SUPPRESSIONS.md` index (template at `assets/SECURITY_SUPPRESSIONS-template.md`).

### Phase 4 — Verify locally

**Critical**: single-query analysis does NOT include `AlertSuppression.ql`. If you used `# lgtm` suppression and you run only the single rule file, the suppression will appear not to work. Always use the full suite for the final check:

```bash
# build DB (only when source changed)
bash $SKILL_DIR/scripts/build_db.sh                     # writes /tmp/codeql-db-py

# run full suite
bash $SKILL_DIR/scripts/analyze.sh /tmp/codeql-db-py \
  codeql/python-queries:codeql-suites/python-code-scanning.qls
# writes /tmp/codeql-result-<ts>.sarif

# inspect
bash $SKILL_DIR/scripts/parse_sarif.sh /tmp/codeql-result-<ts>.sarif py/<rule-id>
# expect: target rule count → 0
```

If the count does not drop to 0:
- **Don't ship**. Stop and re-audit the Level classification — the assumption was wrong.
- Common cause: applied a Level-1 fix on a Level-2 rule (most common: thinking `barrierModel` YAML works when it doesn't).

### Phase 5 — Open the PR

Defer to the **project's own conventions** wherever they differ from these defaults:

1. **Read first**:
   - The repo's `.github/pull_request_template.md` (if any)
   - The repo's `CLAUDE.md` / `AGENTS.md` (for project-specific rules)
   - The user's auto-memory (for cross-project personal preferences like commit language, PR language, base branch, attribution)
2. **General defaults** (only apply when project doesn't say otherwise):
   - Commits in English, Conventional Commits, one focused topic per PR
   - Don't bundle unrelated rules into one PR — split if necessary
   - Base branch: the repo's default (`git remote show origin | grep 'HEAD branch'`) unless memory overrides
3. **Permission rule** (universal): never run `gh pr create` (or push that triggers a PR) without the user's explicit go-ahead **per PR**. Staging files is fine. Committing is **not** fine without explicit say-so.

Write the PR body to mirror the repo's `.github/pull_request_template.md` structure (sections, language, tone). If no template exists, use plain sections: 變動目的 / 影響的檔案 / 修法與分類 / 驗證 / 風險 / 後續 (or the English equivalents) — matched to whatever language the rest of the repo's PRs use.

## Common pitfalls (debt from real past sessions)

- ❌ Assuming `hashlib.sha256(data, usedforsecurity=False)` sanitises `py/weak-sensitive-data-hashing`. The Stdlib.qll model doesn't read that kwarg. Verified by reading `frameworks/Stdlib.qll`'s `HashlibDataPassedToHashClass` class.
- ❌ Assuming Fernet encryption sanitises `py/clear-text-storage-sensitive-data`. The Customizations.qll for this query never imports any crypto module — no encryption is recognised.
- ❌ Running single-query analysis to check whether a `# lgtm` suppression took effect. Single-query runs don't load `AlertSuppression.ql`. Use the full suite.
- ❌ Adding a `barrierModel` YAML entry without listing the pack under `packs.python:` in `.github/workflows/codeql.yml`. The YAML is silently ignored on GitHub even when local `analyze.sh` picks it up.
- ❌ Trying to "fix" a Level-2 rule with code rather than suppression. Wastes effort; CodeQL won't recognise the fix.
- ❌ Renaming a DB column just to drop a sensitive-source heuristic. The cost (migration + ORM + frontend) usually dwarfs the benefit of clearing one CodeQL row.

## Self-update

When CodeQL CLI / pack versions change, rule classifications may shift. Run:

```bash
bash $SKILL_DIR/scripts/check_pack_version.sh
```

If it reports an upgrade, re-run `audit_query.sh` for every rule in `references/known-rules-ledger.md` and update the dates / Levels accordingly.

## Reference files

Load these into context only when needed:

- `references/rule-levels.md` — full Level 1/2/3 taxonomy with QL source proof. **Read this when**: classifying a new rule, explaining to a reviewer why a strategy was chosen.
- `references/per-repo-setup.md` — what each Python project needs for `barrierModel` to work (qlpack.yml + extensions/*.yml + workflow wiring). **Read this when**: adding a new barrier or setting up a fresh repo.
- `references/codeql-cli.md` — CLI install, flag reference, suite names. **Read this when**: a script fails, or troubleshooting `--model-packs` / `--additional-packs`.
- `references/suppression-tracking.md` — `# lgtm` semantics, `SECURITY_SUPPRESSIONS.md` index, Re-audit conditions. **Read this when**: writing a Level-2/3 suppression.
- `references/known-rules-ledger.md` — running classification ledger. **Read this when**: starting Phase 2 (always check here first).
- `references/workflow-architecture.md` — recommended `codeql.yml` job split (analyze + main-report + pr-comment). **Read this when**: setting up or refactoring a project's CodeQL workflow.

## Assets (templates)

- `assets/SECURITY_SUPPRESSIONS-template.md` — repo-root index of all live suppressions.
- `assets/barrierModel-entry-template.yml` — fill-in template for `.github/codeql/extensions/*.yml`.
- `assets/lgtm-comment-template.py` — 3-field suppression comment block (Reason / Reviewer / Re-audit if).
