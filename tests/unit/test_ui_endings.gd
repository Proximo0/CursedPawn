extends TestCase
## Ending screens: data for every ending, naming from the event or the run, and the card.


func test_every_ending_has_its_text_and_it_fits() -> void:
	for id: String in UiEndings.IDS:
		var d: Dictionary = UiEndings.info(id)
		assert_true(str(d["title"]) != "", id)
		assert_true(UiPixelFont.ui_display_width(str(d["title"]), 3, true) <= 600, "title fits " + id)
		assert_true(UiPixelFont.ui_width(str(d["sub"])) <= 600, "sub fits " + id)
		assert_eq((d["epilogue"] as Array).size(), 3)
		for ln: Variant in d["epilogue"] as Array:
			assert_true(UiPixelFont.ui_width(str(ln)) <= 620, "epilogue fits: " + str(ln))
	assert_eq(UiEndings.info("nope")["title"], "DEBT FREE", "unknown reads as the plain ending")


func test_the_event_names_the_ending() -> void:
	var run := RunState.new()
	run.start(3, Catalog.load_default(), Tuning.new())
	assert_eq(UiEndings.ending_of(run, {"ending": "regulars"}), "regulars")
	assert_eq(UiEndings.ending_of(run, {"ending": "bogus"}), "debt_free", "falls back to reading the run")
	run.opts["ending"] = "cursed"
	assert_eq(UiEndings.ending_of(run, {}), "cursed_shop")


func test_inference_from_the_run() -> void:
	var run := RunState.new()
	run.start(3, Catalog.load_default(), Tuning.new())
	assert_eq(UiEndings.infer(run), "debt_free")
	run.collector = {"result": "pleased"}
	assert_eq(UiEndings.infer(run), "collector")
	run.collector = {}
	run.dread = run.tuning.wake_threshold
	assert_eq(UiEndings.infer(run), "cursed_shop")


func test_card_shape() -> void:
	var c: Dictionary = UiEndings.card_for("collector", 120)
	assert_true(c.has("age"), "the shop game ticks every card by age")
	assert_eq(c["style"], "ending")
	assert_eq(c["ending"], "collector")
	assert_true(float(c["secs"]) > UiEndings.LINE_AT + UiEndings.LINE_STEP * 3.0, "long enough to read all three lines")


func test_the_logics_text_wins() -> void:
	var c: Dictionary = UiEndings.card_for("debt_free", 5, {"ending_name": "Debt-Free", "ending_title": "Paid in full",
		"epilogue": "Every rent paid, every lamp lit. You own a pawnshop and nothing owns you. Tonight, at least."})
	assert_eq(c["title"], "DEBT-FREE")
	assert_eq(c["sub"], "PAID IN FULL")
	assert_true((c["epilogue"] as Array).size() >= 1)
	for ln: Variant in c["epilogue"] as Array:
		assert_true(UiPixelFont.ui_width(str(ln)) <= 560)
