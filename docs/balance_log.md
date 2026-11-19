# Balance log

Measured with `godot --headless --path . res://tests/lab/lab.tscn` (300 runs per bot, seeds 1000+). Targets: run
median 15-25 min, wake by night 3 at 0.80-1.00, greedy survival 0.25-0.40, cautious 0.50-0.65, greedy/cautious
cash ratio at least 1.5. Maxed upgrades: cautious at most 0.80, greedy at most 0.65. Haunting 10: 0.05-0.15.

## Lane A progress

### Step 1: audit (2026-11-19) - done
Baseline before any new content (lab green, 0 warn, 0 fail; the playthrough capture needs a renderer and belongs to
the UI lane, so the audit uses the lab, which plays the same runs through the same logic).

| Setting | Cautious survival | Greedy survival | Notes |
| --- | --- | --- | --- |
| Haunting 0 | 0.53 | 0.37 | run median 15.5 min, wake by night 3 0.95, cash ratio 1.61 |
| Haunting 5 | 0.37 | 0.14 | |
| Haunting 10 | 0.10 | 0.11 | target 0.05-0.15 |
| Maxed upgrades | 0.77 | 0.46 | runs to max 21.1 (9.6 ecto per run unmaxed) |

Collector (haunting 0): pleased 0.17 cautious / 0.13 greedy, refused 0.58 / 0.40. Requests done 0.39 / 0.35.
Regulars: visits 0.66 / 0.55 per run. Lab takes about 17 s, not 2 s.

### Step 2: curses 9-12 (2026-11-19) - done
`costume_change` (category swaps each night, `curse_shift`), `copycat` (the next clean object bought takes the curse
once, `curse_copied`), `bashful_purse` (`night_cash_unseen` 28 only if the object was never inspected), `landlord_lullaby`
(`rent_mult` 0.8, `whisper` 0.25 chance per slot, `whispered_away`). Check: 10 tests in `test_curse_mechanics`, catalog
problems empty, lint 0. Lab: cash ratio 1.31 (WARN, below 1.5), cautious 0.60; retune in step 12.

### Step 3: objects 41-56 (2026-11-19) - done
16 objects (3 toy, 3 jewelry, 3 instrument, 3 book, 4 relic; every category now has 11-12), `text` on all 56, catalog
problems() flags a missing text. Check: `test_catalog` (2 new tests) green, lint 0. Lab: greedy 0.30, cautious 0.54,
cash ratio 1.18 (WARN, step 12). `test_sprite_kit` overlay test flickered once on the new fallback sprites and then
passed three times; it is art-lane code, so watch it.

