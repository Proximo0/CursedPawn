extends TestCase
## Customer types 13-16 (seer, errand child, debt collector, twins). Helpers are prefixed ct_.


func ct_run(seed_value: int = 4) -> RunState:
	var run := RunState.new()
	var tun := Tuning.new()
	tun.set_value("wake_threshold", 1000.0)
	run.start(seed_value, Catalog.load_default(), tun)
	return run


## Rolls customers with only `tid` of its kind weighted, returns every event of `n` customers.
func ct_force(tid: String, kind: String, n: int, seed_value: int = 4) -> Array[Dictionary]:
	var run := ct_run(seed_value)
	for t: Dictionary in run.catalog.customers:
		if str(t["kind"]) == kind:
			t["weight"] = 1.0 if str(t["id"]) == tid else 0.0
	run.rng.seed = seed_value
	var out: Array[Dictionary] = []
	for i: int in range(n):
		var ev: Array[Dictionary] = []
		run.customer = {}
		run.clock = 500.0
		run._roll_customer(ev)
		out.append_array(ev)
	return out


func test_catalog_has_the_new_types() -> void:
	var cat := Catalog.load_default()
	assert_eq(cat.problems().size(), 0, ", ".join(cat.problems()))
	for id: String in ["seer", "errand_child", "debt_collector", "twin_a", "twin_b"]:
		var found: bool = false
		for t: Dictionary in cat.customers:
			found = found or str(t["id"]) == id
		assert_true(found, id)


func test_seer_senses_curses() -> void:
	var cursed: int = 0
	var sensed_cursed: int = 0
	var sensed_clean: int = 0
	var clean: int = 0
	var run := ct_run(8)
	for t: Dictionary in run.catalog.customers:
		if str(t["kind"]) == "seller":
			t["weight"] = 1.0 if str(t["id"]) == "seer" else 0.0
	run.tuning.set_value("cursed_share", 0.5)
	for i: int in range(200):
		var ev: Array[Dictionary] = []
		run.inventory.clear()
		run.customer = {}
		run.clock = 500.0
		run._roll_customer(ev)
		var has: bool = run.customer["item"]["curse"] != ""
		if has:
			cursed += 1
			sensed_cursed += 1 if ev[0].has("sense") else 0
		else:
			clean += 1
			sensed_clean += 1 if ev[0].has("sense") else 0
	assert_true(float(sensed_cursed) / cursed > 0.6, "senses most curses")
	assert_true(float(sensed_clean) / clean < 0.3, "rarely cries wolf")


func test_errand_child_brings_small_things() -> void:
	var ev: Array[Dictionary] = ct_force("errand_child", "seller", 30)
	var names: Dictionary = {}
	for o: Dictionary in Catalog.load_default().objects:
		names[o["name"]] = float(o["value"])
	assert_eq(ev.size(), 30)
	for e: Dictionary in ev:
		assert_true(float(names[e["name"]]) <= 45.0, "%s is small" % e["name"])


func test_debt_collector_takes_cash_and_pays_well() -> void:
	var run := ct_run(6)
	for t: Dictionary in run.catalog.customers:
		if str(t["kind"]) == "buyer":
			t["weight"] = 1.0 if str(t["id"]) == "debt_collector" else 0.0
	run.inventory.append({"id": "x", "name": "Thing", "category": "toy", "value": 50, "curse": "", "uid": 99, "est": 50, "tells": 0})
	run.tuning.set_value("seller_share", 0.0)
	run.cash = 200
	run.customer = {}
	run.clock = 500.0
	var ev: Array[Dictionary] = []
	run._roll_customer(ev)
	assert_eq(ev[0]["tid"], "debt_collector")
	assert_eq(ev[1]["e"], "debt_taken")
	assert_eq(ev[1]["amount"], 20, "10 percent of 200")
	assert_eq(run.cash, 180)


func test_debt_never_takes_more_than_you_have() -> void:
	var run := ct_run(6)
	for t: Dictionary in run.catalog.customers:
		if str(t["kind"]) == "buyer":
			t["weight"] = 1.0 if str(t["id"]) == "debt_collector" else 0.0
	run.inventory.append({"id": "x", "name": "Thing", "category": "toy", "value": 50, "curse": "", "uid": 99, "est": 50, "tells": 0})
	run.tuning.set_value("seller_share", 0.0)
	run.cash = 2
	run.customer = {}
	var ev: Array[Dictionary] = []
	run._roll_customer(ev)
	assert_eq(run.cash, 0)
	assert_eq(ev[1]["amount"], 2)


func ct_twin_run() -> RunState:
	var run := ct_run(12)
	run.cash = 1000
	run.customer = {"kind": "seller", "item": {"id": "spinning_top", "name": "Spinning top", "category": "toy", "value": 15,
		"curse": "", "hidden": {}}, "reserve": 5, "ask": 5, "patience": 2, "type": "twin_a", "noise_u": 0.0, "tools": [],
		"tells": [], "imposter": false}
	return run


func test_twin_returns_as_a_buyer_for_the_same_object() -> void:
	var run := ct_twin_run()
	var ev: Array[Dictionary] = run.apply({"t": "buy"})
	assert_true(run.twin.has("uid"), "twin pending")
	var cust: Array[Dictionary] = ev.filter(func(e: Dictionary) -> bool: return e["e"] == "customer")
	assert_true(cust.size() == 1 and not cust[0].has("twin"), "one ordinary customer comes between")
	var guard: int = 0
	while not run.customer.get("twin", false) and guard < 20 and run.phase == "customer":
		run.apply({"t": "pass"})
		guard += 1
	assert_true(run.customer.get("twin", false), "the other twin arrived")
	assert_eq(run.customer["kind"], "buyer")
	assert_eq(run.customer["type"], "twin_b")
	assert_eq(run.sellable().size(), 1)
	assert_true(run.sale_price(run.sellable()[0]) > 0)
	var sold: Array[Dictionary] = run.apply({"t": "sell", "uid": run.sellable()[0]["uid"]})
	assert_eq(sold[0]["e"], "sold")


func test_twin_does_not_return_if_object_is_gone() -> void:
	var run := ct_twin_run()
	run.apply({"t": "buy"})
	run.inventory.clear()
	for i: int in range(12):
		if run.phase != "customer":
			break
		run.apply({"t": "pass"})
		assert_false(run.customer.get("twin", false), "no twin")


func test_twin_survives_snapshot() -> void:
	var run := ct_twin_run()
	run.apply({"t": "buy"})
	var b := RunState.new()
	b.restore(run.snapshot(), run.catalog)
	assert_eq(b.state_hash(), run.state_hash())
	assert_eq(b.twin, run.twin)
