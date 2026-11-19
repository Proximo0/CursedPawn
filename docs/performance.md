# Performance: how to measure

The method that took Sandblood (a gore-heavy physics fighter) from 726 to about 250-340 draw calls and its worst-case
effects script time from 67 ms to 34 ms at high quality, without guessing. Numbers here are examples; each project
keeps its own table at the bottom of this file.

Target: 60 fps on a mid PC and on mid Android phones (Compatibility / GLES3).

## The harness: `tools/perf.sh` + `tests/perf/perf.tscn`

Build one per project once there is a level and a bot. Shape that worked:

`tools/perf.sh [--quality=0|1|2|all] [--seed=S] [--measure=FRAMES] [--heavy] [--hide=part1,part2,...]`

1. **A presented, deterministic scene.** One bot-vs-bot match (or a bot run of a level) with full presentation (level,
   crowd, effects, HUD) in a real window: xvfb on Linux, a tiny resolution (320x180) so the software rasteriser does
   not dominate. Fixed seed so runs compare.
2. **Fast-forward to a state, not a time.** Run at a high time scale until an observed condition holds (for example
   `decals >= 60 and tick >= 600`, or the match ends), with a tick fallback. Then measure N frames (300) at 1x.
3. **A scripted worst case (`--heavy`).** When the measured window starts, inject the most expensive events at once
   (every gore effect on both fighters, every particle burst). Budgets are set against this, not the average.
4. **Toggle parts off (`--hide=`).** Switch one part off during the measured window (crowd, HUD, shadows, effects,
   characters, props); whole scene minus that run is that part's cost in draw calls and triangles.
5. **One row per quality level** (`--quality=all`), printed in a quiet table.

## What to report, and what not to trust

| column | meaning |
| --- | --- |
| frame ms p50 / p95 / max | real frames: `Time.get_ticks_usec()` between frames in a lowest-priority node, after a warm-up |
| script ms per system | each heavy system's own script time, timed apart from the renderer (the number to trust for CPU) |
| phys ms | physics time per frame |
| draw calls | per frame, including shadow passes and the HUD |
| MultiMesh triangles | instances shown x mesh triangles, counted by the harness itself |
| peaks | the counts that grow with play: decals, particles, pooled objects |
| VRAM, nodes | `Performance` monitors, once at the end |

- **Software GL frame time says nothing about a phone or a GPU.** On the cloud box (llvmpipe) engine process time is
  the renderer. Read script ms, draw calls and triangles there; profile frame time on real hardware (the owner's PC
  via Remote Control).
- **Never average `Performance.TIME_PROCESS`.** It updates about once a second with the slowest frame; averaging it
  reported 36 ms for a real 5.2 ms.
- **Godot's primitive counter counts a MultiMesh's mesh once per draw, not once per instance.** Count MultiMesh
  triangles yourself.
- **Warm up.** The first run after `--import` was 4x slower (shader compiles). Rerun a gap twice before hunting it.
  With `--fixed-fps` and vsync off, game time runs faster than wall time: report both.
- **Per-script cost without the editor profiler:** in the measured window call `set_process(false)` on scripted nodes
  and call each `_process` from one timing node, summing by script path.
- CPU ms are noisy under a shared box: read ratios, run heavy jobs one at a time on one machine.

## Budgets

Write budgets per quality level from the worst-case table, and keep low Android-safe. Example shape (Sandblood,
software GL, so treat CPU ms as 3-5x a desktop):

| budget | low | medium | high |
| --- | --- | --- | --- |
| worst-case effects script ms per frame | <= 8 | <= 15 | <= 35 (desktop) |
| draw calls, whole scene | <= 250 | <= 320 | <= 400 |
| MultiMesh triangles incl. crowd | <= 100k | <= 300k | <= 1.6M |
| VRAM | <= 32 MB | <= 48 MB | <= 64 MB |

CI can gate draw calls, triangles and script ms (they are stable under xvfb); GPU frame time stays on real hardware.

## Quality setting

One `GfxQuality.level` (0 low, 1 medium, 2 high) chosen before the scene is built (low on `OS.has_feature("mobile")`,
high on desktop), one Options picker for it, and a `--quality=N` run argument that overrides it. Every expensive
system reads it: crowd density and mesh LOD, shadow splits and distance, MSAA, effect caps, simulation rates and
texture resolution, mesh detail of instanced particles.

## Rules for new effects (each one came from a measured defect)

- Pool and cap everything per quality; never let a count grow with match length.
- A MultiMesh draws its first `visible_instance_count` instances: sort and cut instead of hiding in a shader. Do not
  hide geometry by scaling to zero in the vertex shader; the vertices are still processed.
- Gate repeated work on a changed input (a pool repainting unchanged texels cost 25 ms); hoist per-texel trig into a
  table; budget per-frame work by cost (area, bytes), not by count.
- Only big shapes cast shadows; thin decorative and small limb parts do not, at least on low.
- Many small `draw_*` calls in a HUD add up: cache segment lists and draw them with one `draw_multiline`; hide idle
  banners with `visible = false`.
