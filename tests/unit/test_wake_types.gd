extends TestCase
## Wake variety: the curse that tips the Dread decides the wake type. Helpers are prefixed wt_.


func wt_run(curse: String) -> RunState:
	var run := RunState.new()
	var tun := Tuning.new()
	tun.set_value("start_cash", 5000.0)
	tun.set_value("wake_threshold", 1.0)
	tun.set_value("dread_on_buy", 5.0)
	run.start(5, Catalog.load_default(), tun)
	run.customer = {"kind": "seller", "item": {"id": "y", "name": "Spoon", "category": "relic", "value": 100, "curse": curse,
		"hidden": {}}, "reserve": 5, "ask": 5, "patience": 2, "type": "", "noise_u": 0.0, "tools": [], "tells": [],
		"imposter": false}
	return run


func wt_wake(ev: Array[Dictionary]) -> Dictionary:
	for e: Dictionary in ev:
		if e["e"] == "wake":
			return e
	return {}


func test_every_curse_names_a_known_wake_type() -> void:
	var cat := Catalog.load_default()
	var used: Dictionary = {}
	for c: Dictionary in cat.curses:
		assert_true(Catalog.WAKE_TYPES.has(str(c.get("wake", ""))), "%s has a wake type" % c["id"])
		used[c["wake"]] = true
	assert_eq(used.size(), 5, "all five types are used")


func test_wake_carries_type_and_curse() -> void:
	for pair: Array in [["lucky_paw", "possession"], ["heavy_heart", "topple"], ["sleepwalker", "drift"],
			["thirsty_mirror", "lights_out"], ["whispering_debt", "door_lock"]]:
		var run := wt_run(str(pair[0]))
		var w: Dictionary = wt_wake(run.apply({"t": "buy"}))
		assert_eq(w.get("wake_type"), pair[1], str(pair[0]))
		assert_eq(w.get("curse"), pair[0])


func test_door_lock_always_closes_the_shop() -> void:
	for seed_value: int in range(1, 8):
		var run := wt_run("whispering_debt")
		run.tuning.set_value("wake_close_chance", 0.0)
		var w: Dictionary = wt_wake(run.apply({"t": "buy"}))
		assert_true(bool(w["closed"]), "locked at seed %d" % seed_value)
		assert_near(run.clock, 0.0)


func test_other_wakes_keep_the_close_roll() -> void:
	var run := wt_run("heavy_heart")
	run.tuning.set_value("wake_close_chance", 0.0)
	var w: Dictionary = wt_wake(run.apply({"t": "buy"}))
	assert_false(bool(w["closed"]))


func test_wake_without_a_tipping_curse_uses_the_heaviest_held_one_or_drift() -> void:
	var run := wt_run("")
	run.inventory.append({"id": "x", "name": "T", "category": "toy", "value": 50, "curse": "thirsty_mirror", "uid": 77, "est": 1, "tells": 0})
	run.dread = 50.0
	var ev: Array[Dictionary] = []
	run._check_wake(ev)
	assert_eq(ev[0]["wake_type"], "lights_out")
	var bare := wt_run("")
	bare.dread = 50.0
	var ev2: Array[Dictionary] = []
	bare._check_wake(ev2)
	assert_eq(ev2[0]["wake_type"], "drift")
	assert_eq(ev2[0]["curse"], "")


func test_unknown_wake_type_is_a_problem() -> void:
	var cat := Catalog.load_default()
	cat.curses[0]["wake"] = "zzz"
	assert_eq(cat.problems().size(), 1)
