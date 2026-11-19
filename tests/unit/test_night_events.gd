extends TestCase
## Dusk events: blackout, storm, auction, full moon. Helpers are prefixed ne_.


func ne_run(event_id: String, seed_value: int = 5) -> RunState:
	var run := RunState.new()
	var tun := Tuning.new()
	tun.set_value("wake_threshold", 1000.0)
	run.start(seed_value, Catalog.load_default(), tun)
	var def: Dictionary = NightEvents.get_event(event_id)
	run.night = 2
	run.night_event = {"id": event_id, "name": def["name"], "text": def["text"], "mods": (def["mods"] as Dictionary).duplicate(),
		"auction_done": false}
	return run


func ne_seller(run: RunState, curse: String = "") -> void:
	run.customer = {"kind": "seller", "item": {"id": "y", "name": "Spoon", "category": "relic", "value": 100, "curse": curse,
		"hidden": {}}, "reserve": 50, "ask": 80, "patience": 2, "type": "", "noise_u": 0.0, "tools": [], "tells": [],
		"imposter": false}


func test_data_is_valid() -> void:
	assert_eq(NightEvents.problems().size(), 0, ", ".join(NightEvents.problems()))
	assert_eq(NightEvents.all().size(), 4)


func test_roll_is_seeded_and_never_on_night_one() -> void:
	assert_true(NightEvents.roll(7, 1, 1.0).is_empty(), "night 1")
	assert_eq(NightEvents.roll(7, 3, 1.0).get("id"), NightEvents.roll(7, 3, 1.0).get("id"))
	assert_true(NightEvents.roll(7, 3, 0.0).is_empty(), "chance 0")
	var seen: Dictionary = {}
	for s: int in range(80):
		seen[NightEvents.roll(s, 3, 1.0).get("id", "")] = true
	assert_eq(seen.size(), 4, "all four turn up")


func test_roll_share_follows_chance() -> void:
	var hits: int = 0
	for s: int in range(400):
		hits += 0 if NightEvents.roll(s, 2, 0.35).is_empty() else 1
	assert_true(hits > 100 and hits < 190, "about 35 percent: %d of 400" % hits)


func test_night_event_fires_in_the_next_night() -> void:
	var tun := Tuning.new()
	tun.set_value("night_event_chance", 1.0)
	tun.set_value("wake_threshold", 1000.0)
	tun.set_value("start_cash", 2000.0)
	var run := RunState.new()
	run.start(3, Catalog.load_default(), tun)
	var guard: int = 0
	var fired: Array[Dictionary] = []
	while not run.is_over() and fired.is_empty() and guard < 600:
		guard += 1
		var ev: Array[Dictionary] = run.apply({"t": "table_leave"} if run.phase == "table" else {"t": "pass"})
		fired = ev.filter(func(e: Dictionary) -> bool: return e["e"] == "night_event")
	assert_eq(fired.size(), 1)
	assert_eq(fired[0]["night"], 2)
	assert_true(str(fired[0]["text"]) != "")
	assert_eq(run.night_event["id"], fired[0]["id"])


func test_blackout_doubles_tool_time() -> void:
	var run := ne_run("blackout")
	ne_seller(run)
	var before: float = run.clock
	run.apply({"t": "inspect", "tool": "uv"})
	assert_near(run.clock, before - run.tuning.inspect_minutes * 2.0)
	var calm := ne_run("blackout")
	calm.night_event = {}
	ne_seller(calm)
	var b2: float = calm.clock
	calm.apply({"t": "inspect", "tool": "uv"})
	assert_near(calm.clock, b2 - calm.tuning.inspect_minutes)


