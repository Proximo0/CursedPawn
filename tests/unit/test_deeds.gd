extends TestCase


func de_store() -> RelicStore:
	return RelicStore.create(CurioCollection.create(1, Tuning.new()))


func de_run(opts: Dictionary = {}) -> RunState:
	var run := RunState.new()
	run.start(4, Catalog.load_default(), Tuning.new(), {}, opts)
	return run


func test_data_is_valid() -> void:
	assert_eq(Deeds.problems().size(), 0, "; ".join(Deeds.problems()))
	assert_true(Deeds.all().size() >= 28, "about 30 deeds")
	var secret: int = 0
	for d: Dictionary in Deeds.all():
		secret += 1 if bool(d["secret"]) else 0
	assert_true(secret >= 5 and secret < Deeds.all().size(), "some secret, not all")


func test_run_counter_rules() -> void:
	var s := de_store()
	var run := de_run()
	assert_false(Deeds.holds({"won": true}, run, s))
	run.won = true
	assert_true(Deeds.holds({"won": true}, run, s))
	run.wake_nights.assign([1, 3])
	assert_true(Deeds.holds({"wakes_at_least": 2}, run, s))
	assert_false(Deeds.holds({"wakes_at_least": 3}, run, s))
	run.cash = 300
	assert_true(Deeds.holds({"cash_at_least": 300}, run, s))
	assert_false(Deeds.holds({"cash_at_least": 301}, run, s))
	run.spells_cast = 5
	assert_true(Deeds.holds({"spells_cast": 5}, run, s))
	assert_false(Deeds.holds({"spells_cast": 6}, run, s))
	run.table_wins = 2
	assert_true(Deeds.holds({"table_wins": 2}, run, s))
	assert_false(Deeds.holds({"table_wins": 3}, run, s))
	assert_false(Deeds.holds({"pairs_perfect": true}, run, s))
	run.pairs_perfect = 1
	assert_true(Deeds.holds({"pairs_perfect": true}, run, s))
	assert_false(Deeds.holds({"collector": "pleased"}, run, s))
	run.collector = {"result": "pleased"}
	assert_true(Deeds.holds({"collector": "pleased"}, run, s))
	run.requests_done = 3
	assert_true(Deeds.holds({"requests_done": 3}, run, s))
	assert_false(Deeds.holds({"requests_done": 4}, run, s))
	run.max_cursed_held = 3
	assert_true(Deeds.holds({"all_cursed_held": 3}, run, s))
	assert_false(Deeds.holds({"all_cursed_held": 4}, run, s))
	assert_false(Deeds.holds({"no_tools": true, "won": true}, de_run(), s), "not won")
	run.tools_used = 1
	assert_false(Deeds.holds({"no_tools": true, "won": true}, run, s))
	run.tools_used = 0
	assert_true(Deeds.holds({"no_tools": true, "won": true}, run, s))
	assert_false(Deeds.holds({}, run, s), "an empty rule never holds")


func test_option_rules() -> void:
	var s := de_store()
	var run := de_run({"haunting": 3, "omen": "blind_lamp", "daily": true})
	run.won = true
	assert_true(Deeds.holds({"haunting_at_least": 3, "won": true}, run, s))
	assert_false(Deeds.holds({"haunting_at_least": 4}, run, s))
	assert_true(Deeds.holds({"omen": "blind_lamp", "won": true}, run, s))
	assert_false(Deeds.holds({"omen": "deaf_ear", "won": true}, run, s))
	assert_true(Deeds.holds({"daily": true}, run, s))
	assert_false(Deeds.holds({"daily": true}, de_run(), s))


func test_profile_rules() -> void:
	var s := de_store()
	var run := de_run()
	for id: String in ["curio_01", "curio_02", "curio_03", "curio_17"]:
		s.collection.grant(id)
	assert_true(Deeds.holds({"curios_owned": 4}, run, s))
	assert_false(Deeds.holds({"curios_owned": 5}, run, s))
	assert_false(Deeds.holds({"set_complete": "parlor"}, run, s))
	for id: Variant in s.collection.sets()["parlor"]:
		s.collection.grant(str(id))
	assert_true(Deeds.holds({"set_complete": "parlor"}, run, s))
	assert_false(Deeds.holds({"set_complete": "cellar"}, run, s))
	run.found.append({"kind": "curio", "id": "curio_09"})
	assert_true(Deeds.holds({"curios_owned": 8}, run, s), "a curio just found counts")
	assert_false(Deeds.holds({"regular_finished": "march"}, run, s))
	s.regulars = {"march": 4}
	assert_true(Deeds.holds({"regular_finished": "march"}, run, s))
	s.regulars = {"march": 3}
	assert_false(Deeds.holds({"regular_finished": "march"}, run, s))
	run.regular_progress = {"march": 4}
	assert_true(Deeds.holds({"regular_finished": "march"}, run, s), "the run's own progress counts")


func test_check_skips_earned_and_record_result_inks_them() -> void:
	var s := de_store()
	var run := de_run()
	run.won = true
	var first: PackedStringArray = Deeds.check(run, s)
	assert_true(first.has("first_dawn"))
	assert_false(first.has("rude_awakening"))
	var res: Dictionary = PlayerProfile.record_result(run, s)
	assert_true((res["deeds_new"] as PackedStringArray).has("first_dawn"))
	assert_true(s.deeds.has("first_dawn"))
	assert_false(Deeds.check(run, s).has("first_dawn"), "already inked")
	assert_eq(PlayerProfile.record_result(run, s)["deeds_new"], PackedStringArray(), "nothing new twice")


