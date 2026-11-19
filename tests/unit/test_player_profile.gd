extends TestCase

const PP_PATH: String = "user://test_profile_unit.json"


func pp_cleanup(path: String) -> void:
	for suffix: String in ["", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func pp_store(seed_value: int) -> RelicStore:
	return RelicStore.create(CurioCollection.create(seed_value, Tuning.new()))


func test_round_trip_through_file() -> void:
	var a := pp_store(3)
	a.set_age(30, true)
	a.fulfill("sealed_10", "p1")
	a.fulfill("scried_1", "p2")
	a.collection.open_box()
	a.collection.set_featured("curio_10")
	assert_eq(PlayerProfile.save(a, PP_PATH), OK)
	var b := pp_store(99)
	assert_true(PlayerProfile.load_into(b, PP_PATH))
	assert_true(b.is_open(), "gate remembered")
	assert_eq(b.log.size(), 2)
	assert_eq(b.spent_cents(), a.spent_cents())
	assert_eq(b.collection.paid_boxes, a.collection.paid_boxes)
	assert_eq(b.collection.owned, a.collection.owned)
	assert_eq(b.collection.tradeable, a.collection.tradeable)
	assert_eq(b.collection.featured_id, "curio_10")
	assert_eq(b.collection.open_box(), a.collection.open_box(), "same next box")
	pp_cleanup(PP_PATH)


func test_missing_or_bad_file_leaves_store_alone() -> void:
	var s := pp_store(1)
	assert_false(PlayerProfile.load_into(s, "user://no_such_profile.json"))
	var f := FileAccess.open(PP_PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_false(PlayerProfile.load_into(s, PP_PATH))
	assert_false(s.is_open())
	pp_cleanup(PP_PATH)


func test_newer_version_is_not_loaded() -> void:
	var f := FileAccess.open(PP_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": PlayerProfile.VERSION + 1, "store": {"age_ok": true}}))
	f.close()
	assert_false(PlayerProfile.load_into(pp_store(1), PP_PATH))
	pp_cleanup(PP_PATH)


func test_run_in_progress_round_trips_exactly() -> void:
	var path: String = "user://test_run_unit.save"
	var cat := Catalog.load_default()
	var a := RunState.new()
	a.start(42, cat, Tuning.new())
	var bot := ShopBot.new()
	for i: int in range(12):
		a.apply(bot.decide(a))
	assert_eq(PlayerProfile.save_run(a, {"seed": 42}, path), OK)
	var loaded: Dictionary = PlayerProfile.load_run(cat, path)
	assert_eq(loaded["rec"], {"seed": 42}, "recording kept")
	var b: RunState = loaded["run"]
	assert_eq(b.state_hash(), a.state_hash(), "identical state")
	for i: int in range(20):
		if a.is_over():
			break
		var cmd: Dictionary = bot.decide(a)
		assert_eq(b.apply(cmd), a.apply(cmd), "same events after load")
	pp_cleanup(path)


func test_finished_run_clears_the_save() -> void:
	var path: String = "user://test_run_unit2.save"
	var cat := Catalog.load_default()
	var a := RunState.new()
	a.start(1, cat, Tuning.new())
	assert_eq(PlayerProfile.save_run(a, {}, path), OK)
	assert_true(FileAccess.file_exists(path))
	a.phase = RunState.PHASE_OVER
	PlayerProfile.save_run(a, {}, path)
	assert_false(FileAccess.file_exists(path))
	assert_true(PlayerProfile.load_run(cat, path).is_empty())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("junk")
	f.close()
	assert_true(PlayerProfile.load_run(cat, path).is_empty(), "junk is ignored")
	pp_cleanup(path)


func test_grimoire_round_trips_and_bank_finds_grants() -> void:
	var a := pp_store(5)
	var run := RunState.new()
	run.start(1, Catalog.load_default(), Tuning.new())
	run.found = [{"kind": "page", "id": "seal"}, {"kind": "page", "id": "scry"}, {"kind": "curio", "id": "curio_13"}]
	var added: PackedStringArray = PlayerProfile.bank_finds(run, a)
	assert_eq(added, PackedStringArray(["seal"]), "scry was already known")
	assert_eq(a.grimoire, PackedStringArray(["scry", "hex", "seal"]))
	assert_eq(a.collection.owned.get("curio_13", 0), 1)
	assert_eq(a.collection.tradeable.get("curio_13", 0), 1, "found curios are tradeable")
	assert_eq(PlayerProfile.save(a, PP_PATH), OK)
	var b := pp_store(6)
	assert_true(PlayerProfile.load_into(b, PP_PATH))
	assert_eq(b.grimoire, a.grimoire)
	assert_eq(b.collection.owned, a.collection.owned)
	pp_cleanup(PP_PATH)


func test_version_1_profile_gets_the_default_grimoire() -> void:
	var f := FileAccess.open(PP_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "store": pp_store(1).to_dict()}))
	f.close()
	var s := pp_store(2)
	assert_true(PlayerProfile.load_into(s, PP_PATH))
	assert_eq(s.grimoire, Grimoire.DEFAULT_KNOWN)
	pp_cleanup(PP_PATH)


func test_record_result_unlocks_and_keeps_best() -> void:
	var s := pp_store(1)
	var run := RunState.new()
	run.start(1, Catalog.load_default(), Tuning.new(), {}, {"haunting": 0})
	run.won = true
	run.cash = 300
	var r: Dictionary = PlayerProfile.record_result(run, s)
	assert_eq(r["unlocked"], 1)
	assert_eq(s.haunting_unlocked, 1)
	assert_eq(s.best_cash, 300)
	run.cash = 100
	assert_eq(PlayerProfile.record_result(run, s)["unlocked"], 0, "a win below the top unlocked level unlocks nothing")
	assert_eq(s.best_cash, 300)
	run.opts["haunting"] = 1
	assert_eq(PlayerProfile.record_result(run, s)["unlocked"], 2)
	run.won = false
	run.opts["haunting"] = 2
	assert_eq(PlayerProfile.record_result(run, s)["unlocked"], 0, "a loss unlocks nothing")
	s.haunting_unlocked = 10
	run.won = true
	run.opts["haunting"] = 10
	assert_eq(PlayerProfile.record_result(run, s)["unlocked"], 0)
	assert_eq(s.haunting_unlocked, 10)


func test_daily_first_attempt_counts_and_keeps_thirty() -> void:
	var s := pp_store(1)
	var run := RunState.new()
	run.start(1, Catalog.load_default(), Tuning.new(), {}, {"daily": true, "date": "2026-12-18", "number": 1})
	run.cash = 50
	assert_true(PlayerProfile.record_result(run, s)["daily_counted"])
	run.cash = 999
	assert_false(PlayerProfile.record_result(run, s)["daily_counted"], "only the first attempt counts")
	assert_eq(s.daily_best["2026-12-18"]["cash"], 50)
	assert_eq(s.daily_last, "2026-12-18")
	for d: int in range(1, 41):
		run.opts["date"] = "2027-01-%02d" % d if d <= 31 else "2027-02-%02d" % (d - 31)
		PlayerProfile.record_result(run, s)
	assert_eq(s.daily_best.size(), 30)
	assert_false(s.daily_best.has("2026-12-18"), "oldest dropped")


func test_progress_round_trip_and_old_file_loads() -> void:
	var a := pp_store(1)
	a.haunting_unlocked = 4
	a.best_cash = 321
	a.daily_last = "2026-12-18"
	a.daily_best = {"2026-12-18": {"number": 1, "night": 5, "cash": 9, "won": true, "wakes": 2}}
	PlayerProfile.save(a, PP_PATH)
	var b := pp_store(2)
	assert_true(PlayerProfile.load_into(b, PP_PATH))
	assert_eq(b.haunting_unlocked, 4)
	assert_eq(b.best_cash, 321)
	assert_eq(b.daily_last, "2026-12-18")
	assert_eq(int(b.daily_best["2026-12-18"]["cash"]), 9)
	var f := FileAccess.open(PP_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "store": a.to_dict(), "grimoire": ["scry"]}))
	f.close()
	var c := pp_store(3)
	assert_true(PlayerProfile.load_into(c, PP_PATH), "a version 2 file still loads")
	assert_eq(c.haunting_unlocked, 0)
	assert_eq(c.daily_best.size(), 0)
	pp_cleanup(PP_PATH)


