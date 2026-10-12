#!/usr/bin/env python3
"""Plays the scripted bot under several sets of numbers, in parallel.

usage: python3 scripts/balance_sweep.py '<configs json>' [seeds] [workers]

A config is a dict: {"waves:HP_QUADRATIC": 0.03, "sub:towers#1": ["old", "new"]}.
`file:CONSTANT` sets a `const` of godot/content/<file>.gd (waves, foes, towers or
rules); `sub:<file>#<n>` replaces `old` by `new` in that file (the `#n` only keeps
the keys apart). Each config runs in its own copy of the godot project, and each
(config, profile) is one godot process playing every seed, so a sweep takes about as
long as its slowest job. The working tree is never touched.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# the godot binary: the GODOT environment variable, else `godot` on the PATH
GODOT = os.environ.get("GODOT", "godot")
PROFILES = ["spoolOnly", "mortarHeavy", "prismHeavy", "mix"]
FILES = {
    "waves": "content/waves.gd",
    "foes": "content/foes.gd",
    "towers": "content/towers.gd",
    "rules": "content/game_rules.gd",
}


def make_copy(index, cfg, tmp):
    dest = os.path.join(tmp, "c%d" % index, "godot")
    shutil.copytree(os.path.join(REPO, "godot"), dest, symlinks=True,
                    ignore=shutil.ignore_patterns(".godot"))
    for key, val in cfg.items():
        if key.startswith("sub:"):
            name_file = key.split(":")[1].split("#")[0]
            if name_file not in FILES:
                sys.exit("config %d: unknown file %r in %s (use %s)"
                         % (index, name_file, key, ", ".join(FILES)))
            if not (isinstance(val, list) and len(val) == 2
                    and all(isinstance(v, str) for v in val)):
                sys.exit("config %d: %s needs [old text, new text]" % (index, key))
            path = os.path.join(dest, FILES[name_file])
            text = open(path).read()
            if val[0] not in text:
                sys.exit("config %d: %r not found for %s" % (index, val[0], key))
            open(path, "w").write(text.replace(val[0], val[1], 1))
            continue
        if ":" not in key:
            sys.exit("config %d: key %r is not file:CONSTANT or sub:file#n" % (index, key))
        name_file, name = key.split(":")
        if name_file not in FILES:
            sys.exit("config %d: unknown file %r in %s (use %s)"
                     % (index, name_file, key, ", ".join(FILES)))
        if isinstance(val, bool) or not isinstance(val, (int, float)):
            sys.exit("config %d: %s must be a number, not %r" % (index, key, val))
        path = os.path.join(dest, FILES[name_file])
        text, n = re.subn(r"(const %s := )[^\n]+" % re.escape(name), r"\g<1>%s" % json.dumps(val),
                          open(path).read())
        if n != 1:
            sys.exit("config %d: constant %s not found in %s" % (index, name, name_file))
        open(path, "w").write(text)
    imported = subprocess.run([GODOT, "--headless", "--path", dest, "--import"],
                              capture_output=True, text=True)
    if imported.returncode != 0:
        sys.exit("config %d: godot could not import the copy:\n%s" % (index, imported.stderr))
    return dest


def run_job(job):
    index, profile, dest, seeds = job
    run = subprocess.run(
        [GODOT, "--headless", "--path", dest, "-s", "tools/balance_run.gd", "--",
         "--seeds=" + seeds, "--waves=20", "--profiles=" + profile],
        capture_output=True, text=True)
    out = run.stdout
    # a number that breaks a script makes godot print a script error and play a game
    # without it (a quiet "win"), so any error in the output is fatal
    if run.returncode != 0 or "SCRIPT ERROR" in out or "SCRIPT ERROR" in run.stderr:
        sys.exit("config %d, %s: godot failed:\n%s%s" % (index, profile, out[-1500:], run.stderr[-1500:]))
    rows = []
    for line in out.splitlines():
        p = line.split()
        if len(p) >= 11 and p[0] == profile and p[1].lstrip("-").isdigit():
            # cleared, died on wave, Heartstone health, Buttons left
            rows.append((int(p[2]), int(p[3]), int(p[4]), int(p[8])))
    wanted = len(seeds.split(","))
    if len(rows) != wanted:
        sys.exit("config %d, %s: %d rows for %d seeds:\n%s" % (index, profile, len(rows), wanted, out[-1500:]))
    return index, profile, rows


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    configs = json.loads(sys.argv[1])
    seeds = sys.argv[2] if len(sys.argv) > 2 else "1,2,3,4,5,6,7,8"
    workers = int(sys.argv[3]) if len(sys.argv) > 3 else max(2, (os.cpu_count() or 4) - 2)
    tmp = tempfile.mkdtemp(prefix="balance_sweep_")
    try:
        with ThreadPoolExecutor(workers) as pool:
            dests = list(pool.map(lambda ic: make_copy(ic[0], ic[1], tmp), enumerate(configs)))
            jobs = [(i, p, dests[i], seeds) for i in range(len(configs)) for p in PROFILES]
            results = list(pool.map(run_job, jobs))
        by_config = {}
        for index, profile, rows in results:
            by_config.setdefault(index, {})[profile] = rows
        for index, cfg in enumerate(configs):
            print(json.dumps(cfg))
            for profile in PROFILES:
                rows = by_config[index][profile]
                n = max(1, len(rows))
                cleared = sorted(r[0] for r in rows)
                died = sorted(r[1] for r in rows if r[1])
                print("  %-12s cleared %s died_on %s heart %.1f buttons_left %d"
                      % (profile, cleared, died, sum(r[2] for r in rows) / n,
                         sum(r[3] for r in rows) // n))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


main()
