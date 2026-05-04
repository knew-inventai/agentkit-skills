---
name: deepflow-backend-test
description: Use when running tests for backend/src in the DeepFlow repository. Uses kubeops.sh instead of invoking pytest directly.
version: 1.0.0
author: knew@chtinventai.com
license: MIT
allowed-tools: Bash, AskUser
---

# deepflow-backend-test

## Overview

This skill tells the agent how to run tests for code under
`/home/knew/workspace/deepflow/backend/src/`.

When backend testing is needed, use
`/home/knew/workspace/deepflow/kubeops.sh` from the repository root.
Do not run `pytest` directly inside `backend/src`.

## Requirements

1. Run commands from `/home/knew/workspace/deepflow`.
2. Use `./kubeops.sh test` for backend test execution.
3. If the environment requires elevated privileges, use
   `sudo ./kubeops.sh test` instead.
4. For targeted backend tests, pass a single `<option>` argument to `test`.
5. If `<option>` contains `/`, treat it as a pytest path or node id and pass it
   through directly.
6. If `<option>` does not contain `/`, treat it as a pytest `-k` expression.
7. If it is unclear whether `sudo` is required, ask the user instead of
   guessing.

## Inputs

- Optional `<option>` argument for targeted execution. Supported patterns:
  - a pytest path, directory, file path, or node id containing `/`
  - a test class name
  - a test function name
  - a pytest `-k` expression when no `/` is present
- Whether `sudo` is required in the current environment.

## Workflow

### 1. Change to the repository root

```bash
cd /home/knew/workspace/deepflow
```

### 2. Run backend tests through kubeops.sh

```bash
# Run all tests:
./kubeops.sh test

# Run an entire test directory or file (contains `/`, so it is passed directly):
./kubeops.sh test src/ams/tests
./kubeops.sh test src/ams/tests/test_api_payloads.py
./kubeops.sh test src/ams/tests/test_api_payloads.py::test_some_case
./kubeops.sh test src/ams/tests/test_api_payloads.py::TestPayloads::test_some_case

# Run a specific backend test target by name (no `/`, so it uses pytest -k):
./kubeops.sh test TestWorkspaceModel
./kubeops.sh test test_product_creation_validation

# Run a filtered expression (quoted because it contains spaces):
./kubeops.sh test "TestLibsUtil and test_check_nvidia_resource_name_is_valid"

# If permissions or environment setup require it:
sudo ./kubeops.sh test
sudo ./kubeops.sh test src/ams/tests
sudo ./kubeops.sh test TestWorkspaceModel
```

## Output

The agent should report:
- which `kubeops.sh test` command was used
- whether the full test suite or a targeted selector was used
- the resulting success or failure

## Notes

`kubeops.sh test` sets up the test environment and runs pytest in the expected
containerized workflow for this repository.

`kubeops.sh test <option>` supports two selector modes:
- If `<option>` contains `/`, the script runs `pytest -v "<option>"`.
- Otherwise, the script runs `pytest -v -k "<option>"`.

Prefer `./kubeops.sh test` first when possible. Use `sudo ./kubeops.sh test`
when the local environment requires elevated privileges.

Prefer the narrowest selector that matches the need:
- use a path or node id when you know the exact file or test
- use a class or function name when a pytest `-k` selector is sufficient
- use a boolean expression only when a simple name would be ambiguous

If the requested change only affects `backend/src`, this skill still applies.
