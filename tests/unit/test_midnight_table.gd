extends TestCase
## The Midnight Table: house games, odds and the table phase of a run. Helpers here are prefixed mt_.


func mt_run(seed_value: int = 3) -> RunState:
	var tun := Tuning.new()
	tun.set_value("hidden_find_chance", 0.0)
	tun.set_value("wake_threshold", 20.0)
	tun.set_value("table_games_per_night", 3.0)
	var run := RunState.new()
	run.start(seed_value, Catalog.load_default(), tun)
	run.phase = RunState.PHASE_TABLE
	run.customer = {}
	run.cash = 400
	run.table = {"games_left": 3, "lots_left": 1, "hand": {}, "pairs": {}}
	return run


func mt_find(ev: Array[Dictionary], name: String) -> Dictionary:
	for e: Dictionary in ev:
		if e["e"] == name:
			return e
	return {}


func mt_count(ev: Array[Dictionary], name: String) -> int:
	var n: int = 0
	for e: Dictionary in ev:
		if e["e"] == name:
			n += 1
	return n


func test_every_game_returns_less_than_one() -> void:
	var cat := Catalog.load_default()
	var m := MidnightTable.load_default(Tuning.new())
	assert_true(m.dice_return() < 1.0, "dice %f" % m.dice_return())
	assert_true(m.hand_return() < 1.0, "hand %f" % m.hand_return())
	assert_true(m.wheel_return() < 1.0, "wheel %f" % m.wheel_return())
	assert_true(m.item_return() < 1.0, "item %f" % m.item_return())
	assert_true(m.pairs_return(cat.tarot) < 1.0, "pairs %f" % m.pairs_return(cat.tarot))
	assert_true(m.pairs_return(cat.tarot) > 0.2, "pairs is worth playing")


func test_catalog_flags_each_generous_game() -> void:
	var edits: Array = [["dice", func(t: Dictionary) -> void: t["dice"]["mult"] = 3.0],
		["hand", func(t: Dictionary) -> void: t["hand"]["win_mult"] = 5.0],
		["wheel", func(t: Dictionary) -> void: t["wheel"][0]["mult"] = 9.0],
		["item stake", func(t: Dictionary) -> void: t["stake_item"]["win_chance"] = 0.6]]
	for e: Array in edits:
		var c := Catalog.load_default()
		(e[1] as Callable).call(c.table)
		var p: PackedStringArray = c.problems()
		assert_eq(p.size(), 1, str(e[0]))
		assert_true(p.size() > 0 and str(p[0]).begins_with(str(e[0])), str(e[0]))


func test_catalog_flags_generous_pairs() -> void:
	var c := Catalog.load_default()
	for card: Dictionary in c.tarot:
		card["mult"] = 5.0
	c.tarot[3]["id"] = "x"  # nothing voids
	var found_pairs: bool = false
	for p: String in c.problems():
		if p.begins_with("tarot"):
			found_pairs = true
	assert_true(found_pairs)


