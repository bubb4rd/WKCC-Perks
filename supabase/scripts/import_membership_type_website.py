#!/usr/bin/env python3
"""Generate SQL to import Membership Type + Website from a Chamber listing CSV.

Usage:
  python3 supabase/scripts/import_membership_type_website.py \\
    supabase/data/chamber_member_listing.csv \\
    > /tmp/import_membership.sql
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def sql_str(value: str | None) -> str:
    if value is None:
        return "NULL"
    return "'" + value.replace("'", "''") + "'"


def normalize_type(raw: str) -> str:
    t = raw.strip()
    if not t:
        return "Basic"
    lower = t.lower()
    if lower in {"not-for-profit", "nonprofit", "non-profit"}:
        return "Non-Profit"
    allowed = {
        "Basic",
        "Silver",
        "Gold",
        "Platinum",
        "Municipality",
        "Chamber of Commerce",
        "Non-Profit",
    }
    return t if t in allowed else "Basic"


def normalize_website(raw: str) -> str | None:
    w = raw.strip()
    if not w:
        return None
    if not w.lower().startswith(("http://", "https://")):
        w = "https://" + w
    return w


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv_path", type=Path)
    args = parser.parse_args()

    updates: list[str] = []
    with args.csv_path.open(newline="", encoding="latin-1") as f:
        for row in csv.DictReader(f):
            email = (row.get("Email") or "").strip().lower()
            if not email or "@" not in email:
                continue
            mtype = normalize_type(row.get("Membership Type") or "")
            website = normalize_website(row.get("Website") or "")
            if website:
                updates.append(
                    "UPDATE public.chamber_members SET "
                    f"membership_type = {sql_str(mtype)}, "
                    f"website_url = COALESCE(website_url, {sql_str(website)}) "
                    f"WHERE lower(email) = {sql_str(email)};"
                )
            else:
                updates.append(
                    "UPDATE public.chamber_members SET "
                    f"membership_type = {sql_str(mtype)} "
                    f"WHERE lower(email) = {sql_str(email)};"
                )

    print("-- Import Membership Type + Website from chamber listing CSV.")
    print("-- website_url only filled when null (member edits preserved).")
    print(f"-- {len(updates)} email-matched updates from {args.csv_path}")
    print()
    print("\n".join(updates))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
