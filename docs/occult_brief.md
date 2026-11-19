# Occult round brief: grimoire, Midnight Table, curios found in play

Curtis (2026-11-18): "everything is working but i feel bored, i want to be able to obtain collectable items, i think
there should be more gambling involved and more occult magic". Three features, built in parallel by three workers
against the contract below. Read CLAUDE.md, docs/core_brief.md and docs/lessons_learned.md first.

## Legal lines (do not cross)
- All gambling uses **run cash** or **held run objects** only. Run cash is never bought with money and is worthless
  outside the run.
- Spells and spell pages are **earned only**. Nothing from a paid reliquary box ever changes a run.
- Curios found in play are granted as **tradeable** (earned) via `CurioCollection.grant(id)`.
- Every house game must return < 1.0 per coin staked; `Catalog.problems()` checks it, as it does for tarot.

## Shared contract (logic owns it; UI and art code against it)

### Data files (logic worker writes them)
- `game/data/spells.json`: `[{id, name, dread, text, backfire}]`, where `backfire` is a short line. Ids:
  `scry, hex, glamour, banish, summon, seal`.
- `game/data/table.json`: `{dice: {...}, hand: {...}, wheel: [{id, name, weight, mult, dread, prize, text}], lot: {...}}`.
  A wheel `prize` is "", "curio" or "page".
- `game/data/curios.json`: the 12 placeholders become **24** real occult curios with `{id, name, rarity, set, text}`.
  Sets: `parlor`, `attic`, `cellar`, `chapel`. Rarity counts: 14 common, 7 rare, 3 legendary. Keep the existing 12 ids
  so saved profiles still load.

### RunState additions
- `const PHASE_TABLE := "table"`. After a survived night (rent paid, no win), the run enters PHASE_TABLE and emits
  `{"e":"table_open","night":n,"games_left":k,"lots_left":m}` **before** `night_start`. The next night starts on
  `table_leave` (or once games and lots run out and the player leaves).
- `var spells_known: PackedStringArray` (set by the caller before `start()` or passed in; default `["scry","hex"]`).
- `var found: Array[Dictionary]`: `{kind: "page"|"curio", id}` collected this run. The caller grants them at run end.
- `var casts_left: int` (per night, from Tuning) and `var sealed: bool`.
- Sellers' items may hide a find: `customer["item"]["hidden"] = {kind, id}` or `{}`. A **touch** inspect reveals it
  (event `found_hint`). Buying the item moves it to `found` (event `found`).

### Commands
| cmd | when | effect |
|---|---|---|
| `{"t":"cast","spell":id,"uid":n?}` | customer phase | cast a known spell; `uid` only for banish |
| `{"t":"table_dice","stake":n,"call":"high"\|"low"}` | table | 2d6, 7 loses |
| `{"t":"table_hand","stake":n}` then `{"t":"hand_draw"}` / `{"t":"hand_stand"}` | table | draw to 13, the house draws to 10 |
| `{"t":"table_wheel","stake":n}` | table | weighted wheel; some segments give a page or curio |
| `{"t":"table_stake_item","uid":n}` | table | coin flip at house odds: win doubles the item's value, lose and the house keeps it |
| `{"t":"table_pairs","stake":n}` then `{"t":"pairs_flip","i":k}` | table | Tarot Pairs (match 2): the tarot cards face down in a grid; flip two per try, a match pays that card |
| `{"t":"table_lot"}` | table | buy a sealed lot at a fixed price: a random object, sometimes with a hidden find |
| `{"t":"table_leave"}` | table | next night starts |

### Events (UI and art key on these exact names)
- `cast {spell, ok, backfire, text, dread}`: `ok` false only when invalid. `backfire` true means the backfire effect
  happened instead.
- Spell effects: `scry_reveal {tool, tell}`, `hexed {reserve, ask}`, `glamoured {mult}`, `banished {uid, name}`,
  `summoned {category}` (the next customer is a buyer of that category), `sealed {}`.