func test_storm_means_fewer_customers_and_higher_prices() -> void:
	var run := ne_run("storm")
	assert_near(run._customer_minutes(), run.tuning.customer_minutes * 1.4)
	var calm := ne_run("storm")
	calm.night_event = {}
	ne_seller(run)
	ne_seller(calm)
	var item: Dictionary = {"id": "x", "name": "T", "category": "toy", "value": 100, "curse": "", "uid": 50, "est": 50, "tells": 0}
	run.customer = {"kind": "buyer", "category": "toy", "imposter": false, "pay_mult": 1.0, "cursed_mult": 1.0}
	calm.customer = run.customer.duplicate()
	assert_true(run.sale_price(item) > calm.sale_price(item), "buyers pay more")
	var n_storm: int = 0
	var n_calm: int = 0
	for r: RunState in [run, calm]:
		r.cash = 100000
		r.clock = 280.0
		var guard: int = 0
		while r.clock >= r._customer_minutes() and guard < 100:
			r.customer = {}
			var ev: Array[Dictionary] = []
			r._roll_customer(ev)
			guard += 1
			if r == run:
				n_storm += 1
			else:
				n_calm += 1
	assert_true(n_storm < n_calm, "storm %d vs calm %d" % [n_storm, n_calm])


func test_storm_raises_seller_prices() -> void:
	var storm_sum: int = 0
	var calm_sum: int = 0
	for seed_value: int in range(1, 40):
		for stormy: bool in [true, false]:
			var r := ne_run("storm", seed_value)
			if not stormy:
				r.night_event = {}
			r.rng.seed = seed_value
			r.customer = {}
			r.inventory.clear()
			r.tuning.set_value("seller_share", 1.0)
			r._roll_customer([] as Array[Dictionary])
			if r.customer.get("kind", "") != "seller":
				continue
			if stormy:
				storm_sum += int(r.customer["reserve"])
			else:
				calm_sum += int(r.customer["reserve"])
	assert_true(storm_sum > calm_sum, "storm %d vs calm %d" % [storm_sum, calm_sum])


func test_auction_brings_a_fine_lot_first_and_once() -> void:
	var run := ne_run("auction")
	var ev: Array[Dictionary] = []
	run.customer = {}
	run._next_customer(ev)
	var c: Dictionary = ev.filter(func(e: Dictionary) -> bool: return e["e"] == "customer")[0]
	assert_true(bool(c["auction"]), "auction flag")
	assert_eq(c["kind"], "seller")
	assert_true(int(run.customer["item"]["value"]) >= 60, "a valuable lot")
	var ev2: Array[Dictionary] = []
	run._next_customer(ev2)
	var c2: Dictionary = ev2.filter(func(e: Dictionary) -> bool: return e["e"] == "customer")[0]
	assert_false(c2.has("auction"), "only one auction lot")


func test_full_moon_doubles_curses() -> void:
	var run := ne_run("full_moon")
	var calm := ne_run("full_moon")
	calm.night_event = {}
	run.cash = 1000
	calm.cash = 1000
	for r: RunState in [run, calm]:
		ne_seller(r, "sleepwalker")
		r._buy_at(50, [] as Array[Dictionary])
	assert_near(run.dread, calm.dread * 2.0, 0.001)
	var cursed_runs: int = 0
	var cursed_calm: int = 0
	for i: int in range(300):
		for pair: Array in [[run, 0], [calm, 1]]:
			var r: RunState = pair[0]
			r.customer = {}
			r.inventory.clear()
			r.clock = 500.0
			r._roll_customer([] as Array[Dictionary])
			if r.customer.get("kind", "") == "seller" and r.customer["item"]["curse"] != "":
				if int(pair[1]) == 0:
					cursed_runs += 1
				else:
					cursed_calm += 1
	assert_true(cursed_runs > cursed_calm * 1.5, "moon %d vs calm %d" % [cursed_runs, cursed_calm])
	var item: Dictionary = {"id": "x", "name": "T", "category": "toy", "value": 100, "curse": "sleepwalker", "uid": 50, "est": 50, "tells": 0}
	run.inventory = [item]
	calm.inventory = [item]
	run.customer = {"kind": "buyer", "category": "toy", "imposter": false, "pay_mult": 1.0, "cursed_mult": 1.0}
	calm.customer = run.customer.duplicate()
	assert_true(run.sale_price(item) > calm.sale_price(item), "buyers pay more for curses")


func test_event_clears_at_night_end_and_survives_snapshot() -> void:
	var run := ne_run("blackout")
	var b := RunState.new()
	b.restore(run.snapshot(), run.catalog)
	assert_eq(b.state_hash(), run.state_hash())
	run.cash = 5000
	run.clock = 0.0
	run._end_night([] as Array[Dictionary])
	assert_true(run.night_event.is_empty(), "cleared when the night ends")
