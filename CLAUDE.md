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
- `tools/run_tests.sh [test_name]`: headless unit tests (`tests/unit/test_*.gd`), split across the CPUs (~4 s for all).
  A pass prints one `TESTS` line; a failure prints that shard's full output.
- `tools/lint.sh`: parse and static checks for every script. Ends with `LINT problems=<n>`.
- `tools/run_sims.sh`: regression sims (`tests/sim/sim_*.gd`, listed in `tests/sim/sim_suite.gd`).
- `tools/check_all.sh`: everything at once (unit, sims, lint, plus the bot and lab if their scenes exist).
- `tools/export_web.sh`: web build in `build/web/` plus its size check. Release uses the 2D-only engine with unused modules off,
  fetched on first use by `tools/fetch_web_template.sh` (6.3 MB download, wasm 19 MiB); `--debug` uses the stock debug template.
  A game that needs a module switched off (ogg, regex, websocket, mbedtls...) must turn it back on in `web_template.yml`.
  `node tools/web_smoke.mjs`: boots `build/web` in headless Chromium (no errors, a full screen within 30 s); with
  `SMOKE_BOT=greedy` a second page plays a whole run with the play-bot (`SMOKE_BOT_HASH` = the native run's hash).
- Bot play through the real screen: `godot --headless --path . -- --scripted --bot=greedy --seed=7` prints one `BOT`
  line (exit 1 if stuck or the recording does not replay). The web build takes the same switches as `?scripted&bot=greedy`.
- `tools/export_windows.sh`: Windows build zip in `build/`. `tools/export_android.sh`: debug APK in `build/`. Stock
  templates come from `tools/fetch_templates.py`, which range-reads only the ones needed out of the 1.28 GB file.
- `.claude/hooks/lint-on-edit.sh`: after every Edit/Write of a `.gd` file, parse-checks that script and lints it (~0.3 s;
  ~4 s when it adds a new `class_name`). Problems come back to the agent at once.
- `tools/import.sh`: the shared import step; skipped when no file changed (`FORCE_IMPORT=1` to force). Every tool calls it.
- CI: `checks` (unit, lint, sims, lab) and `web` (playable build; main deploys to GitHub Pages). Doc-only pushes to main skip both; every PR runs both, because main requires `unit`, `lint`, `sims`, `lab` and `build` to pass and PRs auto-merge when they do.
- Run the game: `godot --path .` (add `-- --dev` for dev entries, `-- --stamp` to show the frame stamp). In the game
  screen and the debug shop, F12 reloads `game/data/*.json` and restarts the run on the same seed; F1 loads a tuning
  preset.

## Layout
- `game/autoload/`: `Flags` (run flags, frame counter, state hash), `Controls` (input actions).
- `game/debug/`: frame stamp (F10), render toggles (F4, F6-F9), `Tuning` (live-tunable numbers).
- `game/<system>/`: one folder per system.
- `tests/unit/`: one `test_<module>.gd` per module, `extends TestCase`. `tests/sim/`: regression sims.
- `tools/`: shell and Python tools. Python uses the standard library only.
- `docs/`: `playbook.md` (kickoff, fan-out, measure-fix loop), `agent_brief.md` (contracts and subagent rules),
  `lessons_learned.md` (rows for this game; `lessons/kit_archive.md` has the full starter-kit list),
  `new_project_checklist.md`, `production_pipeline.md`, `performance.md`, `online.md`, `android.md`,
  `agent_dashboard.md`, `character_creation_lessons.md`.

## Rules
- Static typing everywhere: typed vars, params and returns. Tabs for indentation.
- Headless scenes that step physics run with `--fixed-fps 60`, or they wait on the wall clock.
- Gameplay logic is pure `RefCounted` classes with `class_name`, no Node, no wall clock, no `randf()`: take `delta`
  and a seeded `RandomNumberGenerator`. Nodes are thin wrappers that feed them input. Put pure logic in
  `game/logic/` (or edit `PURE_PREFIXES` in `tools/lint.py`).
- Gameplay numbers live in `Tuning` (or data files), never as literals in logic.
- Every logic module has a unit test file. A change is done when `tools/run_tests.sh` and `tools/lint.sh` pass.
- File-local helper names must be unique across the project (one `class_name` space).
- Tools are quiet: print errors and failures, then one summary line.
- Reading CI: list the job's steps first (names, times, conclusion), then fetch only the failing job's log with a
  small tail (about 40 lines); every tool's last line is its summary. Full CI logs are thousands of tokens of setup.
- Scripted shots key on game state (an observed condition) with a time fallback, never fixed seconds alone.
- Compare state hashes only on frames where `Flags.commands == 0`.
- Captures, tests and gates never write player data (`Flags.is_scripted_run()`).
- No secrets in git: credentials live in git-ignored `config/*credentials*` and are injected at export.
- Reproduce a bug (test, sim, bot, replay) before fixing it; fix the traced mechanism, not a guess.
- Read `docs/lessons_learned.md` before starting; add a row whenever something goes wrong.
