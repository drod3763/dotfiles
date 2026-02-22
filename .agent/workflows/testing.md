---
description: Run and extend shell script tests with rendered-template checks.
---

**Goal**
- Validate shell-script changes safely by testing rendered chezmoi templates and mocked CLI behavior.

**When to Use**
- Any change to `home/.chezmoiscripts/**/*.tmpl`.
- Any change to shared includes in `home/.chezmoitemplates/**/*.tmpl`.
- Any change to test runner/hook scripts under `scripts/`.

**Steps**
1. Run rendered-template lint checks:
   - `scripts/check_rendered_shell_templates.sh`
2. Run Bats test suite:
   - `scripts/run_bats_tests.sh`
3. Keep test files mirrored to script paths (examples):
   - `tests/bats/install.sh.bats`
   - `tests/bats/scripts/check_rendered_shell_templates.bats`
   - `tests/bats/home/.chezmoiscripts/macOS/run_onchange_before_install-packages.bats`
   - `tests/bats/home/.chezmoiscripts/macOS/run_before_90_bootstrap-age-identities.bats`
4. Keep test names in format:
   - `GIVEN ... EXPECT ...`
5. Mock external CLIs (do not call real services in tests):
   - Stub tools like `brew`, `sudo`, `chezmoi`, `op`, `age`, `jq` via a temp `PATH`.

**Guidelines**
- Prefer logic assertions over output snapshotting.
- Test both success and failure paths.
- Cover profile variants where relevant (`personal`, `non-personal`, `transient`) via `chezmoi execute-template --override-data-file`.

**Done Criteria**
- Rendered template lint passes.
- Bats suite passes.
- New behavior has at least one focused `GIVEN ... EXPECT ...` test.
