extends TestCase
## The detail card: what it shows for counter and shelf objects, and what it never gives away.


func ti_run() -> RunState:
	var run := RunState.new()
	run.start(3, Catalog.load_default(), Tuning.new())
	return run


func test_counter_card_has_name_text_and_no_value() -> void:
	var run: RunState = ti_run()
	run.customer = {"kind": RunState.SELLER, "tools": [], "tells": [], "ask": 40, "item": {"id": "music_box", "name": "Music box",
		"category": "toy", "value": 77, "curse": "lucky_paw"}}
	var ui := UiInspect.new()
	ui.open_counter()
	var c: Dictionary = ui.card(run, {}, {})
	assert_eq(c["name"], "Music box")
	assert_true(str(c["text"]) != "", "flavour text")
	assert_eq(c["curse"], "", "unidentified")
	assert_false(str(c).contains("77"), "value stays hidden")


func test_a_matching_tell_names_the_curse() -> void:
	var cat: Catalog = Catalog.load_default()
	var told: Dictionary = (cat.curse("lucky_paw")["tells"] as Dictionary)
	var tool: String = str(told.keys()[0])
	assert_eq(UiInspect.curse_label("lucky_paw", {tool: told[tool]}, cat), "LUCKY PAW")
	assert_eq(UiInspect.curse_label("lucky_paw", {"uv": "nothing"}, cat), "")
	assert_eq(UiInspect.curse_label("lucky_paw", {"pendulum": "cursed"}, cat), "CURSED, KIND UNKNOWN")
	assert_eq(UiInspect.curse_label("", {"pendulum": "clean"}, cat), "CLEAN, THE PENDULUM SAYS")


func test_held_card_uses_the_tells_kept_at_purchase() -> void:
	var run: RunState = ti_run()
	run.inventory.append({"uid": 9, "id": "hand_bell", "name": "Hand bell", "category": "instrument", "value": 5, "curse": ""})
	var ui := UiInspect.new()
	ui.open_held(9)
	var c: Dictionary = ui.card(run, {}, {9: {"touch": "Cold."}})
	assert_eq((c["tells"] as Array).size(), 1)
	ui.open_held(404)
	assert_eq(ui.card(run, {}, {}), {}, "gone items show nothing")


func test_provenance_falls_back_to_history() -> void:
	assert_eq(UiInspect.provenance_of({"provenance": "Found in a well."}), "Found in a well.")
	assert_true(UiInspect.provenance_of({"history": [["Ann", 3, 1, false]]}).contains("Ann"))
	assert_eq(UiInspect.provenance_of({}), "")


func test_buyer_has_no_counter_card() -> void:
	var run: RunState = ti_run()
	run.customer = {"kind": RunState.BUYER, "category": "toy"}
	var ui := UiInspect.new()
	ui.open_counter()
	assert_eq(ui.card(run, {}, {}), {})