- Backfires: `backfire {spell, kind, text}`, where `kind` is one of `dread_spike`, `cash_burn`, `customer_flees` or
  `curse_jumps`.
- `found_hint {kind}`, `found {kind, id, name}`.
- Table: `table_open {night, games_left, lots_left}`, `dice {d1, d2, call, win, stake, payout}`,
  `hand_card {who: "you"|"house", card, total}`, `hand_end {you, house, win, stake, payout}`,
  `pairs_deal {count, tries}`, `pairs_flip {i, card, name}`, `pairs_match {card, name, mult, dread}`,
  `pairs_miss {a, b}` (flip both back), `pairs_end {matches, stake, payout, dread}`,
  `wheel {segment, name, mult, stake, payout, prize, dread}`, `item_staked {uid, name, win, value}`,
  `lot {name, price, item_uid, hidden: bool}`, `table_leave {}`.

### Tarot Pairs (Curtis 2026-11-18: "make a match 2 with the tarot cards you already made")
A memory game using the existing tarot deck (game/data/tarot.json, SpriteKit.card_texture). The board deals 2 copies of
each tarot card face down (10 cards, seeded shuffle). You get `pairs_tries` tries of two flips each. Each match adds that
card's `mult` share to the payout (Sun best, Fool neutral) and its `dread` (the Tower). A Death pair voids the
payout so far. Tune `pairs_tries` and the per-card pay so the expected return with perfect memory stays < 1.0, and
check it in `Catalog.problems()` with a deterministic perfect-memory simulation over a fixed seed set.

### Tuning fields (logic adds them, group "Grimoire" or "Midnight Table")
`spell_casts_per_night`, `spell_backfire_base`, `spell_backfire_per_dread`, `hex_mult`, `glamour_mult`,
`banish_dread`, `seal_debt_mult`, `hidden_find_chance`, `hidden_page_share`, `table_games_per_night`,
`table_lots_per_night`, `pairs_tries`, `pairs_pay_scale`, `table_max_stake_frac`, `lot_price`, `night_curio_chance`.

### Persistence
`PlayerProfile` saves the grimoire (known spell ids) next to the collection in `user://profile.json`, versioned, and
skips scripted runs. At run end ShopGame calls a single helper, `PlayerProfile.bank_finds(run, store)`: pages join the
grimoire and curios go to `store.collection.grant(id)`.

## Worker split and file ownership
- **Logic**: `game/logic/*` (new `grimoire.gd` with the spell rules and `midnight_table.gd` with the house games, plus
  the RunState wiring), `game/data/*`, `game/debug/tuning.gd`, `game/logic/shop_bot.gd` (the bot casts sensibly and
  plays one table game per night at most), unit tests, `docs/core_brief.md`. Rerun the lab once at the end. All
  feel targets in CLAUDE.md must still hold.
- **UI**: `game/ui/*` (spell bar on keys 5-0 with Dread cost and backfire odds, the Midnight Table screen, the found
  reveal popup, a grimoire page, a run-end "what you found" list), `game/shop/relic_shop_panel.gd` (show real curio
  names and text, group by set) and their tests and shot scripts. Wire `PlayerProfile.bank_finds` at run end.
- **Art**: `game/room2d/sprite_kit.gd` (croupier 64x96 with 4 frames, bone dice, card faces, soul wheel, sealed-lot
  parcel, spell page, six 16x16 spell icons, one 24x24 icon per curio id), `game/room2d/shop_room_2d.gd`,
  `room_fx.gd` (spell effects in the room: scry eye, hex chains on the customer, glamour sparkle, banish smoke, summon
  sigil, seal circle, backfire flash; table-night lighting), plus their tests and sheets.

Until logic lands, UI and art drive themselves from hand-built event dictionaries in tests and sheets. Lint rules,
static typing, tabs, `Image.create_empty`, no `randf()` in logic. Do not commit; the lead integrates.
