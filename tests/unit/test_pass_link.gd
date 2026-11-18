extends TestCase
## Pass-it-on codes. Helpers prefixed pl_ (one class_name space).


func pl_run(seed_value: int) -> RunState:
	var run := RunState.new()
	run.start(seed_value, Catalog.load_default(), Tuning.new())
	return run


func pl_cursed_item(run: RunState) -> Dictionary:
	var obj: Dictionary = run.catalog.objects[0]
	return {"uid": 1, "id": obj["id"], "name": obj["name"], "category": obj["category"], "value": 50,
		"curse": run.catalog.curses[0]["id"], "est": 40, "tells": 1}


func test_round_trip_keeps_object_curse_and_history() -> void:
	var run := pl_run(5)
	var item := pl_cursed_item(run)
	var code: String = PassLink.encode(item, run, "Mara")
	assert_true(code.begins_with("1"))
	assert_false(code.contains("+") or code.contains("/") or code.contains("="), "URL safe")
	var gift: Dictionary = PassLink.decode(code, run.catalog, run.tuning)
	assert_eq(gift["id"], item["id"])
	assert_eq(gift["curse"], item["curse"])
	assert_eq(gift["value"], int(round(float(run.catalog.objects[0]["value"]) * run.tuning.cursed_value_mult)),
		"value comes from the receiver's catalog, not the link")
	assert_eq(gift["history"], [["Mara", run.night, 0, false]])


func test_history_grows_and_is_capped() -> void:
	var run := pl_run(5)
	var item := pl_cursed_item(run)
	for i: int in range(PassLink.MAX_HISTORY + 3):
		var gift: Dictionary = PassLink.decode(PassLink.encode(item, run, "p%d" % i), run.catalog, run.tuning)
		item = gift
	assert_eq((item["history"] as Array).size(), PassLink.MAX_HISTORY)
	assert_eq(item["history"][-1][0], "p%d" % (PassLink.MAX_HISTORY + 2), "newest holder kept")


func test_gift_starts_a_run() -> void:
	var run := pl_run(5)
	var gift: Dictionary = PassLink.decode(PassLink.encode(pl_cursed_item(run), run, ""), run.catalog, run.tuning)
	var next := RunState.new()
	next.start(9, run.catalog, Tuning.new(), gift)
	assert_eq(next.inventory.size(), 1)
	assert_eq(next.inventory[0]["curse"], gift["curse"])


func test_bad_codes_decode_to_nothing() -> void:
	var run := pl_run(5)
	var good: String = PassLink.encode(pl_cursed_item(run), run, "x")
	for bad: String in ["", "1", "2" + good.substr(1), good.substr(0, good.length() - 6), "1!!!!"]:
		assert_eq(PassLink.decode(bad, run.catalog, run.tuning), {}, "rejects %s" % bad.left(12))


func test_unknown_object_or_curse_is_rejected() -> void:
	var run := pl_run(5)
	var item := pl_cursed_item(run)
	item["id"] = "no_such_object"
	assert_eq(PassLink.decode(PassLink.encode(item, run, ""), run.catalog, run.tuning), {})
	item = pl_cursed_item(run)
	item["curse"] = "no_such_curse"
	assert_eq(PassLink.decode(PassLink.encode(item, run, ""), run.catalog, run.tuning), {})


func test_pick_worst_prefers_cursed_then_cheapest() -> void:
	var run := pl_run(5)
	var a := pl_cursed_item(run)
	a["curse"] = ""
	a["value"] = 30
	var b := a.duplicate()
	b["value"] = 10
	run.inventory.assign([a, b])
	assert_eq(PassLink.pick_worst(run)["value"], 10)
	var c := pl_cursed_item(run)
	c["value"] = 500
	run.inventory.append(c)
	assert_eq(PassLink.pick_worst(run)["curse"], c["curse"])
	run.inventory.clear()
	assert_eq(PassLink.pick_worst(run), {})


func test_url_and_pasted_text() -> void:
	assert_eq(PassLink.url("https://example.test/play", "1abc"), "https://example.test/play#gift=1abc")
	assert_eq(PassLink.code_from_text("  https://example.test/play#gift=1abc \n"), "1abc")
	assert_eq(PassLink.code_from_text("1abc"), "1abc")


func test_handle_is_cleaned() -> void:
	assert_eq(PassLink.pass_clean_handle("  a\nb\tc  "), "abc")
	assert_eq(PassLink.pass_clean_handle("x".repeat(40)).length(), PassLink.MAX_HANDLE)
