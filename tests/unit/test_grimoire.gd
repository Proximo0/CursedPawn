extends TestCase
## Spell rules and their RunState effects. Helpers here are prefixed gr_.


func gr_run(known: Array = ["scry", "hex", "glamour", "banish", "summon", "seal"]) -> RunState:
	var tun := Tuning.new()
	tun.set_value("spell_backfire_base", 0.0)
	tun.set_value("spell_backfire_per_dread", 0.0)
	tun.set_value("hidden_find_chance", 0.0)
	tun.set_value("wake_threshold", 20.0)
	var run := RunState.new()
	run.spells_known = PackedStringArray(known)
	run.start(5, Catalog.load_default(), tun)
	return run


func gr_seller(run: RunState, curse: String = "") -> void:
	run.customer = {"kind": "seller", "item": {"id": "music_box", "name": "Music box", "category": "toy", "value": 100,
		"curse": curse, "hidden": {}}, "reserve": 60, "ask": 90, "patience": 3, "type": "", "noise_u": 0.0,
		"tools": [], "tells": [], "imposter": false}


func gr_held(run: RunState, curse: String) -> int:
	var uid: int = run.next_uid
	run.next_uid += 1
	run.inventory.append({"uid": uid, "id": "tin_soldier", "name": "Tin soldier", "category": "toy", "value": 20,
		"curse": curse, "est": 20, "tells": 1 if curse != "" else 0})
	return uid


func gr_find(ev: Array[Dictionary], name: String) -> Dictionary:
	for e: Dictionary in ev:
		if e["e"] == name:
			return e
	return {}


func test_data_loads_all_six() -> void:
	var g := Grimoire.load_default(Tuning.new())
	assert_eq(g.ids(), PackedStringArray(["scry", "hex", "glamour", "banish", "summon", "seal"]))
	for s: Dictionary in g.spells:
		assert_true(str(s["backfire"]) != "" and str(s["text"]) != "", "text on %s" % s["id"])


func test_backfire_chance_rises_with_dread() -> void:
	var g := Grimoire.load_default(Tuning.new())
	assert_true(g.backfire_chance(5.0) > g.backfire_chance(0.0))
	assert_true(g.backfire_chance(1000.0) <= 1.0)


func test_scry_reveals_the_curse_tell() -> void:
	var run := gr_run()
	var cid: String = str(run.catalog.curses[0]["id"])
	gr_seller(run, cid)
	var ev: Array[Dictionary] = run.apply({"t": "cast", "spell": "scry"})
	var r: Dictionary = gr_find(ev, "scry_reveal")
	assert_true(str(r["tell"]) != "", "tell shown")
	assert_true((run.customer["tells"] as Array).has(r["tool"]))
	assert_eq(run.casts_left, int(run.tuning.spell_casts_per_night) - 1)
	assert_true(run.dread > 0.0, "cast costs dread")


func test_scry_on_clean_object_shows_nothing() -> void:
	var run := gr_run()
	gr_seller(run)
	assert_eq(gr_find(run.apply({"t": "cast", "spell": "scry"}), "scry_reveal")["tell"], "")


func test_hex_lowers_reserve_and_ask() -> void:
	var run := gr_run()
	gr_seller(run)
	var h: Dictionary = gr_find(run.apply({"t": "cast", "spell": "hex"}), "hexed")
	assert_eq(h["reserve"], int(round(60 * run.tuning.hex_mult)))
	assert_eq(run.customer["ask"], h["ask"])
	assert_true(int(h["ask"]) < 90)


func test_glamour_raises_buyer_pay() -> void:
	var run := gr_run()
	run.customer = {"kind": "buyer", "category": "toy", "imposter": false, "pay_mult": 1.0, "cursed_mult": 1.0}
	var ev: Array[Dictionary] = run.apply({"t": "cast", "spell": "glamour"})
	assert_near(float(gr_find(ev, "glamoured")["mult"]), run.tuning.glamour_mult)
	assert_near(float(run.customer["pay_mult"]), run.tuning.glamour_mult)


