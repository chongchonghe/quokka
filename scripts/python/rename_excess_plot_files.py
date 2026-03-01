#!/usr/bin/env python3

"""Rename/restore excess Quokka plotfile directories.

Renaming mode: find the last checkpoint index (chk*), then rename plotfile
folders matching *plt<digits> with index >= last checkpoint to:
    <name>.old.excess.<timestamp>

Undo mode: restore folders renamed at a specific timestamp.

Examples:
    ./rename_excess_plot_files.py .
    ./rename_excess_plot_files.py . --dry-run
    ./rename_excess_plot_files.py . --undo 20260301T140531
    ./rename_excess_plot_files.py . --undo 20260301T140531 --dry-run
"""

import os
import re
import sys
import argparse
from datetime import datetime

def get_timestamp():
    return datetime.now().strftime("%Y%m%dT%H%M%S")

def is_valid_timestamp(timestamp):
    return bool(re.fullmatch(r"\d{8}T\d{6}", timestamp))

def undo_renames(root, timestamp, dry_run):
    suffix = f".old.excess.{timestamp}"
    entries = sorted(os.listdir(root))

    restored = 0
    skipped = 0
    for e in entries:
        if not e.endswith(suffix):
            continue
        full = os.path.join(root, e)
        if not os.path.isdir(full):
            continue

        old_name = e[: -len(suffix)]
        old_full = os.path.join(root, old_name)
        if os.path.exists(old_full):
            print(f"Skipping (target exists): {e}  ->  {old_name}", file=sys.stderr)
            skipped += 1
            continue

        if dry_run:
            print(f"[dry-run] Would restore: {e}  ->  {old_name}")
        else:
            os.rename(full, old_full)
            print(f"Restored: {e}  ->  {old_name}")
        restored += 1

    if restored == 0 and skipped == 0:
        print(f"No folders found for undo timestamp '{timestamp}'.")
    elif dry_run:
        print(f"\n[dry-run] {restored} folder(s) would be restored.")
        if skipped > 0:
            print(f"[dry-run] {skipped} folder(s) would be skipped due to existing targets.")
    else:
        print(f"\n{restored} folder(s) restored.")
        if skipped > 0:
            print(f"{skipped} folder(s) skipped due to existing targets.", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser(description="Back up excess Quokka output folders beyond the last checkpoint.")
    parser.add_argument("directory", help="Path to the Quokka output folder")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be done without renaming")
    parser.add_argument(
        "--undo",
        metavar="TIMESTAMP",
        help="Undo previous renames for a specific timestamp (format: YYYYMMDDTHHMMSS).",
    )
    args = parser.parse_args()

    root = args.directory
    if not os.path.isdir(root):
        print(f"Error: '{root}' is not a directory.", file=sys.stderr)
        sys.exit(1)

    if args.undo:
        if not is_valid_timestamp(args.undo):
            print(
                "Error: --undo expects timestamp format YYYYMMDDTHHMMSS.",
                file=sys.stderr,
            )
            sys.exit(1)
        undo_renames(root, args.undo, args.dry_run)
        sys.exit(0)

    entries = sorted(os.listdir(root))

    chk_re = re.compile(r"^chk(\d+)$")
    chk_indices = []
    for e in entries:
        m = chk_re.match(e)
        if m and os.path.isdir(os.path.join(root, e)):
            chk_indices.append(int(m.group(1)))

    if not chk_indices:
        print("No chk* folders found. Nothing to do.")
        sys.exit(0)

    nlast = max(chk_indices)
    print(f"Last checkpoint index: {nlast}")

    plt_re = re.compile(r"^.*plt(\d+)$")
    timestamp = get_timestamp()

    renamed = 0
    for e in entries:
        m = plt_re.match(e)
        if not m:
            continue
        full = os.path.join(root, e)
        if not os.path.isdir(full):
            continue
        idx = int(m.group(1))
        if idx >= nlast:
            new_name = f"{e}.old.excess.{timestamp}"
            new_full = os.path.join(root, new_name)
            if args.dry_run:
                print(f"[dry-run] Would rename: {e}  ->  {new_name}")
            else:
                os.rename(full, new_full)
                print(f"Renamed: {e}  ->  {new_name}")
            renamed += 1

    if renamed == 0:
        print("No folders needed renaming.")
    elif args.dry_run:
        print(f"\n[dry-run] {renamed} folder(s) would be renamed.")
    else:
        print(f"\n{renamed} folder(s) renamed.")

if __name__ == "__main__":
    main()
