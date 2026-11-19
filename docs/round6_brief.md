# Round 6 brief: regulars with stories, the Ledger of Deeds, curios on display, a guided first night

Curtis (2026-11-18 21:49 PT): "go ahead with another round". This round targets **first-hour retention** (a guided
first night), **reasons to come back** (regulars whose stories continue across runs, deeds to earn), and **making
collectables visible** (curios on a display shelf in the shop). It also fixes the known weak spots from round 5.
Three workers build in parallel. Read CLAUDE.md, docs/core_brief.md, docs/round5_brief.md,
docs/horror_polish_brief.md and docs/lessons_learned.md first. Do not commit; the lead integrates through a PR.

## Contract

### Regulars (story arcs across runs)
- `game/data/regulars.json`: 6 regulars `{id, name, tid (a customers.json type to look like), chapters: [{line,
  kind: "seller"|"buyer", item_id or category, curse or "", outcome_lines: {done, refused}, reward: {kind, id} or
  {}}]}`, each with 3-4 chapters. Each arc is a tiny spooky-funny story told through what they sell or ask to buy.
  Examples: the widow who keeps selling back the same music box that keeps coming home; a boy whose grandfather's
  voice is in a radio; a priest losing a bet with something; a magician whose assistant is still in the box.
  Original writing, gentle horror, no gore.
- Profile: `regulars: {id: chapter_index}`. One regular visit per run at most, on night 2-4 (seeded,
  `regular_chance` Tuning). It plays the next chapter for a regular whose arc is unfinished. Doing what the chapter
  asks (buy the item, or sell them a matching item) advances the arc. Refusing still advances it, but the story
  branches through `outcome_lines`.
- Events: `regular {id, name, chapter, line}` (alongside the usual customer event; the customer has `regular: id`),
  `regular_done {id, chapter, line, reward}`, `regular_refused {id, chapter, line}`. Finds go to `run.found`.
  `PlayerProfile.record_result` advances `regulars` from `run.regular_progress`.

### Ledger of Deeds (achievements, later mirrored to Steam)
- `game/data/deeds.json`: about 30 deeds `{id, name, text, secret: bool, check}`, where `check` is a small rule
  object evaluated by `Deeds.check(run, profile) -> PackedStringArray` (the newly earned ids). Supported rule kinds:
  `{won: true}`, `{haunting_at_least: n}`, `{wakes_at_least: n}`, `{cash_at_least: n}`, `{spells_cast: n}`,
  `{table_wins: n}`, `{pairs_perfect: true}`, `{collector: "pleased"}`, `{requests_done: n}`, `{curios_owned: n}`,
  `{set_complete: id}`, `{regular_finished: id}`, `{omen: id, won: true}`, `{daily: true}`, `{no_tools: true, won:
  true}`, `{all_cursed_held: n}`. RunState keeps the counters these need (spells_cast, table_wins and so on) and
  includes them in its snapshot.
- Profile: `deeds: PackedStringArray`. `record_result` returns `deeds_new` too.

### Guided first night
- `Tutorial.script() -> Array[Dictionary]`: the first run ever (profile flag `tutorial_done` false) uses a fixed seed
  and a scripted night 1. It brings a fixed sequence of customers (a seller with a clean item, a seller with a
  cursed item and an obvious UV tell, a buyer), with `tutorial: step` on customer events. RunState opts gets
  `tutorial: true`, which applies the script. Hints come from `tutorial_step {step, text, focus}` events, where focus
  is a UI id: "tools", "offer", "buy", "pass", "shelf", "dread", "spells" or "table".
- Night 1 is safe in the tutorial: no wake, and rent covered by a starting purse. After night 1 the run continues
  normally. Finishing the tutorial run, or pressing Skip on the title, sets `tutorial_done`.

### Balance
- With every upgrade maxed, cautious survival at haunting 0 is 0.97, which is too easy. Retune upgrade strengths and
  costs so maxed cautious survival is at most 0.80 and greedy at most 0.65. Haunting 0 with no upgrades keeps all
  five feel targets.
- Report the expected number of runs to max every upgrade (average ecto per run from the lab). Aim for 15-25 runs.

## Ownership
- **Logic**: game/logic/*, game/data/*, tuning.gd, the logic tests, tests/lab and core_brief.md. Build regulars,
  deeds, the tutorial script, the counters and the balance above. The bots handle regulars (do the chapter if
  sensible). The lab ignores the tutorial.
- **UI**: game/ui/*, game/shop/*, the UI tests and tests/shots/* (except the sprite and room sheets).
  - A **Ledger of Deeds** page (title and pause): a parchment ledger with earned deeds inked and secret ones as
    "????". A toast when one is earned mid-run or at run end: a wax seal stamps, ink writes the name, a small sound
    through sfx.ui("deed").
  - **Regulars**: a portrait-and-name card when a regular arrives ("THE WIDOW MARCH, chapter 2"), and a "Regulars"
    page listing their arcs so far (lines already seen, next chapter "...").
  - The **tutorial**: an overlay that dims everything except the focused UI element, with a quill pointer and the
    hint text in a parchment note. The Skip tutorial option goes on the title for first-time players.
  - Fixes: make the altar buy animation readable at 1x (a bigger wisp, a flash on the card, the rank pip igniting).
  - Extend `tests/shots/playthrough.gd` with the tutorial night, a regular visit and a deed toast.
- **Art**: game/room2d/*, test_sprite_kit.gd, test_room2d_*, and the sprite and room sheets.
  - **Curio display shelf**: a glass-fronted cabinet on the left wall showing up to 12 owned curios (curio_icon)
    with a soft glint. `room.set_displayed(ids: PackedStringArray)` is called by the UI at run start. Make room on
    the wall for it.
  - `regular_portrait(id) -> ImageTexture` at 32x40 for the 6 regulars (read regulars.json at call time, with a
    fallback).
  - `deed_seal(id)`: a 20x20 wax seal (colour by hash).
  - Fixes:
    - The Collector's face reads like a skull: give him a gaunt but living face with spectacles.
    - The drawer case reads as red bricks: make it a velvet case with brass drawer pulls.
    - The blind_lamp and deaf_ear omen art is murky.
    - The Dread 0.5 eyes should sit low, in the shadows under the counter or the shelves.
  - In the room, a regular stands out slightly: a faint warm rim light while they are the customer (customer event
    with `regular`).
- **Audio** is folded into UI: add `deed` and `regular` UI kinds only if SfxSynth recipes for them exist. Otherwise
  reuse `haunt_unlock` for deed and `request_pinned` for regular, through sfx.ui.
