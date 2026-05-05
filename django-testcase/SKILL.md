---
name: "django-testcase"
description: "Expert patterns for Django testing: minimal necessary tests, parameterized testing, factory_boy integration, and synchronized documentation."
version: 1.0.0
author: knew@chtinventai.com
license: MIT
tags: [django, python, orm, factory-boy, drf, pytest]
testingTypes: [unit, integration]
frameworks: [django, pytest, pytest-django]
languages: [python]
domains: [web, api, backend]
agents: [claude-code, cursor, github-copilot, windsurf, codex, aider, continue, cline, zed, bolt]
---

# Django Testing Patterns

You are an expert QA engineer specializing in Django testing. Your goal is to create a robust, maintainable, and efficient test suite that verifies business logic without redundant overhead.

## Core Principles

1. **Minimalism** — Write only the minimal necessary tests. Avoid testing Django's built-in field validation or framework internals.
2. **Quality Over Quantity** — Prioritize complex edge cases and custom business logic over high-level code coverage metrics.
3. **Synchronization** — Ensure Docstrings always reflect the current state of the test logic.
4. **Data-Driven** — Use parameterization to handle multiple scenarios within a single test logic flow.

## Implementation Guide

### Setup & Best Practices

- **Prefer Factories over Fixtures**: Use factory_boy for generating test data to avoid the brittleness of static JSON/YAML fixtures.
- **Parametrized Testing**: Use @pytest.mark.parametrize to reduce code duplication for similar test scenarios.
- **Docstring Requirement**: Every test case must have a brief Docstring.
    - **Format**: [Purpose] -> [Input] -> [Expected Result]
    - **Maintenance**: You MUST update the Docstring whenever the test logic is modified.
- **Database Isolation**: Use pytest.mark.django_db for standard tests and TransactionTestCase only when testing signals or atomic transactions.

### Test Execution Discovery

- Before proposing or running any test command, first check whether another
  installed skill is responsible for **test execution** in the current
  repository or environment.
- If such a skill exists, follow that skill for the execution command and
  runtime workflow. This skill is responsible for **test design and test case
  quality**, not for overriding repository-specific execution rules.
- If the execution skill supports a selector-style command such as
  `./kubeops.sh test <option>`, provide the most specific useful selector
  possible instead of defaulting to the full suite.
- Assume `<option>` may map either to pytest name filtering such as `pytest -k`
  or to a direct pytest path/node id, depending on the execution skill's
  contract.
- If no execution-oriented skill exists, ask the user how tests should be run
  before executing anything.
- Do **not** assume that direct `pytest`, `python -m pytest`, `manage.py test`,
  Docker Compose, or CI wrappers are the correct entrypoint unless another
  skill or the user has established that explicitly.

### Targeted Execution Compatibility

- Write test names that are stable, descriptive, and easy to target through
  selector-based execution workflows.
- Test class names should be specific, for example `TestWorkspaceModel` or
  `TestProjectResourceFlavorManagementViewset`.
- Test function names should clearly describe behavior, for example
  `test_product_creation_validation` or
  `test_check_nvidia_resource_name_is_valid`.
- When another skill supports targeted execution, prefer selectors in this
  order:
  1. a precise pytest path or node id, if the execution skill supports it
  2. test class name
  3. test function name
  4. a boolean selector expression combining names
- Example selectors for a workflow like `./kubeops.sh test <option>`:
  - `src/ams/tests`
  - `src/ams/tests/test_api_payloads.py`
  - `src/ams/tests/test_api_payloads.py::TestPayloads::test_some_case`
  - `TestWorkspaceModel`
  - `test_product_creation_validation`
  - `"TestLibsUtil and test_check_nvidia_resource_name_is_valid"`
- `@pytest.mark.parametrize` is fully compatible with this approach because the
  underlying test function name remains selectable. Parameterized cases should
  still use a precise and searchable base test name.
- `@pytest.mark` remains useful for categorization, but it should not replace
  descriptive class and function names when the execution workflow relies on a
  selector-style command such as pytest `-k` or pytest path/node-id selection.

### Regression Test Traceability

