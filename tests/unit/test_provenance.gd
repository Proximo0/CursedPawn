extends TestCase
## Provenance lines on bought objects. Helpers are prefixed pv_.


func test_every_bought_object_has_a_provenance() -> void:
	var run := RunState.new()
	var tun := Tuning.new()
	tun.set_value("wake_threshold", 1000.0)
	run.start(3, Catalog.load_default(), tun)
	run.cash = 5000
	var bought: Array[Dictionary] = []
	var guard: int = 0
	while bought.size() < 5 and guard < 100 and not run.is_over():
		guard += 1
		if run.customer.get("kind", "") == "seller":
			for e: Dictionary in run.apply({"t": "buy"}):
				if e["e"] == "bought":
					bought.append(e)
		else:
			run.apply({"t": "table_leave"} if run.phase == "table" else {"t": "pass"})
	assert_eq(bought.size(), 5)
	for e: Dictionary in bought:
		assert_true(str(e["provenance"]) != "", "event carries provenance")
	for item: Dictionary in run.inventory:
		assert_true(str(item["provenance"]).length() > 20, "item.provenance set")


func test_same_seed_and_uid_give_the_same_line() -> void:
	var item: Dictionary = {"id": "violin", "category": "instrument", "curse": "", "uid": 4}
	assert_eq(Provenance.make(item, 9), Provenance.make(item, 9))
	var other: Dictionary = {"id": "violin", "category": "instrument", "curse": "", "uid": 5}
	var differs: bool = false
	for s: int in range(1, 20):
		differs = differs or Provenance.make(item, s) != Provenance.make(other, s)
	assert_true(differs, "uid changes the story")


func test_cursed_objects_lean_ominous_without_naming_the_curse() -> void:
	var d: Dictionary = Provenance.data()
	var hits_cursed: int = 0
	var hits_clean: int = 0
	for s: int in range(200):
		var c: String = Provenance.make({"id": "violin", "category": "instrument", "curse": "copycat", "uid": s}, 1)
		var k: String = Provenance.make({"id": "violin", "category": "instrument", "curse": "", "uid": s}, 1)
		for o: Variant in d["ominous"]:
			hits_cursed += 1 if c.contains(str(o)) else 0
			hits_clean += 1 if k.contains(str(o)) else 0
		assert_false(c.contains("copycat") or c.contains("Copycat"), "never names the curse")
	assert_true(hits_cursed > hits_clean * 1.5, "cursed %d vs clean %d" % [hits_cursed, hits_clean])


func test_gift_merges_pass_it_on_history() -> void:
	var cat := Catalog.load_default()
	var run := RunState.new()
	var gift: Dictionary = {"id": "violin", "name": "Violin", "category": "instrument", "value": 100, "curse": "copycat",
		"est": 0, "tells": 0, "history": [["Ann", 3, 2, false], ["Bo", 5, 1, true]]}
	run.start(5, cat, Tuning.new(), gift)
	var line: String = str(run.inventory[0]["provenance"])
	assert_true(line.contains("Passed on by Bo"), line)
	assert_true(line.contains("Reached night 5"), line)
	assert_true(line.contains("Paid every rent"), line)
	assert_true(line.contains("2 holders"), line)


func test_provenance_does_not_touch_the_run_stream() -> void:
	var a := RunState.new()
	a.start(21, Catalog.load_default(), Tuning.new())
	var state: int = a.rng.state
	Provenance.make({"id": "violin", "category": "instrument", "curse": "", "uid": 1}, 21)
	assert_eq(a.rng.state, state)


func test_data_problems_empty() -> void:
	assert_eq(Provenance.problems().size(), 0, ", ".join(Provenance.problems()))
