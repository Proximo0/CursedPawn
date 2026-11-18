# Cursed Pawn (Godot 4.7.2, GDScript)

Cursed Pawn (working title *Pass It On*): a spooky-funny roguelite where you run an occult pawnshop. Customers bring
objects; you inspect them with four tools (UV lamp, scale, listen, touch), haggle, buy and sell to pay a rising nightly
rent over a 5-night run. Cursed objects pay best but raise the shop's Dread until something wakes (physics chaos in one
room). At the end of a run you pass your worst object to a friend as a link; their run starts with it and its history.
v1 (ship 18 Dec 2026): one shop, ~40 objects, 8 curses, 12 customer types, browser build on our own site (first run
free, $7.99 unlock) plus Windows/Linux downloads for Steam and itch. Design and feel targets: the "Game production
pipeline" doc, section "Design: the cursed pawnshop" (https://claude.ai/artifact/UVzDwm55T274i1FEqVb2X7).
Web export uses the Compatibility renderer, single-threaded, GDScript only.

## Commands
- `tools/run_tests.sh [test_name]`: headless unit tests (`tests/unit/test_*.gd`). Prints failures only.
- `tools/lint.sh`: parse and static checks for every script. Ends with `LINT problems=<n>`.
- `tools/run_sims.sh`: regression sims (`tests/sim/sim_*.gd`, listed in `tests/sim/sim_suite.gd`).
- `tools/check_all.sh`: everything at once (unit, sims, lint, plus the bot and lab if their scenes exist).
- `tools/export_windows.sh`: Windows build zip in `build/`. `tools/export_android.sh`: debug APK in `build/`.
- `tools/fetch_web_template.sh`: fetch the 2D-only web engine (needed before a Web export; 7.3 MB download vs 9.9 MB).
- Run the game: `godot --path .` (add `-- --dev` for dev entries, `-- --stamp` to show the frame stamp).

## Layout
- `game/autoload/`: `Flags` (run flags, frame counter, state hash), `Controls` (input actions).
- `game/debug/`: frame stamp (F10), render toggles (F4, F6-F9), `Tuning` (live-tunable numbers).
- `game/<system>/`: one folder per system.
- `tests/unit/`: one `test_<module>.gd` per module, `extends TestCase`. `tests/sim/`: regression sims.
- `tools/`: shell and Python tools. Python uses the standard library only.
- `docs/`: `playbook.md` (kickoff, fan-out, measure-fix loop), `agent_brief.md` (contracts and subagent rules),
  `lessons_learned.md`, `new_project_checklist.md`, `production_pipeline.md`, `performance.md`, `online.md`,
  `android.md`, `agent_dashboard.md`, `character_creation_lessons.md`.

## Rules
- Static typing everywhere: typed vars, params and returns. Tabs for indentation.
- Gameplay logic is pure `RefCounted` classes with `class_name`, no Node, no wall clock, no `randf()`: take `delta`
  and a seeded `RandomNumberGenerator`. Nodes are thin wrappers that feed them input. Put pure logic in
  `game/logic/` (or edit `PURE_PREFIXES` in `tools/lint.py`).
- Gameplay numbers live in `Tuning` (or data files), never as literals in logic.
- Every logic module has a unit test file. A change is done when `tools/run_tests.sh` and `tools/lint.sh` pass.
- File-local helper names must be unique across the project (one `class_name` space).
- Tools are quiet: print errors and failures, then one summary line.
- Scripted shots key on game state (an observed condition) with a time fallback, never fixed seconds alone.
- Compare state hashes only on frames where `Flags.commands == 0`.
- Captures, tests and gates never write player data (`Flags.is_scripted_run()`).
- No secrets in git: credentials live in git-ignored `config/*credentials*` and are injected at export.
- Reproduce a bug (test, sim, bot, replay) before fixing it; fix the traced mechanism, not a guess.
- Read `docs/lessons_learned.md` before starting; add a row whenever something goes wrong.
