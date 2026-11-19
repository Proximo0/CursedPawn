extends TestCase


func tu_run(seed_value: int, tun: Tuning = null) -> RunState:
	var run := RunState.new()
	run.start(seed_value, Catalog.load_default(), tun if tun != null else Tuning.new(), {}, Tutorial.opts())
	return run


## Plays night 1 buying every seller's object and selling to the buyer. Returns every event, in order.
func tu_night_one(run: RunState, first: Array[Dictionary]) -> Array[Dictionary]:
	var all: Array[Dictionary] = first.duplicate()
	var ev: Array[Dictionary] = first
	while run.phase == RunState.PHASE_CUSTOMER and run.commands < 60:
		var cmd: Dictionary = {"t": "pass"}
		if run.customer["kind"] == "seller":
			cmd = {"t": "inspect", "tool": "uv"} if (run.customer["tools"] as Array).is_empty() else {"t": "buy"}
		elif not run.sellable().is_empty():
			cmd = {"t": "sell", "uid": run.sellable()[0]["uid"]}
		ev = run.apply(cmd)
		all.append_array(ev)
	return all


func tu_customers(ev: Array[Dictionary]) -> Array:
	return ev.filter(func(e: Dictionary) -> bool: return e["e"] == "customer")


func test_data_is_valid() -> void:
	assert_eq(Tutorial.problems(Catalog.load_default()).size(), 0, "; ".join(Tutorial.problems(Catalog.load_default())))
	assert_eq(Tutorial.customers().size(), 3)
	assert_true(Tutorial.script().size() >= 6)


func test_same_customers_whatever_the_seed() -> void:
	var a := tu_run(1)
	var b := tu_run(987654)
	var ea: Array[Dictionary] = tu_night_one(a, a.last_events)
	var eb: Array[Dictionary] = tu_night_one(b, b.last_events)
	assert_eq(tu_customers(ea), tu_customers(eb), "identical customers")
	var c: Array = tu_customers(ea)
	assert_eq(c.size(), 3)
	assert_eq([c[0]["kind"], c[1]["kind"], c[2]["kind"]], ["seller", "seller", "buyer"])
	assert_eq([c[0]["tutorial"], c[1]["tutorial"], c[2]["tutorial"]], [1, 3, 5])
	assert_eq([c[0]["name"], c[1]["name"]], ["Hand bell", "Oil portrait"])


func test_night_one_is_safe_and_covered() -> void:
	var tun := Tuning.new()
	tun.set_value("dread_on_buy", 5.0)
	tun.set_value("dread_per_night", 5.0)
	tun.set_value("wake_threshold", 1.0)
	var run := tu_run(5, tun)
	assert_eq(run.cash, int(tun.start_cash + tun.tutorial_purse), "the purse")
	var ev: Array[Dictionary] = tu_night_one(run, run.last_events)
	var kinds: Array = ev.map(func(e: Dictionary) -> String: return str(e["e"]))
	assert_false(kinds.has("wake"), "no wake on the guided night")
	assert_eq(run.wake_nights.size(), 0)
	assert_true(kinds.has("night_end") and kinds.has("table_open"), "the night ends after the third customer")
	assert_false(kinds.has("run_lost"))
	assert_true(run.dread < tun.wake_threshold, "Dread is held under the line")
	assert_eq(run.phase, RunState.PHASE_TABLE)


func test_uv_tell_is_certain() -> void:
	var tun := Tuning.new()
	tun.set_value("tell_chance", 0.0)
	var run := tu_run(3, tun)
	run.apply({"t": "pass"})
	assert_eq(run.customer["item"]["curse"], "sleepwalker")
	var ev: Array[Dictionary] = run.apply({"t": "inspect", "tool": "uv"})
	assert_true(str(ev[0]["tell"]) != "", "the UV lamp always shows it")


func test_hints_come_in_order_with_ui_focus() -> void:
	var run := tu_run(5)
	var ev: Array[Dictionary] = tu_night_one(run, run.last_events)
	var steps: Array = ev.filter(func(e: Dictionary) -> bool: return e["e"] == "tutorial_step")
	assert_eq(steps.map(func(e: Dictionary) -> int: return int(e["step"])), [1, 2, 3, 4, 5, 6])
	for e: Dictionary in steps:
		assert_true(Tutorial.FOCUS.has(str(e["focus"])), str(e["focus"]))
		assert_true(str(e["text"]) != "")
	var later: Array[Dictionary] = run.apply({"t": "table_leave"})
	assert_true(later.any(func(e: Dictionary) -> bool: return e["e"] == "tutorial_step" and int(e["step"]) == 7), "spells hint on night 2")
	assert_false(tu_customers(later).any(func(e: Dictionary) -> bool: return e.has("tutorial")), "night 2 is a normal night")


func test_after_night_one_the_run_continues_and_finishing_marks_it_done() -> void:
	var run := tu_run(5)
	tu_night_one(run, run.last_events)
	var bot := ShopBot.new(ShopBot.CAUTIOUS)
	assert_true(bot.play(run), "plays on")
	var s := RelicStore.create(CurioCollection.create(1, Tuning.new()))
	assert_true(PlayerProfile.needs_tutorial(s))
	PlayerProfile.record_result(run, s)
	assert_true(s.tutorial_done)
	assert_false(PlayerProfile.needs_tutorial(s))


func test_state_survives_snapshot() -> void:
	var run := tu_run(5)
	run.apply({"t": "pass"})
	var back := RunState.new()
	back.restore(run.snapshot(), Catalog.load_default())
	assert_eq(back.state_hash(), run.state_hash())
	assert_eq(back.apply({"t": "pass"}), run.apply({"t": "pass"}))
