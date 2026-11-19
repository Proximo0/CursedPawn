extends TestCase


func om_run(omen: String, seed_value: int = 4, cash: float = 5000.0) -> RunState:
	var tun := Tuning.new()
	tun.set_value("start_cash", cash)
	var run := RunState.new()
	run.start(seed_value, Catalog.load_default(), tun, {}, {"omen": omen})
	return run


func test_data_is_valid() -> void:
	assert_eq(Omens.problems().size(), 0, "; ".join(Omens.problems()))
	assert_true(Omens.all().size() >= 12)


func test_offer_is_three_distinct_and_seeded() -> void:
	for s: int in range(1, 20):
		var o: Array[String] = Omens.offer(s)
		assert_eq(o.size(), 3)
		assert_true(o[0] != o[1] and o[1] != o[2] and o[0] != o[2], "distinct")
		assert_eq(o, Omens.offer(s), "stable")
		for id: String in o:
			assert_false(Omens.get_omen(id).is_empty())


func test_every_omen_changes_the_run() -> void:
	var base: Dictionary = Tuning.new().to_dict()
	for o: Dictionary in Omens.all():
		var run := om_run(str(o["id"]))
		assert_eq(run.opts["omen_name"], o["name"])
		assert_true(run.tuning.to_dict() != base or run.rules != om_run("").rules or not (o["flags"] as Dictionary).is_empty(),
			"%s has an effect" % o["id"])


func test_all_cursed() -> void:
	var run := om_run("gravedigger")
	var sellers: int = 0
	for i: int in range(20):
		if run.customer.get("kind", "") == RunState.SELLER:
			sellers += 1
			assert_true(str(run.customer["item"]["curse"]) != "", "cursed")
		run.apply({"t": "pass"})
	assert_true(sellers > 3)


func test_no_tool() -> void:
	var run := om_run("blind_lamp")
	while run.customer.get("kind", "") != RunState.SELLER:
		run.apply({"t": "pass"})
	assert_eq(run.apply({"t": "inspect", "tool": "uv"})[0]["e"], "invalid")
	assert_eq(run.apply({"t": "inspect", "tool": "scale"})[0]["e"], "inspected")


func test_start_spell() -> void:
	var run := om_run("open_book")
	assert_true(run.spells_known.has("seal"))
	assert_false(RunState.new().spells_known.has("seal"), "only this run")


func test_double_table() -> void:
	var run := om_run("gamblers_moon")
	var bot := ShopBot.new(ShopBot.GREEDY)
	while run.phase == RunState.PHASE_CUSTOMER:
		run.apply(bot.decide(run))
	assert_eq(run.phase, RunState.PHASE_TABLE)
	assert_eq(int(run.table["games_left"]), 2)


func test_one_customer_type() -> void:
	var run := om_run("regular_crowd")
	var seen: Dictionary = {}
	for i: int in range(40):
		if run.customer.get("kind", "") == RunState.SELLER:
			seen[run.customer["type"]] = true
		run.apply({"t": "pass"})
		if run.phase != RunState.PHASE_CUSTOMER:
			break
	assert_eq(seen.size(), 1, "one seller type")


func test_cursed_buyers_pay_more() -> void:
	var run := om_run("gravedigger")
	var item: Dictionary = {"category": "book", "value": 100, "curse": "x", "uid": 1}
	run.customer = {"kind": "buyer", "category": "book", "pay_mult": 1.0, "cursed_mult": 1.0, "imposter": false}
	var plain: Dictionary = {"category": "book", "value": 100, "curse": "", "uid": 2}
	assert_eq(run.sale_price(item), int(round(run.sale_price(plain) * 1.5 * Tuning.new().cursed_buyer_mult)), "the omen multiplies the base cursed-buyer pay")
