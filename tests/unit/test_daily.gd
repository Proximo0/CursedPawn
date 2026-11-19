extends TestCase


func test_number_counts_from_launch() -> void:
	assert_eq(Daily.number(2026, 12, 18), 1)
	assert_eq(Daily.number(2026, 12, 19), 2)
	assert_eq(Daily.number(2027, 1, 1), 15)
	assert_eq(Daily.number(2026, 12, 17), 0)
	assert_eq(Daily.number(2028, 3, 1) - Daily.number(2028, 2, 28), 2, "leap day")


func test_seed_is_stable_and_differs() -> void:
	assert_eq(Daily.seed_for(2026, 12, 18), Daily.seed_for(2026, 12, 18))
	assert_true(Daily.seed_for(2026, 12, 18) != Daily.seed_for(2026, 12, 19))
	assert_true(Daily.seed_for(2026, 12, 18) >= 0)
	assert_eq(Daily.seed_for(2026, 12, 18), 1711319059, "pinned: a change would move every player's daily")


func test_opts_use_first_offered_omen() -> void:
	var s: int = Daily.seed_for(2026, 12, 20)
	var o: Dictionary = Daily.opts_for(s)
	assert_eq(o["omen"], Omens.offer(s)[0])
	assert_eq(o["haunting"], 0)
	assert_true(o["daily"])


func test_result_text() -> void:
	var cat := Catalog.load_default()
	var run := RunState.new()
	run.start(Daily.seed_for(2026, 12, 18), cat, Tuning.new(), {}, Daily.opts_for(Daily.seed_for(2026, 12, 18)))
	run.night = 5
	run.won = true
	run.cash = 412
	run.wake_nights.assign([3, 3, 4])
	var lines: PackedStringArray = Daily.result_text(run, 12).split("\n")
	assert_eq(lines.size(), 4)
	assert_eq(lines[0], "Cursed Pawn Séance #12")
	assert_eq(lines[1], "Night 5/5 survived | 412 coins | woke 3x")
	assert_eq(lines[2], "🕯🕯🔥🔥🕯")
	assert_true(lines[3].begins_with("Omen: "))
	run.won = false
	run.night = 3
	run.wake_nights.assign([2])
	assert_eq(Daily.result_text(run, 12).split("\n")[2], "🕯🔥💀▫▫")
	assert_true(Daily.result_text(run, 12).split("\n")[1].begins_with("Night 3/5 lost"))


func test_theme_data_is_valid() -> void:
	assert_eq(DailyThemes.problems().size(), 0, "; ".join(DailyThemes.problems()))
	assert_eq(DailyThemes.all().size(), 8)
	assert_eq(str(DailyThemes.all()[0]["id"]), "cursed_week", "the launch week is Cursed Week")


func test_theme_changes_weekly_and_cycles() -> void:
	var first: String = str(DailyThemes.theme_for(2026, 12, 18)["id"])
	for day: int in range(18, 25):
		assert_eq(str(DailyThemes.theme_for(2026, 12, day)["id"]), first, "same theme all week (Dec %d)" % day)
	assert_true(str(DailyThemes.theme_for(2026, 12, 25)["id"]) != first, "next week, next theme")
	var seen: Dictionary = {}
	for week: int in range(8):
		seen[str(DailyThemes.theme_for(2027, 1, 1 + week * 7)["id"])] = true
	assert_eq(seen.size(), 8, "eight weeks, eight themes")
	assert_eq(DailyThemes.days_left(2026, 12, 18), 7)
	assert_eq(DailyThemes.days_left(2026, 12, 24), 1)
	assert_eq(DailyThemes.days_left(2026, 12, 25), 7)
	assert_true(DailyThemes.theme_for(2026, 6, 1).has("id"), "dates before launch still have a theme")


func test_everyone_gets_the_same_theme_on_a_date() -> void:
	assert_eq(Daily.opts_for_date(2026, 12, 20), Daily.opts_for_date(2026, 12, 20))
	assert_eq(Daily.opts_for_date(2026, 12, 20)["theme"], str(DailyThemes.theme_for(2026, 12, 20)["id"]))
	assert_eq(Daily.opts_for_date(2026, 12, 20)["omen"], Daily.opts_for(Daily.seed_for(2026, 12, 20))["omen"])


