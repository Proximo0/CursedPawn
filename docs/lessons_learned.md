# Lessons learned (read before starting work)

The rows that apply to Cursed Pawn (Godot 4.7.2, GDScript, one physics room, web and desktop builds, cloud agents).
The full starter-kit list, with rows about other engines, Houdini, dashboards, networking, Android, self-hosted CI and
overnight loops, is in `docs/lessons/kit_archive.md`: read its section before work in one of those areas.

Add a row under the matching heading whenever something goes wrong: what happened (one line, with numbers when you
have them) and the rule that prevents it. At the end of the project, copy the generic rows back into the starter kit
(`docs/playbook.md`, section 4).

## Workflow and agents

| What happened | Rule |
| --- | --- |
| Subagents messaged the user directly | Never call `mcp__hearthbot__` tools. Report only to the lead. |
| A global `flock` around every Godot run deadlocked agents | Only `godot --import` takes `/tmp/<project>_import.lock`. Never wrap `tools/*.sh` in flock. |
| 4 cloud cores capped how many checks and agents could run Godot at once | Use `tools/check_all.sh` locally and the GitHub Actions matrix (`checks`) for scale. Keep local workers to about 8 (every worker runs the engine); run more as remote cloud agents, each on its own machine and branch, merged by the lead after the gate. |
| `git commit -a` pushed another worker's half-finished file | The lead stages files by name while workers are editing. |
| Untracked new files from a finished worker vanished from the shared tree while other workers were still running | Commit a finished worker's files promptly, or back them up first. Workers never run git at all (no clean, stash, checkout or reset) and never delete files they did not create. |
| Unit tests passed in the working tree but failed in CI, and mid-flight workers left the tree red while CI linted the pushed tree | Other workers' uncommitted edits hide failures. The lead copies finished files into a clean clone (`/tmp/<project>_build`) or a `git worktree` of HEAD, runs lint, tests and sims there, commits by name and pushes from it. |
| A worker typed a parameter as a contract class that was not committed yet; CI lint failed on the pushed tree | Code against an uncommitted contract class with duck typing (`Node3D`), and lint a clean clone before pushing. |
| The lead pushed a red tree: `(lint; tests; sims) && git commit` only checks the last command of the subshell | Gate commits on the summary lines (`failed=0`, `problems=0`), not on a subshell exit code. |
| A worker reported "sims and bot skipped as instructed" when the brief asked for them | The lead reruns `check_all` and the bot before every commit of physics-adjacent files. |
| Container restarts killed running workers three times | Workers leave WIP in the tree; relaunch on that WIP with the prior findings in the prompt, never from scratch. |
| A worker cleared its own hung Godot with `pkill godot` and killed another worker's render | Kill only your own PIDs (`kill <pid>`); never `pkill godot` while other workers run. |
| A worker reported a shared test failing in a file it did not touch; the cause was a concurrent worker (a tuning row made a filter match two groups; a data file length change broke a data test) | Before fixing a failure outside your files, check whether another worker's recent change caused it, and tell that worker. |
| Two commit hashes were misquoted in reports | Report a commit hash only after the push has returned it. |
| The orchestrator ran on the largest model for days and used most of the owner's token budget | Run the lead on a mid-tier model and workers on a small one from day one; use the largest model only for short contract or design passes the owner asks for. |
| A commit was pushed without its attribution trailers, and force-push is denied, so it stays that way | Check the message before every push (`git log -1 --format=%B`, look for the trailer lines). |
| A new CI option was "proven" by a run that never reached its new code: the fast-mode proof skipped the diff step, and the first real run hung in it | A proof run must go through the code it proves. Run each new branch of a workflow (here `auto`, `true`, `fast`) once before calling it done. |
| A worker's new test, written to match its own hypothesis, still passed with the fix switched off | Every new test is shown red without the fix, then green with it; the lead reruns the red build, not just the green one. |
| A blacked-out-planet bug took hours of guessing until env-var debug traces (why a body is resident, probes of big bodies) named the missed call in minutes | Build cheap env-var-gated traces for each subsystem's "why" (why resident, why culled, why rejected) before the second guess. |

