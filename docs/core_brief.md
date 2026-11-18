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
