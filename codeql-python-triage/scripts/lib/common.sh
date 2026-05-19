#!/usr/bin/env bash
# Shared helpers and constants for codeql-python-triage scripts.
# Source this file: . "$(dirname "$0")/lib/common.sh"

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SKILL_DIR

DEFAULT_DB="${CODEQL_DB:-/tmp/codeql-db-py}"
DEFAULT_SUITE="codeql/python-queries:codeql-suites/python-code-scanning.qls"
CODEQL_PACKAGES_ROOT="${CODEQL_PACKAGES_ROOT:-$HOME/.codeql/packages}"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "[$(date +%H:%M:%S)] $*" >&2; }
warn() { echo "WARN: $*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

latest_python_all_dir() {
  # Print the highest-versioned codeql/python-all pack directory.
  ls -d "$CODEQL_PACKAGES_ROOT/codeql/python-all/"*/ 2>/dev/null \
    | sort -V | tail -n1
}

latest_python_queries_dir() {
  ls -d "$CODEQL_PACKAGES_ROOT/codeql/python-queries/"*/ 2>/dev/null \
    | sort -V | tail -n1
}