## Testing and measurement

| What happened | Rule |
| --- | --- |
| Seven CI rounds chased a web build that "never reached its first frame" on the runner; the game was running fine. A PR's CI builds the PR merged with main, main had switched its main scene, and the ready flag lived in the old scene | Before guessing at a CI-only failure, merge `origin/main` locally and rerun the same check. Put signals that tools wait on (web ready, bot hooks) in an autoload, never in one scene. When artifacts are unreachable, print the evidence (a JPEG screenshot as log lines) on the first failure, not the fifth. |
| Caching the Playwright install in CI saved almost nothing; the boot check stayed at 19 s. Phase timings showed each screenshot cost 6-10 s on the 2-core runner with software GL. | Time phases before optimising a CI step. Browser checks take one screenshot at the game's native size and gather extra evidence only on failure. |
| main requires `unit`, `lint`, `sims`, `lab`, `build` and agent PRs auto-merge on green. | Never add `paths-ignore` to the `pull_request` trigger: a skipped workflow never reports its required checks and the PR can never merge. Agents enable auto-merge on their PRs instead of waiting for a person. |
| Sims ran in real time: `run_sims.sh` launched the scene without `--fixed-fps`, so 1,500 physics ticks of room wake took 30 s of wall clock (0.8 s CPU) and were the long pole of `check_all` (41 s) and CI | Every headless scene that steps physics runs with `--fixed-fps 60` (disables real-time sync). Same results, sims 30 s -> 0.4 s, `check_all` 41 s -> 10 s. |
| Feel bugs were found by the player, not by us | Build the debug layer and the bot before content: tunables, debug frame, snapshot/replay, recorder, overlay, lab, bot. |
| A fix looked plausible but the bug predated the changed code | Check git history for when a bug first appeared. |
| A lab WARN almost undid a design choice the player wanted | Check a WARN against the player's stated wishes before tuning it away. |
| Evaluators reported bugs that were capture artefacts (a bot teleport wiped open state; a UI element caught mid-fade) | Before fixing an evaluator finding, reproduce it in the live scene; bots wait for open state to settle before teleporting. |
| Balance work started from stale numbers after an AI change | Re-measure the baseline on the current tree before tuning; numbers go stale after any AI or physics change. |
| A bot run hung 15 min and wrote 334 MB: another worker's half-saved shared script failed to parse, so every tick errored | Watch a long bot run's log size or error lines, not just its exit; re-run balance after a shared script stops changing. |
| Mid-run restore of a physics match diverged (0.2 m after 1 s) though idle restore and fresh starts were exact | Record runs as seed + inputs from tick 0 and replay from the start; treat mid-run restore as approximate. |
| A bot tool reported a false "crash" on big outputs | Under `set -o pipefail`, `echo "$out" \| grep -q` fails when grep exits early (SIGPIPE). Use a here-string: `grep -q pat <<<"$out"`. |
| Per-frame timing was noisy and misleading: a first run after `--import` was 4x slower, a gap shrank on rerun, and with `--fixed-fps` and vsync off game time ran faster than wall time | Warm up before measuring and rerun a gap twice before hunting it. Report game time and wall time. Time frames with `Time.get_ticks_usec()` in a lowest-priority node (mean, p95, max) and track the worst frame per match. |
| Heavy GPU/CPU jobs run in parallel on one laptop distorted each other's results | Run heavy jobs one at a time on one machine. |
| Screenshots were black three times for three different reasons: no GPU on the runner service, a failed material, wrong exposure | Grade every capture automatically (mean, black %, verdict) and fail on BLACK. Split the cause in one round with console overrides: exposure off, unlit view mode. |
| Screenshot runs measured a 45-90 ms hitch that was the editor compiling a missing shader permutation, not the game | After every camera cut a capture waits in a warm phase: at least N frames, then M quiet frames (no pending shader or asset compiles, no render-state churn), with a timeout, and logs the wait. Measure only after it. |
| Game data in `game/data/*.json` is not a Godot resource, so exports would have shipped without it (empty catalog) | Every export preset's `include_filter` lists the data globs; check an exported build shows real data before handing it over. |
| A saved RNG state came back different after a JSON round trip (64-bit int stored as a double), so the next reliquary changed after a restart | Store 64-bit values (RNG state, big hashes) as strings in JSON, and test save-then-load by comparing the next random outcome. |

