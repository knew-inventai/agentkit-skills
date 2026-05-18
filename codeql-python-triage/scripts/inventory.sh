#!/usr/bin/env bash
# Inventory open CodeQL alerts for a repo, grouped by rule.
#
# Usage: bash inventory.sh <owner>/<repo> [--state open|dismissed|fixed]
#        bash inventory.sh acme/example-project
#
# Outputs a Markdown table to stdout. Stores raw JSON at /tmp/codeql-inventory-<ts>.json
# for downstream scripts.

. "$(dirname "$0")/lib/common.sh"

repo="${1:-}"
state="${2:-open}"
[[ -z "$repo" ]] && die "usage: inventory.sh <owner>/<repo> [state]"

require_cmd gh
require_cmd jq

ts="$(date +%s)"
raw="/tmp/codeql-inventory-${ts}.json"
info "fetching alerts (state=${state}) from ${repo}"

gh api "repos/${repo}/code-scanning/alerts?state=${state}&per_page=100" --paginate \
  > "$raw" || die "gh api call failed; check 'gh auth status' and repo access"

count="$(jq 'length' "$raw")"
info "fetched ${count} alerts → ${raw}"

# Group by rule id
echo
echo "# CodeQL ${state} alerts in ${repo}"
echo
echo "| Severity | Rule | Count | Sample locations |"
echo "|---|---|---|---|"
jq -r '
  group_by(.rule.id)
  | sort_by(.[0].rule.severity, -length)
  | reverse
  | .[]
  | {
      rule: .[0].rule.id,
      severity: .[0].rule.severity,
      count: length,
      sample: ([.[] | "`\(.most_recent_instance.location.path):\(.most_recent_instance.location.start_line)`"][0:3] | join("<br>"))
    }
  | "| \(.severity) | `\(.rule)` | \(.count) | \(.sample) |"
' "$raw"

echo
echo "_raw: ${raw}_"
