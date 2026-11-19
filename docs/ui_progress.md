# Lane B (UI, UX, onboarding) step log

Full-game run, 19 Nov 2026. Plan: docs/full_game_plan.md. Newest at the bottom.

- 15a Test menu: DONE. `TestMenu` (grid, pages, scares/regular/chapter options), `TestScenes` (46 tiles, each builds a
  seeded state in a ShopGame), `TestOverlay` (strip + Dread slider), title entry "TEST MENU" (debug builds and `--dev`).
  Throwaway profile (`RelicShopPanel.no_save`, a fresh RelicStore); Esc returns. Tests: `test_ui_test_menu` opens every
  tile at both scare levels. Sheet: tests/shots/test_menu_sheet.gd.
- 16 Inspect panel: DONE. `UiInspect` card (2x art, flavour, provenance, tells so far, curse once a tell names it).
  Open with the LOOK CLOSER button, I, a click on a shelf object, or right click. Tests: `test_ui_inspect`.
- 19 Night event cards: DONE (Lane A's `night_event` event landed). Dusk card with glyph and spelled-out rules, plus a
  tag under the top bar. `UiNightEvent`, `test_ui_night_event`.
- 21 Settings: DONE. Four tabs (audio, display, game, keys), sfx/music/shake/flash/text speed/text size/colour-blind/
  window scale, key rebinding for every shop action (`TsKeys`), reset. Tests: `test_ui_settings`.
- 15 Playthrough at full length: DONE. playthrough.gd now stages a real regular and deed toast through the test menu tiles when the
  policy's run meets none, and plays a loss (cash 0, pass until the rent falls). Sheet: 30 cells, no fallbacks. Bug found and fixed:
  leaving the test menu without a title left the HUD hidden (the loss cells were black).
- 20 Ending screens: DONE (UI side). `UiEndings`: four endings (debt_free, cursed, collector, regulars), full-screen card with
  epilogue, end panel heading. Reads `run_won.ending`, else infers from the run. Tableau uses `SpriteKit.ending_tableau(id)` when
  Lane C ships it, else a stand-in.
- 22 Controller: DONE. `TsPad` maps ui_* actions and pad buttons onto the keyboard path of every TsScreen (title, pause, settings,
  altar, setup, test menu, journal); shop screen has a focus ring over HUD widgets, A/B/X/Y/shoulders, button prompts.
  Test: `test_ui_pad`.
- 25 Run history data: `UiJournalLog` (last 20 runs, customers met, curses known), `test_ui_journal_log`. UI tab follows with 24.
- 24 Journal: DONE. Ledger has six tabs (grimoire, deeds, regulars, curios, bestiary, runs); runs tab lists the last 20 runs with
  a REPLAY SEED button that starts a fresh run on that seed and options. Title and pause menus say JOURNAL. `UiJournalPages`,
  `test_ui_journal_pages`.
- 23 Haggle clarity: DONE. Patience candle (hover tip with the number), mood chip after the first counter (faces + word), counter
  tells go to the log. `UiHaggle`, `test_ui_haggle`.
- 17 Larger text: PARTIAL. Text size 2x applies to the title and pause menu labels and the log; settings, tells and cards stay 1x.
- 26 Continue card on the title screen: DONE (`TitleScreen._ts_draw_preview`).
- 18 Buyer offers UI: DONE. Ordinary buyers open with `buyer_offer`; the offered shelf item glows alone with an OFFER tag, ACCEPT N
  [Enter], a counter box (starts 25% above the offer, bounded to 3x) with - / + and COUNTER [C], DECLINE [P]. Candle and mood chip show
  for buyers too; clicking the offered item opens the inspect card. `COUNTER` is a rebindable key. Collector (no offer) keeps the
  old click-to-sell path. Test menu tile BUYER OFFERS. Tests in `test_ui_haggle`.
- 27 Feedback audit: DONE for what Lane B owns. Every event in game/logic was checked for a sound (sfx_player or
  `ShopGame._feedback_sounds`) and a visual (card, log line, HUD or room). Closed items:
  - buyer_offer, night_event: sound in sfx_player; log line and card added (UI).
  - curse_copied, curse_shift, whispered_away: sounds existed, had no log line: added.
  - debt_taken: no sound, no visual: log line, card "THE TILL IS LIGHTER" and a wrong_note.
  - request_due, regular_done, regular_refused: no sound: mapped to existing sounds in `FEEDBACK_SOUNDS`.
  - inspect open/close: click on both. Every TsScreen button plays click and hover already.
  - colour-blind setting: Dread meter gains a percent and a DANGER word.
  - Open for other lanes: sfx has no `set_sfx_volume`, room has no `shake_scale` or `flash_reduce` (the settings call them when
    they appear); banished, glamoured, hexed, sealed, summoned have no own sound beyond cast_<spell>.
- Coordinator hooks: DONE. Copy diagnostics button (game tab, `DiagLog.copy_report`), `DiagLog.context` set by shop_game, title music on
  return to the title, title live backdrop (`room.set_title_mode`, on while the title shows), EndingArt tableaux in the ending cards,
  Daily themes through `Daily.opts_for_date`, a title notice when `PlayerProfile.last_load` is "reset". Music is driven by SfxPlayer events
  already, so no extra track switches in shop_game. Lazy HUD build: NOT done (risk against the schedule).
- Test menu: new groups CURSES (4 new curses), MUSIC (every track with its three layers), tile BUYER OFFERS. Bug fixed: `TestScenes.build`
  re-synced the room after every tile, wiping wakes, which is why the possession tile never fired. `test_wake_tiles_fire_their_wake_type`
  now proves each wake tile starts its wake. Ending card lacked `age` (crash on the card tick): fixed and tested.
- Render check: tests/shots/buyer_shot.gd (offer, then the counter): ACCEPT/counter box/COUNTER/DECLINE, OFFER tag, mood chip and tell line read.