func test_journal_round_trips() -> void:
	var a := pp_store(3)
	a.regulars = {"march": 2, "ned": 4}
	a.deeds = PackedStringArray(["first_dawn", "hedge_witch"])
	a.tutorial_done = true
	assert_eq(PlayerProfile.save(a, PP_PATH), OK)
	var b := pp_store(9)
	assert_true(PlayerProfile.load_into(b, PP_PATH))
	assert_eq(b.regulars, {"march": 2, "ned": 4})
	assert_eq(b.deeds, PackedStringArray(["first_dawn", "hedge_witch"]))
	assert_true(b.tutorial_done)
	pp_cleanup(PP_PATH)


func test_unfinished_tutorial_is_remembered() -> void:
	var a := pp_store(3)
	PlayerProfile.save(a, PP_PATH)
	var b := pp_store(9)
	b.tutorial_done = true
	PlayerProfile.load_into(b, PP_PATH)
	assert_false(b.tutorial_done, "a version-5 file that says not done stays not done")
	pp_cleanup(PP_PATH)


func test_old_version_file_loads_with_defaults_and_skips_the_tutorial() -> void:
	var f := FileAccess.open(PP_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 4, "store": {"age_ok": true}, "grimoire": ["scry", "hex"],
		"progress": {"haunting_unlocked": 3, "best_cash": 410, "daily_last": "", "daily_best": {}},
		"altar": {"ecto": 12, "upgrades": {"keen_eye": 1}, "carry_cash": 0}}))
	f.close()
	var s := pp_store(1)
	assert_true(PlayerProfile.load_into(s, PP_PATH))
	assert_eq(s.haunting_unlocked, 3)
	assert_eq(s.ecto, 12)
	assert_eq(s.upgrades, {"keen_eye": 1})
	assert_eq(s.regulars, {})
	assert_eq(s.deeds, PackedStringArray())
	assert_true(s.tutorial_done, "a player who already has a profile is not walked through night 1 again")
	pp_cleanup(PP_PATH)


func test_journal_cleans_unknown_entries() -> void:
	var f := FileAccess.open(PP_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 5, "store": {}, "journal": {"regulars": {"march": 99, "nobody": 2},
		"deeds": ["first_dawn", "no_such_deed", "first_dawn"], "tutorial_done": true}}))
	f.close()
	var s := pp_store(1)
	assert_true(PlayerProfile.load_into(s, PP_PATH))
	assert_eq(s.regulars, {"march": 4})
	assert_eq(s.deeds, PackedStringArray(["first_dawn"]))
	pp_cleanup(PP_PATH)
