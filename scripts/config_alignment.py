#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from fnmatch import fnmatch
from pathlib import Path


CHEZMOI_PREFIXES = (
    "private_",
    "dot_",
    "executable_",
    "encrypted_",
    "empty_",
)

DEFAULT_IGNORE_PATTERNS = [
    "*/.DS_Store",
    "*/Caches/*",
    "*/Cache/*",
    "*/cache/*",
    "*/tmp/*",
    "*/temp/*",
    "*/logs/*",
    "*/log/*",
    "*.lock",
    "*/lock*",
    "*/socket*",
]

DEFAULT_SENSITIVE_PATTERNS = [
    "*secret*",
    "*token*",
    "*credential*",
    "*apikey*",
    "*auth*",
    "*key*",
    "*ssh*",
]

DEFAULT_MACHINE_SPECIFIC_PATTERNS = [
    "*/history*",
    "*/state*",
    "*/session*",
    "*/recent*",
    "*/machine-id",
    "*/uuid",
]


@dataclass
class RepoEntry:
    source_rel: str
    source_abs: Path
    target_rel: str
    is_template: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate delta and alignment plan for ~/.config vs home/private_dot_config"
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path.cwd(),
        help="Path to repository root (default: current directory)",
    )
    parser.add_argument(
        "--repo-config-subdir",
        default="home/private_dot_config",
        help="Repo path containing chezmoi-managed config files",
    )
    parser.add_argument(
        "--local-config",
        type=Path,
        default=Path.home() / ".config",
        help="Local config directory to compare",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("tmp/config-alignment"),
        help="Directory where delta-report.json and alignment-plan.md are written",
    )
    parser.add_argument(
        "--chezmoiignore",
        default="home/.chezmoiignore",
        help="Path to .chezmoiignore file relative to repo root",
    )
    parser.add_argument(
        "--chezmoiexternal",
        default="home/.chezmoiexternal.toml.tmpl",
        help="Path to .chezmoiexternal.toml(.tmpl) relative to repo root",
    )
    parser.add_argument(
        "--ignore",
        action="append",
        default=[],
        metavar="PATTERN",
        help="Extra fnmatch pattern to classify as ignored",
    )
    parser.add_argument(
        "--sensitive",
        action="append",
        default=[],
        metavar="PATTERN",
        help="Extra fnmatch pattern to treat as sensitive",
    )
    parser.add_argument(
        "--machine-specific",
        action="append",
        default=[],
        metavar="PATTERN",
        help="Extra fnmatch pattern to treat as machine-specific",
    )
    parser.add_argument(
        "--omit-from-report",
        action="append",
        default=[],
        metavar="PATTERN",
        help="Fnmatch pattern to exclude paths entirely from report entries",
    )
    return parser.parse_args()


def decode_segment(segment: str) -> str:
    value = segment
    changed = True
    while changed:
        changed = False
        for prefix in CHEZMOI_PREFIXES:
            if value.startswith(prefix):
                if prefix == "dot_":
                    value = "." + value[len(prefix) :]
                else:
                    value = value[len(prefix) :]
                changed = True
                break
    return value


def normalize_repo_rel_path(rel: Path) -> str:
    parts = list(rel.parts)
    if parts and parts[-1].endswith(".tmpl"):
        parts[-1] = parts[-1][:-5]
    mapped = [decode_segment(part) for part in parts]
    return Path(*mapped).as_posix()


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def hash_bytes(content: bytes) -> str:
    digest = hashlib.sha256()
    digest.update(content)
    return digest.hexdigest()


