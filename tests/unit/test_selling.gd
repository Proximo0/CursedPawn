extends TestCase
## Selling depth: a buyer makes an offer on one shelf item; accept it or counter. Helpers are prefixed sl_.


func sl_run(mood: String = "calm") -> RunState:
	var run := RunState.new()
	var tun := Tuning.new()
	tun.set_value("wake_threshold", 1000.0)
	run.start(5, Catalog.load_default(), tun)
	run.inventory.append({"id": "x", "name": "Thing", "category": "toy", "value": 100, "curse": "", "uid": 900, "est": 100, "tells": 0})
	run.customer = {"kind": "buyer", "category": "toy", "imposter": false, "type": "tourist", "pay_mult": 1.0, "cursed_mult": 1.0}
	var ev: Array[Dictionary] = []
	run._quote_buyer(ev)
	run.customer["mood"] = mood
	run.customer["open"] = float(Moods.get_mood(mood)["buyer_open"])
	run.customer["patience"] = 2
	run._set_offer(run.inventory[0], ev, "")
	return run


func sl_limit(run: RunState) -> int:
	return int(run.customer["limit"])


func test_buyer_opens_with_an_offer_on_a_specific_item() -> void:
	var run := RunState.new()
	run.start(11, Catalog.load_default(), Tuning.new())
	run.inventory.append({"id": "x", "name": "Thing", "category": "toy", "value": 100, "curse": "", "uid": 900, "est": 100, "tells": 0})
	var seen: int = 0
	for i: int in range(80):
		if run.is_over():
			break
		run.inventory.append({"id": "x", "name": "Thing", "category": "toy", "value": 100, "curse": "", "uid": 901 + i, "est": 100, "tells": 0})
		var ev: Array[Dictionary] = run.apply({"t": "table_leave"} if run.phase == "table" else {"t": "pass"})
		for e: Dictionary in ev:
			if e["e"] == "buyer_offer":
				seen += 1
				assert_true(int(e["offer"]) > 0)
				assert_false(e["counter"], "an opening offer")
				assert_eq(run.customer["offer"]["uid"], e["uid"])
	assert_true(seen > 0, "buyers made offers")


func test_offer_is_below_the_limit_and_the_limit_stays_hidden_in_events() -> void:
	var run := sl_run("calm")
	assert_true(int(run.customer["offer"]["price"]) < sl_limit(run))
	assert_eq(int(run.customer["offer"]["price"]), int(round(sl_limit(run) * 0.85)))
	for e: Dictionary in run.last_events:
		assert_false(e.has("limit"))


func test_accept_sells_at_the_offer() -> void:
	var run := sl_run("calm")
	var price: int = int(run.customer["offer"]["price"])
	var cash: int = run.cash
	var ev: Array[Dictionary] = run.apply({"t": "accept"})
	assert_eq(ev[0]["e"], "sold")
	assert_eq(ev[0]["price"], price)
	assert_eq(run.cash, cash + price)
	assert_eq(run.inventory.filter(func(i: Dictionary) -> bool: return i["uid"] == 900).size(), 0)


func test_counter_at_or_under_the_limit_is_paid_in_full() -> void:
	var run := sl_run("calm")
	var limit: int = sl_limit(run)
	var cash: int = run.cash
	var ev: Array[Dictionary] = run.apply({"t": "counter", "amount": limit})
	assert_eq(ev[0]["e"], "sold")
	assert_eq(ev[0]["price"], limit)
	assert_eq(run.cash, cash + limit)


func test_counter_above_the_limit_raises_the_offer_part_way() -> void:
	var run := sl_run("calm")
	var limit: int = sl_limit(run)
	var offer: int = int(run.customer["offer"]["price"])
	var ev: Array[Dictionary] = run.apply({"t": "counter", "amount": limit + 20})
	assert_eq(ev[0]["e"], "buyer_offer")
	assert_true(ev[0]["counter"])
	assert_eq(ev[0]["offer"], mini(limit, int(round(offer + (limit + 20 - offer) * 0.5))))
	assert_eq(ev[0]["patience"], 1)
	assert_true(run.customer["offer"]["price"] <= limit, "never above the limit")


func test_buyer_runs_out_of_patience_and_leaves() -> void:
	var run := sl_run("calm")
	var limit: int = sl_limit(run)
	run.apply({"t": "counter", "amount": limit + 5})
	var ev: Array[Dictionary] = run.apply({"t": "counter", "amount": limit + 5})
	assert_eq(ev[0]["e"], "left")


