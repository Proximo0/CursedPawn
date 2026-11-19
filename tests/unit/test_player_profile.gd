extends TestCase

const PP_PATH: String = "user://test_profile_unit.json"


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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PP_PATH))


func test_missing_or_bad_file_leaves_store_alone() -> void:
	var s := pp_store(1)
	assert_false(PlayerProfile.load_into(s, "user://no_such_profile.json"))
	var f := FileAccess.open(PP_PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_false(PlayerProfile.load_into(s, PP_PATH))
	assert_false(s.is_open())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PP_PATH))


func test_newer_version_is_not_loaded() -> void:
	var f := FileAccess.open(PP_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": PlayerProfile.VERSION + 1, "store": {"age_ok": true}}))
	f.close()
	assert_false(PlayerProfile.load_into(pp_store(1), PP_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PP_PATH))


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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PP_PATH))


func test_version_1_profile_gets_the_default_grimoire() -> void:
	var f := FileAccess.open(PP_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "store": pp_store(1).to_dict()}))
	f.close()
	var s := pp_store(2)
	assert_true(PlayerProfile.load_into(s, PP_PATH))
	assert_eq(s.grimoire, Grimoire.DEFAULT_KNOWN)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PP_PATH))
