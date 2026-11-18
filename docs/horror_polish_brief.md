# Horror polish brief (art round, 18 Nov 2026)

Curtis: "go hard on a polish round for the art, make it more horror, or friendly to horror experience".
Direction: dread over gore. The shop should feel unsafe to stand in: deep darkness with small pools of warm
candlelight, things in the corners that were not there a moment ago, customers who are slightly wrong. Keep it
readable and fair (tools, prices and tells must stay clear) and keep the dark-funny voice in the text. No blood
splatter or body horror; implication beats explicitness. Everything stays procedural (code-drawn), palette-locked,
deterministic where it touches gameplay, and cheap on a single-threaded web build (p95 frame <= 20 ms).

## Shared rules
- 480x270 native canvas; `RoomPalette` is the palette (owned by the room worker; others read it only).
- Any random visual must use a seeded RandomNumberGenerator (lint bans global randf()). Scares that depend on run
  state key off RunState values (dread, night, wake_nights), never the wall clock.
- A "Scares" setting (owned by the UI worker, stored in TsSettings) with values full / gentle. Gentle keeps the
  mood but drops sudden flashes, loud stingers and screen-filling faces. The room exposes `scare_level: int`
  (0 gentle, 1 full) and reads nothing else from settings.
- No deprecated Godot APIs (the web engine is built with deprecated=no).
- Budget: run only your own tests while iterating; at most 3 contact-sheet renders, look at each; one full
  `tools/run_tests.sh` + `tools/lint.sh` at the end (both pass). No lab.

## Room worker (`game/room2d/shop_room_2d.gd`, `game/room2d/room_palette.gd`, new `game/room2d/*` files except
sprite_kit.gd; `tests/unit/test_room2d_*.gd`; `tests/sim/sim_room2d_wake.gd`; `tests/shots/room2d_sheet.gd`)
- Lighting: much darker base (CanvasModulate), candle pools with soft falloff and slow breathing, a cold moonlit
  window, deep shadows under shelves and the counter; vignette and fine film grain in the post shader; palette
  retuned toward colder darks (keep 16 colours, keep amber/bone for readable UI and items).
- Dread escalation (driven by set_dread): 0.3 candles gutter; 0.5 a pair of eyes opens in a dark corner and closes
  when the customer speaks; 0.7 a shelf object turns to face the counter, portraits' eyes follow, a shadow passes
  the window; 0.9 breathing fog, the door rattles, a figure stands motionless outside the window.
- Wake: lights cut to black for a beat, a single red flicker shows a tall silhouette behind the counter (full
  scares only; gentle shows it dimly without the flash), then the chaos as now. Keep the sim passing.
- Idle life: dust motes in candlelight, a slow clock pendulum, a moth at the window.
- Contact sheet: add cells for dread 0.3 / 0.5 / 0.7 / 0.9 and the wake silhouette at full and gentle.

## Sprite worker (`game/room2d/sprite_kit.gd`, `tests/unit/test_sprite_kit.gd`, `tests/shots/sprite_sheet.gd`)
- Customers: taller, gaunter silhouettes, uneven shoulders, long pale fingers resting on the counter, eye glints
  that differ per type (pinpricks, hollow, too many). Add `customer_frames(look) -> Array[ImageTexture]` (2-4 idle
  frames: breathe, blink, head tilt) without changing existing signatures.
- Objects: grime, cracks, tarnish and age on everything; add `object_cursed_overlay(id) -> ImageTexture` (a faint
  wrongness: hairline crack glowing, a hidden face, a fingerprint smear) the room can show once a tell is found.
- New props for the room worker to use: `horror_texture(kind)` for "eyes", "portrait", "silhouette", "hand",
  "moth", "clock" (sizes in the doc comment).
- Tiles: stained wallpaper with peeling seams, warped floorboards with dark gaps, a door with scratches.

## UI worker (`game/ui/*`, `tests/unit/test_ui_*.gd`, `tests/shots/ui_sheet.gd`, `tests/shots/title_sheet.gd`)
- Frames: aged parchment and blackened wood, worn corners, faint stains; buttons press like old brass.
- Type: keep the 5x7 font readable; add a jitter/flicker style for titles and a slow ink-bleed reveal for title cards
  ("SOMETHING WOKE", night cards).
- Title: near-black room, one candle, the title fades up; eyes open in the dark after a few seconds; the menu
  cursor is a small flame.
- HUD: Dread meter becomes a candle that burns down/gutters with Dread; the hint and log strips look like notes in
  a ledger.
- Settings: add "Scares: full / gentle" (persisted) and pass it to the room as `room.scare_level`.
- Sheet cells for the new frames, title sequence, title card reveal, and the settings row.
