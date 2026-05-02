#!/usr/bin/env python3
"""Validate AgentKit package manifest and structure.

pre-commit passes all staged file paths as argv[1:].
This script resolves their package directories and validates each.
"""

import json
import re
import sys
from pathlib import Path

REQUIRED_FIELDS = ["name", "version", "description", "author", "license", "_agentkit"]
VALID_TYPES = {"skill", "prompt", "mcp", "plugin"}
KEBAB_RE = re.compile(r"^[a-z][a-z0-9-]+$")
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$")
# Body file required per type; plugin uses plugin.json itself (no separate body)
BODY_FILE: dict[str, str] = {
    "skill": "SKILL.md",
    "prompt": "PROMPT.md",
    "mcp": "mcp-config.json",
}


def validate(pkg_dir: Path) -> list[str]:
    errors: list[str] = []
    manifest_path = pkg_dir / "plugin.json"

    if not manifest_path.exists():
        return [f"{pkg_dir}: plugin.json not found"]

    try:
        m = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return [f"{manifest_path}: invalid JSON — {e}"]

    # Required fields
    for field in REQUIRED_FIELDS:
        if field not in m:
            errors.append(f"{manifest_path}: missing required field '{field}'")
    if errors:
        return errors  # skip further checks if structure is broken

    # name: kebab-case and matches directory
    name = m["name"]
    if not KEBAB_RE.match(name):
        errors.append(f"{manifest_path}: 'name' must be kebab-case, got '{name}'")
    if name != pkg_dir.name:
        errors.append(
            f"{manifest_path}: 'name' ({name!r}) must match directory name ({pkg_dir.name!r})"
        )

    # version: SemVer
    if not SEMVER_RE.match(str(m["version"])):
        errors.append(f"{manifest_path}: 'version' must be SemVer x.y.z, got '{m['version']}'")

    # author.name required
    author = m["author"]
    if not isinstance(author, dict) or not author.get("name"):
        errors.append(f"{manifest_path}: 'author' must be an object with at least 'name'")

    # _agentkit.type
    agentkit = m.get("_agentkit", {})
    if not isinstance(agentkit, dict):
        errors.append(f"{manifest_path}: '_agentkit' must be an object")
        return errors
    pkg_type = agentkit.get("type", "")
    if pkg_type not in VALID_TYPES:
        errors.append(
            f"{manifest_path}: '_agentkit.type' must be one of "
            f"{sorted(VALID_TYPES)}, got '{pkg_type}'"
        )
    elif pkg_type in BODY_FILE:
        body = pkg_dir / BODY_FILE[pkg_type]
        if not body.exists():
            errors.append(
                f"{pkg_dir}: missing body file '{BODY_FILE[pkg_type]}' for type '{pkg_type}'"
            )

    # _agentkit.tags: non-empty list
    tags = agentkit.get("tags", [])
    if not isinstance(tags, list) or len(tags) == 0:
        errors.append(f"{manifest_path}: '_agentkit.tags' must be a non-empty array")

    return errors


def main() -> None:
    changed = [Path(f) for f in sys.argv[1:]]

    # Collect unique top-level package directories
    pkg_dirs: set[str] = set()
    for f in changed:
        if len(f.parts) >= 2:
            pkg_dirs.add(f.parts[0])

    all_errors: list[str] = []
    for d in sorted(pkg_dirs):
        all_errors.extend(validate(Path(d)))

    if all_errors:
        print("AgentKit validation failed:\n")
        for err in all_errors:
            print(f"  ✗ {err}")
        sys.exit(1)


if __name__ == "__main__":
    main()
