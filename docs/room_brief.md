# Room brief: the 3D shop room (RETIRED 18 Nov 2026, replaced by docs/room2d_brief.md)

Goal: the one-room pawnshop the run plays in. Fixed camera, low-poly 3D rendered at low resolution with a limited
palette and ordered dither (handoff: "one room, fixed camera, low-poly 3D at low resolution with palette and
dither"). The wake is the main clip moment and must read in 3 s with the sound off.

## Ownership
- Room worker owns `game/room/*` (new), `tests/sim/sim_room_wake.gd`, `tests/unit/test_room_*.gd`.
- Lead owns `game/shop/shop_debug.gd` integration lines, `project.godot`, `tests/sim/sim_suite.gd` (worker reports
  the line to add).

## Units, axes
Metres, Y up, -Z forward. Camera fixed. 60 Hz physics (Godot physics, Compatibility renderer, web single-threaded).
Room about 6 m wide, 5 m deep, 3 m high. Counter across the front third; shelves on the back and side walls; door on
the left wall; the customer stands in front of the counter facing the camera.

## API (`ShopRoom`, `game/room/shop_room.gd`, extends Node3D, builds everything in code)
- `setup(run: RunState)`: fills shelves with one prop per held item.
- `apply_events(events: Array[Dictionary])`: reacts to RunState events (see docs/core_brief.md):
  customer (show the placeholder customer, a hooded cloaked silhouette, never a sculpted humanoid), passed/left/
  bought/sold (customer leaves; bought adds a prop to a shelf, sold removes it), inspected (a short tool effect on
  the counter object: UV lamp purple glow, scale tips, listen ripples, touch frost), wager (a tarot card flips on
  the counter), wake (chaos, below), night_end/night_start (lights dim/raise), run_lost/run_won.
- `set_dread(v: float)`: flicker and fog grow with Dread.
- `wake(seed: int)`: deterministic chaos for about 4 s: shelf props become RigidBody3D and are pushed off, one
  shelf topples, lights die and come back red, the door slams. Seeded so a replay looks the same.
- Props: low-poly primitives coloured by object category (placeholder until art), one per held item.

## Look
- Render the 3D world into a SubViewport at 480x270 (nearest filter) shown full screen; UI stays full resolution.
- Post shader on the viewport texture: quantise to a 16-colour occult palette (deep purples, sickly greens, candle
  amber, bone white) with a 4x4 Bayer ordered dither. A toggle (F7 is MSAA in RenderToggles; use the room's own
  `dither_enabled` flag) to compare.
- Candle-like warm omni lights, dark corners. Big shapes cast shadows only.

## Tests
- Unit: palette has 16 colours; `apply_events` with each event kind does not error; prop count follows inventory.
- Sim `sim_room_wake`: after `wake()`, every prop is still above the floor (no fall-through) after 4 s and comes to
  rest (speed < 0.05 m/s) within 8 s; two wakes with the same seed end in the same prop positions (within 1 cm).