func test_counters_follow_real_play() -> void:
	var run := de_run()
	assert_eq(run.tools_used, 0)
	run.apply({"t": "pass"})
	while run.customer.get("kind", "") != "seller":
		run.apply({"t": "pass"})
	run.apply({"t": "inspect", "tool": "uv"})
	assert_eq(run.tools_used, 1)
	run.apply({"t": "cast", "spell": "scry"})
	assert_eq(run.spells_cast, 1)
	var tun := Tuning.new()
	tun.set_value("cursed_share", 1.0)
	tun.set_value("start_cash", 1000.0)
	tun.set_value("wake_threshold", 20.0)
	var all_cursed := RunState.new()
	all_cursed.start(2, Catalog.load_default(), tun)
	var bought: int = 0
	while bought < 3 and not all_cursed.is_over() and all_cursed.commands < 200:
		if all_cursed.customer.get("kind", "") == "seller" and int(all_cursed.customer["ask"]) <= all_cursed.cash:
			bought += 1 if all_cursed.apply({"t": "buy"})[0]["e"] == "bought" else 0
		elif all_cursed.phase == RunState.PHASE_TABLE:
			all_cursed.apply({"t": "table_leave"})
		else:
			all_cursed.apply({"t": "pass"})
	assert_true(all_cursed.max_cursed_held >= 2, "holds several cursed objects")


func test_counters_survive_snapshot() -> void:
	var run := de_run()
	run.spells_cast = 4
	run.table_wins = 2
	run.pairs_perfect = 1
	run.tools_used = 3
	run.max_cursed_held = 2
	var back := RunState.new()
	back.restore(run.snapshot(), Catalog.load_default())
	assert_eq([back.spells_cast, back.table_wins, back.pairs_perfect, back.tools_used, back.max_cursed_held], [4, 2, 1, 3, 2])
	assert_eq(back.state_hash(), run.state_hash())


func test_full_game_deeds_exist_and_are_valid() -> void:
	assert_eq(Deeds.all().size(), 59)
	for id: String in ["costume_party", "monkey_see", "unwatched_pot", "quiet_landlord", "storm_chaser", "going_twice", "moon_dancer",
			"lights_down", "paid_in_full", "beyond_saving", "set_complete_ending", "last_chapter", "lights_out_wake", "locked_in",
			"possessed_ornament", "every_trouble", "haggler_hand", "both_halves", "hush_hush", "night_owl", "curse_sampler", "full_cabinet"]:
		assert_false(Deeds.get_deed(id).is_empty(), id)


func test_curse_and_event_counters_drive_deeds() -> void:
	var s := de_store()
	var run := de_run()
	assert_false(Deeds.holds({"curse_held": "costume_change"}, run, s))
	run.inventory.append({"id": "x", "name": "T", "category": "toy", "value": 5, "curse": "costume_change", "uid": 800, "est": 1, "tells": 0})
	run._track_cursed()
	assert_true(Deeds.holds({"curse_held": "costume_change"}, run, s))
	assert_true(Deeds.holds({"curses_held_count": 1}, run, s))
	assert_false(Deeds.holds({"curses_held_count": 2}, run, s))
	run.events_seen = ["storm", "auction"]
	assert_true(Deeds.holds({"night_event": "storm"}, run, s))
	assert_false(Deeds.holds({"night_event": "full_moon"}, run, s))
	assert_false(Deeds.holds({"night_events_seen": 3}, run, s))
	run.events_seen.append("blackout")
	assert_true(Deeds.holds({"night_events_seen": 3}, run, s))


func test_wake_and_ending_deeds() -> void:
	var s := de_store()
	var run := de_run()
	run.wake_types = ["lights_out", "drift"]
	assert_true(Deeds.holds({"wake_type": "lights_out"}, run, s))
	assert_false(Deeds.holds({"wake_type": "door_lock"}, run, s))
	assert_false(Deeds.holds({"wake_types_count": 5}, run, s))
	run.ending = "cursed_shop"
	run.won = true
	assert_true(Deeds.holds({"ending": "cursed_shop", "won": true}, run, s))
	assert_false(Deeds.holds({"ending": "debt_free", "won": true}, run, s))


func test_behaviour_counters_drive_deeds() -> void:
	var s := de_store()
	var run := de_run()
	run.copies = 1
	run.haggle_wins = 3
	run.whispered = 3
	run.unseen_cash = 50
	run.twin_sales = 1
	for rule: Dictionary in [{"copies_at_least": 1}, {"haggle_wins": 3}, {"whispered_at_least": 3}, {"unseen_cash": 50}, {"twin_sold": true}]:
		assert_true(Deeds.holds(rule, run, s), str(rule))
	assert_false(Deeds.holds({"haggle_wins": 4}, run, s))


func test_counters_tick_in_play_and_survive_snapshot() -> void:
	var run := RunState.new()
	var tun := Tuning.new()
	tun.set_value("wake_threshold", 1000.0)
	run.start(5, Catalog.load_default(), tun)
	run.cash = 1000
	run.inventory.append({"id": "x", "name": "T", "category": "toy", "value": 5, "curse": "copycat", "uid": 801, "est": 1, "tells": 0})
	run.customer = {"kind": "seller", "item": {"id": "y", "name": "Spoon", "category": "tool", "value": 30, "curse": "",
		"hidden": {}}, "reserve": 5, "ask": 5, "patience": 2, "type": "", "noise_u": 0.0, "tools": [], "tells": [], "imposter": false}
	run._buy_at(5, [] as Array[Dictionary])
	assert_eq(run.copies, 1)
	assert_true(run.curses_held.has("copycat"))
	var b := RunState.new()
	b.restore(run.snapshot(), run.catalog)
	assert_eq(b.copies, 1)
	assert_eq(b.curses_held, run.curses_held)
	assert_eq(b.state_hash(), run.state_hash())
