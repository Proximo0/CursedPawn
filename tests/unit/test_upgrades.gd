extends TestCase

const UP_PATH: String = "user://test_upgrades_profile.json"


func up_store() -> RelicStore:
	return RelicStore.create(CurioCollection.create(1, Tuning.new()))


func up_maxed() -> Dictionary:
	var ranks: Dictionary = {}
	for u: Dictionary in Upgrades.all():
		ranks[str(u["id"])] = int(u["max_rank"])
	return ranks


func up_run(ranks: Dictionary, tun: Tuning = null, seed_value: int = 6) -> RunState:
	var run := RunState.new()
	run.start(seed_value, Catalog.load_default(), tun if tun != null else Tuning.new(), {}, {"upgrades": ranks})
	return run


func test_data_is_valid() -> void:
	assert_eq(Upgrades.problems().size(), 0, "; ".join(Upgrades.problems()))


func test_each_upgrade_applies() -> void:
	var base := Tuning.new()
	for u: Dictionary in Upgrades.all():
		var id: String = str(u["id"])
		var run := up_run({id: int(u["max_rank"])})
		assert_eq(run.opts["upgrades"], {id: int(u["max_rank"])}, id)
		var t: Tuning = run.tuning
		match id:
			"extra_cast":
				assert_eq(int(t.spell_casts_per_night), int(base.spell_casts_per_night) + 2)
				assert_eq(run.casts_left, int(t.spell_casts_per_night))
			"start_spell":
				assert_eq(run.spells_known.size(), Grimoire.DEFAULT_KNOWN.size() + 1)
			"keen_eye":
				assert_near(t.tell_chance, base.tell_chance + 0.3)
			"thrifty_rent":
				assert_near(t.rent_base, base.rent_base * pow(0.94, 3.0))
			"pendulum":
				assert_true(run.tool_ok("pendulum"))
			"loss_purse":
				assert_near(float(Upgrades.flags_for({id: 1})["loss_cash_frac"]), 0.1)
			"altar_candle":
				assert_near(t.night_dread_relief, 1.0)
			"deep_pockets":
				assert_eq(run.cash, int(base.start_cash) + 45)
			_:
				assert_true(false, "no test for upgrade %s" % id)
	assert_false(up_run({}).tool_ok("pendulum"), "off without the upgrade")
	assert_eq(up_run({"extra_cast": 99}).opts["upgrades"], {"extra_cast": 2}, "ranks are clamped")


func test_candle_relieves_dread_at_dawn() -> void:
	var run := up_run({"altar_candle": 2})
	run.dread = 3.0
	run.phase = RunState.PHASE_TABLE
	run.table = {"hand": {}, "pairs": {}}
	var ev: Array[Dictionary] = run.apply({"t": "table_leave"})
	assert_near(run.dread, 2.0)
	assert_eq(ev[0]["e"], "table_leave")
	assert_near(float(ev[1]["dread_relief"]), 1.0)


func test_buy_validation() -> void:
	var s := up_store()
	assert_false(bool(Upgrades.buy("nope", s)["ok"]))
	var r: Dictionary = Upgrades.buy("extra_cast", s)
	assert_false(bool(r["ok"]))
	assert_eq(r["why"], "not enough ectoplasm")
	s.ecto = 100
	r = Upgrades.buy("extra_cast", s)
	assert_true(bool(r["ok"]))
	assert_eq(s.ecto, 100 - Upgrades.cost_of("extra_cast", 0))
	assert_eq(s.upgrades["extra_cast"], 1)
	assert_eq(Upgrades.cost_of("extra_cast", 1), 2 * Upgrades.cost_of("extra_cast", 0), "next rank costs more")
	assert_true(bool(Upgrades.buy("extra_cast", s)["ok"]))
	var ecto: int = s.ecto
	r = Upgrades.buy("extra_cast", s)
	assert_eq(r["why"], "already at max rank")
	assert_eq(s.ecto, ecto, "nothing charged")


