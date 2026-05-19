#!/usr/bin/env bash
# Check installed CodeQL pack versions and warn when they may have drifted from
# the assumptions baked into references/known-rules-ledger.md.
#
# Usage: bash check_pack_version.sh

. "$(dirname "$0")/lib/common.sh"

require_cmd codeql

echo "## Local CodeQL pack versions"
echo

cli_ver="$(codeql version --format=terse 2>/dev/null | head -1)"
echo "**CLI**: \`$cli_ver\`"
echo

python_all_dir="$(latest_python_all_dir)"
python_queries_dir="$(latest_python_queries_dir)"
python_all_ver="$(basename "$python_all_dir")"
python_queries_ver="$(basename "$python_queries_dir")"

echo "| Pack | Local version |"
echo "|---|---|"
echo "| codeql/python-all | \`${python_all_ver:-MISSING}\` |"
echo "| codeql/python-queries | \`${python_queries_ver:-MISSING}\` |"
echo

# Optional drift check against ledger
ledger="$SKILL_DIR/references/known-rules-ledger.md"
if [[ -f "$ledger" ]]; then
  recorded_all="$(grep -oE 'python-all/[0-9.]+' "$ledger" 2>/dev/null | sort -u | head -1 | cut -d/ -f2)"
  recorded_queries="$(grep -oE 'python-queries/[0-9.]+' "$ledger" 2>/dev/null | sort -u | head -1 | cut -d/ -f2)"

  drift=0
  if [[ -n "$recorded_all" && "$recorded_all" != "$python_all_ver" ]]; then
    warn "python-all drift: ledger recorded $recorded_all, local is $python_all_ver"
    drift=1
  fi
  if [[ -n "$recorded_queries" && "$recorded_queries" != "$python_queries_ver" ]]; then
    warn "python-queries drift: ledger recorded $recorded_queries, local is $python_queries_ver"
    drift=1
  fi

  if (( drift )); then
    echo
    echo "**ACTION**: re-run \`audit_query.sh\` for each rule in the ledger and update Levels + date."
  else
    info "no drift detected (ledger and local packs in sync)"
  fi
fi
