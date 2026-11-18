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
`night_start {night, rent}` · `customer {kind: seller|buyer, name, ask | category}` ·
`inspected {tool, tell, estimate}` · `counter {offer, ask, patience}` · `left {offer}` · `bought {uid, name, price}` ·
`sold {uid, name, price, imposter}` · `passed {kind}` · `wake {night, dread, broke, closed}` ·
`night_end {night, rent, cash}` · `run_lost {night, cash, rent}` · `run_won {cash}` · `invalid {why}`.

## Customer dictionaries
Seller: `{kind, item {id, name, category, value, curse}, reserve, ask, patience, noise_u, tools, tells, imposter}`.
Buyer: `{kind, category, pay_mult, imposter}`. UI and bots must not show `value`, `curse`, `reserve` or `noise_u`.

## Numbers
All in `Tuning` (`game/debug/tuning.gd`, groups Run, Clock, Customers, Inspect, Curses, Pacing). Pacing fields are
the lab's estimate of real seconds per action, used for the run-length target.

## Lab
`tests/lab/lab.tscn` (in `check_all` and CI): 300 runs per bot. FAIL on stuck runs, replay or restore divergence, or a
curse with no tell. WARN on the balance targets in `docs/handoff.md`.

## Estate boxes (paid gacha, US-only design, decided 18 Nov 2026)
`CurioCollection` (`game/logic/curio_collection.gd`): `create(seed, tuning)`, `odds() -> {common, rare, legendary}`
(show before every purchase), `pity_left()`, `add_boxes(n)` (purchase or reward), `reward_run(run)`, `open_box() ->
{id, name, rarity, new, pity}`, `to_dict()`/`from_dict()`. Curios (`game/data/curios.json`, placeholder) are cosmetic:
shop decor and a collection book. Never tradeable, sellable or convertible to money, and they never change run
numbers. New curios come before duplicates. Payments: Steam microtransactions; the web store needs a payment
provider that allows paid random items (Paddle's AUP bans "games of chance").
