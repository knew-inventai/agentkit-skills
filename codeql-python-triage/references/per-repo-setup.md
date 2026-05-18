# Per-repo setup — what each Python project needs for CodeQL barriers

Generic guide for wiring a project's own `barrierModel` data extensions. Concepts here apply to any Python repo; substitute the placeholder names with your project's real ones.

## The minimum file set

If you want Level-1 rules (`py/path-injection`, `py/command-injection`, etc.) to recognise your project's validator helpers as sanitizers, the repo needs:

```
<repo>/
├── .github/
│   ├── codeql/
│   │   ├── qlpack.yml                  # declares the pack
│   │   └── extensions/
│   │       └── <your-name>-sanitizers.yml   # the barrierModel entries
│   └── workflows/
│       └── codeql.yml                  # uses packs.python: ./.github/codeql
└── src/<your-package>/utils/
    ├── path_validators.py              # your safe-path helpers
    └── command_validators.py           # your safe-command helpers
```

## `qlpack.yml` shape

```yaml
name: <your-org>/<pack-name>            # e.g. acme/python-sanitizers
version: 0.0.1
library: true
extensionTargets:
  codeql/python-all: "*"
dataExtensions:
  - extensions/*.yml
```

- `library: true` + `extensionTargets` = data-extension-only pack (no QL queries of its own)
- The pack `name` is what you pass to `--model-packs=<name>` on the CLI

## `extensions/*-sanitizers.yml` shape

```yaml
extensions:
  - addsTo:
      pack: codeql/python-all
      extensible: barrierModel
    data:
      # Each row: ["<root-package>", "<api-graph-path>", "<barrier-kind>"]
      - ["<your-package>", "Member[utils].Member[path_validators].Member[<func>].ReturnValue", "path-injection"]
      - ["<your-package>", "Member[utils].Member[command_validators].Member[<func>].ReturnValue", "command-injection"]
```

The `barrier-kind` strings must match what the target query's `SanitizerFromModel` reads. Currently known: `"path-injection"`, `"command-injection"`, `"url-redirection"`, `"unsafe-deserialization"`. For others, audit the query (see `references/rule-levels.md`).

## Multi-package repos

If your repo has a "core" / "extension" layered structure where the **lower layer can't import the upper layer**, declare each layer's validators independently — barrier YAML can list both:

```yaml
- ["<upper-package>", "Member[utils].Member[path_validators].Member[resolve_under].ReturnValue", "path-injection"]
- ["<lower-package>", "Member[utils].Member[path_validators].Member[resolve_under].ReturnValue", "path-injection"]
```

The validator implementation in the lower package is typically a byte-for-byte mirror of the upper one (so behaviour is identical) with the duplication documented in module-level docstrings.

## Workflow wiring

```yaml
# .github/workflows/codeql.yml (excerpt)
- uses: github/codeql-action/init@v3
  with:
    languages: python
    packs:
      python:
        - ./.github/codeql
```

The `packs:` block is what makes GitHub-side CodeQL load your data extensions. **Without this, your YAML is silently ignored on GitHub** even though local `analyze.sh` (which adds `--model-packs` automatically) still picks it up — that drift is the most common debugging trap.

## Validator helper contract

Validators wired into `barrierModel` are the trust contract. Any change should:

1. Keep existing unit tests passing
2. Still raise on every adversarial payload — at minimum:
   - Path traversal: `..` segment, `\x00`, leading `/`
   - Option injection: leading `-` for arg-style values
   - Log poisoning: control chars `\x00`–`\x1f`, `\x7f`
3. Be reviewed in sync with the `.github/codeql/extensions/*.yml` row — adding a new function to the YAML widens the trust surface

## Workflow split (recommended)

If your CodeQL workflow currently has one job that runs reporting on every event, split it into separate jobs for PR vs default-branch — see `references/workflow-architecture.md` for the reasoning.

## Project-specific defaults this skill can pick up

The skill's `scripts/analyze.sh` auto-detects `./.github/codeql/qlpack.yml` in the current working directory. If it exists, the script reads the pack name from it and passes the right `--additional-packs` + `--model-packs` combo. No skill-side configuration needed per repo.
