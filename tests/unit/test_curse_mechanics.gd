extends TestCase
## Curses 9-12: costume_change, copycat, bashful_purse, landlord_lullaby. Helpers are prefixed cm_.


func cm_run(seed_value: int = 5) -> RunState:
	var run := RunState.new()
	var tun := Tuning.new()
	tun.set_value("wake_threshold", 1000.0)  # no wake breaks an object mid-test
	run.start(seed_value, Catalog.load_default(), tun)
	return run


func cm_item(run: RunState, curse: String, category: String = "toy") -> Dictionary:
	var item: Dictionary = {"id": "x", "name": "Thing", "category": category, "value": 50, "curse": curse,
		"uid": run._take_uid(), "est": 50, "tells": 0}
	run.inventory.append(item)
	return item


func cm_seller_with_item(run: RunState, curse: String) -> void:
	run.customer = {"kind": "seller", "item": {"id": "y", "name": "Spoon", "category": "tool", "value": 30, "curse": curse,
		"hidden": {}}, "reserve": 5, "ask": 5, "patience": 2, "type": "", "noise_u": 0.0, "tools": [], "tells": [],
		"imposter": false}


func test_catalog_has_twelve_curses_with_tells() -> void:
	var cat := Catalog.load_default()
	assert_eq(cat.curses.size(), 12)
	assert_eq(cat.problems().size(), 0, "problems: %s" % ", ".join(cat.problems()))
	for id: String in ["costume_change", "copycat", "bashful_purse", "landlord_lullaby"]:
		assert_true((cat.curse(id)["tells"] as Dictionary).size() >= 2, "%s has tells" % id)


func test_costume_change_swaps_category_each_night() -> void:
	var run := cm_run()
	var item: Dictionary = cm_item(run, "costume_change", "toy")
	var clean: Dictionary = cm_item(run, "", "toy")
	var ev: Array[Dictionary] = []
	run._shift_categories(ev)
	assert_eq(ev.size(), 1, "only the cursed one shifts")
	assert_eq(ev[0]["e"], "curse_shift")
	assert_true(item["category"] != "toy", "category changed")
	assert_eq(ev[0]["to"], item["category"])
	assert_eq(clean["category"], "toy")


func test_copycat_copies_onto_next_object_once() -> void:
	var run := cm_run()
	var src: Dictionary = cm_item(run, "copycat")
	run.cash = 1000
	cm_seller_with_item(run, "")
	var ev: Array[Dictionary] = []
	run._buy_at(5, ev)
	var copied: Array[Dictionary] = ev.filter(func(e: Dictionary) -> bool: return e["e"] == "curse_copied")
	assert_eq(copied.size(), 1, "copied")
	assert_eq(run.inventory[-1]["curse"], "copycat")
	assert_true(bool(src["spread_used"]))
	# The copy and the source do not spread again.
	cm_seller_with_item(run, "")
	var ev2: Array[Dictionary] = []
	run._buy_at(5, ev2)
	assert_eq(ev2.filter(func(e: Dictionary) -> bool: return e["e"] == "curse_copied").size(), 0)
	assert_eq(run.inventory[-1]["curse"], "")


func test_copycat_does_not_overwrite_a_curse() -> void:
	var run := cm_run()
	cm_item(run, "copycat")
	run.cash = 1000
	cm_seller_with_item(run, "sleepwalker")
	var ev: Array[Dictionary] = []
	run._buy_at(5, ev)
	assert_eq(run.inventory[-1]["curse"], "sleepwalker")
	assert_false(bool(run.inventory[0].get("spread_used", false)), "still waiting")


func test_bashful_purse_pays_only_if_never_inspected() -> void:
	var run := cm_run()
	var unseen: Dictionary = cm_item(run, "bashful_purse")
	unseen["inspected"] = false
	var pay: int = int(run.catalog.curse("bashful_purse")["night_cash_unseen"])
	var ev: Array[Dictionary] = []
	var cash0: int = run.cash
	run.cash = 1000
	run.clock = 0.0
	run._end_night(ev)
	assert_eq(ev[0]["curse_cash"], pay, "unseen pays")
	var run2 := cm_run()
	var seen: Dictionary = cm_item(run2, "bashful_purse")
	seen["inspected"] = true
	var ev2: Array[Dictionary] = []
	run2.cash = 1000
	run2._end_night(ev2)
	assert_eq(ev2[0]["curse_cash"], 0, "inspected pays nothing")
	assert_true(cash0 >= 0)


func test_buying_after_inspecting_marks_item_inspected() -> void:
	var run := cm_run()
	run.cash = 1000
	cm_seller_with_item(run, "bashful_purse")
	(run.customer["tools"] as Array).append("uv")
	var ev: Array[Dictionary] = []
	run._buy_at(5, ev)
	assert_true(bool(run.inventory[-1]["inspected"]))
	cm_seller_with_item(run, "bashful_purse")
	run._buy_at(5, ev)
	assert_false(bool(run.inventory[-1]["inspected"]))


func test_landlord_lullaby_lowers_rent() -> void:
	var run := cm_run()
	var base: int = run.rent_for(2)
	cm_item(run, "landlord_lullaby")
	var want: int = int(round(run.tuning.rent_base * run.tuning.rent_growth * 0.8))
	assert_eq(run.rent_for(2), want)
	assert_true(run.rent_for(2) < base)


func test_landlord_lullaby_whispers_customers_away() -> void:
	var run := cm_run(9)
	cm_item(run, "landlord_lullaby")
	var whispered: int = 0
	var guard: int = 0
	while not run.is_over() and guard < 300:
		for e: Dictionary in run.apply({"t": "pass"}):
			if e["e"] == "whispered_away":
				whispered += 1
		guard += 1
	assert_true(whispered > 0, "some customers whispered away")


func test_no_lullaby_no_whisper() -> void:
	var run := cm_run(9)
	var ev: Array[Dictionary] = []
	for i: int in range(30):
		ev.append_array(run.apply({"t": "pass"}))
	assert_eq(ev.filter(func(e: Dictionary) -> bool: return e["e"] == "whispered_away").size(), 0)


func test_new_curses_survive_snapshot_restore() -> void:
	var run := cm_run()
	cm_item(run, "copycat")["spread_used"] = true
	var b := RunState.new()
	b.restore(run.snapshot(), run.catalog)
	assert_eq(b.state_hash(), run.state_hash())
