# Room brief: the 2D shop room (replaces the 3D room, 18 Nov 2026)

Curtis chose full 2D: a side-on pixel-art pawnshop. Same job as the 3D room (docs/room_brief.md): the room the run
plays in, and the wake is the clip moment that must read in 3 s with the sound off. Game rules, saves, links and
replay are pure logic and do not change.

## Ownership (one class_name space: prefix file-local helpers as noted)
- Worker A (room): `game/room2d/shop_room_2d.gd` and any other new `game/room2d/*` file EXCEPT `sprite_kit.gd`;
  `tests/unit/test_room2d_*.gd`; `tests/sim/sim_room2d_wake.gd`; `tests/shots/room2d_sheet.gd` (+ .tscn if needed).
  Helper prefix `r2_`.
- Worker B (sprites): `game/room2d/sprite_kit.gd` (stub exists; keep its API), `tests/unit/test_sprite_kit.gd`,
  `tests/shots/sprite_sheet.gd`. Helper prefix `sk_`.
- Lead: `game/shop/shop_debug.gd`, `project.godot`, `tests/sim/sim_suite.gd`, deleting `game/room/` (3D). Report the
  lines you need there; do not edit them.
- Reuse, do not edit: `game/room/room_palette.gd` (`RoomPalette`: 16 colours + palette/dither shader). The lead moves
  it into game/room2d/ after you finish.

## Pixels and axes
Native canvas 480x270, nearest filter, shown at an integer scale behind the full-resolution debug UI (a CanvasLayer
at layer -10, as ShopRoom did). Pixels, Y down. Side-on view: floor line at about y=230, counter in the foreground
across the lower third (top at about y=170), shelves on the back wall, door at the left edge, the customer stands
behind the counter so only head and shoulders show above it. 2D physics at 60 Hz (Godot Physics 2D,
single-threaded web).

## SpriteKit API (`game/room2d/sprite_kit.gd`, static, pure: no Node, seeded only by its arguments)
- `object_texture(id: String, category: String) -> ImageTexture`: one pixel-art object, at most 32x32 with a
  transparent background, readable at 1x. Same id gives the same pixels every time.
- `customer_texture(look: Dictionary) -> ImageTexture`: a hooded figure, head and shoulders, about 48x64.
  `look` is a customers.json row: `cloak` and `eyes` are hex colours, `height` scales the figure (0.7..1.3).
  Never a detailed humanoid face: a dark hood with two glowing eyes.
- `tool_texture(tool: String) -> ImageTexture`: "uv", "scale", "listen", "touch" icons/props for the counter.
- `card_texture(card_name: String, face_up: bool) -> ImageTexture`: a tarot card, about 24x40.
- `tile_texture(kind: String) -> ImageTexture`: "wall", "floor", "shelf", "counter", "door" (tileable, 16x16 or
  32x32).
- Colours come from `RoomPalette.colors()` (the 16-colour occult palette); outline every sprite in the darkest
  colour so it reads on any background. Draw with Image.set_pixel/fill_rect only.

## ShopRoom2D API (`game/room2d/shop_room_2d.gd`, `class_name ShopRoom2D`, extends Node, builds in code)
Same contract as ShopRoom, so the debug shop swaps one class:
- `setup(run: RunState)`, `apply_events(events: Array[Dictionary])`, `set_dread(v: float)`, `wake(seed: int)`,
  `dither_enabled: bool`, `prop_count() -> int`, `is_waking() -> bool`, signal `wake_finished`.
- Events (docs/core_brief.md): customer (figure walks in from the door, dressed by `tid` via customers.json; a speech
  line in a small pixel bubble for 2 s), passed/left/bought/sold (walk out; bought puts the object sprite on a shelf,
  sold takes it), inspected (a 1 s tool effect over the counter object: UV violet glow and hidden marks, scale
  tipping, listen rings, touch frost), wager (card flips on the counter), wake, night_start/night_end (light up/down),
  run_won/run_lost.
- `set_dread`: candle flicker and a green fog layer grow with Dread.
- `wake(seed)`: about 4 s of chaos, deterministic per seed: shelf objects become RigidBody2D and are thrown, one
  shelf tips over, lights die and return red, the door slams, screen shake. The wake event's `broke` item shatters
  into pixel shards. Seed from the event like ShopRoom did (run seed, night, dread).
- Lighting: CanvasModulate for the room tone plus PointLight2D candles (Compatibility supports 2D lights).
- Post: draw the 480x270 SubViewport through `RoomPalette.make_shader()` (palette + Bayer dither, toggle).

## Fast iteration (use these; they are the point)
- `tests/shots/room2d_sheet.gd` (Worker A): one headless-capable command renders a labelled contact sheet PNG of
  room states into one image: calm empty, calm with 10 props, each of the 4 tools, card flip, 3 customer types,
  Dread high, wake at 0.5 s / 1.5 s / 3 s. Run: `xvfb-run -a godot --path . -s res://tests/shots/room2d_sheet.gd`
  -> `/tmp/shots/room2d_sheet.png`. One image read checks everything.
- `tests/shots/sprite_sheet.gd` (Worker B): every object (40), customer type (12), tool, card and tile on one
  labelled sheet at 2x -> `/tmp/shots/sprite_sheet.png`.
- Budget: at most 3 sheet renders each. Run only your own tests while iterating; one full `tools/run_tests.sh` and
  `tools/lint.sh` at the end. No lab runs (balance is unchanged).

## Tests
- Worker A: unit: every event kind applies without error before and after setup; prop count follows inventory;
  customer dressed by tid. Sim `sim_room2d_wake`: after wake every body stays inside the room bounds and above the
  floor, rests (speed < 2 px/s) within 8 s, and two wakes with the same seed end within 1 px.
- Worker B: every object id in game/data/objects.json gets a non-empty texture with transparent corners; same id
  twice gives identical bytes; different ids differ; all colours used are palette colours.