## Physics and gameplay

| What happened | Rule |
| --- | --- |
| Same-seed physics runs split late in about 40% of fresh runs; a second match in one process always diverged | Jolt's contact order is thread-dependent: sort contacts before first-per-key debounce, and run each same-seed repeat in a fresh process. |
| A dynamic prop with a one-sided layer/mask became an immovable block that pinned a character for 40 s | Give dynamic props symmetric masks, or no layer at all; never one-sided. |
| A win rule had no fallback for its zero case, so every time-out of one match type was a draw | Every judge or scoring rule needs a fallback when its main measure is level. |

## Rendering and art

| What happened | Rule |
| --- | --- |
| The 2D-only web engine (built with `deprecated=no`) failed in the browser on `Image.create()` while desktop and tests passed | Use `Image.create_empty`; lint rule `no-deprecated` catches it; after a template change, load the web build in headless Chromium before shipping (`tools/web_smoke.mjs`, run by the CI `web` job). |
| A GPU glitch was blamed on a guess | Sample screenshot pixels and reproduce first. If it can't be reproduced, ship toggles. |
| A `-s` render script couldn't see autoloads | `load()` game classes inside a deferred call. |
| Shader compile failed: `MODELVIEW_MATRIX` used in a fragment shader; a disc rendered culled | `MODELVIEW_MATRIX` is vertex-only (use `VIEW_MATRIX * MODEL_MATRIX` in fragment); Godot front faces wind clockwise. |
| Hand-built meshes were inside out but looked fine in previews (previews draw both sides) | Check face direction numerically (normals against the outward direction) on any hand-built mesh. |
| Match-start hitches from first-use shader compiles (Godot 4.4+ ubershaders precompile only what is loaded at load time) | Instance every effect resource once off-screen at match start; keep GPU perf on real hardware (xvfb skews GPU frame times) and CI on draw calls, primitives and script time. |
| A humanoid character was rebuilt ten times (code lofts, Blender, Houdini, polish passes) and still read as a placeholder | Never sculpt humanoids in code. Start from a creator-made or licensed model on a standard humanoid skeleton; follow `docs/character_creation_lessons.md`. |
| The CI runner runs as a service with no GPU: offscreen captures were black at 0.2 fps | Take screenshots in the owner's desktop session (Remote Control or a desktop runner), never from a service-account runner. |

## Assets

| What happened | Rule |
| --- | --- |
| The cloud proxy blocked many asset sites, discovered late | On day one, test-download one file from each asset source; if blocked, fetch through the owner's machine into an asset branch. |
| An asset's polish was thrown away by the game's loader | Before building an asset the game will use, read the importer or loader code and check which data survives it. |
| Two instances of one glb shared a cached `Mesh`; per-instance override materials errored at teardown | Duplicate an instanced glb's mesh before setting surface override materials. |
| A local Godot version bump rewrote every `.import` file | Never commit that churn; revert the `.import` files before staging. |

## Online

| What happened | Rule |
| --- | --- |
| Secrets (online service client keys) must ship in builds but not in a public repo | Keep them in a git-ignored `config/*credentials*` file injected by the export script; never write them to memory or docs (`docs/online.md`). |
| `x as RigidBody2D` on a freed node raised "Trying to cast a freed object" twice in ShopRoom2D (slides, then the wake plan), even with an is_instance_valid check right after the cast | Call is_instance_valid on the raw Variant before any `as` cast of a node that a scheduled step may outlive. |
| The web engine was 27 MiB, over Cloudflare's 25 MiB per-file limit, though the game only uses a few engine modules | Size engine changes as trial builds (`web_template.yml` variant + extra flags) beside the live one, then gate them on the boot + bot + native-hash check before switching. size_extra plus unused modules off: 27.2 -> 19.1 MiB, same hash. |