func dy_run(theme_id: String, seed_value: int = 9) -> RunState:
	var run := RunState.new()
	var opts: Dictionary = {"haunting": 0, "omen": "", "daily": true, "theme": theme_id}
	run.start(seed_value, Catalog.load_default(), Tuning.new(), {}, opts)
	return run


func test_cursed_week_makes_every_seller_object_cursed() -> void:
	var run := dy_run("cursed_week")
	assert_eq(run.opts["theme"], "cursed_week")
	assert_eq(run.opts["theme_name"], "Cursed Week")
	var sellers: int = 0
	for i: int in range(60):
		if run.is_over():
			break
		if run.customer.get("kind", "") == "seller":
			sellers += 1
			assert_true(str(run.customer["item"]["curse"]) != "", "every item is cursed")
		run.apply({"t": "table_leave"} if run.phase == "table" else {"t": "pass"})
	assert_true(sellers > 5, "enough sellers seen: %d" % sellers)
	assert_near(run.tuning.cursed_buyer_mult, Tuning.new().cursed_buyer_mult * 1.3)  # the theme multiplies the base


func test_theme_rules_reach_the_tuning_and_flags() -> void:
	var lean := dy_run("lean_week")
	var base := Tuning.new()
	assert_near(lean.tuning.start_cash, base.start_cash * 0.6)
	assert_near(lean.tuning.inspect_minutes, base.inspect_minutes * 0.5)
	assert_eq(lean.cash, int(base.start_cash * 0.6))
	assert_true(dy_run("table_week").rules["double_table"])
	assert_near(dy_run("table_week").tuning.lot_price, base.lot_price * 0.5)
	assert_true(str(dy_run("haggle_week").rules["seller_type"]) != "", "one seller type")
	assert_near(dy_run("storm_season").tuning.night_event_chance, 1.0)
	assert_eq(int(dy_run("quiet_week").tuning.spell_casts_per_night), 0)
	assert_true(dy_run("gift_week").inventory.size() == 1 and str(dy_run("gift_week").inventory[0]["curse"]) != "", "a cursed object on the shelf")
	assert_near(dy_run("long_nights").tuning.day_minutes, base.day_minutes * 1.3)


func test_theme_only_applies_to_daily_runs() -> void:
	var run := RunState.new()
	run.start(9, Catalog.load_default(), Tuning.new(), {}, {"theme": "cursed_week"})
	assert_false(run.opts.has("theme"))
	assert_false(bool(run.rules["all_cursed"]))
	var bad := dy_run("no_such_theme")
	assert_false(bad.opts.has("theme"))


func test_storm_season_fires_an_event_on_night_two() -> void:
	var run := dy_run("storm_season")
	run.tuning.set_value("start_cash", 3000.0)
	run.cash = 3000
	run.tuning.set_value("wake_threshold", 1000.0)
	var fired: bool = false
	var guard: int = 0
	while not run.is_over() and not fired and guard < 300:
		guard += 1
		for e: Dictionary in run.apply({"t": "table_leave"} if run.phase == "table" else {"t": "pass"}):
			fired = fired or e["e"] == "night_event"
	assert_true(fired)


func test_theme_runs_survive_snapshot_and_recording() -> void:
	var run := dy_run("lean_week")
	var b := RunState.new()
	b.restore(run.snapshot(), run.catalog)
	assert_eq(b.state_hash(), run.state_hash())
	var rec_run := RunState.new()
	var rec: RunRecording = RunRecording.begin(rec_run, 5, run.catalog, Tuning.new(), {}, {"daily": true, "theme": "gift_week"})
	var bot := ShopBot.new()
	for i: int in range(40):
		if not rec_run.is_over():
			rec.drive(rec_run, bot.decide(rec_run))
	assert_eq(rec.first_divergence(run.catalog), -1)


func test_result_text_names_the_theme() -> void:
	var run := dy_run("cursed_week")
	run.won = true
	var lines: PackedStringArray = Daily.result_text(run, 3).split("\n")
	assert_eq(lines.size(), 5)
	assert_eq(lines[4], "Theme: Cursed Week")
	var plain := RunState.new()
	plain.start(1, Catalog.load_default(), Tuning.new(), {}, Daily.opts_for(1))
	assert_eq(Daily.result_text(plain, 3).split("\n").size(), 4, "no theme line without a theme")
