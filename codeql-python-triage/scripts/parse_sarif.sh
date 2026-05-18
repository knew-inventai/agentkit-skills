#!/usr/bin/env bash
# Parse a CodeQL SARIF result file into a digestible summary.
#
# Usage: bash parse_sarif.sh <sarif-file> [rule-filter]
#        bash parse_sarif.sh /tmp/codeql-result-1234.sarif
#        bash parse_sarif.sh /tmp/codeql-result-1234.sarif py/path-injection
#
# Without rule-filter: prints count per rule.
# With rule-filter: prints each location for that rule.

. "$(dirname "$0")/lib/common.sh"

sarif="${1:-}"
filter="${2:-}"
[[ -z "$sarif" ]] && die "usage: parse_sarif.sh <sarif-file> [rule-filter]"
[[ -f "$sarif" ]] || die "file not found: $sarif"

require_cmd jq

if [[ -z "$filter" ]]; then
  echo "## All rules in $sarif"
  echo
  echo "| Rule | Count |"
  echo "|---|---|"
  jq -r '
    [.runs[].results[]?.ruleId]
    | group_by(.) | map({rule: .[0], count: length})
    | sort_by(-.count)
    | .[]
    | "| `\(.rule)` | \(.count) |"
  ' "$sarif"
else
  echo "## Locations for $filter"
  echo
  count=$(jq --arg r "$filter" '[.runs[].results[] | select(.ruleId == $r)] | length' "$sarif")
  echo "**Count: $count**"
  echo
  if (( count > 0 )); then
    echo "| File | Line | Message |"
    echo "|---|---|---|"
    jq -r --arg r "$filter" '
      .runs[].results[]
      | select(.ruleId == $r)
      | .locations[0].physicalLocation as $p
      | "| `\($p.artifactLocation.uri)` | \($p.region.startLine) | \(.message.text | gsub("[\n|]"; " ") | .[0:120]) |"
    ' "$sarif"
  fi
fi