func test_ecto_earning() -> void:
	var run := RunState.new()
	run.tuning = Tuning.new()
	run.won = true
	run.night = 5
	assert_eq(Upgrades.ecto_for(run), int(5 * run.tuning.ecto_per_night + run.tuning.ecto_win_bonus))
	run.opts = {"haunting": 5}
	assert_eq(Upgrades.ecto_for(run), int(round((5 * run.tuning.ecto_per_night + run.tuning.ecto_win_bonus) * 1.5)))
	run.won = false
	run.night = 3
	run.opts = {}
	assert_eq(Upgrades.ecto_for(run), int(2 * run.tuning.ecto_per_night), "two nights survived, no bonus")
	var s := up_store()
	run.won = true
	run.night = 5
	var res: Dictionary = PlayerProfile.record_result(run, s)
	assert_eq(s.ecto, res["ecto"])
	assert_true(int(res["ecto"]) > 0)


func test_loss_purse_carries_cash() -> void:
	var s := up_store()
	s.upgrades = {"loss_purse": 1}
	var run := up_run({}, null)
	run.won = false
	run.cash = 250
	var res: Dictionary = PlayerProfile.record_result(run, s)
	assert_eq(res["carried"], 25)
	var next: RunState = RunState.new()
	next.start(2, Catalog.load_default(), Tuning.new(), {}, PlayerProfile.altar_opts(s))
	assert_eq(next.cash, int(Tuning.new().start_cash) + 25)


func test_pendulum_says_cursed_or_clean_only() -> void:
	for cursed: float in [0.0, 1.0]:
		var tun := Tuning.new()
		tun.set_value("cursed_share", cursed)
		var run := up_run({"pendulum": 1}, tun)
		assert_eq(run.customer["kind"], RunState.SELLER)
		var ev: Array[Dictionary] = run.apply({"t": "inspect", "tool": "pendulum"})
		assert_eq(ev[0]["e"], "inspected")
		assert_eq(ev[0]["tell"], "cursed" if cursed > 0.0 else "clean")
	var plain := up_run({})
	assert_eq(plain.apply({"t": "inspect", "tool": "pendulum"})[0]["e"], "invalid")


func test_profile_round_trip_and_old_version() -> void:
	var a := up_store()
	a.ecto = 31
	a.upgrades = {"pendulum": 1, "extra_cast": 2}
	a.carry_cash = 12
	assert_eq(PlayerProfile.save(a, UP_PATH), OK)
	var b := up_store()
	assert_true(PlayerProfile.load_into(b, UP_PATH))
	assert_eq(b.ecto, 31)
	assert_eq(b.upgrades, {"pendulum": 1, "extra_cast": 2})
	assert_eq(b.carry_cash, 12)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UP_PATH))  # an old (v3) file has no altar
	d["version"] = 3
	d.erase("altar")
	var f := FileAccess.open(UP_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var c := up_store()
	assert_true(PlayerProfile.load_into(c, UP_PATH), "old file loads")
	assert_eq(c.ecto, 0)
	assert_eq(c.upgrades, {})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(UP_PATH))


func test_replay_equal_with_upgrades() -> void:
	var cat := Catalog.load_default()
	for style: String in ShopBot.STYLES:
		var run := RunState.new()
		var opts: Dictionary = {"upgrades": up_maxed(), "haunting": 2, "carry_cash": 15}
		var rec := RunRecording.begin(run, 77, cat, Tuning.new(), {}, opts)
		assert_true(ShopBot.new(style).play(run, rec))
		assert_eq(rec.first_divergence(cat), -1, "replay matches")
		var back := RunRecording.from_dict(JSON.parse_string(JSON.stringify(rec.to_dict())))
		assert_eq(back.first_divergence(cat), -1, "after JSON")
		assert_eq(back.replay(cat).state_hash(), run.state_hash())
