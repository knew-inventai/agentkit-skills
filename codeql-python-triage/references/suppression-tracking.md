# Suppression tracking — `# lgtm[]` vs UI Dismiss

## Mechanics

CodeQL has three ways to suppress an alert. All three produce the same **effect** (alert marked suppressed, doesn't count in open totals, GitHub Security tab doesn't show it as open). They differ in **where the suppression metadata lives**.

### 1. `# lgtm[py/<rule>]` end-of-line comment

Source-of-truth: in the `.py` file itself.

```python
target_line_of_code  # lgtm[py/<rule-id>]
```

Recognised by `AlertSuppression.ql` (in every standard suite). The matching regex from `~/.codeql/packages/codeql/util/<ver>/codeql/util/suppression/AlertSuppression.qll`:

```ql
class LgtmSuppressionComment extends SuppressionComment {
  LgtmSuppressionComment() {
    exists(string text | text = this.(Comment).getText() |
      annotation = text.regexpFind("(?i)\\blgtm\\s*\\[[^\\]]*\\]", _, _)
      or
      annotation = text.regexpFind("(?i)(?<=^|;)\\s*lgtm(?!\\B|\\s*\\[)", _, _).trim()
    )
  }
  // ...
  override predicate covers(...) {
    this.hasLocationInfo(filepath, startline, _, endline, endcolumn) and
    startcolumn = 1                                              // covers whole line
  }
}
```

End-of-line comments cover the entire line (`startcolumn = 1`) so they catch alerts reported on that line.

### 2. `# noqa` (Python only)

```python
target_line  # noqa: py/<rule>
```

Same effect, recognised by `NoqaSuppressionComment` in `python-queries/<ver>/AlertSuppression.ql`. Slightly less explicit than `# lgtm[]` — prefer `# lgtm[<rule>]` for CodeQL-specific suppressions so the intent is clear.

### 3. GitHub UI Dismiss

Source-of-truth: GitHub's database, keyed by alert fingerprint.

Fork-unsafe: if someone forks the repo and rescans, the dismissal is lost.

## When to use which

| Situation | Preferred |
|---|---|
| FP we want to document the rationale for, in code | `# lgtm[py/<rule>]` with 3-field comment |
| TP that's architecturally unavoidable (e.g., bootstrap key plaintext) | `# lgtm[py/<rule>]` with 3-field comment |
| Truly one-off, no rationale to share | UI Dismiss |
| Bulk dismissal during incident triage | UI Dismiss (fastest) |

## The 3-field comment format (mandatory)

Every `# lgtm[]` we add must include these three things, either above or beside the suppression:

```python
# lgtm[py/<rule-id>]
#   Reason: <why this site is FP or unfixable>
#   Reviewer: <@user>  Date: <YYYY-MM-DD>
#   Re-audit if: <condition that, when changed, invalidates this suppression>
target_line  # lgtm[py/<rule-id>]
```

Why **Re-audit if**: future code changes can flip a FP into a TP (e.g., someone might refactor `login.py` to put plaintext in the cookie — the `# lgtm[]` would silently mask a real new vulnerability). The "Re-audit if" line tells the next reader what to watch for.

See `assets/lgtm-comment-template.py` for a copy-paste-ready block.

## SECURITY_SUPPRESSIONS.md (repo-root index)

To make suppressions grep-able and reviewable in one place, maintain a Markdown index at the repo root:

| File:Line | Rule | Reason | Reviewer | Re-audit if |
|---|---|---|---|---|
| `src/.../foo.py:42` | `py/clear-text-storage` | FP — value is Fernet ciphertext | @Tcweeei | 2026-05-18 | cookie source != user.store_api_key |

Template: `assets/SECURITY_SUPPRESSIONS-template.md`. Add a row whenever a new `# lgtm[]` is committed.

## Audit cadence

Quarterly:

```bash
grep -rn 'lgtm\[' src/ > /tmp/current.txt
# compare against SECURITY_SUPPRESSIONS.md (must be 1:1)
# read each "Re-audit if" line and decide if still applies
```

If a "Re-audit if" condition is no longer true, the suppression must be re-evaluated — either remove (and let the alert reappear so a real fix is filed) or rewrite the rationale.

## CI lint (optional, recommended)

Surface new suppressions to reviewers automatically:

```yaml
- name: Detect new lgtm suppressions in PR
  run: |
    if git diff origin/${{ github.base_ref }}...HEAD -- '*.py' | grep -E '^\+.*lgtm\['; then
      echo "::warning::This PR adds CodeQL suppression(s) — confirm Reason / Re-audit if in PR body"
    fi
```

This makes silent FP-creep harder. Not currently installed in `.github/workflows/`; consider proposing in a future PR if the suppression count exceeds ~10.
