#!/usr/bin/env python3
"""Checks that the tests can fail: applies each mutation to a copy of the code.

usage: python3 scripts/mutate.py <mutations.json> [workers]

The file is a list of mutations:

  [{"name": "ignore the armor", "file": "sim/barracks/barracks.gd",
    "old": "foe.attack_damage - float(guard.armor)", "new": "foe.attack_damage - 0.0",
    "tests": ["test_guard_fight"]}]

`file` is relative to `godot/`; `old` must appear in it (the first match is replaced);
`tests` are GUT script names (`-gselect`) that should fail. Each mutation runs in its
own temporary copy of the godot project, so the working tree is never touched, and
only those test files run, so a check takes seconds, not the minute of the full suite.
A mutation is killed when a test fails (or a script no longer parses) and survives
when every listed test still passes; a survivor means the tests cannot see that change.
A baseline run of the same tests, unmutated, must pass first. Exit code 1 when any
mutation survives or the baseline fails. Reviewers: run this instead of editing code by
hand, and report only the survivors.
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
# repo-root files the tests read through `res://../` (test_project, test_camera_pitch_rule)
ROOT_FILES = ("CLAUDE.md", ".godot-version")
# appended to the output of a Godot run that ended on a signal
CRASHED = "mutate.py: godot crashed"


def run_godot(project, *args):
    try:
        done = subprocess.run([GODOT, "--headless", "--path", project, *args],
                              capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit("godot not found (%s): put it on the PATH or set GODOT" % GODOT)
    # killed by a signal (negative) or by its own crash handler (128 + signal)
    crashed = "\n" + CRASHED if done.returncode < 0 or done.returncode >= 128 else ""
    return done.stdout + done.stderr + crashed


def prepare(tmp, name):
    dest = os.path.join(tmp, name)
    shutil.copytree(os.path.join(REPO, "godot"), dest, symlinks=True,
                    ignore=shutil.ignore_patterns(".godot"))
    # each copy sits in `tmp`, so `res://../<file>` is `tmp/<file>`
    for root_file in ROOT_FILES:
        shutil.copyfile(os.path.join(REPO, root_file), os.path.join(tmp, root_file))
    out = run_godot(dest, "--import")
    if CRASHED in out:
        out = run_godot(dest, "--import")
    if CRASHED in out or re.search(r"SCRIPT ERROR|Parse Error", out):
        sys.exit("%s: the project does not import:\n%s" % (name, out[-1500:]))
    return dest


def tests_fail(project, tests):
    """The name of the first test script that fails (or breaks), else None."""
    for test in tests:
        args = ("-s", "addons/gut/gut_cmdln.gd", "-gdir=res://tests", "-ginclude_subdirs",
                "-gselect=" + test, "-gexit")
        out = run_godot(project, *args)
        if CRASHED in out:
            # one crash is not a test failure (Godot crashes now and then, #504): run it again;
            # a crash that repeats is the mutation's doing, and is named as such
            out = run_godot(project, *args)
            if CRASHED in out:
                return test + " (godot crashed twice)"
        failing = re.search(r"Failing Tests\s+(\d+)", out)
        passing = re.search(r"Passing Tests\s+(\d+)", out)
        if failing and int(failing.group(1)) > 0:
            return test
        if re.search(r"SCRIPT ERROR|Parse Error", out) or not passing:
            return test
    return None


def check(mutation):
    index, m, tmp = mutation
    dest = prepare(tmp, "m%d" % index)
    path = os.path.join(dest, m["file"])
    text = open(path).read()
    if m["old"] not in text:
        sys.exit("mutation %r: the old text is not in %s" % (m["name"], m["file"]))
    open(path, "w").write(text.replace(m["old"], m["new"], 1))
    return m["name"], tests_fail(dest, m["tests"])


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    try:
        mutations = json.load(open(sys.argv[1]))
    except (OSError, ValueError) as error:
        sys.exit("cannot read %s: %s" % (sys.argv[1], error))
    workers = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    for m in mutations:
        for key in ("name", "file", "old", "new", "tests"):
            if key not in m:
                sys.exit("a mutation needs %r: %r" % (key, m))
    with tempfile.TemporaryDirectory() as tmp:
        tests = sorted({t for m in mutations for t in m["tests"]})
        base = tests_fail(prepare(tmp, "base"), tests)
        if base:
            sys.exit("baseline: %s fails without any mutation; fix that first" % base)
        jobs = [(i, m, tmp) for i, m in enumerate(mutations)]
        with ThreadPoolExecutor(max_workers=workers) as pool:
            results = list(pool.map(check, jobs))
    survivors = 0
    for name, killer in results:
        if killer:
            print("killed    %s (by %s)" % (name, killer))
        else:
            survivors += 1
            print("SURVIVED  %s" % name)
    print("%d of %d mutations killed" % (len(results) - survivors, len(results)))
    sys.exit(1 if survivors else 0)


if __name__ == "__main__":
    main()
