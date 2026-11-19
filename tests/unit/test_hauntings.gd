extends TestCase


func test_data_is_valid() -> void:
	assert_eq(Hauntings.problems().size(), 0, "; ".join(Hauntings.problems()))
	assert_eq(Hauntings.all().size(), 10)


func test_levels_stack_and_each_applies() -> void:
	var cat := Catalog.load_default()
	var base := Tuning.new()
	var prev: Dictionary = base.to_dict()
	for level: int in range(1, 11):
		var run := RunState.new()
		run.start(5, cat, base, {}, {"haunting": level})
		var now: Dictionary = run.tuning.to_dict()
		var changed: bool = now != prev or (level == 10 and bool(run.rules["start_cursed"]))
		assert_true(changed, "level %d changes something" % level)
		assert_eq(Hauntings.upto(level).size(), level)
		prev = now
	assert_eq(base.to_dict(), Tuning.new().to_dict(), "the shared tuning is never touched")


func test_rent_and_start_cursed() -> void:
	var cat := Catalog.load_default()
	var run := RunState.new()
	run.start(3, cat, Tuning.new(), {}, {"haunting": 1})
	assert_eq(run.rent_for(1), int(round(Tuning.new().rent_base * 1.1)))
	var r10 := RunState.new()
	r10.start(3, cat, Tuning.new(), {}, {"haunting": 10})
	assert_eq(r10.inventory.size(), 1, "the shop remembers")
	assert_true(str(r10.inventory[0]["curse"]) != "")
	var r9 := RunState.new()
	r9.start(3, cat, Tuning.new(), {}, {"haunting": 9})
	assert_eq(r9.inventory.size(), 0)


func test_haunting_zero_matches_no_opts() -> void:
	var cat := Catalog.load_default()
	var a := RunState.new()
	var ev_a: Array[Dictionary] = a.start(8, cat, Tuning.new())
	var b := RunState.new()
	var ev_b: Array[Dictionary] = b.start(8, cat, Tuning.new(), {}, {"haunting": 0})
	assert_eq(ev_a, ev_b, "no run_opts event for plain opts")
	assert_eq(a.tuning.to_dict(), b.tuning.to_dict())
