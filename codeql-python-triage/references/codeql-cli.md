# CodeQL CLI Reference

## Install

macOS (verified):

```bash
brew install codeql
codeql version                    # 2.25.4 at time of writing
```

The Homebrew formula installs the CLI binary. Pack downloads happen on first use and live under `~/.codeql/packages/`.

Pull the Python packs explicitly:

```bash
codeql pack download codeql/python-all
codeql pack download codeql/python-queries
```

## Database creation

For Python projects (no compilation):

```bash
codeql database create /tmp/codeql-db-py \
  --language=python \
  --source-root=. \
  --build-mode=none \
  --overwrite
```

Use `scripts/build_db.sh` instead of remembering the flags.

## Database analysis

Two common modes:

**Single query** (fast, but does NOT load `AlertSuppression.ql`):

```bash
codeql database analyze /tmp/codeql-db-py \
  codeql/python-queries:Security/CWE-022/PathInjection.ql \
  --format=sarif-latest --output=/tmp/out.sarif --rerun
```

**Full suite** (slower, loads suppressions — REQUIRED for `# lgtm` verification):

```bash
codeql database analyze /tmp/codeql-db-py \
  codeql/python-queries:codeql-suites/python-code-scanning.qls \
  --format=sarif-latest --output=/tmp/out.sarif --rerun
```

Use `scripts/analyze.sh`.

## Suites

Under `~/.codeql/packages/codeql/python-queries/<version>/codeql-suites/`:

| Suite | Use when |
|---|---|
| `python-code-scanning.qls` | **default for our verification** — what GitHub Code Scanning runs |
| `python-security-extended.qls` | Want extra security queries beyond the default |
| `python-security-and-quality.qls` | Adds code-quality checks (not relevant for CodeQL alert sweeps) |

## Repo-local packs

If a project ships a data-extension pack under `.github/codeql/`, tell analysis to load it with **two flags together**:

```bash
codeql database analyze /tmp/codeql-db-py <spec> \
  --additional-packs=./.github/codeql \
  --model-packs=<pack-name> \
  --format=sarif-latest --output=/tmp/out.sarif --rerun
```

- `--additional-packs` points at the **directory** holding `qlpack.yml`.
- `--model-packs` activates the data extensions inside; the value must match the `name:` field in that `qlpack.yml`.

Without both, the `barrierModel` YAML entries are silently ignored.

`scripts/analyze.sh` auto-detects `.github/codeql/qlpack.yml`, parses out the pack name, and adds both flags — no per-project configuration needed.

## Inspecting installed packs

```bash
codeql resolve packs                                    # list everything codeql can see
codeql pack list                                        # alias
ls ~/.codeql/packages/codeql/python-all/                # version dirs
```

Pack source files live under `~/.codeql/packages/codeql/python-all/<ver>/semmle/python/...`. Reading the `*Customizations.qll` files is how `audit_query.sh` works.

## Flags worth knowing

| Flag | Meaning |
|---|---|
| `--rerun` | Re-evaluate queries even when cached results exist. **Always pass this** — caching has burned us. |
| `--threads=N` | Parallelism. Default uses all cores. Set to e.g. 4 if hosting other heavy work. |
| `--ram=NMB` | Cap heap. Default usually fine. |
| `--no-build-mode-none-required` | (For non-Python langs.) |
| `--format=sarifv2.1.0` or `sarif-latest` | Output format. We use SARIF + `jq`. |
| `--sarif-add-snippets` | Embed source snippets in SARIF. Useful for review, doubles file size. |

## Common errors

- **"could not resolve query pack"** → run `codeql pack download codeql/python-queries`
- **"could not find any data extension"** → check `--additional-packs` points at the dir with `qlpack.yml`, not the YAML itself
- **"no model pack matching name"** → `--model-packs` name must equal the `name:` field in `qlpack.yml`
- **alerts unchanged after adding `barrierModel`** → either you targeted a Level 2 rule (YAML silently ignored) or you forgot one of the two pack flags
