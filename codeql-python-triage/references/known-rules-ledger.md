# Known Rules Ledger

Running classification of every CodeQL Python rule the user / team has audited so far. Updated when:
- A new rule appears and `audit_query.sh` is run on it
- A pack upgrade is detected by `check_pack_version.sh`
- A reviewer overrides an audit verdict

**Always check this before running `audit_query.sh`** — saves time and keeps history consistent.

**Pack versions for current entries**: codeql/python-all/7.1.0, codeql/python-queries/1.8.2 (CLI 2.25.4)

---

| Rule | Level | Last audit | Notes |
|---|---|---|---|
| `py/command-injection` (a.k.a. `py/command-line-injection`) | 1 | 2026-05-15 | `barrierModel` YAML works. Wire each `validate_*` helper return value with `barrier-kind: "command-injection"`. Helpers should raise `ValueError` on bad input and enforce allowlist/regex against option-injection (`-`), refspec abuse, traversal, control chars. |
| `py/path-injection` | 1 | 2026-05-15 | `barrierModel` YAML works. Wire validator return values (e.g. `resolve_under`, `safe_filename_component`) with `barrier-kind: "path-injection"`. Note: the **validator's own internals** (`Path.resolve()` etc.) still get flagged since CodeQL can't tell the helper from arbitrary user code — accept as inherent FP and dismiss in UI. |
| `py/clear-text-storage-sensitive-data` | 2 | 2026-05-18 | No `SanitizerFromModel`; no crypto recognition in `CleartextStorageCustomizations.qll`. Wrapping in Fernet / sha256 / bcrypt is invisible to the query. Only `# lgtm[]` or refactor (drop sink / rename source) work. Sources are heuristic — variable names matching `password`/`api_key`/`secret`/`token`. |
| `py/weak-sensitive-data-hashing` | 2 (effectively 3) | 2026-05-15 | Abstract `Sanitizer` only. Plus `Stdlib.qll`'s `HashlibDataPassedToHashClass` ignores the `usedforsecurity` kwarg, so Python's official sanitization hint is dead-code to CodeQL. Only `# lgtm[]` or refactor work. Common FP: O(1) lookup hashes and log fingerprints — bcrypt would actively break them. |
| `py/stack-trace-exposure` | TBD | — | Audit before fixing. Common true-positive pattern: bare `except Exception` that returns `str(exc)` to client. Common fix: wrap in generic 500 + log the trace server-side. |
| `py/url-redirection` | TBD | — | Common fix path: `urlparse(...).hostname` check against an allowlist with `endswith()` style suffix matching. Not typically a `barrierModel` candidate. |
| `py/incomplete-url-substring-sanitization` | TBD | — | Common fix: regex with explicit hostname boundary (`r"https://example\.com(?:[/\s]|$)"`) instead of bare `"https://example.com" in s`. |
| `py/overly-large-range` | TBD | — | Common fix for emoji filters: replace supplementary-plane regex character class with an explicit codepoint-range list + a char-by-char check (regex character classes covering the full supplementary plane sweep up legitimate CJK extension ranges). |

---

## Append rule for `audit_query.sh --write`

When run with `--write`, the script appends a single line in this format:

```
| `py/<rule>` | <Level> | (recorded by audit_query.sh) | <YYYY-MM-DD> |
```

Review and edit by hand to fill in the **Notes** column with gotchas and any project-specific links. The script is intentionally conservative — it never overwrites an existing row.

---

## Source pack provenance

Entries above were audited against **codeql/python-all 7.1.0 / codeql/python-queries 1.8.2**. If a future audit produces a different Level, leave both rows and date them. Don't silently overwrite — the history matters for "did CodeQL change?" debugging.