func test_silly_price_sends_them_away_at_once() -> void:
	var run := sl_run("calm")
	var ev: Array[Dictionary] = run.apply({"t": "counter", "amount": sl_limit(run) * 3})
	assert_eq(ev[0]["e"], "left")


func test_counter_must_beat_the_offer_and_needs_a_buyer() -> void:
	var run := sl_run("calm")
	assert_eq(run.apply({"t": "counter", "amount": int(run.customer["offer"]["price"])})[0]["e"], "invalid")
	assert_eq(run.apply({"t": "accept"})[0]["e"], "sold")
	var seller := RunState.new()
	seller.start(3, Catalog.load_default(), Tuning.new())
	assert_eq(seller.apply({"t": "accept"})[0]["e"], "invalid")


func test_stingy_buyer_opens_low_and_bluffs() -> void:
	var calm := sl_run("calm")
	var greedy := sl_run("greedy")
	assert_true(int(greedy.customer["offer"]["price"]) < int(calm.customer["offer"]["price"]))
	var held: int = 0
	for s: int in range(200):
		var r := sl_run("greedy")
		r.rng.seed = s
		var offer: int = int(r.customer["offer"]["price"])
		var ev: Array[Dictionary] = r.apply({"t": "counter", "amount": sl_limit(r) + 10})
		if ev[0]["e"] == "buyer_offer" and int(ev[0]["offer"]) == offer:
			held += 1
	assert_true(held > 30 and held < 90, "about 30 percent hold: %d" % held)


func test_eager_buyer_opens_high_and_gives_ground() -> void:
	var nervous := sl_run("nervous")
	assert_eq(int(nervous.customer["offer"]["price"]), int(round(sl_limit(nervous) * 0.92)))


func test_imposter_never_pays() -> void:
	var run := sl_run("calm")
	run.customer["imposter"] = true
	var cash: int = run.cash
	run.apply({"t": "accept"})
	assert_eq(run.cash, cash)


func test_sell_command_still_works_at_the_opening_offer() -> void:
	var run := sl_run("calm")
	var price: int = int(run.customer["offer"]["price"])
	var ev: Array[Dictionary] = run.apply({"t": "sell", "uid": 900})
	assert_eq(ev[0]["price"], price)


func test_offer_requotes_when_the_item_is_gone() -> void:
	var run := sl_run("calm")
	run.inventory.append({"id": "z", "name": "Other", "category": "toy", "value": 60, "curse": "", "uid": 901, "est": 60, "tells": 0})
	run.inventory.remove_at(0)
	var ev: Array[Dictionary] = run.apply({"t": "accept"})
	assert_eq(ev[0]["e"], "buyer_offer", "a fresh offer on the other toy")
	assert_eq(ev[0]["uid"], 901)
	assert_eq(ev[-1]["e"], "invalid")
	assert_eq(run.apply({"t": "accept"})[0]["e"], "sold")


func test_glamour_raises_the_limit_and_requotes() -> void:
	var run := sl_run("calm")
	run.spells_known.append("glamour")
	run.casts_left = 3
	var before: int = int(run.customer["offer"]["price"])
	run.tuning.set_value("spell_backfire_base", 0.0)
	run.tuning.set_value("spell_backfire_per_dread", 0.0)
	var ev: Array[Dictionary] = run.apply({"t": "cast", "spell": "glamour"})
	var quotes: Array[Dictionary] = ev.filter(func(e: Dictionary) -> bool: return e["e"] == "buyer_offer")
	assert_eq(quotes.size(), 1)
	assert_true(int(quotes[0]["offer"]) > before)


func test_counter_survives_snapshot() -> void:
	var run := sl_run("calm")
	run.apply({"t": "counter", "amount": sl_limit(run) + 10})
	var b := RunState.new()
	b.restore(run.snapshot(), run.catalog)
	assert_eq(b.state_hash(), run.state_hash())
	assert_eq(b.apply({"t": "accept"})[0]["price"], run.apply({"t": "accept"})[0]["price"])


func test_collector_and_regulars_keep_fixed_prices() -> void:
	var run := sl_run("calm")
	run.customer = {"kind": "buyer", "category": "toy", "imposter": false, "pay_mult": 1.0, "cursed_mult": 1.0, "collector": true,
		"want": {"category": "toy", "curse": "", "text": "x"}, "type": "collector_boss"}
	assert_false(run._ordinary_buyer())
	assert_eq(run.apply({"t": "accept"})[0]["e"], "invalid")
