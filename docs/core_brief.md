# Core brief: the shop run (contract)

Pure logic in `game/logic/`, no Node, no clock, seeded RNG. Workers code against this; only the lead changes it.

## Classes
- `Catalog` (`catalog.gd`): `objects` `{id, name, category, value}`, `curses`
  `{id, name, dread, sale_mult, imposter_every, tells: {tool: text}}` from `game/data/*.json` (placeholder content).
  `Catalog.TOOLS = ["uv", "scale", "listen", "touch"]`. `load_default()`, `curse(id)`, `categories()`, `problems()`.
- `RunState` (`run_state.gd`): one run. `start(seed, catalog, tuning = Tuning.shared(), gift = {}) -> events`,
  `apply(cmd) -> events`, `is_over()`, `estimate() -> {mid, spread}`, `sellable()`, `sale_price(item)`, `rent_for(n)`,
  `snapshot()`/`restore(d, catalog)`, `state_hash()`, `debug_frame()`.
  Readable: `night, cash, clock (day minutes left), dread, inventory, customer, phase, won, wake_nights, play_secs`.
- `RunRecording` (`run_recording.gd`): flight recorder. `begin(run, seed, catalog, tuning, gift)`, `drive(run, cmd)`,
  `replay(catalog, upto)`, `first_divergence(catalog)`, `wake_at`, `wake_clip(i, before) -> Vector2i`, JSON save/load.
- `ShopBot` (`shop_bot.gd`): `ShopBot.new("greedy"|"cautious")`, `decide(run) -> cmd`, `play(run, rec)`.
  Sees only what a player sees.

## Commands (Dictionary)
`{t: "inspect", tool}` · `{t: "offer", amount}` · `{t: "buy"}` · `{t: "pass"}` (also declines a buyer) ·
`{t: "sell", uid}`. Invalid commands return `{e: "invalid", why}` and change nothing but the command count.

