---
name: deepflow-backend-dev
description: Use when needing to execute, verify, or debug Python code under backend/src/ in the DeepFlow repository via the devspace backend pod. Use when running Django management commands, shell scripts, or ad-hoc Python inside the dev cluster.
---

# deepflow-backend-dev

## Overview

Execute and verify backend code through the devspace backend pod instead of running locally. The backend pod has the correct environment, dependencies, and database access.

## When to Use

- Running or verifying Python code under `backend/src/`
- Executing Django management commands (`migrate`, `shell`, `check`, etc.)
- Debugging backend logic interactively with Django context
- Verifying import paths, model definitions, or ORM queries

**When NOT to use:**
- Running backend **tests** → use `deepflow-backend-test` skill instead
- Building or pushing images → use `kubeops.sh build`

## Workflow

### 1. Verify the backend is running in devspace dev mode

A regular backend pod does **NOT** have local file sync — code edits (especially from a git worktree) will not be reflected. You must confirm the pod has been replaced by `devspace dev`.

```bash
kubectl -n deepflow-system get pods -l app.deepflow.io/module=backend,devspace.sh/replaced=true --no-headers
```

- Pod listed and `Running` → proceed to step 2.
- No result → the backend pod is either missing or is a **regular (non-devspace) pod** without file sync. **Stop and tell the user** to start dev mode first: `bash kubeops.sh dev` from the repo root.

### 2. Get the pod name

```bash
POD=$(kubectl -n deepflow-system get pods -l app.deepflow.io/module=backend,devspace.sh/replaced=true -o jsonpath='{.items[0].metadata.name}')
```

### 3. Execute commands inside the pod

The working directory inside the pod is `/app` which maps to the local `./backend/` directory. Source code is under `/app/src/`.

**Run a one-off command:**

```bash
kubectl -n deepflow-system exec -it $POD -- bash -c '<command>'
```

**Run a Django management command:**

```bash
kubectl -n deepflow-system exec -it $POD -- bash -c 'cd src && python manage.py <command>'
```

**Run ad-hoc Python with Django context:**

```bash
kubectl -n deepflow-system exec -it $POD -- bash -c 'cd src && python manage.py shell -c "
from some_app.models import SomeModel
print(SomeModel.objects.count())
"'
```

**Interactive Django shell (for multi-step exploration):**

```bash
kubectl -n deepflow-system exec -it $POD -- bash -c 'cd src && python manage.py shell'
```

## Quick Reference

| Task | Command inside pod |
|---|---|
| Check imports | `cd src && python -c "from module import X; print(X)"` |
| Django check | `cd src && python manage.py check` |
| Run migrations | `cd src && python manage.py migrate` |
| Django shell one-liner | `cd src && python manage.py shell -c "<code>"` |
| Inspect settings | `cd src && python manage.py diffsettings` |
| List URLs | `cd src && python manage.py show_urls` |
| Run arbitrary script | `cd src && python <script.py>` |

## Common Mistakes

- **Executing on a regular (non-devspace) pod**: Without `devspace.sh/replaced=true` label, the pod has no file sync — local changes are invisible. Always verify the label before exec.
- **Forgetting `cd src`**: The pod lands in `/app` (= `backend/`), but Django code expects `/app/src/` as the working directory.
- **Running locally instead of in pod**: Local machine may lack DB access, env vars, or Python dependencies. Always use the pod.
- **Using pytest directly**: For tests, use the `deepflow-backend-test` skill which handles test pod setup and cleanup.

## Notes

- The pod's file system is synced from local `./backend` via devspace. Edits you make locally appear in the pod automatically (with container restart on upload).
- Namespace is `deepflow-system` by default.
- Label selector for the backend pod: `app.deepflow.io/module=backend`.
