# Rule Levels — CodeQL Python sanitizer support taxonomy

This is the deep classification used by `scripts/audit_query.sh`. Each Level is a function of how the query's `Customizations.qll` exposes its `Sanitizer` class, **not** of how severe the alerts are.

The CodeQL packs this taxonomy was built against:

- `codeql/python-all` 7.1.0
- `codeql/python-queries` 1.8.2
- CodeQL CLI 2.25.4

If `check_pack_version.sh` reports drift, re-audit before trusting these.

---

## Level 1 — query accepts external `barrierModel` YAML

**Signature in `Customizations.qll`**:

```ql
abstract class Sanitizer extends DataFlow::Node { }

class SanitizerFromModel extends Sanitizer {
  SanitizerFromModel() { ModelOutput::barrierNode(this, "<kind>") }
}
```

The presence of `class SanitizerFromModel extends Sanitizer` (or an equivalent class that calls into `ModelOutput::barrierNode` / `ModelInput::getABarrierNode`) is the marker. The `"<kind>"` string is what your YAML entry's last column must match (e.g., `"path-injection"`, `"command-injection"`).

**Examples**:

| Rule | `Customizations.qll` | Barrier kind |
|---|---|---|
| `py/path-injection` | `PathInjectionCustomizations.qll` line ~105 | `"path-injection"` |
| `py/command-injection` (a.k.a. `py/command-line-injection`) | `CommandInjectionCustomizations.qll` | `"command-injection"` |
| `py/unsafe-deserialization` | `UnsafeDeserializationCustomizations.qll` | `"unsafe-deserialization"` |

**Caveat**: even on Level 1 queries, the validator's *internal* code path (e.g., the `Path.resolve()` call inside a `resolve_under` helper) still gets flagged — CodeQL can't tell the helper from arbitrary user code. The `barrierModel` only blocks the helper's *return value* from being flagged at downstream callers. The validator's own internals will keep showing up in the alert list; treat those as inherent FPs (UI dismiss or `# lgtm[]`).

---

## Level 2 — abstract Sanitizer with no concrete subclass

**Signature**:

```ql
abstract class Sanitizer extends DataFlow::Node { }
// ... no subclass anywhere in this file or the entire pack
```

The class exists but nothing populates it. Adding `barrierModel` YAML for these rules is **silently ignored** — there's nothing on the QL side to consume `ModelOutput::barrierNode`. Worse, the `Customizations.qll` typically doesn't import any crypto / encoding / encryption module, so **wrapping the data in Fernet, sha256, base64, etc., is invisible to the query**.

**Examples**:

| Rule | `Customizations.qll` | Why level 2 |
|---|---|---|
| `py/clear-text-storage-sensitive-data` | `CleartextStorageCustomizations.qll` | abstract Sanitizer line 36; no subclass; no crypto imports — verified on 2026-05-18 |
| `py/weak-sensitive-data-hashing` (two sub-modules: NormalHashFunction + ComputationallyExpensiveHashFunction) | `WeakSensitiveDataHashingCustomizations.qll` | abstract Sanitizer at both line 49 and 118; zero subclasses — verified on 2026-05-18 |
| `py/cleartext-logging` | `CleartextLoggingCustomizations.qll` | suspected; not yet audited |

**What works for Level 2**:

1. **Inline suppression**: `# lgtm[py/<rule>]` end-of-line. CodeQL's `AlertSuppression.ql` handles this — but you must verify by running the **full** `codeql-suites/python-code-scanning.qls`, not a single `.ql`. See `references/codeql-cli.md`.
2. **Rename the source variable**. Sources are heuristic-based (variable names containing `password` / `api_key` / `secret` / `token` etc., matched via `SensitiveDataSource`'s `sensitiveString` regex). Rename and the heuristic stops triggering.
3. **Remove the data flow**: don't store the value anywhere CodeQL sees as a sink. For `clear-text-storage`, the sinks are `FileSystemWriteAccess.getADataNode()` and `Http::Server::CookieWrite.getValueArg()` — refactor to use session ids, server-side storage, etc.

**What doesn't work**:

- Wrapping in `Fernet.encrypt(...)` — query has no crypto recognition
- Wrapping in `hashlib.sha256(...)` — same
- `barrierModel` YAML — no consumer class
- Custom regex / allowlist sanitizers — same

---

## Level 3 — framework model in `Stdlib.qll` ignores the natural kwarg / hint

This is a subset of Level 2 with an extra wrinkle: the query *could* be made to accept a sanitization hint at the framework-model level (in `Stdlib.qll` or similar), but the existing model **doesn't read** the hint Python provides.

**Canonical example**: `py/weak-sensitive-data-hashing`.

Python 3.9 added `hashlib.sha256(data, usedforsecurity=False)` as the standard way to say "this hash is not used for security." The `Stdlib.qll`'s `HashlibDataPassedToHashClass` class:

```ql
class HashlibDataPassedToHashClass extends HashlibGenericHashOperation {
  HashlibDataPassedToHashClass() {
    this = hashClass.getACall() and
    exists(
      [
        this.(DataFlow::CallCfgNode).getArg(0),
        this.(DataFlow::CallCfgNode).getArgByName("string")
      ]
    )
  }
  // ...
}
```

— only inspects positional arg 0 and the `string=` keyword arg. **It never checks `usedforsecurity`**. So writing `hashlib.sha256(value, usedforsecurity=False)` produces zero CodeQL effect even though Python officially designates that kwarg as the sanitization hint.

**Implication**: Level 3 rules need either a CodeQL pack upgrade (when upstream eventually models the kwarg), a custom `.qll` override (high effort), or the same fixes as Level 2 (suppression / refactor / rename).

---

## Quick decision flow

```
Have a CodeQL alert?
│
├─ Phase 1: inventory.sh (group by rule, count)
│
└─ Phase 2: for each rule
   │
   ├─ Already in known-rules-ledger.md?
   │  └─ YES → use stored Level, skip to Phase 3
   │
   └─ NO → audit_query.sh py/<rule>
      │
      ├─ "Verdict: Level 1" → use barrierModel YAML
      ├─ "Verdict: Level 2" → use inline suppression (or rename / refactor)
      └─ "Verdict: Level 3" → use inline suppression (track pack upgrade in ledger)
```

---

## Pre-classified rules (snapshot 2026-05-18)

See `references/known-rules-ledger.md` for the live ledger. Snapshot here for quick lookup:

| Rule | Level | Evidence |
|---|---|---|
| `py/command-injection` | 1 | CommandInjectionCustomizations.qll has SanitizerFromModel |
| `py/path-injection` | 1 | PathInjectionCustomizations.qll line ~105: `class SanitizerFromModel` |
| `py/clear-text-storage-sensitive-data` | 2 | CleartextStorageCustomizations.qll: abstract only, 0 subclasses |
| `py/weak-sensitive-data-hashing` | 2 (effectively 3 due to Stdlib.qll) | WeakSensitiveDataHashingCustomizations.qll: abstract only; Stdlib.qll ignores `usedforsecurity` |
| `py/stack-trace-exposure` | TBD | StackTraceExposureCustomizations.qll — run audit_query.sh to confirm |
| `py/url-redirection` | TBD | Not yet audited. Commonly fixed via `urlparse` allowlist refactor rather than barrier YAML. |
| `py/overly-large-range` | TBD | Commonly fixed by replacing supplementary-plane regex with explicit codepoint-range list (not via barrier). |