## Events (Dictionary, key `e`)
`night_start {night, rent}` · `customer {kind: seller|buyer, name, ask | category, type (display name), tid (type id), line}` ·
`inspected {tool, tell, estimate}` · `counter {offer, ask, patience}` · `left {offer}` · `bought {uid, name, price}` ·
`sold {uid, name, price, imposter}` · `passed {kind}` · `wake {night, dread, broke, closed}` ·
`night_end {night, rent, cash, curse_cash}` (curse_cash: sum of held curses' `night_cash`, added before rent) · `run_lost {night, cash, rent}` · `run_won {cash}` · `invalid {why}`.

## Customer dictionaries
Seller: `{kind, item {id, name, category, value, curse}, reserve, ask, patience, noise_u, tools, tells, imposter}`.
Buyer: `{kind, category, pay_mult, imposter}`. UI and bots must not show `value`, `curse`, `reserve` or `noise_u`.

## Numbers
All in `Tuning` (`game/debug/tuning.gd`, groups Run, Clock, Customers, Inspect, Curses, Pacing). Pacing fields are
the lab's estimate of real seconds per action, used for the run-length target.

## Lab
`tests/lab/lab.tscn` (in `check_all` and CI): 300 runs per bot. FAIL on stuck runs, replay or restore divergence, or a
curse with no tell. WARN on the balance targets in `docs/handoff.md`.

## Reliquaries, relics and tarot (gacha plan, 18 Nov 2026; doc https://claude.ai/artifact/HeWHGkv8j31YYkXppPvAsR)
Washington gambling = paying + chance + a thing of value; each way to get a curio drops one of the three.
- `CurioCollection` (`game/logic/curio_collection.gd`): `odds()` (next box, soft and hard pity included),
  `pity_left()`, `add_boxes(n, paid)`, `boxes()`, `open_box() -> {id, name, rarity, new, pity, tradeable, shards}`
  (free boxes first; paid-box curios are locked; paid duplicates become locked shards), `appraised_offer()` /
  `buy_appraised()` (scried reliquary: contents shown before buying, tradeable), `set_featured(id)`, `grant(id)`,
  `craft(id)`, `craft_cost(id)`, `take_tradeable(id)`, `receive_trade(id)`, `sets()`, `claim_completed_sets()`,
  `reward_run(run)`, fields `owned, tradeable, free_boxes, paid_boxes, shards_free, shards_locked, featured_id`.
- `RelicStore` (`game/logic/relic_store.gd`): `set_age(years, accepts_terms)` (18+ and the current `TERMS_VERSION`
  of `docs/legal/terms_of_sale.md`, with binding individual arbitration), `is_open()`, `quote(id)` (dollars, odds,
  pity, what a scried or bound relic contains), `fulfill(id, payment_ref)` after payment, `refund(n)`, `log`.
  Products in `game/data/store.json`. Display names: sealed reliquary, scried reliquary, bound relic, curios.
- Tarot wager (`RunState`): `{t: "wager", amount}` up to `max_wager()`; event `wager {card, text, stake, payout,
  dread}`. Deck in `game/data/tarot.json`; `Catalog.tarot_return()` must stay below 1. Run cash is never sold for
  real money and nothing from the store changes a run.

## Pass it on and saved runs
- `PassLink.pick_worst(run)` picks the item to pass on (most dread among cursed, else cheapest). `PassLink.encode(item,
  run, handle)` makes the code; `PassLink.url(base, code)` puts it in the fragment (`#gift=`). `PassLink.decode(code,
  cat, tun)` returns a gift for `RunState.start(..., gift)` or {}; value is re-derived from the receiver's catalog.
  Items may carry `history`: [[handle, night reached, wakes, won], ...], newest last, at most 6.
- `PlayerProfile.save_run(run)` after every command (clears the file when the run is over), `load_run(cat)` on boot.

## Occult round (18 Nov 2026; contract in docs/occult_brief.md)
- `Grimoire` (`grimoire.gd`): spell rules from `game/data/spells.json` (`scry, hex, glamour, banish, summon, seal`):
  `why_invalid`, `backfire_chance(dread)`, `backfire_kind(rng, inventory)`, `scry_pick`, `hexed`, `summon_category`.
- `MidnightTable` (`midnight_table.gd`): house games from `game/data/table.json`: `dice_roll`, `hand_card`,
  `hand_house_draws`, `hand_result`, `wheel_spin`, `stake_item_flip`, `pairs_deal`, `pairs_add`, and the
  `*_return()` odds (dice, hand with best play, wheel, item stake, Tarot Pairs with perfect memory over 400 fixed seeds).
  `Catalog.problems()` fails any of them at 1.0 or more.
- `RunState`: `PHASE_TABLE` after a survived night (`table_open` before `night_start`; `table_leave` starts the next
  night, `night` in `table_open` is the night just survived). Fields `spells_known` (set before `start()`),
  `found`, `casts_left`, `sealed`, `table`, `summon_category`, all in snapshot/restore. Commands `cast`, `table_*`,
  `hand_draw`, `hand_stand`, `pairs_flip`. A stake is paid up front; a game or lot uses one of `games_left` or
  `lots_left`. Seller items carry `hidden` ({} or {kind, id}); touch shows `found_hint`, buying gives `found`.
  Pairs events carry the tarot id in `card`. `RunRecording` also stores `spells`.
- `PlayerProfile.bank_finds(run, store)`; the grimoire lives on `RelicStore.grimoire`, saved in profile version 2.
- Extra Tuning: `backfire_dread`, `backfire_cash_frac`. `ShopBot`: scry (cautious), hex, glamour, banish; greedy spins
  the wheel with 3% of spare cash once a night, cautious never gambles.

## Engagement round (18 Nov 2026; contract in docs/engagement_brief.md)
- `RunState.start(seed, cat, tun, gift = {}, run_opts = {})`, `run_opts = {haunting 0..10, omen, daily}` (optional `date`,
  `number` for the profile). Applied as overrides on a **copy** of the tuning when any option is on; `run.opts` (with
  `omen_name`) and `run.rules` (`all_cursed, no_tool, double_table, seller_type, start_cursed, start_spells`) are in
  snapshot/restore and `RunRecording` (`opts`). Event `run_opts` comes first, only when an option is on. `run.tool_ok(tool)`.
- `Hauntings` (`hauntings.json`, levels stack, entries may carry `flags: {start_cursed}`), `Omens` (`omens.json`,
  `offer(seed)`, `get_omen(id)`), `Daily` (`seed_for`, `number`, `opts_for(seed)`, `result_text(run, number)`),
  `Requests` (`requests.json`; `make`, `want_text`, `matches`), shared helpers in `DataFiles`. `Catalog.problems()` checks them.
- Requests: `run.requests` (`{id, who, tid, want, due, pay_mult, reward, called}`), counters `requests_done/failed`. A new
  request is announced (`request_new`) beside a normal customer slot, never instead of one. On the due night the
  requester is the first customer (a buyer with `request: true`, `want`, `who`; `category` is "" for "any cursed object").
  Sale pays `value * pay_mult`. Passing, fleeing or holding nothing fails it.
- Tuning: `spell_dread_mult`, `cursed_buyer_mult`, `requests_max`, `request_chance`, `request_pay_mult`.
- `PlayerProfile.record_result(run, store) -> {unlocked, new_best, daily_counted}`; `RelicStore` fields
  `haunting_unlocked, best_cash, daily_last, daily_best`; profile VERSION 3 (older files load with defaults).
- Lab INFO: survival at haunting 5 and 10, request counts. Haunting 10 lands near 13% (cautious).

## Round 5: the Collector and the altar (logic)
- **Collector** (`game/data/collector.json`, `Collector`): on the final night (`tuning.nights`, night 5) the first customer is
  him (`customer` event with `boss: true`, `tid: "collector_boss"`, `who`, `want_text`, `line`, then `collector_arrives
  {want_text, line}`). At night `nights - 2` start the want is rolled from the seed (own RNG) and `collector_omen {text,
  night, arrive_night, want_text}` follows `night_start`. `run.collector` = `{want: {category, curse, text}, rolled,
  arrived, done, result: ""|"pleased"|"refused"}` (snapshot/restore). `sell` of a matching item pays `value *
  collector_pay_mult * pay_mult` (glamour works) and gives a rare/legendary curio `found`, then `collector_pleased {price,
  line, reward}`. Passing, fleeing or holding nothing: `collector_refused {toll, dread, line, curse_line}` (cash -
  `collector_toll_frac`, Dread + `collector_curse_dread`). Tuning: `collector_pay_mult` 3.0, `collector_curse_dread` 0.2,
  `collector_toll_frac` 0.2, `collector_legendary_odds` 0.3.
- **Ectoplasm and the altar** (`upgrades.json`, `Upgrades`): `run_opts.upgrades = {id: rank}` is recorded in `run.opts` and
  `RunRecording.opts`. `Upgrades.apply(tun, ranks) -> {overrides, flags}` (per rank: `add`, `mul` compounds, `set`),
  `buy(id, store) -> {ok, why, rank, cost}` (next rank costs `cost * (rank + 1)`), `cost_of`, `ecto_for(run)`
  (`ecto_per_night` * nights survived + `ecto_win_bonus` on a win, times 1 + 0.1 * haunting), `clean`, `flags_for`.
  Upgrades: extra_cast, start_spell (opts `start_spell` id, else the first unknown spell), keen_eye, thrifty_rent, pendulum,
  loss_purse, altar_candle (`night_dread_relief`; `night_start` carries `dread_relief` when > 0), deep_pockets.
- **Pendulum**: `inspect` with tool `pendulum` when `run.tool_ok("pendulum")`; `inspected` has `tell` "cursed" or "clean"
  (certain, no curse id), adds "pendulum" to the seller's `tells` only when cursed, costs `inspect_minutes`, does not
  sharpen the estimate. `Catalog.TOOLS` is unchanged (four tools).
- **Profile** version 4: `RelicStore.ecto, upgrades, carry_cash`; `record_result` also returns `{ecto, carried}` and banks
  ectoplasm; `PlayerProfile.altar_opts(store)` gives `{upgrades, carry_cash}` to merge into the next run's opts.
- Bots keep a want-matching item for the Collector on the evening before; cautious uses the Pendulum first. Lab adds the
  `*_collector` and `upgrades_info` lines (maxed upgrades: cautious 0.97, greedy 0.53).

## Round 6: regulars, the Ledger of Deeds, the guided first night, balance (logic; contract in docs/round6_brief.md)
- **Regulars** (`game/data/regulars.json`, `Regulars`): six `{id, name, tid, chapters: [{line, kind, item_id | category, curse,
  outcome_lines: {done, refused}, reward}]}`, 3-4 chapters, lines at most 80 characters, the last chapter always pays a reward.
  Ids: march (Widow March, music box), ned (Little Ned, gramophone), crowe (Father Crowe, cribbage with the cellar), vane (the Great
  Vane, the assistant in the box), ashby (Colonel Ashby, the backwards clock), dottie (Dottie Vane, the shy ghost).
  Profile `regulars: {id: next chapter index}` (`RelicStore.regulars`). The key `regulars` in run opts switches visits on
  (`PlayerProfile.altar_opts` always sets it; the lab and tests without it see none). `run.regular` is `{id, night, chapter
  (0-based), state: ""|"here"|"done"|"refused"}`, planned at start on its own RNG (`Regulars.plan`: `regular_chance`, night 2-4, an
  unfinished arc). The regular is the first customer on or after their night; a seller chapter comes at once, a buyer chapter
  as soon as a held object matches (item_id, or category, and curse when named), so no story is lost to an empty shelf.
  Events: `customer` with `regular: id` (type is the regular's name, `tid` the look-alike type), then `regular {id, name, chapter
  (1-based), chapters, line}`. Buying (seller) or selling a match (buyer, pays `regular_pay_mult` * value): `regular_done {id,
  chapter, line, reward, price}`, the reward goes to `run.found` (`found` event). Passing, fleeing or haggling out:
  `regular_refused {id, chapter, line}`. Either way `run.regular_progress[id] = chapter + 1` and `PlayerProfile.record_result`
  folds it into `store.regulars`.
- **Deeds** (`game/data/deeds.json`, `Deeds`): 37 `{id, name, text, secret, check}`. `Deeds.check(run, profile) -> PackedStringArray`
  (new ids only, writes nothing, safe mid-run); every key of a rule must hold. Kinds: won, haunting_at_least, wakes_at_least,
  cash_at_least, spells_cast, table_wins, pairs_perfect, collector "pleased", requests_done, curios_owned (owned plus found this run),
  set_complete (parlor, attic, cellar, chapel), regular_finished, omen, daily, no_tools, all_cursed_held (most held at once).
  RunState counters (snapshot/restore): `spells_cast, table_wins, pairs_perfect, tools_used, max_cursed_held`.
  `store.deeds`; `record_result` appends and returns `deeds_new` (call `bank_finds` first so found curios count).
- **Tutorial** (`Tutorial`): `PlayerProfile.needs_tutorial(store)`; the first run uses `Tutorial.SEED` and `Tutorial.opts()`
  (`{tutorial: true}`; `run.opts.tutorial`). Night 1 is `Tutorial.customers()`: a clean Hand bell seller, a cursed Oil portrait
  seller (sleepwalker; the UV tell is certain) and an instrument buyer, with no random draws, then the night ends. No wake on
  night 1 (Dread is capped under the threshold), `tutorial_purse` extra cash covers rent. `customer` events carry `tutorial: step`.
  `tutorial_step {step, text, focus}` events (`Tutorial.script()`: 1 tools, 2 offer, 3 tools, 4 dread, 5 shelf, 6 table at
  `table_open`, 7 spells on night 2); focus is one of `Tutorial.FOCUS`. `record_result` sets `store.tutorial_done` (the title's Skip
  sets it directly). A profile file older than version 5 loads with `tutorial_done` true; profile VERSION 5 adds a `journal` block.
- **Balance**: the Pendulum now costs `pendulum_minutes` (50) per swing, Keen Eye +5% per rank, Patient Landlord 3% per rank, Altar
  Candle 0.3 per rank, Deep Pockets 8 per rank. Maxed: cautious 0.77, greedy 0.46 (targets 0.80 and 0.65); haunting 0 with no
  upgrades keeps all five feel targets. Every upgrade costs 220 ectoplasm (`Upgrades.total_cost()`), about 21 runs at the lab's
  average ectoplasm per run. New Tuning: `regular_chance`, `regular_pay_mult`, `tutorial_purse`, `pendulum_minutes`.
