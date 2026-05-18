# Security Suppressions Index

Repo-root counterpart to `grep -rn 'lgtm\[' src/`. Every `# lgtm[py/<rule>]` we
commit must have a row here, and every row here must point at a real
suppression in the codebase. Quarterly audit checks that the two match exactly.

When **adding** a row: append at the bottom; don't sort historically.
When **removing** a suppression: also remove the row (or mark `REMOVED <date>`
in the Re-audit column for audit-trail purposes).

| File:Line | Rule | Reason | Reviewer | Date | Re-audit if |
|---|---|---|---|---|---|
| `src/example/foo.py:42` | `py/clear-text-storage-sensitive-data` | FP — value is Fernet ciphertext (encrypted at api_key.py:70) | @example-user | 2026-MM-DD | cookie value source ever changes to plaintext |

## Audit log

| Date | Auditor | Note |
|---|---|---|
| 2026-MM-DD | @example | Initial creation |