### Step 4: customer types 13-16 (2026-11-19) - done
Seer, errand child, debt collector, twin pair (a seller and its buyer return). Check: `test_customer_types` (8 tests) green,
catalog problems empty. Full suite passes except another lane's in-progress `ui_hud.gd` parse error (not mine). Lab: greedy 0.31,
cautious 0.55, cash ratio 1.04 (WARN: debt collector and cheap child items cut greedy's cash; step 12 retunes).

### Step 5: object history (2026-11-19) - done
`Provenance` class and `provenance.json`; `item.provenance` on bought, lot, gift and start-cursed objects, merged with
pass-it-on history. Check: `test_provenance` 6 tests green. No balance effect (own RNG). Lint shows one parse error in
`game/audio/sfx_synth.gd`, another lane's work in progress.

### Step 6: night events (2026-11-19) - done
`NightEvents`, `night_events.json`, `night_event_chance` 0.35. Check: `test_night_events` 10 tests green (one per event plus roll,
fire, snapshot). `test_regulars` made robust to the debt collector (starts with 2000 cash). Lab: median 14.6 min (WARN), greedy 0.30,
cautious 0.53, ratio 1.44 (WARN); step 12 retunes.

### Step 7: wake variety (2026-11-19) - done
`wake` per curse, `wake_type` and `curse` on the wake event, door_lock forces closed. Check: `test_wake_types` 6 tests green, lint 0.
Lab not rerun (only door_lock closing changed; step 8 reruns it). `test_music` build-time budget flickers under CPU load from other lanes.

### Step 8: haggling depth (2026-11-19) - done
Moods (calm, nervous, greedy), mood lines on the customer event, smarter counters with tells. Check: `test_moods` 9 tests green; full
suite 477 passed. Lab: greedy 0.30, cautious 0.50 (low edge), cash ratio 1.38 (WARN), median 14.65 min (WARN), maxed 0.66/0.41,
haunting 10 0.07/0.06. The cumulative drift from steps 2-8 is retuned in step 12.

### Step 9: selling depth (2026-11-19) - done
Buyers make an offer on one item; `accept` and `counter` commands; bots updated (greedy accepts, cautious counters once).
Check: `test_selling` 16 tests green, full suite green apart from other lanes' audio and music tests. First lab after the change:
greedy 0.14, cautious 0.43 (opening offers cut income); first-order fix `buyer_pay_frac` 1.5 -> 1.75 gives greedy 0.22, cautious 0.58,
ratio 0.95, median 14.1 min. Remaining WARNs go to step 12.

### Step 10: ending variants (2026-11-19) - done
Four endings picked by priority (collector, regulars, cursed_shop, debt_free); `run_won` carries `ending` plus its card text. Check:
`test_endings` 6 tests green (one per ending, plus lost run and snapshot), lint 0. No balance effect.

### Step 11: deeds (2026-11-19) - done
22 new deeds (59 total) for curses, night events, endings, wake types, haggling, twins and whispers, with 12 rule kinds and 9 run counters.
Check: `test_deeds` 4 new tests green; full suite 523 passed, 0 failed; lint 0. No balance effect.

### Step 12: balance sweep (2026-11-19) - done
After steps 2-11 the lab drifted (greedy 0.22, cautious 0.58, cash ratio 0.95, median 14 min) because buyers now open low and
the new content takes cash (debt collector, cheap child items). Findings from sweeps with `--set`:
- A free counter was worth about +0.18 cautious survival (0.40 -> 0.58): with `buyer_patience` 2 a failed counter cost nothing.
  `buyer_patience` 1 makes a counter above the limit lose the sale (a calm buyer walks), so it is a gamble. The bots now both
  counter once; cautious reads the mood (calm +15%, stingy +35%, eager left alone), greedy asks +15% of everyone and loses
  eager buyers.
- Greedy's cash edge came from cursed stock: `cursed_value_mult` 1.8 -> 2.5 restores the ratio to 1.50. `buyer_pay_frac` 1.5 -> 1.75
  repays the opening-offer discount. `secs_per_customer` 25 -> 27 (more offers and counters per customer) puts the median at 15.7.
Final (300 runs, haunting 0, no upgrades): run median 15.72 min, wake by night 3 0.93, greedy 0.26, cautious 0.59, cash ratio 1.50
(all five targets hold). Haunting 5: 0.32 / 0.12; haunting 10: 0.17 / 0.10 (a little above the 0.05-0.15 aim for cautious).
Maxed upgrades: 0.76 / 0.34 (limits 0.80 / 0.65). Runs to max 22.1 (limit 15-25). Collector pleased 0.15 / 0.10. Lab: 0 warn, 0 fail.
Weak: the ratio sits exactly on its floor and greedy survival is 0.01 over its floor, so the next content change may tip them.

### Step 13: save robustness (2026-11-19) - done
`SaveGuard` validates profile and run saves before use; a bad file moves to `.bak` and the game resets. Fuzz test `test_save_fuzz`
(11 tests, about 1,500 loads): every field of both saves with 12 wrong values, truncations, random byte flips, garbage, missing run
keys, older and newer versions, and each loaded run is played on for up to 400 commands. No script errors (only the engine's own
"Error when trying to decode Variant" lines for broken binary saves). Check: green; full suite 544 passed, the 2 failures are the
art lane's collector-face test and the audio synth work in progress. Lab unchanged.

### Step 14: daily rotation (2026-11-19) - done
Eight weekly Daily Seance themes (Cursed Week, Lean Week, Midnight Table Week, Haggler's Week, Storm Season, Quiet Week, Long Nights Week,
Inheritance Week) as extra tuning and flag rules on top of the omen; `Daily.opts_for_date`. Check: `test_daily` 8 new tests green (rotation,
every theme's rules, Cursed Week makes every item cursed, recording replay, result text). Daily runs are not in the lab.

### Polish loop and final run (2026-11-19)
No playthrough capture (no renderer here), so the loop was the lab, the sims and a read of every new line of text. Final: lint 0 problems,
sims 11/11, lab 0 warn 0 fail, unit tests 553 passed, 3 failed, all in other lanes (`test_ui_settings` diag rows, `test_music` build time
under CPU load, `test_sprite_kit` collector spectacles). Weak spots left: the cash ratio (1.50) and greedy survival (0.26) sit on their
floors; haunting 10 cautious 0.17 is above the 0.05-0.15 aim; the lab bots never use `curse_shift`, seer senses, or table games; the 16 new
objects and 5 new customer looks have only fallback art.
