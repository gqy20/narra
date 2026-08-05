#!/usr/bin/env python3
"""Validate Narra commit headers against the repository convention."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


HEADER_PATTERN = re.compile(
    r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)"
    r"\([a-z0-9][a-z0-9._/-]*\): \S.*$"
)
ZERO_SHA_PATTERN = re.compile(r"^0+$")


def validate_header(message: str) -> str | None:
    header = message.splitlines()[0].strip() if message.splitlines() else ""
    if header.startswith("Merge ") or header.startswith('Revert "'):
        return None
    if HEADER_PATTERN.fullmatch(header):
        return None
    return header


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        check=True,
        text=True,
        encoding="utf-8",
        stdout=subprocess.PIPE,
    )
    return result.stdout.strip()


def commits_in_range(base: str, head: str) -> list[str]:
    revision = ""
    candidate_base = base
    if not base or ZERO_SHA_PATTERN.fullmatch(base):
        default_branch = subprocess.run(
            ["git", "rev-parse", "--verify", "origin/main"],
            check=False,
            text=True,
            encoding="utf-8",
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        ).stdout.strip()
        if default_branch and default_branch != head:
            candidate_base = default_branch

    if candidate_base and not ZERO_SHA_PATTERN.fullmatch(candidate_base):
        ancestor = subprocess.run(
            ["git", "merge-base", "--is-ancestor", candidate_base, head],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if ancestor.returncode == 0:
            revision = f"{candidate_base}..{head}"
    if not revision:
        return [head]
    output = git("rev-list", "--reverse", revision)
    return output.splitlines() if output else []


def check_messages(messages: list[tuple[str, str]]) -> int:
    failures: list[tuple[str, str]] = []
    for identifier, message in messages:
        invalid_header = validate_header(message)
        if invalid_header is not None:
            failures.append((identifier, invalid_header))

    if not failures:
        print(f"Commit message validation passed: {len(messages)} message(s).")
        return 0

    print("Invalid commit message header(s):", file=sys.stderr)
    for identifier, header in failures:
        print(f"  {identifier}: {header or '<empty>'}", file=sys.stderr)
    print(
        "Expected: type(scope): subject\n"
        "Example: feat(ui): 调整地图交互\n"
        "Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert",
        file=sys.stderr,
    )
    return 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--file", type=Path, help="commit message file used by commit-msg")
    source.add_argument("--message", help="literal message for diagnostics and tests")
    source.add_argument("--range", nargs=2, metavar=("BASE", "HEAD"))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.file is not None:
        return check_messages([(str(args.file), args.file.read_text(encoding="utf-8-sig"))])
    if args.message is not None:
        return check_messages([("message", args.message)])

    base, head = args.range
    commits = commits_in_range(base, head)
    messages = [(commit[:12], git("show", "-s", "--format=%B", commit)) for commit in commits]
    return check_messages(messages)


if __name__ == "__main__":
    raise SystemExit(main())
