extends TestCase
## Seller moods and smarter counter-offers. Helpers are prefixed md_.


func md_run(mood: String) -> RunState:
	var run := RunState.new()
	var tun := Tuning.new()
	tun.set_value("wake_threshold", 1000.0)
	tun.set_value("start_cash", 5000.0)
	run.start(5, Catalog.load_default(), tun)
	run.customer = {"kind": "seller", "item": {"id": "y", "name": "Spoon", "category": "relic", "value": 200, "curse": "",
		"hidden": {}}, "reserve": 100, "ask": 200, "patience": 6, "type": "", "noise_u": 0.0, "tools": [], "tells": [],
		"imposter": false, "mood": mood}
	return run


func md_counter(ev: Array[Dictionary]) -> Dictionary:
	for e: Dictionary in ev:
		if e["e"] == "counter":
			return e
	return {}


func test_data_is_valid() -> void:
	assert_eq(Moods.problems().size(), 0, ", ".join(Moods.problems()))
	assert_eq(Moods.all().size(), 3)


func test_customer_event_carries_mood_and_a_readable_line() -> void:
	var run := RunState.new()
	run.start(9, Catalog.load_default(), Tuning.new())
	var seen: Dictionary = {}
	for i: int in range(60):
		for e: Dictionary in run.apply({"t": "pass"}):
			if e["e"] == "customer" and e["kind"] == "seller" and e.has("mood"):
				seen[e["mood"]] = true
				assert_true(str(e["mood_line"]) != "", "line for %s" % e["mood"])
	assert_eq(seen.size(), 3, "all three moods turn up")


func test_calm_splits_the_difference_like_before() -> void:
	var run := md_run("calm")
	var c: Dictionary = md_counter(run.apply({"t": "offer", "amount": 60}))
	assert_eq(c["ask"], 130)
	assert_eq(c["tell"], "")


func test_nervous_drops_fast_and_shows_it() -> void:
	var run := md_run("nervous")
	var c: Dictionary = md_counter(run.apply({"t": "offer", "amount": 60}))
	assert_eq(c["ask"], 100, "moves 75 percent of the gap, floored at the reserve")
	assert_true(str(c["tell"]) != "", "a nervous tell")
	var calm := md_run("calm")
	var nerv := md_run("nervous")
	nerv.customer["reserve"] = 20
	calm.customer["reserve"] = 20
	var a: int = int(md_counter(nerv.apply({"t": "offer", "amount": 10}))["ask"])
	var b: int = int(md_counter(calm.apply({"t": "offer", "amount": 10}))["ask"])
	assert_true(a < b, "nervous %d under calm %d" % [a, b])


func test_nervous_flees_from_a_lowball() -> void:
	var run := md_run("nervous")
	var ev: Array[Dictionary] = run.apply({"t": "offer", "amount": 30})
	assert_eq(ev[0]["e"], "left")
	var calm := md_run("calm")
	assert_eq(calm.apply({"t": "offer", "amount": 30})[0]["e"], "counter", "a calm seller just counters")


func test_greedy_bluffs_and_holds_the_ask() -> void:
	var held: int = 0
	var moved: int = 0
	var tell_bluff: int = 0
	var tell_honest: int = 0
	for s: int in range(300):
		var run := md_run("greedy")
		run.rng.seed = s
		var c: Dictionary = md_counter(run.apply({"t": "offer", "amount": 60}))
		if int(c["ask"]) == 200:
			held += 1
			tell_bluff += 1 if str(c["tell"]) != "" else 0
		else:
			moved += 1
			tell_honest += 1 if str(c["tell"]) != "" else 0
			assert_true(int(c["ask"]) >= 100, "never under the reserve")
	assert_true(held > 50 and held < 130, "about 30 percent bluff: %d" % held)
	assert_true(float(tell_bluff) / held > 0.55, "the bluff tell fires most of the time")
	assert_true(float(tell_honest) / moved < 0.3, "an honest counter rarely shows it")


func test_greedy_moves_slowly_when_not_bluffing() -> void:
	var asks: Array[int] = []
	for s: int in range(40):
		var r := md_run("greedy")
		r.customer["reserve"] = 20
		r.rng.seed = s
		var c: Dictionary = md_counter(r.apply({"t": "offer", "amount": 10}))
		asks.append(int(c["ask"]))
	assert_true(asks.has(153) and asks.has(200), "a quarter of the gap, or a bluff: %s" % str(asks))
	for a: int in asks:
		assert_true(a == 200 or a == 153, "got %d" % a)


func test_mood_data_moves_reserve_and_patience() -> void:
	assert_true(float(Moods.get_mood("nervous")["reserve_mult"]) < 1.0, "nervous sellers are cheaper")
	assert_true(float(Moods.get_mood("greedy")["reserve_mult"]) > 1.0, "greedy sellers ask more")
	assert_true(int(Moods.get_mood("greedy")["patience_add"]) > 0, "greedy sellers wait longer")


func test_mood_survives_snapshot() -> void:
	var run := md_run("greedy")
	var b := RunState.new()
	b.restore(run.snapshot(), run.catalog)
	assert_eq(b.customer["mood"], "greedy")
	assert_eq(b.state_hash(), run.state_hash())
