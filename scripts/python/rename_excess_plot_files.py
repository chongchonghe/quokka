#!/usr/bin/env python3

import os
import re
import sys
import argparse
from datetime import datetime

def get_timestamp():
    return datetime.now().strftime("%Y%m%d%H%M%S")

def main():
    parser = argparse.ArgumentParser(description="Back up excess Quokka output folders beyond the last checkpoint.")
    parser.add_argument("directory", help="Path to the Quokka output folder")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be done without renaming")
    args = parser.parse_args()

    root = args.directory
    if not os.path.isdir(root):
        print(f"Error: '{root}' is not a directory.", file=sys.stderr)
        sys.exit(1)

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
