extends TestCase
## Core shop rules. Helpers here are prefixed rs_ (one class_name space).


func rs_run(seed_value: int = 7, tun: Tuning = null) -> RunState:
	var run := RunState.new()
	run.start(seed_value, Catalog.load_default(), tun if tun != null else Tuning.new())
	return run


## Passes until a seller shows up (or the run ends).
func rs_to_seller(run: RunState) -> void:
	var guard: int = 0
	while not run.is_over() and run.customer.get("kind", "") != RunState.SELLER and guard < 200:
		run.apply({"t": "pass"})
		guard += 1


func test_start_state() -> void:
	var run := rs_run()
	assert_eq(run.night, 1)
	assert_eq(run.cash, 100)
	assert_eq(run.customer["kind"], RunState.SELLER, "empty shop gets a seller first")
	assert_eq(run.rent_for(1), 40)
	assert_eq(run.rent_for(3), 90)


func test_same_seed_same_run() -> void:
	var a := rs_run(11)
	var b := rs_run(11)
	for i: int in range(40):
		a.apply({"t": "pass"})
		b.apply({"t": "pass"})
	assert_eq(a.state_hash(), b.state_hash())


func test_inspect_costs_time_and_narrows_estimate() -> void:
	var run := rs_run()
	var before: float = run.clock
	var spread0: float = float(run.estimate()["spread"])
	var ev: Array[Dictionary] = run.apply({"t": "inspect", "tool": "uv"})
	assert_eq(ev[0]["e"], "inspected")
	assert_near(run.clock, before - 15.0)
	assert_true(float(run.estimate()["spread"]) < spread0, "spread shrinks")
	assert_eq(run.apply({"t": "inspect", "tool": "uv"})[0]["e"], "invalid", "same tool twice")


func test_cursed_object_shows_its_tell() -> void:
	var tun := Tuning.new()
	tun.set_value("cursed_share", 1.0)
	var run := rs_run(3, tun)
	var cid: String = run.customer["item"]["curse"]
	assert_true(cid != "", "cursed")
	var tells: Dictionary = run.catalog.curse(cid)["tells"]
	var tool: String = str(tells.keys()[0])
	var ev: Array[Dictionary] = run.apply({"t": "inspect", "tool": tool})
	assert_eq(ev[0]["tell"], tells[tool])


func test_buy_takes_cash_and_adds_item() -> void:
	var run := rs_run()
	var ask: int = int(run.customer["ask"])
	var ev: Array[Dictionary] = run.apply({"t": "buy"})
	assert_eq(ev[0]["e"], "bought")
	assert_eq(run.cash, 100 - ask)
	assert_eq(run.inventory.size(), 1)


func test_low_offers_run_out_patience() -> void:
	var run := rs_run()
	var patience: int = int(run.customer["patience"])
	var left: bool = false
	for i: int in range(patience):
		var ev: Array[Dictionary] = run.apply({"t": "offer", "amount": 1})
		if ev[0]["e"] == "left":
			left = true
	assert_true(left, "seller walks out")


func test_offer_at_reserve_buys() -> void:
	var run := rs_run()
	var reserve: int = int(run.customer["reserve"])
	var ev: Array[Dictionary] = run.apply({"t": "offer", "amount": reserve})
	assert_eq(ev[0]["e"], "bought")
	assert_eq(ev[0]["price"], reserve)


func test_missed_rent_ends_run() -> void:
	var tun := Tuning.new()
	tun.set_value("start_cash", 0.0)
	var run := rs_run(5, tun)
	var guard: int = 0
	while not run.is_over() and guard < 100:
		run.apply({"t": "pass"})
		guard += 1
	assert_true(run.is_over())
	assert_false(run.won)
	assert_eq(run.night, 1)


func test_paying_every_rent_wins() -> void:
	var tun := Tuning.new()
	tun.set_value("start_cash", 1000.0)
	tun.set_value("rent_base", 10.0)
	var run := rs_run(5, tun)
	var guard: int = 0
	while not run.is_over() and guard < 500:
		run.apply({"t": "pass"})
		guard += 1
	assert_true(run.won)
	assert_eq(run.night, 5)


func test_cursed_buy_raises_dread_and_wakes() -> void:
	var tun := Tuning.new()
	tun.set_value("cursed_share", 1.0)
	tun.set_value("wake_threshold", 1.0)
	tun.set_value("start_cash", 1000.0)
	var run := rs_run(9, tun)
	var ev: Array[Dictionary] = run.apply({"t": "buy"})
	var woke: bool = false
	for e: Dictionary in ev:
		if e["e"] == "wake":
			woke = true
	assert_true(woke, "wake event")
	assert_eq(run.wake_nights, [1] as Array[int])


func test_sell_to_buyer() -> void:
	var tun := Tuning.new()
	tun.set_value("start_cash", 1000.0)
	tun.set_value("seller_share", 0.0)
	tun.set_value("buyer_match_chance", 1.0)
	tun.set_value("cursed_share", 0.0)
	var run := rs_run(4, tun)
	run.apply({"t": "buy"})
	assert_eq(run.customer["kind"], RunState.BUYER)
	var item: Dictionary = run.sellable()[0]
	var price: int = run.sale_price(item)
	var cash: int = run.cash
	var ev: Array[Dictionary] = run.apply({"t": "sell", "uid": item["uid"]})
	assert_eq(ev[0]["e"], "sold")
	assert_eq(run.cash, cash + price)
	assert_true(run.inventory.is_empty())


func test_snapshot_restore_continues_identically() -> void:
	var a := rs_run(21)
	var bot := ShopBot.new(ShopBot.GREEDY)
	for i: int in range(15):
		a.apply(bot.decide(a))
	var b := RunState.new()
	b.restore(a.snapshot(), a.catalog)
	assert_eq(b.state_hash(), a.state_hash(), "restored hash")
	for i: int in range(30):
		if a.is_over():
			break
		a.apply(bot.decide(a))
		b.apply(bot.decide(b))
	assert_eq(b.state_hash(), a.state_hash(), "continued hash")


func test_gift_starts_in_inventory() -> void:
	var run := RunState.new()
	var gift: Dictionary = {"id": "x", "name": "Gift", "category": "toy", "value": 50, "curse": "lucky_paw", "est": 50, "tells": 0}
	run.start(2, Catalog.load_default(), Tuning.new(), gift)
	assert_eq(run.inventory.size(), 1)
	assert_near(run.sale_mult(), 1.5)
