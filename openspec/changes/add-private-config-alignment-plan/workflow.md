# Config Alignment Workflow

Use this workflow to compare local `~/.config` drift against repo-managed `home/private_dot_config` and generate a reviewable plan.

## 1) Generate delta and plan (read-only)

```bash
./scripts/run_config_alignment.sh
```

The wrapper includes baseline ignore/sensitive/machine-specific filters plus omit rules for tealdeer cache and zed `.tmp` files. Override or add filters by passing extra flags.

Minimal direct invocation:

```bash
python3 scripts/config_alignment.py \
  --repo-root . \
  --output-dir tmp/config-alignment \
  --omit-from-report 'tealdeer/cache/**' \
  --omit-from-report 'zed/**/*.tmp'
```

Artifacts:
- `tmp/config-alignment/delta-report.json`
- `tmp/config-alignment/alignment-plan.md`

The script classifies each path as one of:
- `local-only`
- `repo-only`
- `different`
- `matched`
- `template-driven`

Paths matching ignore filters are excluded from report entries (tracked only via `ignored_count` in `delta-report.json`).

`template-driven` marks chezmoi `.tmpl` sources that need rendering-aware review before any sync decision.

`--omit-from-report` excludes matched paths entirely from `delta-report.json` and `alignment-plan.md`.

## 2) Review recommendations

Open `tmp/config-alignment/alignment-plan.md` and review one row at a time:
- `adopt-to-repo`: candidate to copy from local into repo
- `keep-local`: preserve local-only data or sensitive/machine-specific paths
- `remove-local-drift`: align local state back to repo-managed config

Safety defaults:
- Sensitive and machine-specific paths default to `keep-local`
- Ignore filters suppress noisy artifacts (cache, temp, lock files) by excluding them from the report

## 3) Apply approved updates safely

After manual edits for approved items, run preview commands before final apply:

```bash
chezmoi diff
chezmoi apply --dry-run
```

Only if the preview is expected:

```bash
chezmoi apply
```

Planning mode does not mutate `~/.config` automatically.
