#!/usr/bin/env bash
# Audit a CodeQL Python query's source to classify it Level 1 / 2 / 3.
#
# Usage: bash audit_query.sh py/<rule-id> [--write]
#        bash audit_query.sh py/path-injection
#        bash audit_query.sh py/clear-text-storage-sensitive-data --write
#
# Level 1: Customizations.qll has a concrete class consuming ModelsAsData::barrierNode
#          → external `barrierModel` YAML works.
# Level 2: only abstract Sanitizer class with no concrete subclass
#          → external sanitizers ignored; suppression / refactor / rename only.
# Level 3: relevant framework model in Stdlib.qll (or similar) ignores the natural
#          kwarg / API hint → even local code-level hints don't help.
#
# Without --write, prints findings. With --write, appends a verdict line to
# references/known-rules-ledger.md.

. "$(dirname "$0")/lib/common.sh"

rule="${1:-}"
write_flag="${2:-}"
[[ -z "$rule" ]] && die "usage: audit_query.sh py/<rule-id> [--write]"

require_cmd grep
require_cmd find

pack_dir="$(latest_python_all_dir)"
[[ -z "$pack_dir" ]] && die "codeql/python-all pack not found under $CODEQL_PACKAGES_ROOT"
queries_dir="$(latest_python_queries_dir)"
info "using python-all at: $pack_dir"
info "using python-queries at: $queries_dir"

# Strip the py/ prefix, convert to CamelCase chunks for QL search.
short="${rule#py/}"

echo
echo "## Audit: $rule"
echo

# Step 1: locate .ql file by @id annotation
ql_files=( $(grep -rlE "@id[[:space:]]+$rule\b" "$queries_dir" 2>/dev/null | grep '\.ql$' || true) )
if (( ${#ql_files[@]} == 0 )); then
  warn "no .ql file with '@id $rule' annotation found under $queries_dir"
else
  echo "**Query file(s)**:"
  for f in "${ql_files[@]}"; do echo "- \`${f#$queries_dir}\`"; done
fi
echo

# Step 2: locate Customizations.qll by parsing the .ql's imports
echo "**Searching Customizations.qll for sanitizer hookup...**"
echo
match_files=()
for ql in "${ql_files[@]}"; do
  # Extract names like CleartextStorageQuery or CleartextStorageCustomizations
  while read -r mod; do
    base="${mod%Query}"
    base="${base%Customizations}"
    candidate="$pack_dir/semmle/python/security/dataflow/${base}Customizations.qll"
    [[ -f "$candidate" ]] && match_files+=("$candidate")
  done < <(grep -oE "[A-Z][A-Za-z]+(Customizations|Query)" "$ql" | sort -u)
done

# Fallback: scan all Customizations.qll for hyphen-stripped rule name
if (( ${#match_files[@]} == 0 )); then
  custom_files=( $(find "$pack_dir/semmle/python/security/dataflow" -name "*Customizations.qll" 2>/dev/null) )
  short_nohyphen="$(echo "$short" | tr -d '-')"
  for cf in "${custom_files[@]}"; do
    if grep -qi "$short_nohyphen" "$cf" 2>/dev/null; then
      match_files+=("$cf")
    fi
  done
fi

# Deduplicate
match_files=( $(printf '%s\n' "${match_files[@]}" | sort -u) )

verdict="UNKNOWN"
verdict_evidence=""
if (( ${#match_files[@]} == 0 )); then
  echo "_No Customizations.qll matched heuristically — falling back to manual listing._"
  for cf in "${custom_files[@]}"; do echo "- \`${cf#$pack_dir/}\`"; done
else
  for cf in "${match_files[@]}"; do
    echo "### \`${cf#$pack_dir/}\`"
    echo
    echo '```ql'
    grep -nE "class (Sanitizer|SanitizerFromModel|ConstCompareBarrier|ModelInputBarrier)" "$cf" || true
    echo "..."
    # Find the abstract class declaration and any subclasses
    awk '/abstract class Sanitizer/,/^}/ {print NR": "$0}' "$cf" | head -20 || true
    echo '```'
    echo

    if grep -qE "class\s+SanitizerFromModel\s+extends\s+Sanitizer" "$cf"; then
      verdict="Level 1"
      verdict_evidence="$cf has class SanitizerFromModel extends Sanitizer"
    elif grep -qE "abstract\s+class\s+Sanitizer" "$cf" \
         && ! grep -qE "class\s+\w+\s+extends\s+Sanitizer\b" "$cf"; then
      verdict="Level 2"
      verdict_evidence="$cf has abstract Sanitizer but no concrete subclass"
    fi
  done
fi

echo
echo "## Verdict: **$verdict**"
echo
[[ -n "$verdict_evidence" ]] && echo "Evidence: $verdict_evidence"
echo

if [[ "$write_flag" == "--write" ]]; then
  ledger="$SKILL_DIR/references/known-rules-ledger.md"
  date="$(date +%Y-%m-%d)"
  line="| \`$rule\` | $verdict | (recorded by audit_query.sh) | $date |"
  echo "$line" >> "$ledger"
  info "appended to $ledger:"
  echo "$line" >&2
fi
