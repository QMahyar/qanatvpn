#!/usr/bin/env python3
# scripts/compare_capabilities.py — verify yourvpn >= every researched VPN on every row
# Usage: python scripts/compare_capabilities.py
# Reads research/*.md + SPEC.md success criteria 1, reports matrix.
# TODO at todo:1 — implement capability matrix parsing.
import pathlib, sys

root = pathlib.Path(__file__).parent.parent
research = sorted((root / "research").glob("*.md"))
print(f"Found {len(research)} research files")
for p in research:
    print(f" - {p.name} ({p.stat().st_size} B)")
print(
    "TODO: implement row-by-row compare vs 13 VPNs — see SPEC.md:Success Criteria 1 + intent.md matrix"
)
sys.exit(0)
