#!/usr/bin/env python3
"""Reads the output of scripts/balance_sweep.py and prints the wins of each strategy.

usage: python3 scripts/balance_wins.py <sweep output file> [seeds, default 16]

A run is a loss when its seed appears in `died_on`, so wins = seeds - len(died_on).
Each config block in the file (a line starting with `{`) is printed with its five strategies.
"""
import re
import sys


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    seeds = int(sys.argv[2]) if len(sys.argv) > 2 else 16
    row = re.compile(
        r"\s+(\w+)\s+cleared \[(.*?)\] died_on \[(.*?)\] heart ([0-9.]+) buttons_left (\d+)"
    )
    for line in open(sys.argv[1]):
        if line.startswith("{"):
            print("CONFIG", line[:100].strip())
        match = row.match(line)
        if match:
            died = [x for x in match.group(3).split(",") if x.strip()]
            print(
                "  %-12s wins %2d/%d  heart %s left %s"
                % (match.group(1), seeds - len(died), seeds, match.group(4), match.group(5))
            )


if __name__ == "__main__":
    main()
