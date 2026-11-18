# UI brief: the pixel-art game screen (replaces the debug panels for players, 18 Nov 2026)

Curtis wants everything 2D. The run already plays in `ShopRoom2D` (docs/room2d_brief.md); the controls are still the
debug Control panels in `game/shop/shop_debug.gd`. Build the player-facing screen: `ShopGame`.

## Ownership
- UI worker: `game/ui/*` (new: `shop_game.gd` + `shop_game.tscn`, `pixel_font.gd`, any helpers),
  `tests/unit/test_ui_*.gd`, `tests/shots/ui_sheet.gd`. Helper prefix `ui_`.
- Lead: `project.godot` (main scene switch), `game/shop/shop_debug.gd` (stays as the dev scene), `game/room2d/*`,
  `game/logic/*`. Report needed changes there; do not edit them.

## Flow to copy (read `game/shop/shop_debug.gd`, keep the same behaviour)
Every command goes through `rec.drive(run, cmd)` (RunRecording); then `PlayerProfile.save_run(run, rec.to_dict())`
unless `Flags.is_scripted_run()`; resume a saved run on launch (`PlayerProfile.load_run`); gift link in the page URL
(`#gift=`) or pasted; end screen with the pass-on code from `PassLink`; "Replay the wake" (same logic as
`ShopDebug.start_replay`); won runs give a free reliquary via `RelicShopPanel.reward_run`. Add `TuningPanel` (F1),
`DebugOverlay` (F2), `RelicShopPanel` (F3), `FrameStamp`, `RenderToggles` as ShopDebug does. Room: `ShopRoom2D`
created and fed exactly as ShopDebug does.

## Look
- Everything drawn at the room's native 480x270 pixel grid, so UI pixels match the art. Put the HUD in the same
  SubViewport as the room or in its own 480x270 SubViewport scaled the same way. Colours only from
  `RoomPalette.colors()`; panels are 9-slice frames drawn with Image (dark wood/bone border).
- Text: a procedural bitmap pixel font (`pixel_font.gd`, 5x7 glyphs or similar, ASCII 32-126, drawn from a
  hard-coded bit table; no font files, nothing licensed). Expose it as a Godot `Font` (e.g. FontFile with glyph
  images) so Labels can use it, or draw text yourself with `draw_texture_rect_region`. It must be readable at 1x.
- Short words, spooky-funny tone. No walls of text.

## Screen
- Top strip: night N/5, clock, cash, rent due, Dread meter (fills toward the wake threshold, pulses near it).
- Seller at the counter: the four tool icons on the counter are the inspect buttons (SpriteKit.tool_texture);
  under them an offer row: coin amount with -/+ (hold to repeat; mouse wheel), Offer, Buy at ask, Pass. Tells found
  appear as small notes pinned by the counter. Estimate shown as a price tag "~27 +-50%".
- Buyer at the counter: they want a category; held items of that category on the shelves glow; click one to see
  its sale price, click again to sell; Decline button.
- Tarot: the deck on the counter is clickable; a stake chooser like the offer row, max `run.max_wager()`.
- Every action also has a key: 1-4 tools, Left/Right offer, Enter offer, B buy, P pass, T tarot, R replay.
- Log: the last 3 event lines (ShopDebug.sd_event_text) in a small parchment strip; customer lines go in the
  room's speech bubble already.
- Night end / wake / win / loss: big pixel title cards for 2 s. End screen: result, the pass-on code with Copy, a
  field to paste a friend's link, New run.
- Mouse and keyboard; buttons have hover and pressed states; works at 1280x720 and 1920x1080 (integer scale
  where possible, letterbox with the darkest palette colour).

## Fast iteration (use these)
- `tests/shots/ui_sheet.gd`: one command renders a labelled contact sheet of UI states (seller, after an inspect
  with a tell, buyer with glowing shelf item, tarot stake, night card, wake card, end screen won and lost) to
  `/tmp/shots/ui_sheet.png`. Run: `xvfb-run -a godot --path . --resolution 1280x720 -s res://tests/shots/ui_sheet.gd
  -- --scripted`. At most 3 renders. Look at the image each time.
- Tests: run only `tools/run_tests.sh test_ui_<name>` while iterating; one full `tools/run_tests.sh` and
  `tools/lint.sh` at the end (LINT problems=0). Unit tests: font covers ASCII 32-126 with non-empty glyphs except
  space; every key action maps to the right command; a full bot-driven run through `ShopGame.act` reaches the end
  screen and produces a pass-on code; replay works.
