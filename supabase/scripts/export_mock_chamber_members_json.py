#!/usr/bin/env python3
"""Emit MockChamberMembers.json from a ChamberMaster MemberResource XML export.

Usage:
  python3 supabase/scripts/export_mock_chamber_members_json.py \\
    /path/to/WKCCActiveMembers.html \\
    -o "Wilmette Kenilworth Perks/Services/Mock/MockChamberMembers.json"
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def tag(block: str, name: str) -> str | None:
    match = re.search(rf"<{name}\b[^>]*>(.*?)</{name}\s*>", block, flags=re.S)
    if not match:
        return None
    return (
        re.sub(r"\s+", " ", match.group(1))
        .replace("&amp;", "&")
        .replace("&apos;", "'")
        .strip()
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("xml_path", type=Path)
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        required=True,
        help="Path to write MockChamberMembers.json",
    )
    args = parser.parse_args()

    text = args.xml_path.read_text(errors="ignore")
    blocks = re.findall(
        r"<MemberResource\b[^>]*>(.*?)</MemberResource\s*>",
        text,
        flags=re.S,
    )

    rows: list[dict] = []
    for block in blocks:
        email = tag(block, "Email")
        cm_id = int(tag(block, "Id") or "0")
        name = tag(block, "Name") or f"Member {cm_id}"
        rows.append(
            {
                "cm_id": cm_id,
                "name": name,
                "display_name": tag(block, "DisplayName") or name,
                "email": email.lower().strip() if email else None,
                "status": tag(block, "Status") or "0",
                "display_flags": tag(block, "DisplayFlags") or "",
                "membership_established": tag(block, "MembershipEstablished"),
            }
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + "\n")
    print(f"wrote {args.output} ({len(rows)} rows)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