def render_template(
    repo_root: Path, template_path: Path
) -> tuple[bytes | None, str | None]:
    result = subprocess.run(
        [
            "chezmoi",
            "execute-template",
            "--file",
            "--source",
            str(repo_root),
            str(template_path),
        ],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", errors="replace").strip()
        if not stderr:
            stderr = (
                f"chezmoi execute-template failed with exit code {result.returncode}"
            )
        return None, stderr
    return result.stdout, None


def collect_repo_inventory(repo_config_dir: Path) -> dict[str, list[RepoEntry]]:
    inventory: dict[str, list[RepoEntry]] = {}
    for source in sorted(repo_config_dir.rglob("*")):
        if not source.is_file():
            continue
        rel = source.relative_to(repo_config_dir)
        target_rel = normalize_repo_rel_path(rel)
        entry = RepoEntry(
            source_rel=rel.as_posix(),
            source_abs=source,
            target_rel=target_rel,
            is_template=source.name.endswith(".tmpl"),
        )
        inventory.setdefault(target_rel, []).append(entry)
    return inventory


def collect_local_inventory(local_config_dir: Path) -> dict[str, Path]:
    inventory: dict[str, Path] = {}
    if not local_config_dir.exists():
        return inventory
    for path in sorted(local_config_dir.rglob("*")):
        if path.is_file():
            inventory[path.relative_to(local_config_dir).as_posix()] = path
    return inventory


def any_match(path: str, patterns: list[str]) -> bool:
    return any(fnmatch(path, pattern) for pattern in patterns)


def has_glob(pattern: str) -> bool:
    return any(token in pattern for token in "*?[")


def load_chezmoiignore_patterns(
    repo_root: Path, chezmoiignore_path: str
) -> tuple[list[str], str | None]:
    source_path = (repo_root / chezmoiignore_path).resolve()
    if not source_path.exists():
        return [], None

    rendered, render_error = render_template(
        repo_root=repo_root, template_path=source_path
    )
    if render_error is not None:
        return [], render_error
    if rendered is None:
        return [], "chezmoiignore rendered with empty output"

    expanded_patterns: list[str] = []
    seen: set[str] = set()
    for raw_line in rendered.decode("utf-8", errors="replace").splitlines():
        pattern = raw_line.strip()
        if not pattern or pattern.startswith("#"):
            continue

        candidates = [pattern]
        if pattern.endswith("/"):
            candidates.append(f"{pattern}**")
        elif not has_glob(pattern):
            candidates.append(f"{pattern}/**")

        for candidate in candidates:
            if candidate in seen:
                continue
            expanded_patterns.append(candidate)
            seen.add(candidate)

    return expanded_patterns, None


def any_match_chezmoiignore(config_rel_path: str, patterns: list[str]) -> bool:
    if not patterns:
        return False

    home_rel_path = f".config/{config_rel_path}"
    for pattern in patterns:
        if fnmatch(config_rel_path, pattern) or fnmatch(home_rel_path, pattern):
            return True
    return False


EXTERNAL_TABLE_PATTERN = re.compile(r"^\[\s*([\"'])(?P<path>.+?)(\1)\s*\]$")


def load_chezmoiexternal_patterns(
    repo_root: Path, chezmoiexternal_path: str
) -> tuple[list[str], str | None]:
    source_path = (repo_root / chezmoiexternal_path).resolve()
    if not source_path.exists():
        return [], None

    rendered, render_error = render_template(
        repo_root=repo_root, template_path=source_path
    )
    if render_error is not None:
        return [], render_error
    if rendered is None:
        return [], "chezmoiexternal rendered with empty output"

    patterns: list[str] = []
    seen: set[str] = set()
    for raw_line in rendered.decode("utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        match = EXTERNAL_TABLE_PATTERN.match(line)
        if match is None:
            continue

        raw_path = match.group("path").strip()
        if not raw_path:
            continue

        candidates = [raw_path]
        if raw_path.endswith("/"):
            candidates.append(f"{raw_path}**")

        for candidate in candidates:
            if candidate in seen:
                continue
            patterns.append(candidate)
            seen.add(candidate)

    return patterns, None


def recommendation_for(
    classification: str, sensitive: bool, machine_specific: bool
) -> tuple[str, str]:
    if sensitive or machine_specific:
        return (
            "keep-local",
            "Path matches sensitive or machine-specific filters; default to local retention.",
        )

    if classification == "local-only":
        return (
            "adopt-to-repo",
            "Local config exists without repo counterpart and appears safe to promote.",
        )
    if classification in ("repo-only", "different"):
        return (
            "remove-local-drift",
            "Repo is source of truth; align local path to managed state.",
        )
    if classification == "template-driven":
        return (
            "keep-local",
            "Template rendering failed; resolve render dependencies before syncing.",
        )
    return (
        "keep-local",
        "No synchronization action recommended.",
    )


def render_plan_markdown(
    rows: list[dict[str, object]],
    report_path: Path,
    local_config_dir: Path,
    repo_config_dir: Path,
) -> str:
    lines: list[str] = []
    lines.append("# Config Alignment Plan")
    lines.append("")
    lines.append(f"Generated: {datetime.now(timezone.utc).isoformat()}")
    lines.append(f"Local config root: `{local_config_dir}`")
    lines.append(f"Repo config root: `{repo_config_dir}`")
    lines.append(f"Delta report: `{report_path}`")
    lines.append("")
    lines.append("## Recommended Actions")
    lines.append("")
    lines.append("| Path | Classification | Recommendation | Rationale |")
    lines.append("|---|---|---|---|")
    for row in rows:
        if row["classification"] == "matched":
            continue
        target = row["target_path"]
        classification = row["classification"]
        recommendation = row["recommendation"]
        rationale = str(row["rationale"]).replace("|", "\\|")
        lines.append(
            f"| `{target}` | `{classification}` | `{recommendation}` | {rationale} |"
        )
    lines.append("")
    lines.append("## Safe Apply Workflow")
    lines.append("")
    lines.append("1. Generate report and plan without modifying files.")
    lines.append(
        "2. Review rows marked `adopt-to-repo` and manually copy only approved, non-sensitive content."
    )
    lines.append("3. Validate changes before applying:")
    lines.append("")
    lines.append("```bash")
    lines.append("chezmoi diff")
    lines.append("chezmoi apply --dry-run")
    lines.append("```")
    lines.append("")
    lines.append("4. Apply only after preview output is expected:")
    lines.append("")
    lines.append("```bash")
    lines.append("chezmoi apply")
    lines.append("```")
    lines.append("")
    lines.append("Planning mode does not mutate local `~/.config` files.")
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()

    repo_root = args.repo_root.expanduser().resolve()
    repo_config_dir = (repo_root / args.repo_config_subdir).resolve()
    local_config_dir = args.local_config.expanduser().resolve()

    if not repo_config_dir.exists():
        raise SystemExit(f"Repo config directory not found: {repo_config_dir}")

    output_dir = args.output_dir.expanduser()
    if not output_dir.is_absolute():
        output_dir = (repo_root / output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    ignore_patterns = DEFAULT_IGNORE_PATTERNS + args.ignore
    sensitive_patterns = DEFAULT_SENSITIVE_PATTERNS + args.sensitive
    machine_patterns = DEFAULT_MACHINE_SPECIFIC_PATTERNS + args.machine_specific
    omit_from_report_patterns = args.omit_from_report
    chezmoiignore_patterns, chezmoiignore_render_error = load_chezmoiignore_patterns(
        repo_root=repo_root,
        chezmoiignore_path=args.chezmoiignore,
    )
    chezmoiexternal_patterns, chezmoiexternal_render_error = (
        load_chezmoiexternal_patterns(
            repo_root=repo_root,
            chezmoiexternal_path=args.chezmoiexternal,
        )
    )

    repo_inventory = collect_repo_inventory(repo_config_dir)
    local_inventory = collect_local_inventory(local_config_dir)
    all_paths = sorted(set(repo_inventory.keys()) | set(local_inventory.keys()))

    rows: list[dict[str, object]] = []
    omitted_count = 0
    ignored_count = 0
    template_render_failures = 0
    template_sha_cache: dict[Path, tuple[str | None, str | None]] = {}
    for target_rel in all_paths:
        if any_match(target_rel, omit_from_report_patterns):
            omitted_count += 1
            continue

        repo_entries = repo_inventory.get(target_rel, [])
        local_path = local_inventory.get(target_rel)
        local_exists = local_path is not None
        ignored = (
            any_match(target_rel, ignore_patterns)
            or any_match_chezmoiignore(target_rel, chezmoiignore_patterns)
            or any_match_chezmoiignore(target_rel, chezmoiexternal_patterns)
        )
        sensitive = any_match(target_rel, sensitive_patterns)
        machine_specific = any_match(target_rel, machine_patterns)

        classification = "matched"
        reason = ""
        local_sha256 = hash_file(local_path) if local_path else None
        repo_sha256 = None
        template_render_error = None

        if ignored:
            ignored_count += 1
            continue
        elif len(repo_entries) > 1:
            ignored_count += 1
            continue
        elif not repo_entries:
            classification = "local-only"
            reason = "Path exists locally but not in repository inventory."
        else:
            repo_entry = repo_entries[0]
            if repo_entry.is_template:
                if repo_entry.source_abs not in template_sha_cache:
                    rendered, render_error = render_template(
                        repo_root=repo_root,
                        template_path=repo_entry.source_abs,
                    )
                    template_sha_cache[repo_entry.source_abs] = (
                        hash_bytes(rendered) if rendered is not None else None,
                        render_error,
                    )
                repo_sha256, template_render_error = template_sha_cache[
                    repo_entry.source_abs
                ]
            else:
                repo_sha256 = hash_file(repo_entry.source_abs)

            if template_render_error is not None:
                classification = "template-driven"
                reason = f"Template rendering failed: {template_render_error}"
                template_render_failures += 1
            elif not local_exists:
                classification = "repo-only"
                reason = "Path exists in repository inventory but is missing locally."
            elif repo_sha256 == local_sha256:
                classification = "matched"
                reason = "File contents match exactly."
            else:
                classification = "different"
                reason = "File contents differ."

        recommendation, rationale = recommendation_for(
            classification=classification,
            sensitive=sensitive,
            machine_specific=machine_specific,
        )

        repo_sources = [entry.source_rel for entry in repo_entries]
        rows.append(
            {
                "target_path": target_rel,
                "local_path": str(local_config_dir / target_rel),
                "repo_sources": repo_sources,
                "classification": classification,
                "is_template": bool(repo_entries and repo_entries[0].is_template),
                "local_sha256": local_sha256,
                "repo_sha256": repo_sha256,
                "template_render_error": template_render_error,
                "sensitive": sensitive,
                "machine_specific": machine_specific,
                "recommendation": recommendation,
                "rationale": rationale,
                "details": reason,
            }
        )

    counts: dict[str, int] = {}
    for row in rows:
        key = str(row["classification"])
        counts[key] = counts.get(key, 0) + 1

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "repo_root": str(repo_root),
        "repo_config_dir": str(repo_config_dir),
        "local_config_dir": str(local_config_dir),
        "ignore_patterns": ignore_patterns,
        "chezmoiignore_patterns": chezmoiignore_patterns,
        "chezmoiignore_render_error": chezmoiignore_render_error,
        "chezmoiexternal_patterns": chezmoiexternal_patterns,
        "chezmoiexternal_render_error": chezmoiexternal_render_error,
        "sensitive_patterns": sensitive_patterns,
        "machine_specific_patterns": machine_patterns,
        "omit_from_report_patterns": omit_from_report_patterns,
        "omitted_count": omitted_count,
        "ignored_count": ignored_count,
        "template_render_failures": template_render_failures,
        "counts": counts,
        "entries": rows,
    }

    report_path = output_dir / "delta-report.json"
    plan_path = output_dir / "alignment-plan.md"
    report_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    plan_path.write_text(
        render_plan_markdown(
            rows=rows,
            report_path=report_path,
            local_config_dir=local_config_dir,
            repo_config_dir=repo_config_dir,
        ),
        encoding="utf-8",
    )

    print(f"Wrote delta report: {report_path}")
    print(f"Wrote alignment plan: {plan_path}")
    print(f"Classifications: {json.dumps(counts, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
