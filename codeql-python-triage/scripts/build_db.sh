#!/usr/bin/env bash
# Build a CodeQL database for Python.
#
# Usage: bash build_db.sh [source-root] [db-path]
#        bash build_db.sh                            # source=. db=/tmp/codeql-db-py
#        bash build_db.sh . /tmp/my-db
#
# Always overwrites the target DB path.

. "$(dirname "$0")/lib/common.sh"

src="${1:-.}"
db="${2:-$DEFAULT_DB}"

[[ -d "$src" ]] || die "source root not a directory: $src"
require_cmd codeql

info "removing old DB at $db (if any)"
rm -rf "$db"

info "creating DB at $db from $src"
codeql database create "$db" \
  --language=python \
  --source-root="$src" \
  --build-mode=none \
  --overwrite

info "DB ready: $db"
echo "$db"