func test_dice_rules() -> void:
	var m := MidnightTable.load_default(Tuning.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var sevens: int = 0
	for i: int in range(300):
		var call: String = "high" if i % 2 == 0 else "low"
		var r: Dictionary = m.dice_roll(rng, call, 10)
		var total: int = int(r["d1"]) + int(r["d2"])
		sevens += 1 if total == 7 else 0
		assert_eq(r["win"], (call == "high" and total > 7) or (call == "low" and total < 7))
		assert_eq(r["payout"], 22 if r["win"] else 0)
	assert_true(sevens > 0, "a 7 came up and lost")


func test_dice_command_moves_cash() -> void:
	var run := mt_run()
	var ev: Array[Dictionary] = run.apply({"t": "table_dice", "stake": 50, "call": "high"})
	var d: Dictionary = mt_find(ev, "dice")
	assert_eq(run.cash, 400 - 50 + int(d["payout"]))
	assert_eq(run.table["games_left"], 2)
	ev = run.apply({"t": "table_dice", "stake": 9999, "call": "high"})
	assert_eq(ev[0]["e"], "invalid", "over the stake cap")
	ev = run.apply({"t": "table_dice", "stake": 10, "call": "mid"})
	assert_eq(ev[0]["e"], "invalid")


func test_hand_result_rules() -> void:
	var m := MidnightTable.load_default(Tuning.new())
	assert_true(m.hand_result(12, 9, 10)["win"])
	assert_true(m.hand_result(5, 14, 10)["win"], "house bust")
	assert_eq(m.hand_result(14, 9, 10)["payout"], 0)
	assert_eq(m.hand_result(10, 10, 10)["payout"], 10, "push returns the stake")
	assert_eq(m.hand_result(9, 12, 10)["payout"], 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var cards: Array[int] = m.hand_house_draws(rng, 0)
	var sum: int = 0
	for c: int in cards:
		sum += c
	assert_true(sum >= 10, "the house draws to 10")


func test_hand_flow_draw_stand_and_bust() -> void:
	var run := mt_run()
	var ev: Array[Dictionary] = run.apply({"t": "table_hand", "stake": 40})
	assert_eq(mt_count(ev, "hand_card"), 1)
	assert_eq(run.cash, 360)
	assert_eq(run.apply({"t": "table_leave"})[0]["e"], "invalid", "cannot leave mid-hand")
	var end: Dictionary = {}
	var guard: int = 0
	while end.is_empty() and guard < 20:
		ev = run.apply({"t": "hand_draw"})
		end = mt_find(ev, "hand_end")
		guard += 1
	assert_true(not end.is_empty() and not end["win"], "drew until bust")
	assert_true(int(end["you"]) > 13)
	assert_eq(run.cash, 360)
	run.table["games_left"] = 2
	run.apply({"t": "table_hand", "stake": 40})
	ev = run.apply({"t": "hand_stand"})
	end = mt_find(ev, "hand_end")
	assert_true(mt_count(ev, "hand_card") >= 1, "house cards shown")
	assert_eq(run.cash, 360 - 40 + int(end["payout"]))
	assert_true(run.table["hand"].is_empty())


func test_wheel_segments_and_prizes() -> void:
	var m := MidnightTable.load_default(Tuning.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var seen: Dictionary = {}
	for i: int in range(600):
		seen[m.wheel_spin(rng, 10)["segment"]] = true
	assert_eq(seen.size(), m.wheel().size(), "every segment turns up")
	var run := mt_run()
	run.catalog.table["wheel"] = [{"id": "p", "name": "P", "weight": 1, "mult": 0.0, "dread": 0.0, "prize": "page", "text": ""}]
	var ev: Array[Dictionary] = run.apply({"t": "table_wheel", "stake": 20})
	assert_eq(mt_find(ev, "wheel")["prize"], "page")
	var f: Dictionary = mt_find(ev, "found")
	assert_eq(f["kind"], "page")
	assert_false(run.spells_known.has(f["id"]), "a page you did not know")
	assert_eq(run.found.size(), 1)
	run.catalog.table["wheel"] = [{"id": "c", "name": "C", "weight": 1, "mult": 0.0, "dread": 1.0, "prize": "curio", "text": ""}]
	var d0: float = run.dread
	ev = run.apply({"t": "table_wheel", "stake": 20})
	assert_eq(mt_find(ev, "found")["kind"], "curio")
	assert_near(run.dread, d0 + 1.0)
	assert_eq(run.found.size(), 2)


func test_stake_item_win_doubles_and_loss_forfeits() -> void:
	var run := mt_run()
	run.inventory.append({"uid": 90, "id": "a", "name": "A", "category": "toy", "value": 50, "curse": "", "est": 50, "tells": 0})
	run.catalog.table["stake_item"]["win_chance"] = 1.0
	var ev: Array[Dictionary] = run.apply({"t": "table_stake_item", "uid": 90})
	assert_true(mt_find(ev, "item_staked")["win"])
	assert_eq(run.inventory[0]["value"], 100)
	run.catalog.table["stake_item"]["win_chance"] = 0.0
	ev = run.apply({"t": "table_stake_item", "uid": 90})
	assert_false(mt_find(ev, "item_staked")["win"])
	assert_true(run.inventory.is_empty(), "the house keeps it")
	assert_eq(run.apply({"t": "table_stake_item", "uid": 90})[0]["e"], "invalid")


func mt_pairs(run: RunState, stake: int = 100) -> Array:
	run.apply({"t": "table_pairs", "stake": stake})
	return run.table["pairs"]["board"]


func mt_pair_of(board: Array, card: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in range(board.size()):
		if board[i] == card:
			out.append(i)
	return out


func test_pairs_deal_and_a_perfect_match_pays() -> void:
	var run := mt_run()
	var ev: Array[Dictionary] = run.apply({"t": "table_pairs", "stake": 100})
	assert_eq(ev[0], {"e": "pairs_deal", "count": 10, "tries": 3})
	var board: Array = run.table["pairs"]["board"]
	var counts: Dictionary = {}
	for c: Variant in board:
		counts[c] = int(counts.get(c, 0)) + 1
	assert_eq(counts.size(), 5)
	for k: Variant in counts:
		assert_eq(counts[k], 2)
	var sun: int = 0  # the Sun is the first tarot card
	var p: Array[int] = mt_pair_of(board, sun)
	var e1: Array[Dictionary] = run.apply({"t": "pairs_flip", "i": p[0]})
	assert_eq(mt_find(e1, "pairs_flip")["name"], "The Sun")
	assert_eq(run.apply({"t": "pairs_flip", "i": p[0]})[0]["e"], "invalid", "same card twice")
	var e2: Array[Dictionary] = run.apply({"t": "pairs_flip", "i": p[1]})
	var m: Dictionary = mt_find(e2, "pairs_match")
	assert_near(float(m["mult"]), 3.0)
	# Burn the remaining two tries on misses.
	var others: Array[int] = mt_pair_of(board, 1) + mt_pair_of(board, 2) + mt_pair_of(board, 4)
	var misses: int = 0
	var end: Dictionary = {}
	var a: int = mt_pair_of(board, 1)[0]
	var b: int = mt_pair_of(board, 2)[0]
	var c2: int = mt_pair_of(board, 4)[0]
	for pair: Array in [[a, b], [b, c2]]:
		run.apply({"t": "pairs_flip", "i": pair[0]})
		var ev2: Array[Dictionary] = run.apply({"t": "pairs_flip", "i": pair[1]})
		misses += mt_count(ev2, "pairs_miss")
		if not mt_find(ev2, "pairs_end").is_empty():
			end = mt_find(ev2, "pairs_end")
	assert_eq(misses, 2)
	assert_eq(end["matches"], 1)
	var want: int = int(round(100 * 3.0 * run.tuning.pairs_pay_scale))
	assert_eq(end["payout"], want)
	assert_eq(run.cash, 400 - 100 + want)
	assert_true(run.table["pairs"].is_empty())
	assert_eq(others.size(), 6)


func test_pairs_death_voids_and_tower_adds_dread() -> void:
	var run := mt_run()
	var board: Array = mt_pairs(run)
	var tarot: Array[Dictionary] = run.catalog.tarot
	var by_id: Dictionary = {}
	for i: int in range(tarot.size()):
		by_id[tarot[i]["id"]] = i
	var d0: float = run.dread
	var all: Array[Dictionary] = []
	for id: String in ["the_sun", "death", "the_tower"]:
		var p: Array[int] = mt_pair_of(board, int(by_id[id]))
		run.apply({"t": "pairs_flip", "i": p[0]})
		all.append_array(run.apply({"t": "pairs_flip", "i": p[1]}))
	var end: Dictionary = mt_find(all, "pairs_end")
	assert_eq(end["matches"], 3)
	assert_eq(end["payout"], 0, "the death pair voids the payout so far")
	assert_near(float(end["dread"]), 1.0)
	assert_near(run.dread, d0 + 1.0)


func test_lot_buys_an_object_and_can_hide_a_find() -> void:
	var run := mt_run()
	run.tuning.set_value("hidden_find_chance", 1.0)
	var ev: Array[Dictionary] = run.apply({"t": "table_lot"})
	var lot: Dictionary = mt_find(ev, "lot")
	assert_eq(run.cash, 400 - int(run.tuning.lot_price))
	assert_true(lot["hidden"])
	assert_eq(run.inventory[0]["uid"], lot["item_uid"])
	assert_eq(run.found.size(), 1)
	assert_eq(run.apply({"t": "table_lot"})[0]["e"], "invalid", "one lot a night")


func test_table_only_between_nights_and_leave_starts_the_next() -> void:
	var run := RunState.new()
	run.start(8, Catalog.load_default(), Tuning.new())
	assert_eq(run.apply({"t": "table_wheel", "stake": 5})[0]["e"], "invalid")
	var bot := ShopBot.new(ShopBot.CAUTIOUS)
	var ev: Array[Dictionary] = []
	var guard: int = 0
	while run.phase != RunState.PHASE_TABLE and not run.is_over() and guard < 400:
		ev = run.apply(bot.decide(run))
		guard += 1
	if run.is_over():
		return  # lost before the table; seed-dependent, covered by test_paying_every_rent_wins
	assert_eq(ev[-1]["e"], "table_open")
	assert_eq(ev[-1]["night"], 1)
	assert_eq(run.apply({"t": "pass"})[0]["e"], "invalid", "no customers at the table")
	ev = run.apply({"t": "table_leave"})
	assert_eq(ev[0]["e"], "table_leave")
	assert_eq(ev[1]["e"], "night_start")
	assert_eq(ev[1]["night"], 2)
	assert_eq(run.casts_left, int(run.tuning.spell_casts_per_night))


func test_snapshot_restore_mid_hand_and_mid_pairs() -> void:
	var run := mt_run()
	run.found.append({"kind": "page", "id": "seal"})
	run.apply({"t": "table_hand", "stake": 30})
	var b := RunState.new()
	b.restore(run.snapshot(), run.catalog)
	assert_eq(b.state_hash(), run.state_hash())
	assert_eq(b.apply({"t": "hand_stand"}), run.apply({"t": "hand_stand"}))
	var board: Array = mt_pairs(run)
	run.apply({"t": "pairs_flip", "i": 0})
	var c := RunState.new()
	c.restore(run.snapshot(), run.catalog)
	assert_eq(c.found, run.found)
	assert_eq(c.apply({"t": "pairs_flip", "i": 1}), run.apply({"t": "pairs_flip", "i": 1}))
	assert_eq(board.size(), 10)