- Visibility ranges (HLOD) work on `MultiMeshInstance3D`; use decimated meshes or impostors at distance (a MultiMesh
  cannot use engine mesh LOD).
- Pre-warm every effect, material and pool once off-screen during the intro: Godot 4.4+ ubershaders precompile only
  what is loaded, so first use hitches (one was 596 ms).
- Re-run `tools/perf.sh --quality=all` after adding an effect and put the new row in this file.

## Soak

Before a release, run 50+ back-to-back bot matches on real hardware and track the worst frame per match. It finds
per-match hitches (a slow match start, a first-use shader compile) that a single run never shows.

## This project's numbers
<!-- One table per pass: before/after per quality level, the scripted worst case, and what was changed. -->

### Pass 1 (19 Nov 2026, Lane D, steps 43 and 44)

Tools: `tools/perf.sh [--frames=N]` (`RES=640x360`, xvfb and software GL, the real ShopGame driven by the greedy bot, 120 frames
of warm-up, then N timed frames; also the boot phases and the first-call cost of every SpriteKit texture family) and
`node tools/web_smoke.mjs` (first frame time and requestAnimationFrame gaps in headless Chromium on swiftshader). Headless
(`godot --headless -s res://tests/perf/perf.gd -- --scripted`) skips the renderer, so it is the script and engine cost alone.
**Caveat:** the cloud host was shared with other lanes (load average 5 to 10 on 4 cores), so every number below is pessimistic
and noisy by about 2x; re-run on a quiet machine before quoting a final figure.

| measure (native) | before | after |
| --- | --- | --- |
| frame ms p50 / p95 / p99 / max, headless (script only), 600 frames | 6.9 / 19.5 / 69.8 / 170.8 | 6.9 / 12.4 / 54.4 / 92.2 |
| frames over 30 ms (all of them had an audio stream build in them) | 13 to 17 of 600 | 17 of 600 (spread out, no frame over 100 ms) |
| frame ms p50 / p95 / max, software GL 640x360 (llvmpipe) | 39 / 100 / 155 | not re-run |
| draw calls per frame, average / max | 98 to 109 / 116 | same |
| all 74 sounds, total build | 2.7 s (one 200 ms build in a frame) | 2.1 s; warm-up is paced (see below) |
| music, build of a whole track (title, shop, table, collector) | n/a | 0.67 s, 0.93 s, 0.24 s, 0.30 s |

Target p95 at or under 20 ms: **met natively on the script side (12.4 ms)**. Not met in software GL (100 ms): llvmpipe on a
loaded CPU, not the game's cost, because draw calls are about 100 a frame; check on a real GPU.

SpriteKit first-call cost (target under 50 ms): **already met, no cache needed.** Every object texture: avg 1.4 ms, worst 2.3 ms
(56 objects, 79 ms for all of them); customer textures worst 4.4 ms; tiles under 1.2 ms each; the five tool icons 5 ms in total.
The callers (ShopRoom2D, ui_inspect, ui_hud) keep their own caches, so a repeat call is free. A cache inside SpriteKit would live in
game/room2d (Lane C); it is not needed for the budget.

Where the boot time goes (headless, one run, ms): script load and autoloads 300 to 650, then `ShopGame` scene build 1700
(of which UiHud 650 plus 156 on its first frame, ShopRoom2D 356, Catalog 164, the ambient bed 150). First customer at 2.0 s after
process start natively. The UI and room numbers belong to Lanes B and C: **a lazy HUD (build the table, found and toast panels
on first use) is the largest remaining boot cost.**

What changed (all in game/audio, tools):
- Sounds are warmed one per calm frame, and a build over 25 ms is followed by 30 idle frames, so a hitch is at most about 3 percent
  of frames. The dread shimmer builds when Dread first appears, not at boot. `au_organ` is one pass instead of four voices.
- Music builds one stem per calm frame, starting 2 s after boot (the first customer comes first), each stem at the lowest sample
  rate its content allows (5.5 or 11 kHz). The title track is built while the title is up.
- Loudness normalisation costs about 25 percent of a sound's build; it samples every third sample to stay cheap.

Web (headless Chromium, swiftshader, same shared host): first shop frame at 5.8 to 8.3 s after page load in three runs (limit 15 s,
now asserted by `tools/web_smoke.mjs`, override with `SMOKE_FIRST_MS`); engine banner at 0.4 to 0.7 s; download 8.0 MB gzip.
requestAnimationFrame gaps were 770 to 920 ms (about 1.2 fps): software GL at this load cannot say anything about the web frame
time on a real GPU, so the p95 figure for the web build is **not measured** (the smoke prints it every run as a trend number).
Wasm runs GDScript roughly 2 to 3 times slower than native, so a 100 ms native build is a 250 ms hitch there: that is why audio
warm-up is paced and music is lazy.

Soak (50 matches back to back) is still to do on real hardware.
