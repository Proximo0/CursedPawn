extends TestCase


func test_defaults_match_fields() -> void:
	var t := Tuning.new()
	for f: Array in Tuning.FIELDS:
		assert_near(float(t.get(f[0])), float(f[1]), 0.0001, str(f[0]))


func test_set_value_clamps() -> void:
	var t := Tuning.new()
	assert_true(t.set_value("start_cash", 100000.0))
	assert_near(t.start_cash, 1000.0)


func test_unknown_field_rejected() -> void:
	assert_false(Tuning.new().set_value("nope", 1.0))


func test_diff_and_dict_round_trip() -> void:
	var t := Tuning.new()
	t.set_value("rent_base", 70.0)
	assert_eq(t.diff_from_defaults().keys(), ["rent_base"])
	var u := Tuning.new()
	assert_eq(u.apply_dict(t.to_dict()), Tuning.FIELDS.size())
	assert_near(u.rent_base, 70.0)
