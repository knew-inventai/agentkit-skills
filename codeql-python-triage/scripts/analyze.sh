#!/usr/bin/env bash
# Run CodeQL analysis with the right packs/flags for this repo's setup.
#
# Usage: bash analyze.sh <db-path> <query-spec> [extra codeql args...]
#        bash analyze.sh /tmp/codeql-db-py codeql/python-queries:codeql-suites/python-code-scanning.qls
#        bash analyze.sh /tmp/codeql-db-py codeql/python-queries:Security/CWE-327/WeakSensitiveDataHashing.ql
#
# Outputs SARIF to /tmp/codeql-result-<ts>.sarif and prints the path.

. "$(dirname "$0")/lib/common.sh"

db="${1:-$DEFAULT_DB}"
spec="${2:-$DEFAULT_SUITE}"
shift || true
shift || true

[[ -d "$db" ]] || die "database not found at $db. Run build_db.sh first."

require_cmd codeql

ts="$(date +%s)"
out="/tmp/codeql-result-${ts}.sarif"

# Auto-detect a repo-local data-extension pack by parsing qlpack.yml
extra_args=()
qlpack="$PWD/.github/codeql/qlpack.yml"
if [[ -f "$qlpack" ]]; then
  extra_args+=(--additional-packs="$PWD/.github/codeql")
  pack_name="$(awk '/^name:/ {sub(/^name:[[:space:]]*/, ""); print; exit}' "$qlpack" 2>/dev/null)"
  if [[ -n "$pack_name" ]]; then
    extra_args+=(--model-packs="$pack_name")
    info "using repo-local model pack: $pack_name (from $qlpack)"
  else
    warn "found .github/codeql/qlpack.yml but could not parse 'name:'; --model-packs not added"
  fi
fi

info "analyzing $db against $spec"
codeql database analyze "$db" "$spec" \
  --format=sarif-latest --output="$out" --rerun \
  "${extra_args[@]}" "$@"

info "results: $out"
echo "$out"