func test_banish_removes_cursed_object_and_dread() -> void:
	var run := gr_run()
	var uid: int = gr_held(run, str(run.catalog.curses[0]["id"]))
	run.dread = 5.0
	var ev: Array[Dictionary] = run.apply({"t": "cast", "spell": "banish", "uid": uid})
	assert_eq(gr_find(ev, "banished")["uid"], uid)
	assert_true(run.inventory.is_empty())
	assert_true(run.dread < 5.0)
	var clean: int = gr_held(run, "")
	assert_false(gr_find(run.apply({"t": "cast", "spell": "banish", "uid": clean}), "cast")["ok"], "clean object invalid")


func test_summon_makes_next_customer_a_buyer() -> void:
	var run := gr_run()
	gr_held(run, "")
	var ev: Array[Dictionary] = run.apply({"t": "cast", "spell": "summon"})
	assert_eq(gr_find(ev, "summoned")["category"], "toy")
	ev = run.apply({"t": "pass"})
	var c: Dictionary = gr_find(ev, "customer")
	assert_eq(c["kind"], "buyer")
	assert_eq(c["category"], "toy")


func test_seal_blocks_wakes_and_raises_rent() -> void:
	var run := gr_run()
	assert_true(gr_find(run.apply({"t": "cast", "spell": "seal"}), "sealed") != {})
	assert_true(run.sealed)
	run.dread = 50.0
	var ev: Array[Dictionary] = []
	run.clock = 0.0
	ev = run.apply({"t": "pass"})
	assert_true(gr_find(ev, "wake").is_empty(), "no wake while sealed")
	var ne: Dictionary = gr_find(ev, "night_end")
	assert_eq(ne["rent"], int(round(run.rent_for(1) * run.tuning.seal_debt_mult)))
	assert_false(run.sealed, "seal ends with the night")


func test_invalid_casts() -> void:
	var run := gr_run(["scry"])
	gr_seller(run)
	assert_false(gr_find(run.apply({"t": "cast", "spell": "hex"}), "cast")["ok"], "unknown")
	run.casts_left = 0
	assert_false(gr_find(run.apply({"t": "cast", "spell": "scry"}), "cast")["ok"], "no casts")
	run.casts_left = 2
	run.customer = {"kind": "buyer", "category": "toy", "pay_mult": 1.0}
	assert_false(gr_find(run.apply({"t": "cast", "spell": "scry"}), "cast")["ok"], "needs seller")
	assert_eq(run.casts_left, 2, "an invalid cast costs nothing")


func test_every_backfire_kind() -> void:
	for kind: String in Grimoire.BACKFIRE_KINDS:
		var run := gr_run()
		run.tuning.set_value("spell_backfire_base", 1.0)
		run.grimoire.force_kind = kind
		gr_seller(run)
		gr_held(run, "")
		var cash0: int = run.cash
		var seen: int = run.customers_seen
		var ev: Array[Dictionary] = run.apply({"t": "cast", "spell": "hex"})
		assert_true(gr_find(ev, "cast")["backfire"], kind)
		assert_eq(gr_find(ev, "backfire")["kind"], kind)
		assert_true(gr_find(ev, "hexed").is_empty(), "effect replaced by the backfire")
		match kind:
			"dread_spike":
				assert_true(run.dread >= run.tuning.backfire_dread, kind)
			"cash_burn":
				assert_eq(run.cash, cash0 - int(cash0 * run.tuning.backfire_cash_frac))
			"customer_flees":
				assert_true(run.customers_seen > seen or gr_find(ev, "left") != {})
			"curse_jumps":
				assert_true(str(run.inventory[0]["curse"]) != "")


func test_curse_jumps_falls_back_without_a_clean_object() -> void:
	var g := Grimoire.load_default(Tuning.new())
	var rng := RandomNumberGenerator.new()
	var inv: Array[Dictionary] = [{"curse": "x"}]
	for i: int in range(40):
		assert_true(g.backfire_kind(rng, inv) != "curse_jumps")
