extends TestCase

## Everyone but the Widow March has finished their arc, so the plan can only pick her.
const ONLY_MARCH: Dictionary = {"ned": 4, "crowe": 4, "vane": 4, "ashby": 4, "dottie": 4}


func rg_run(progress: Dictionary, seed_value: int = 7) -> RunState:
	var tun := Tuning.new()
	tun.set_value("regular_chance", 1.0)
	tun.set_value("start_cash", 2000.0)  # a debt collector must not end a pass-only run early
	var run := RunState.new()
	run.start(seed_value, Catalog.load_default(), tun, {}, {"regulars": progress})
	return run


## Plays on (passing, leaving the table) until the regular is the customer. Returns that customer's events.
func rg_arrive(run: RunState) -> Array[Dictionary]:
	var ev: Array[Dictionary] = run.last_events
	while not run.is_over() and run.commands < 300:
		for e: Dictionary in ev:
			if e["e"] == "regular":
				return ev
		ev = run.apply({"t": "table_leave"} if run.phase == RunState.PHASE_TABLE else {"t": "pass"})
	return []


func rg_kinds(ev: Array[Dictionary]) -> Array:
	return ev.map(func(e: Dictionary) -> String: return str(e["e"]))


func test_data_is_valid() -> void:
	assert_eq(Regulars.problems(Catalog.load_default()).size(), 0, "; ".join(Regulars.problems(Catalog.load_default())))
	assert_eq(Regulars.all().size(), 6)
	for r: Dictionary in Regulars.all():
		var n: int = (r["chapters"] as Array).size()
		assert_true(n == 3 or n == 4, "%s has 3-4 chapters" % r["id"])
		assert_false(((r["chapters"] as Array)[n - 1] as Dictionary)["reward"].is_empty(), "%s pays off" % r["id"])


func test_plan_is_seeded_and_on_night_2_to_4() -> void:
	var nights: Dictionary = {}
	for s: int in range(1, 60):
		var p: Dictionary = Regulars.plan(s, {}, 1.0, 5)
		assert_eq(p, Regulars.plan(s, {}, 1.0, 5), "stable")
		assert_true(int(p["night"]) >= 2 and int(p["night"]) <= 4)
		nights[p["night"]] = true
	assert_eq(nights.size(), 3, "every night comes up")
	assert_eq(Regulars.plan(3, {}, 0.0, 5), {}, "chance 0 means no visit")
	assert_eq(Regulars.plan(3, {"march": 4, "ned": 4, "crowe": 4, "vane": 4, "ashby": 4, "dottie": 4}, 1.0, 5), {}, "all arcs finished")
	assert_eq(Regulars.plan(3, ONLY_MARCH, 1.0, 5)["id"], "march")


func test_regulars_are_off_without_the_option() -> void:
	var run := RunState.new()
	var tun := Tuning.new()
	tun.set_value("regular_chance", 1.0)
	run.start(7, Catalog.load_default(), tun)
	assert_true(run.regular.is_empty(), "the lab and old saves see no regulars")


func test_seller_chapter_done_advances_and_pays_nothing_extra() -> void:
	var run := rg_run(ONLY_MARCH)
	var ev: Array[Dictionary] = rg_arrive(run)
	var kinds: Array = rg_kinds(ev)
	assert_true(kinds.has("customer") and kinds.has("regular"), "customer and regular events")
	assert_true(run.night >= 2 and run.night <= 4)
	var cust: Dictionary = ev[kinds.find("customer")]
	assert_eq(cust["regular"], "march")
	assert_eq(cust["tid"], "widow")
	var reg: Dictionary = ev[kinds.find("regular")]
	assert_eq([reg["id"], reg["name"], reg["chapter"]], ["march", "The Widow March", 1])
	assert_eq(reg["line"], Regulars.chapter("march", 0)["line"])
	run.cash = 500
	var done: Array[Dictionary] = run.apply({"t": "buy"})
	var dk: Array = rg_kinds(done)
	assert_true(dk.has("bought") and dk.has("regular_done"))
	var rd: Dictionary = done[dk.find("regular_done")]
	assert_eq(rd["chapter"], 1)
	assert_eq(rd["line"], Regulars.chapter("march", 0)["outcome_lines"]["done"])
	assert_eq(run.regular_progress, {"march": 1})
	var s := RelicStore.create(CurioCollection.create(1, Tuning.new()))
	PlayerProfile.record_result(run, s)
	assert_eq(s.regulars, {"march": 1})
	assert_eq(PlayerProfile.altar_opts(s)["regulars"], {"march": 1}, "the next run starts from there")


