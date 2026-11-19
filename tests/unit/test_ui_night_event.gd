extends TestCase
## Night event cards and the tag: rules come from the mods, every event in the data has a glyph and fits.


func test_every_event_in_the_data_explains_itself() -> void:
	var all: Array[Dictionary] = NightEvents.all()
	assert_true(all.size() >= 4)
	for e: Dictionary in all:
		var rules: Array[String] = UiNightEvent.rule_lines(e["mods"] as Dictionary)
		assert_false(rules.is_empty(), "rules for " + str(e["id"]))
		for ln: String in rules:
			assert_true(UiPixelFont.ui_width(ln) <= 430, "fits: " + ln)
		assert_true(UiNightEvent.KNOWN.has(str(e["id"])), "glyph for " + str(e["id"]))


func test_rule_sentences() -> void:
	assert_eq(UiNightEvent.rule_lines({"tool_cost_mult": 2.0}), ["TOOLS TAKE TWICE AS LONG."] as Array[String])
	assert_eq(UiNightEvent.rule_lines({"price_mult": 1.15}), ["PRICES UP 15%."] as Array[String])
	assert_eq(UiNightEvent.rule_lines({"cursed_pay_mult": 1.3}), ["BUYERS PAY 30% MORE FOR CURSES."] as Array[String])
	assert_eq(UiNightEvent.rule_lines({}), [] as Array[String])


func test_tag_follows_the_run() -> void:
	var run := RunState.new()
	run.start(3, Catalog.load_default(), Tuning.new())
	assert_eq(UiNightEvent.tag_info(run), {})
	run.night_event = {"id": "storm", "name": "Storm", "text": "x", "mods": {"price_mult": 1.15}}
	var info: Dictionary = UiNightEvent.tag_info(run)
	assert_eq(info["text"], "STORM")
	assert_eq((info["tip"] as Array).size(), 1)


func test_the_event_pushes_a_card_with_its_rules() -> void:
	var g: ShopGame = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate() as ShopGame
	(Engine.get_main_loop() as SceneTree).root.add_child(g)
	g.cards.clear()
	g.test_feed([{"e": "night_event", "id": "blackout", "night": 2}] as Array[Dictionary])
	assert_eq(g.cards.size(), 1)
	assert_eq(str(g.cards[0]["style"]), "event")
	assert_false((g.cards[0]["rules"] as Array).is_empty())
	g.queue_free()
