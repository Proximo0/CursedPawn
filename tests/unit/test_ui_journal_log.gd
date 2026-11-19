extends TestCase
## The journal's own memory: customers met, curses known, the last 20 runs, and surviving a bad file.

const JL_PATH: String = "user://test_ui_journal_log.json"


func jl_run(seed_in: int, won: bool) -> RunState:
	var run := RunState.new()
	run.start(seed_in, Catalog.load_default(), Tuning.new(), {}, {"haunting": 2, "omen": "", "daily": false})
	run.won = won
	run.cash = 33
	return run


func test_notes_are_unique() -> void:
	var l := UiJournalLog.new()
	assert_true(l.note_customer("widow"))
	assert_false(l.note_customer("widow"))
	assert_false(l.note_customer(""))
	assert_true(l.note_curse("lucky_paw"))
	assert_false(l.note_curse("lucky_paw"))


func test_runs_keep_the_last_twenty_newest_first() -> void:
	var l := UiJournalLog.new()
	for i: int in range(25):
		l.record_run(jl_run(i + 1, i % 2 == 0), "debt_free")
	assert_eq(l.runs.size(), 20)
	assert_eq(int(l.runs[0]["seed"]), 25)
	assert_eq(int(l.runs[0]["n"]), 25)
	assert_eq(int(l.runs[19]["seed"]), 6)
	assert_eq(str(l.runs[0]["ending"]), "debt_free", "seed 25 was a win")
	assert_eq(str(l.runs[1]["ending"]), "", "a loss has no ending")


func test_replay_opts_carry_haunting_and_omen() -> void:
	var o: Dictionary = UiJournalLog.replay_opts({"haunting": 3, "omen": "", "seed": 9})
	assert_eq(int(o["haunting"]), 3)
	assert_false(bool(o["daily"]))


func test_round_trip_and_garbage() -> void:
	var a := UiJournalLog.new()
	a.note_customer("widow")
	a.note_curse("lucky_paw")
	a.record_run(jl_run(4, true), "collector")
	assert_eq(a.save(JL_PATH), OK)
	var b := UiJournalLog.new()
	assert_true(b.load_from(JL_PATH))
	assert_eq(b.customers, ["widow"] as Array[String])
	assert_eq(b.curses, ["lucky_paw"] as Array[String])
	assert_eq(str(b.runs[0]["ending"]), "collector")
	assert_eq(b.counter, 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(JL_PATH))
	var g := UiJournalLog.new()
	g.from_dict({"customers": [1, "ok", null], "curses": "nope", "runs": [5, {"seed": "x", "haunting": 99}], "counter": "q"})
	assert_eq(g.customers, ["ok"] as Array[String])
	assert_eq(g.runs.size(), 1)
	assert_eq(int(g.runs[0]["haunting"]), 10)
	assert_false(g.load_from("user://no_such_journal.json"))
