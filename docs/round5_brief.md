# Round 5 brief: polish what we added, the Collector, ectoplasm upgrades, sound for everything

Curtis (2026-11-18 20:30 PT): "start another round on this game polish and develop it further". Four workers build in
parallel with strict file ownership. Read CLAUDE.md, docs/core_brief.md, docs/occult_brief.md,
docs/engagement_brief.md, docs/horror_polish_brief.md and docs/lessons_learned.md first. Do not commit; the lead
integrates.

## New features (contract)

### The Collector (night-5 boss)
- `game/data/collector.json`: `{name, lines: {arrive, want, pleased, refused, curse}, wants: [{curse or category, text}]}`.
- On night 5 the first customer is always **the Collector**, a buyer with `boss: true`. At night 3 start, the run
  rolls (seeded) one `want`, announced through `collector_omen {text, night}` so the player has two nights to find it.
- When he arrives: `collector_arrives {want_text, line}`. Selling a matching held item pays `value *
  collector_pay_mult` and grants a legendary-or-rare curio find (`found`), then `collector_pleased`. Passing, or
  holding nothing that matches, gives `collector_refused`: he lays a parting curse (`dread += collector_curse_dread`)
  and takes `collector_toll_frac` of your cash.
- Tuning: `collector_pay_mult`, `collector_curse_dread`, `collector_toll_frac`. The bots sell to him when they can.
  The lab keeps all five feel targets at haunting 0 (greedy survival is at 0.38 against a 0.40 cap, so watch it).

### Ectoplasm and the altar (meta upgrades, earned only, never sold)
- Every finished run earns ectoplasm: `ecto_per_night` for each night survived, plus `ecto_win_bonus`, times
  (1 + 0.1 * haunting). Saved on the profile, with a version bump; older files still load.
- `game/data/upgrades.json`: about 8 upgrades `{id, name, text, cost, max_rank, set/mul or flag}`. Examples: an extra
  shelf slot, a starting spell slot (pick a known spell to start with a cast), +1 cast per night, tells more likely
  (tell_chance), a cheaper first rent, a 6th tool "the Pendulum" that reveals whether an item is cursed (yes or no,
  never which curse), keep one curio find on a loss (finds are banked anyway, so this keeps cash instead: start the
  next run with 10% of the final cash), and an altar candle that lowers starting Dread.
- `Upgrades.apply(tun, profile_ranks) -> Dictionary` (overrides plus flags), applied through the same opts and
  override path as hauntings and omens, so replays stay equal (record the ranks in RunRecording).
  `Upgrades.buy(id, profile)` returns ok or why not.
- The lab reports upgrades off (the targets) and an INFO line with every upgrade maxed.

## Ownership
- **Logic** (game/logic, game/data, tuning.gd, logic tests, lab, core_brief): the Collector, ectoplasm, upgrades,
  the Pendulum tool (`inspect` with tool "pendulum" when the flag is on: event `inspected` with `tell` "cursed" or
  "clean"), and bot support.
- **UI** (game/ui, game/shop, UI tests and sheets):
  - The **altar screen** from the title: candles, an ectoplasm counter, upgrade cards with rank pips, a buy
    animation.
  - The **Collector** arrival card (DISPLAY font, slow ink-bleed) and his want on the request board from night 3.
  - Polish fixes:
    - Omen cards: use the empty lower half for an illustration slot (SpriteKit.omen_art(id) if it exists, otherwise
      a glyph) plus the upside and downside split into two coloured lines.
    - Table cash readout in sync with the HUD.
    - Spell slots less cramped.
    - "No omen" lit from the start.
    - Enter flips before it picks.
  - **A scripted playthrough capture** `tests/shots/playthrough.gd`. It drives the real ShopGame with ShopBot-like
    decisions through a whole run (omen pick, casts, table games including Pairs, a request, the Collector, run end,
    altar) and saves one frame per milestone into a contact sheet. Use it to verify the live events, not hand-built
    ones.
- **Art** (game/room2d and its tests and sheets):
  - The **Collector** sprite: 72x110, 4 frames. A tall figure in a long coat with a velvet case of tiny drawers,
    unsettling and elegant.
  - `omen_art(id)` at 48x40 for the 12 omens in game/data/omens.json.
  - An altar texture at 96x64 and an `upgrade_icon(id)` at 16x16 (read upgrades.json at call time and fall back by
    hash).
  - A pendulum tool prop.
  - Fixes:
    - The croupier reads skeletal and flat: make him pale and gaunt with shaded arms and coat.
    - Customer hands are identical across types: vary them per body plan.
    - Untangle the marionette strings.
    - Make the Dread 0.5 eyes bigger and lower.
    - The full-scare wake silhouette is tiny on flat red: make it larger, with a textured red and a vignette.
    - Make the banish icon less muddy.
    - Make glamour, banish and glimmer FX more visible.
    - Re-check the curio icons against the real 24 names.
  - In the room: the Collector's arrival (lights gutter, a cold draft of particles).
- **Audio** (game/audio and its tests, tools/render_sfx.sh):
  - New SfxSynth recipes and SfxPlayer.on_events cases for: cast (one per spell, sharing a voice), backfire, found
    page, found curio, found_hint whisper, dice roll, card deal, card flip, wheel tick and settle, the Pairs match
    chime and miss, item staked win and lose, lot unwrap, table_open (a low organ chord), request pinned, request
    done stamp, request failed tear, omen card flip, the Collector arrival motif, collector_pleased and refused,
    altar buy, and the haunting unlock bell.
  - Keep the total synth build under 1.5 s (it is lazy now; check sfx_dump timing).
  - Render a preview zip to /mnt/project-files/audio/sfx_preview.zip (same path as before, overwrite).
