# Engagement round brief: Hauntings, omens, Daily Séance, customer requests

Curtis (2026-11-18) wanted more to keep players coming back, built efficiently, and picked these four. Two workers
(logic, UI) build against this contract in parallel. Read CLAUDE.md, docs/core_brief.md, docs/occult_brief.md and
docs/lessons_learned.md first. Do not commit; the lead integrates.

## Run options (one entry point)
`RunState.start(seed, cat, tun, gift, opts := {})`, where `opts = {haunting: int 0..10, omen: String id or "",
daily: bool}`. The options are applied as Tuning overrides on a **copy** of the tuning (never the shared one), plus
rule flags that RunState reads. They are stored in `snapshot()`/`restore()` and in `RunRecording` (replays must
match). `run.opts` holds what was applied. Events: `run_opts {haunting, omen, omen_name, daily}` at start.

## Hauntings (difficulty tiers)
- `game/data/hauntings.json`: `[{level: 1..10, name, text, set: {tuning_field: value}, mul: {tuning_field: factor}}]`.
  Levels stack, so Haunting N applies levels 1..N in order. Examples: rent up 10%, more cursed sellers, spells cost
  more Dread, a shorter day, fewer tells, the wake comes sooner, fewer table games, and at level 10 "The shop
  remembers" (start with a cursed object).
- Profile: `haunting_unlocked` (starts at 0). Winning at the current max unlocks max+1, up to 10.
  `PlayerProfile.record_result(run, store)` updates it, along with best-cash and daily records (below).
- Lab: haunting 0 with no omen must still meet every feel target. Add an INFO line reporting survival at haunting 5
  and haunting 10 for the cautious bot (target, info only: 10 is roughly 5-15%).

## Omens (pick 1 of 3 at run start)
- `game/data/omens.json`: about 12 entries `{id, name, text, set, mul, flags}`, using the same set/mul shape as
  hauntings. Flags RunState understands: `all_cursed` (every seller's item is cursed), `no_tool` (a tool id that
  cannot be used), `buyers_pay_more_cursed` (handled through mul), `start_spell` (an extra known spell this run),
  `double_table` (2x table games), `one_customer_type` (one seller type only). Each omen must have an upside and a
  downside, and the text says both in under 70 characters.
- `Omens.offer(seed) -> Array[String]`: three distinct omen ids, seeded. The UI shows three cards before the run.
  The player picks one, or "no omen".

## Daily Séance
- `Daily.seed_for(year, month, day) -> int` (pure; the caller passes the date) and `Daily.number(y, m, d) -> int`
  (days since 2026-12-18 + 1; it can be zero or negative before launch, which is fine).
- A daily run uses haunting 0, the omen `Omens.offer(seed)[0]`, and no gift.
- `Daily.result_text(run, number) -> String`: a paste-able spoiler-free summary on 3-4 lines, ASCII plus a few
  emoji, for example: `Cursed Pawn Séance #12`, `Night 5/5 survived | 412 coins | woke 3x`, an 8-char night strip
  like `🕯🕯🔥🕯🕯`, and the omen name.
- Profile: `daily_last` ("YYYY-MM-DD") and `daily_best` per date (keep only the latest 30). Logic does not block
  replays; the UI shows "already played today", and only the first attempt counts.

## Customer requests
- During a night, a seller-or-buyer slot may instead be a **request**. A named customer asks for something:
  `{id, who, tid, want: {category: String or "", cursed: bool}, due: night, pay_mult, reward: {kind: "curio", id}}`.
  At most `requests_max` open at once (Tuning); chance `request_chance`; the due night is 1-2 nights ahead.
- On the due night the requester comes as the first customer, as a buyer with `request: true`. Selling a matching
  held item pays `value * pay_mult` and adds the reward to `run.found` (so it is banked like the other finds).
  Passing, or holding nothing that matches, fails the request.
- Events: `request_new {id, who, line, want_text, due}`, `request_due {id, who}`, `request_done {id, pay, reward}`,
  `request_failed {id}`. `run.requests` lists the open ones for the HUD.
- Bots: sell to a request when they can.

## UI (UI worker)
- New run flow: title > New run > a **Haunting picker** (only when unlocked > 0: arrows, the level's name and stacked
  rule lines) > the **Omen draw**. Three tarot-style omen cards deal in face down and flip one at a time on hover or
  click (use SpriteKit.card_texture for the backs, and draw the omen text on the face). Add a fourth "No omen" button.
- Title menu adds **Daily Séance** (with today's number). After it's played, it shows "Played today: <result line>".
  The run-end screen for a daily adds a **Copy result** button that puts `Daily.result_text` on the clipboard
  (DisplayServer.clipboard_set; it works on the web via user gesture).
- HUD: a small **request board** (pinned notes, 1-3) listing who wants what and the due night, with micro-animations
  (a note pins in, a stamp DONE or a torn FAILED). The run's omen and haunting appear as a small badge near the night
  label. On hover it shows their text.
- Run end: show the Haunting unlocked ("Haunting 3 unlocked"), with ink-write.
- Call `PlayerProfile.record_result(run, store)` at run end (guard on has_method and scripted runs).

## Ownership
- **Logic**: game/logic/*, game/data/*, game/debug/tuning.gd, tests/unit for logic, tests/lab, docs/core_brief.md.
- **UI**: game/ui/*, game/shop/*, tests/unit/test_ui_*, tests/shots/*ui*/title* sheets. Guard calls into logic with
  has_method or "in" checks until logic lands, and drive the sheets from hand-built events.