- When writing or updating a regression test, prefer custom pytest markers for
  issue traceability instead of storing issue metadata in the Docstring.
- First check whether the current context already provides an issue number, such
  as the user request, branch name, commit context, or another linked artifact.
- If no issue number is available from context, ask the user for the related
  issue number before finalizing the regression test.
- If no issue number exists, do not block development. Keep the regression test
  and apply `@pytest.mark.regression` without the issue marker.
- When an issue number is available, use both markers:
  - `@pytest.mark.regression`
  - `@pytest.mark.issue("<issue-number>")`
- Keep the Docstring focused on test purpose, input, and expected result. Do
  not mix tracking metadata into the Docstring.
- If the repository registers these markers in pytest configuration, use the
  registered names exactly instead of inventing new marker names.

### Common Patterns

#### 1. Model & Factory Pattern
(Focus: Custom logic and methods)

```python
import pytest
from .factories import UserFactory

@pytest.mark.django_db
def test_user_custom_display_name():
    """
    [Purpose] -> Verify the custom display_name method.
    [Input] -> User with first_name "John", last_name "Doe".
    [Expected Result] -> Returns "John Doe".
    """
    user = UserFactory(first_name="John", last_name="Doe")
    assert user.get_display_name() == "John Doe"
```

#### 2. Parameterized API Test (DRF)
(Focus: Validation logic and status codes)

```python
import pytest
from django.urls import reverse
from rest_framework import status

@pytest.mark.parametrize("price, expected_status", [
    (-10, status.HTTP_400_BAD_REQUEST),
    (100, status.HTTP_201_CREATED),
    (0, status.HTTP_400_BAD_REQUEST),
])
@pytest.mark.django_db
def test_product_creation_validation(api_client, price, expected_status):
    """
    [Purpose] -> Verify product creation status codes based on price.
    [Input] -> Different price values (negative, positive, zero).
    [Expected Result] -> Matches expected DRF status codes.
    """
    url = reverse('product-list')
    response = api_client.post(url, {'name': 'Test Product', 'price': price})
    assert response.status_code == expected_status
```

#### 3. Regression Test with Issue Marker
(Focus: regression traceability without polluting the Docstring)

```python
import pytest


@pytest.mark.regression
@pytest.mark.issue("1234")
@pytest.mark.django_db
def test_workspace_quota_regression():
    """
    [Purpose] -> Verify the workspace quota regression is fixed.
    [Input] -> Existing workspace with updated quota settings.
    [Expected Result] -> Quota is calculated correctly after the fix.
    """
    ...
```

### Anti-Patterns to Avoid

1. **Redundant Framework Testing**: Don't test if models.CharField(max_length=50) enforces 50 characters; Django's own suite covers this.
2. **Obsolete Docstrings**: Never leave a Docstring that describes logic no longer present in the code. Update them on every change.
3. **Hardcoded IDs**: Never assert against hardcoded primary keys (e.g., assert user.id == 1). Use attributes from the created object.
4. **Over-Mocking**: Avoid mocking the Django ORM; use a test database to ensure query correctness.
5. **Assuming Test Entrypoints**: Never assume the repository should be tested
   with raw `pytest` if a repository-specific execution workflow may exist.
6. **Unfilterable Test Naming**: Avoid vague names such as `TestModel`,
   `test_case_1`, or `test_basic_flow` when the repository may rely on
   selector-based execution like pytest `-k`.
7. **Tracking Metadata in Docstrings**: Do not store issue numbers or other
   regression tracking metadata inside the Docstring when custom pytest markers
   are available.

## Troubleshooting

1. **Database Access Denied**: Ensure the test is decorated with @pytest.mark.django_db.
2. **Factory Integrity Error**: Check if your factory_boy sequences are causing unique constraint collisions.
3. **Leaked State**: If tests pass individually but fail in a suite, check for modified settings or uncleaned cache.

## Integration with CI/CD

- Once the correct execution workflow is known, use the project's approved test
  entrypoint to identify slow-running tests.
- If the approved workflow is direct pytest execution, run
  `pytest --durations=10` to identify slow-running tests.
- Integrate pytest-cov but focus on "Uncovered Logic" rather than achieving 100%.
