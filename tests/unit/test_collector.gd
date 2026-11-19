extends TestCase


func co_run(seed_value: int = 3) -> RunState:
	var tun := Tuning.new()
	tun.set_value("nights", 1.0)  # he arrives as the very first customer
	var run := RunState.new()
	run.start(seed_value, Catalog.load_default(), tun)
	return run


func co_item(run: RunState, value: int = 100) -> Dictionary:
	var want: Dictionary = run.collector["want"]
	var item: Dictionary = {"id": "x", "name": "Thing", "category": str(want["category"]) if str(want["category"]) != "" else "book",
		"value": value, "curse": str(want["curse"]), "uid": 900, "est": value, "tells": 0}
	run.inventory.append(item)
	return item


func co_kinds(ev: Array[Dictionary]) -> Array:
	return ev.map(func(e: Dictionary) -> String: return str(e["e"]))


func test_data_is_valid() -> void:
	assert_eq(Collector.problems(Catalog.load_default()).size(), 0, "; ".join(Collector.problems(Catalog.load_default())))


func test_want_roll_is_seeded_and_varies() -> void:
	var seen: Dictionary = {}
	for s: int in range(1, 40):
		var w: Dictionary = Collector.roll_want(s)
		assert_eq(w, Collector.roll_want(s), "stable")
		assert_true(str(w["text"]) != "")
		seen[w["text"]] = true
	assert_true(seen.size() >= 4, "several different wants")


func test_omen_on_night_3_and_arrival_first_on_night_5() -> void:
	var run := RunState.new()
	var ev: Array[Dictionary] = run.start(5, Catalog.load_default(), Tuning.new())
	var omens: int = 0
	var arrives_night: int = 0
	var bot := ShopBot.new(ShopBot.CAUTIOUS)
	var first_after_start: Array = []
	while not run.is_over() and run.commands < 600:
		for e: Dictionary in ev:
			if e["e"] == "collector_omen":
				omens += 1
				assert_eq(int(e["night"]), 3)
				assert_true(str(e["text"]) != "")
			if e["e"] == "night_start":
				first_after_start = []
			if e["e"] == "customer":
				first_after_start.append(e)
			if e["e"] == "collector_arrives":
				arrives_night = run.night
				assert_true(bool(first_after_start[0].get("boss", false)), "first customer of the night")
				assert_eq(first_after_start.size(), 1)
		ev = run.apply(bot.decide(run))
	assert_eq(omens, 1)
	if run.night >= 5 and run.customers_seen > 0 and arrives_night != 0:
		assert_eq(arrives_night, 5)


func test_pleased_sale_pays_and_gives_a_curio() -> void:
	var run := co_run()
	assert_true(bool(run.customer.get("boss", false)))
	var item: Dictionary = co_item(run, 100)
	assert_eq(run.sellable().size(), 1)
	var cash: int = run.cash
	var ev: Array[Dictionary] = run.apply({"t": "sell", "uid": 900})
	var kinds: Array = co_kinds(ev)
	assert_true(kinds.has("collector_pleased") and kinds.has("found"))
	assert_eq(run.cash, cash + int(round(100.0 * run.tuning.collector_pay_mult)))
	assert_eq(run.collector["result"], "pleased")
	var rarity: String = str(run.catalog.curio(str(run.found[0]["id"]))["rarity"])
	assert_true(rarity == "rare" or rarity == "legendary", rarity)
	assert_false(item.is_empty())


func test_refusal_on_pass_takes_toll_and_curses() -> void:
	var run := co_run()
	run.cash = 200
	var dread: float = run.dread
	var ev: Array[Dictionary] = run.apply({"t": "pass"})
	assert_true(co_kinds(ev).has("collector_refused"))
	assert_eq(run.cash, 200 - int(200 * run.tuning.collector_toll_frac))
	assert_near(run.dread, dread + run.tuning.collector_curse_dread)
	assert_eq(run.collector["result"], "refused")


func test_nothing_matching_is_refused_and_wrong_item_is_invalid() -> void:
	var run := co_run()
	var want: Dictionary = run.collector["want"]
	var other: String = "toy" if str(want["category"]) != "toy" else "book"
	run.inventory.append({"id": "y", "name": "Wrong", "category": other, "value": 50, "curse": "", "uid": 901, "est": 50, "tells": 0})
	assert_true(run.sellable().is_empty())
	assert_eq(co_kinds(run.apply({"t": "sell", "uid": 901})), ["invalid"])
	assert_true(co_kinds(run.apply({"t": "pass"})).has("collector_refused"))
	assert_eq(run.collector["result"], "refused")


func test_snapshot_restore_mid_visit() -> void:
	var run := co_run(8)
	var b := RunState.new()
	b.restore(run.snapshot(), run.catalog)
	assert_eq(b.state_hash(), run.state_hash())
	run.apply({"t": "pass"})
	b.apply({"t": "pass"})
	assert_eq(b.state_hash(), run.state_hash())
