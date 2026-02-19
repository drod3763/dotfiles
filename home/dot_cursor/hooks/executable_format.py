#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Optional, Tuple

SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_PARENT = SCRIPT_PATH.parent
COMMAND_LOG_NAME = "dotnet-format-command.log"
FORMATTABLE_EXTENSIONS = {
    ".cs",
    ".vb",
    ".csproj",
    ".vbproj",
}


def find_repo_root(start: Path) -> Optional[Path]:
    current = start.resolve()
    if current.is_file():
        current = current.parent
    candidates = [current, *current.parents]
    for candidate in candidates:
        if (candidate / ".git").is_dir():
            return candidate
    return None


def relative_from_folder(
    absolute_path: Path,
    folder_name: str,
) -> Path:
    parts = absolute_path.parts
    try:
        start = parts.index(folder_name)
    except ValueError as exc:
        raise SystemExit(
            f"folder '{folder_name}' not found in '{absolute_path}'"
        ) from exc
    return Path(*parts[start:])


def compute_paths(
    absolute_path: Path,
    folder_name: Optional[str],
    repo_root: Optional[Path],
    fallback_root: Path,
) -> Tuple[str, str]:
    if folder_name:
        display_path = relative_from_folder(absolute_path, folder_name)
        if (
            repo_root
            and display_path.parts
            and display_path.parts[0] == repo_root.name
        ):
            display_path = Path(*display_path.parts[1:])
        command_path = display_path
        return str(display_path), str(command_path)

    base_root = repo_root or fallback_root
    try:
        relative = absolute_path.relative_to(base_root)
    except ValueError as exc:
        raise SystemExit(
            f"path '{absolute_path}' is not inside '{base_root}'"
        ) from exc

    display_path = str(relative)
    command_path = display_path
    return display_path, command_path


def append_log(entry: str, working_directory: Path) -> None:
    log_path = working_directory / COMMAND_LOG_NAME
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write(f"{entry}\n")
    except OSError as exc:
        raise SystemExit(f"failed to write log: {exc}") from exc


def run_dotnet_format(command_path: str, working_directory: Path) -> None:
    command = ["dotnet", "format", "--include", command_path]
    try:
        result = subprocess.run(
            command,
            check=True,
            cwd=str(working_directory),
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as exc:
        stdout = exc.stdout.strip() if exc.stdout else ""
        stderr = exc.stderr.strip() if exc.stderr else ""
        log_lines = [f"FAILED: {' '.join(command)}"]
        if stdout:
            log_lines.append(f"STDOUT: {stdout}")
        if stderr:
            log_lines.append(f"STDERR: {stderr}")
        append_log(" | ".join(log_lines), working_directory)
        if stdout:
            sys.stdout.write(stdout + "\n")
        if stderr:
            sys.stderr.write(stderr + "\n")
        raise SystemExit(exc.returncode) from exc

    stdout = result.stdout.strip() if result.stdout else ""
    stderr = result.stderr.strip() if result.stderr else ""
    log_lines = ["SUCCESS: " + " ".join(command)]
    if stdout:
        log_lines.append(f"STDOUT: {stdout}")
    if stderr:
        log_lines.append(f"STDERR: {stderr}")
    append_log(" | ".join(log_lines), working_directory)

    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)


def extract_file_path(payload: dict[str, Any]) -> str:
    if "file_path" in payload:
        return str(payload["file_path"])

    tool_response = payload.get("tool_response")
    if isinstance(tool_response, dict) and "file_path" in tool_response:
        return str(tool_response["file_path"])

    tool_input = payload.get("tool_input")
    if isinstance(tool_input, dict) and "file_path" in tool_input:
        return str(tool_input["file_path"])

    raise SystemExit("missing required field: file_path")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Read JSON from stdin, extract file_path, and log the dotnet format command."
    )
    parser.add_argument(
        "--folder",
        help="Optional folder name where the relative path should start (overrides JSON).",
        default=None,
    )
    args = parser.parse_args()

    raw_input = sys.stdin.read().strip()
    if not raw_input:
        raise SystemExit("expected JSON input on stdin")

    try:
        payload = json.loads(raw_input)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid JSON input: {exc}") from exc

    file_path = extract_file_path(payload)

    absolute_path = Path(file_path).resolve()
    folder_override = args.folder or payload.get("folder_name")

    suffix = absolute_path.suffix.lower()
    skip_format = False

    if suffix not in FORMATTABLE_EXTENSIONS:
        skip_format = True
    elif suffix in {".csproj", ".vbproj"} and absolute_path.is_dir():
        skip_format = True

    repo_root = find_repo_root(absolute_path)
    fallback_root = repo_root or find_repo_root(SCRIPT_PARENT) or SCRIPT_PARENT
    working_root = repo_root or fallback_root

    display_path, command_path = compute_paths(
        absolute_path,
        folder_override,
        repo_root,
        working_root,
    )

    if skip_format:
        print(display_path)
        return

    run_dotnet_format(command_path, working_root)
    print(display_path)


if __name__ == "__main__":
    main()
