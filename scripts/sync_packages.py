#!/usr/bin/env python3
"""Sync changed packages to the AgentKit D1 index.

Called by GitHub Actions after push to main.
Reads changed.txt (list of changed file paths), finds affected plugin.json,
and POSTs each to the Worker /sync endpoint.
"""

import json
import os
import sys
import urllib.request
from pathlib import Path

REPO_TYPE_MAP = {
    "agentkit-skills": "skill",
    "agentkit-prompts": "prompt",
    "agentkit-mcp": "mcp",
    "agentkit-plugins": "plugin",
}


def sync_package(
    worker_url: str, secret: str, pkg_type: str, repo: str, name: str, manifest: dict
) -> None:
    payload = json.dumps(
        {"type": pkg_type, "name": name, "repo": repo, "manifest": manifest}
    ).encode()
    req = urllib.request.Request(
        f"{worker_url}/sync",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {secret}",
            "User-Agent": "agentkit-sync/1.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        if resp.status != 200:
            raise RuntimeError(f"HTTP {resp.status}")


def main() -> None:
    worker_url = os.environ["WORKER_URL"].rstrip("/")
    secret = os.environ["SYNC_SECRET"]
    # GITHUB_REPOSITORY is "knew-inventai/agentkit-skills" → repo name is last part
    repo_name = os.environ.get("GITHUB_REPOSITORY", "").split("/")[-1]
    pkg_type = REPO_TYPE_MAP.get(repo_name, "plugin")

    changed_file = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if changed_file and changed_file.exists():
        lines = [l.strip() for l in changed_file.read_text().splitlines() if l.strip()]
        paths = [Path(l) for l in lines]
    else:
        paths = []

    # Collect affected package dirs
    pkg_names: set[str] = set()
    for p in paths:
        if len(p.parts) >= 1:
            pkg_names.add(p.parts[0])

    if not pkg_names:
        # Fallback: sync all packages (e.g. first commit with no parent)
        pkg_names = {p.parent.name for p in Path(".").glob("*/plugin.json")}

    errors = []
    for name in sorted(pkg_names):
        if name.startswith(".") or name.startswith("_") or name == "scripts":
            continue
        manifest_path = Path(name) / "plugin.json"
        if not manifest_path.exists():
            print(f"SKIP {name}: plugin.json not found")
            continue
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            sync_package(worker_url, secret, pkg_type, repo_name, name, manifest)
            print(f"OK {name}")
        except Exception as e:
            print(f"ERROR {name}: {e}", file=sys.stderr)
            errors.append(name)

    if errors:
        print(f"\nFailed packages: {errors}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
