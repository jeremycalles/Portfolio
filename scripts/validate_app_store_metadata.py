#!/usr/bin/env python3
"""Validate fastlane/metadata character limits without fastlane installed."""

from __future__ import annotations

import sys
from pathlib import Path

LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "keywords.txt": 100,
    "promotional_text.txt": 170,
    "description.txt": 4000,
    "release_notes.txt": 4000,
    "support_url.txt": 255,
    "marketing_url.txt": 255,
    "privacy_url.txt": 255,
    "copyright.txt": 255,
}

ROOT = Path(__file__).resolve().parents[1] / "fastlane" / "metadata"


def main() -> int:
    errors: list[str] = []
    if not ROOT.is_dir():
        print(f"Missing metadata folder: {ROOT}", file=sys.stderr)
        return 1

    locale_dirs = sorted(p for p in ROOT.iterdir() if p.is_dir() and p.name != "default")
    for locale_dir in locale_dirs:
        locale = locale_dir.name
        for filename, limit in LIMITS.items():
            path = locale_dir / filename
            if not path.exists():
                continue
            text = path.read_text(encoding="utf-8").strip()
            if len(text) > limit:
                errors.append(f"{locale}/{filename}: {len(text)} chars (max {limit})")
        keywords = locale_dir / "keywords.txt"
        if keywords.exists() and ", " in keywords.read_text(encoding="utf-8"):
            errors.append(f"{locale}/keywords.txt: remove spaces after commas")

    default_dir = ROOT / "default"
    if default_dir.is_dir():
        for filename, limit in LIMITS.items():
            path = default_dir / filename
            if not path.exists():
                continue
            text = path.read_text(encoding="utf-8").strip()
            if len(text) > limit:
                errors.append(f"default/{filename}: {len(text)} chars (max {limit})")

    if errors:
        print("Metadata validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1

    print(f"Metadata validation passed ({len(locale_dirs)} locales)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
