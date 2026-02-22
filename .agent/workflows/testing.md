---
description: Run and extend shell script tests with rendered-template checks.
---

**Guardrails**
- Keep test files mirrored to script paths (for example `tests/bats/install.sh.bats`, `tests/bats/scripts/check_rendered_shell_templates.bats`, and `tests/bats/home/.chezmoiscripts/...`).
- Name tests using `GIVEN ... EXPECT ...` format.
- Mock external CLIs (for example `brew`, `sudo`, `chezmoi`, `op`, `age`, `jq`) via a temp `PATH`; do not call real services.
- For hardcoded system paths (for example `/Applications`), use test-local rewrites instead of touching real system paths.

**When To Use**
- Any change to `home/.chezmoiscripts/**/*.tmpl`.
- Any change to shared includes in `home/.chezmoitemplates/**/*.tmpl`.
- Any change to test runner/hook scripts under `scripts/`.

**Steps**
1. Run rendered-template lint checks with `scripts/check_rendered_shell_templates.sh`.
2. Run Bats tests with `scripts/run_bats_tests.sh`.
3. Add or update tests for changed behavior, including success and failure paths.
4. Expand coverage for practical edge branches (dependency-missing paths, retry/limit edges, fallback branches, and explicit failure exits from `set -e`).
5. Re-run `scripts/run_bats_tests.sh` after each batch and stop only when no practical untested edge paths remain.

**Guidelines**
- Prefer logic assertions over output snapshotting.
- Cover profile variants where relevant (`personal`, `non-personal`, `transient`) via `chezmoi execute-template --override-data-file`.

**Done Criteria**
- Rendered template lint passes.
- Bats suite passes.
- New behavior has at least one focused `GIVEN ... EXPECT ...` test.
- Coverage review finds no untested practical edge paths (dependency missing, retry/limit edges, failure exits, fallback branches).

**Reference**
- Execute all Bats tests recursively via `scripts/run_bats_tests.sh` (which runs `bats -r tests/bats`).
