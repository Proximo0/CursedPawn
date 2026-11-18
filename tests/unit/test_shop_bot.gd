extends TestCase


func test_both_bots_finish_runs() -> void:
	var cat := Catalog.load_default()
	for style: String in ShopBot.STYLES:
		for s: int in range(1, 6):
			var run := RunState.new()
			run.start(s, cat, Tuning.new())
			assert_true(ShopBot.new(style).play(run), "%s seed %d" % [style, s])
			assert_true(run.is_over())


func test_cautious_walks_away_from_tells() -> void:
	var tun := Tuning.new()
	tun.set_value("cursed_share", 1.0)
	tun.set_value("tell_chance", 1.0)  # every inspect with a matching tool shows the tell
	var run := RunState.new()
	var cat := Catalog.load_default()
	cat.curses = cat.curses.filter(func(c: Dictionary) -> bool: return (c["tells"] as Dictionary).has("uv"))
	run.start(3, cat, tun)
	var bot := ShopBot.new(ShopBot.CAUTIOUS)
	var guard: int = 0
	while (run.customer["tells"] as Array).is_empty() and guard < 5:
		run.apply(bot.decide(run))
		guard += 1
	assert_eq(bot.decide(run), {"t": "pass"})