func test_refusing_still_advances_and_branches_the_line() -> void:
	var run := rg_run(ONLY_MARCH)
	rg_arrive(run)
	var ev: Array[Dictionary] = run.apply({"t": "pass"})
	var k: Array = rg_kinds(ev)
	assert_true(k.has("regular_refused"), "passing refuses")
	assert_false(k.has("regular_done"))
	var rr: Dictionary = ev[k.find("regular_refused")]
	assert_eq(rr["line"], Regulars.chapter("march", 0)["outcome_lines"]["refused"])
	assert_ne_line(rr["line"], str(Regulars.chapter("march", 0)["outcome_lines"]["done"]))
	assert_eq(run.regular_progress, {"march": 1}, "the arc moves on")
	var s := RelicStore.create(CurioCollection.create(1, Tuning.new()))
	PlayerProfile.record_result(run, s)
	assert_eq(s.regulars, {"march": 1})
	var next := rg_run(ONLY_MARCH.merged(s.regulars, true), 11)
	assert_eq(next.regular["chapter"], 1, "chapter 2 is next, whatever was chosen")


func assert_ne_line(a: String, b: String) -> void:
	assert_true(a != b, "the two outcomes read differently")


func test_leaving_by_haggling_out_counts_as_refusing() -> void:
	var run := rg_run(ONLY_MARCH)
	rg_arrive(run)
	run.cash = 500
	run.customer["patience"] = 1
	run.customer["reserve"] = 100000
	var ev: Array[Dictionary] = run.apply({"t": "offer", "amount": 1})
	assert_true(rg_kinds(ev).has("left"))
	assert_true(rg_kinds(ev).has("regular_refused"))


func test_buyer_chapter_waits_for_a_match_then_pays() -> void:
	var run := rg_run({"ned": 4, "crowe": 4, "vane": 4, "ashby": 4, "dottie": 4, "march": 2})
	for i: int in range(40):
		for e: Dictionary in run.last_events:
			assert_true(e["e"] != "regular", "no visit while the shelf is empty")
		if run.is_over():
			break
		run.apply({"t": "table_leave"} if run.phase == RunState.PHASE_TABLE else {"t": "pass"})
		run.inventory.clear()
	var again := rg_run({"ned": 4, "crowe": 4, "vane": 4, "ashby": 4, "dottie": 4, "march": 2})
	again.inventory.append({"id": "tin_soldier", "name": "Tin soldier", "category": "toy", "value": 20, "curse": "", "uid": 900, "est": 20, "tells": 0})
	var ev: Array[Dictionary] = rg_arrive(again)
	assert_false(ev.is_empty(), "arrives once a toy is held")
	assert_eq(again.customer["kind"], "buyer")
	assert_eq(again.sellable().size(), 1)
	var before: int = again.cash
	var sold: Array[Dictionary] = again.apply({"t": "sell", "uid": 900})
	var k: Array = rg_kinds(sold)
	assert_true(k.has("sold") and k.has("regular_done") and k.has("found"), "paid, done, and the reward is found")
	assert_eq(again.cash - before, int(round(20.0 * again.tuning.regular_pay_mult)))
	assert_eq(again.found, [{"kind": "curio", "id": "curio_02"}] as Array[Dictionary])
	assert_eq(again.regular_progress, {"march": 3})


func test_last_chapter_is_the_payoff_and_finishes_the_arc() -> void:
	var run := rg_run({"ned": 4, "crowe": 4, "vane": 4, "ashby": 4, "dottie": 4, "march": 3})
	rg_arrive(run)
	run.cash = 500
	var ev: Array[Dictionary] = run.apply({"t": "buy"})
	var k: Array = rg_kinds(ev)
	assert_true(k.has("regular_done") and k.has("found"))
	var rd: Dictionary = ev[k.find("regular_done")]
	assert_eq(rd["chapter"], 4)
	assert_eq(rd["reward"], {"kind": "curio", "id": "curio_05"})
	var s := RelicStore.create(CurioCollection.create(1, Tuning.new()))
	s.regulars = {"march": 3}
	run.won = true
	var res: Dictionary = PlayerProfile.record_result(run, s)
	assert_eq(s.regulars["march"], 4)
	assert_true((res["deeds_new"] as PackedStringArray).has("last_tune"), "the arc's deed")
	assert_true(Regulars.is_finished("march", s.regulars))


func test_regular_state_survives_snapshot() -> void:
	var run := rg_run(ONLY_MARCH)
	rg_arrive(run)
	var back := RunState.new()
	back.restore(run.snapshot(), Catalog.load_default())
	assert_eq(back.state_hash(), run.state_hash())
	back.cash = 500
	run.cash = 500
	assert_eq(back.apply({"t": "buy"}), run.apply({"t": "buy"}), "continues identically")


func test_bots_play_regular_runs_to_the_end() -> void:
	var visits: int = 0
	for style: String in ShopBot.STYLES:
		for s: int in range(1, 25):
			var run := rg_run({}, s)
			assert_true(ShopBot.new(style).play(run), "not stuck")
			visits += 1 if str(run.regular.get("state", "")) in ["done", "refused"] else 0
	assert_true(visits >= 10, "regulars do visit (%d)" % visits)
