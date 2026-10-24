---
type: lesson
date: 2026-10-24
area: tooling
links: [#504]
promote: script
promoted-to: godot/project.godot (editor/import/use_multiple_threads=false), godot/tests/test_project.gd, scripts/run-gut-parallel.sh, scripts/mutate.py
---
# Import on one thread, and name a stripped Godot crash from the strings its frames reference

## What happened
Headless Godot 4.7.2 crashed now and then on the owner's Mac while agents ran GUT, imports and mutation runs at once (load 55 to 105 on 12 cores). Every real crash was a cold `--import` (a fresh worktree, or `mutate.py`'s copies without `.godot`), not a test run.

## Evidence
`~/Library/Logs/DiagnosticReports/Godot-2026-10-24-{193315,210330,210652}.ips`: `EXC_BAD_ACCESS KERN_INVALID_ADDRESS at 0x10` on a `WorkerThread`, same 13 frames each time. Named from their strings: `EditorFileSystem::_reimport_file` < `ResourceImporterOggVorbis::import` < `ResourceSaver::save` < `ResourceFormatSaverBinary` < `PropertyUtils::get_property_default_value` < `ClassDB::class_get_default_property_value` < `HashMap<StringName,…>::_lookup_pos`, which reads `elements[pos]->key` while another thread fills the unlocked default-value cache. Reproduced once in 120 cold imports at load 170; with threaded import off, 0 of 90 crashed. The 11:43 and 11:51 aborts were reviewers' deliberate `OS.crash()`.

## What we learnt
Godot's threaded import saves several `.ogg` resources at once, and the first lookup of a class's defaults is not thread-safe. The window is small, so heavy load is what exposes it. Disassembling a stripped frame (`lipo -thin arm64`, `objdump --start-address`) and reading the C strings it loads names the function well enough.

## Rule next time
Keep `editor/import/use_multiple_threads=false`. Never treat a run that ended on a signal as a pass or a kill: run it once more and report the crash.
