extends TestCase
## Ending variants of a won run. Helpers are prefixed en_.


func en_run() -> RunState:
	var run := RunState.new()
	var tun := Tuning.new()
	tun.set_value("wake_threshold", 1000.0)
	run.start(5, Catalog.load_default(), tun)
	run.night = int(run.tuning.nights)
	run.cash = 5000
	run.clock = 0.0
	return run


func en_win(run: RunState) -> Dictionary:
	var ev: Array[Dictionary] = []
	run._end_night(ev)
	for e: Dictionary in ev:
		if e["e"] == "run_won":
			return e
	return {}


func en_cursed(run: RunState, n: int) -> void:
	for i: int in range(n):
		run.inventory.append({"id": "x", "name": "T", "category": "toy", "value": 50, "curse": "sleepwalker", "uid": 700 + i, "est": 1, "tells": 0})


func test_data_is_valid() -> void:
	assert_eq(Endings.problems().size(), 0, ", ".join(Endings.problems()))
	assert_eq(Endings.all().size(), 4)


func test_debt_free_is_the_plain_win() -> void:
	var run := en_run()
	var w: Dictionary = en_win(run)
	assert_eq(w["ending"], "debt_free")
	assert_eq(run.ending, "debt_free")
	assert_true(str(w["epilogue"]).length() > 20)
	assert_true(str(w["ending_name"]) != "")


func test_cursed_beyond_saving_with_three_cursed_objects() -> void:
	var run := en_run()
	en_cursed(run, 3)
	assert_eq(en_win(run)["ending"], "cursed_shop")
	var two := en_run()
	en_cursed(two, 2)
	assert_eq(en_win(two)["ending"], "debt_free", "two is not enough")


func test_collector_pleased_wins_the_ending() -> void:
	var run := en_run()
	run.collector = {"want": {}, "rolled": true, "arrived": true, "done": true, "result": "pleased"}
	en_cursed(run, 4)
	assert_eq(en_win(run)["ending"], "collector", "outranks a cursed shop")
	var refused := en_run()
	refused.collector = {"want": {}, "rolled": true, "arrived": true, "done": true, "result": "refused"}
	assert_eq(en_win(refused)["ending"], "debt_free")


func test_regular_finale_makes_the_regulars_ending() -> void:
	var run := en_run()
	var last: int = Regulars.chapter_count("march") - 1
	run.regular = {"id": "march", "night": 3, "chapter": last, "state": "done"}
	en_cursed(run, 4)
	assert_eq(en_win(run)["ending"], "regulars")
	var mid := en_run()
	mid.regular = {"id": "march", "night": 3, "chapter": 0, "state": "done"}
	assert_eq(en_win(mid)["ending"], "debt_free", "an early chapter does not end the story")
	var refused := en_run()
	refused.regular = {"id": "march", "night": 3, "chapter": last, "state": "refused"}
	assert_eq(en_win(refused)["ending"], "debt_free")


func test_lost_run_has_no_ending_and_ending_survives_snapshot() -> void:
	var run := en_run()
	run.cash = 0
	var ev: Array[Dictionary] = []
	run._end_night(ev)
	assert_eq(run.ending, "")
	var won := en_run()
	en_win(won)
	var b := RunState.new()
	b.restore(won.snapshot(), won.catalog)
	assert_eq(b.ending, "debt_free")
	assert_eq(b.state_hash(), won.state_hash())
