#!/usr/bin/env python3
"""Fail CI when the newest migration is not copied verbatim into setup_all.sql."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
migrations = sorted((root / "supabase" / "migrations").glob("*.sql"))
if not migrations:
    raise SystemExit("no Supabase migrations found")

latest = migrations[-1]
setup = (root / "supabase" / "setup_all.sql").read_text(encoding="utf-8").replace("\r\n", "\n")
body = latest.read_text(encoding="utf-8").replace("\r\n", "\n").strip()

marker = f"-- {latest.name}"
if marker not in setup:
    raise SystemExit(f"setup_all.sql is missing migration marker: {latest.name}")
if body not in setup:
    raise SystemExit(f"setup_all.sql does not contain the exact latest migration: {latest.name}")

print(f"SUPABASE_SETUP PASS: {latest.name}")
