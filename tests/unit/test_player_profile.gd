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
