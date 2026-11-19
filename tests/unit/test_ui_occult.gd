extends TestCase


func _run() -> RunState:
	var run := RunState.new()
	run.start(3, Catalog.load_default(), Tuning.new())
	return run


func _evs(list: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in list:
		out.append(e as Dictionary)
	return out


func test_spell_defs_cover_all_six_in_order() -> void:
	var defs: Array[Dictionary] = UiOccult.spell_defs()
	assert_eq(defs.size(), 6)
	for i: int in range(6):
		assert_eq(str(defs[i]["id"]), UiOccult.SPELL_IDS[i])
		assert_true(str(defs[i].get("name", "")) != "", "every spell has a name")


func test_keys_map_to_known_spells_only() -> void:
	var known := PackedStringArray(["scry", "banish"])
	assert_eq(UiOccult.spell_for_key(KEY_5, known), "scry")
	assert_eq(UiOccult.spell_for_key(KEY_6, known), "", "hex is unknown")
	assert_eq(UiOccult.spell_for_key(KEY_8, known), "banish")
	assert_eq(UiOccult.spell_for_key(KEY_1, known), "", "1-4 stay tools")
	assert_eq(UiOccult.key_label("seal"), "0")
	assert_eq(UiOccult.key_label("scry"), "5")


func test_cast_command_shape() -> void:
	assert_eq(UiOccult.cast_command("scry"), {"t": "cast", "spell": "scry"})
	assert_eq(UiOccult.cast_command("banish", 4), {"t": "cast", "spell": "banish", "uid": 4})
	assert_true(UiOccult.needs_item("banish"))
	assert_false(UiOccult.needs_item("hex"))


func test_spells_disabled_outside_the_customer_phase() -> void:
	var run: RunState = _run()
	run.customer = {"kind": RunState.SELLER}
	assert_true(UiOccult.spells_enabled(run))
	run.phase = UiOccult.PHASE_TABLE
	assert_false(UiOccult.spells_enabled(run), "table phase")
	run.phase = RunState.PHASE_CUSTOMER
	run.customer = {}
	assert_false(UiOccult.spells_enabled(run), "nobody at the counter")


func test_backfire_hint_grows_with_dread() -> void:
	var run: RunState = _run()
	run.dread = 0.0
	var low: int = UiOccult.backfire_pct(run, "hex")
	run.dread = 4.0
	assert_true(UiOccult.backfire_pct(run, "hex") >= low)
	assert_true(UiOccult.backfire_pct(run, "hex") <= 95)


func test_wheel_ends_on_its_target_for_every_segment() -> void:
	var segs: Array[Dictionary] = UiOccult.wheel_segments()
	var edges: PackedFloat32Array = UiOccult.wheel_edges(segs)
	assert_eq(edges.size(), segs.size() + 1)
	assert_true(absf(edges[edges.size() - 1] - TAU) < 0.001)
	for from: float in [0.0, 2.0]:
		for i: int in range(segs.size()):
			var end: float = UiOccult.wheel_angle(1.0, edges, i, 4, from)
			assert_eq(UiOccult.wheel_under(edges, end), i, "segment %d under the pointer" % i)
	assert_true(UiOccult.wheel_angle(0.5, edges, 0) > UiOccult.wheel_angle(0.2, edges, 0), "spins forward")
	var late: float = UiOccult.wheel_angle(1.0, edges, 2) - UiOccult.wheel_angle(0.9, edges, 2)
	var early: float = UiOccult.wheel_angle(0.1, edges, 2) - UiOccult.wheel_angle(0.0, edges, 2)
	assert_true(late < early * 0.2, "it slows onto the segment")


func test_wheel_index_reads_id_name_or_number() -> void:
	var segs: Array[Dictionary] = UiOccult.wheel_segments()
	assert_eq(UiOccult.wheel_index(segs, {"segment": 2}), 2)
	assert_eq(UiOccult.wheel_index(segs, {"segment": str(segs[1]["id"])}), 1)
	assert_eq(UiOccult.wheel_index(segs, {"segment": "?", "name": str(segs[3]["name"])}), 3)
	assert_eq(UiOccult.wheel_index(segs, {"segment": 99, "name": "nope"}), -1)


func test_pairs_grid_maths() -> void:
	var cell := Vector2(36.0, 48.0)
	var o := Vector2(100.0, 50.0)
	assert_eq(UiOccult.pairs_cell(o, 0, cell), o)
	assert_eq(UiOccult.pairs_cell(o, 7, cell), o + Vector2(72.0, 48.0))
	assert_eq(UiOccult.pairs_index_at(o, o + Vector2(1.0, 1.0), cell, 10), 0)
	assert_eq(UiOccult.pairs_index_at(o, o + Vector2(5.0 * 36.0 - 1.0, 49.0), cell, 10), 9)
	assert_eq(UiOccult.pairs_index_at(o, o + Vector2(5.0 * 36.0 + 1.0, 1.0), cell, 10), -1)
	assert_eq(UiOccult.pairs_index_at(o, Vector2(0.0, 0.0), cell, 10), -1)
	assert_true(UiOccult.flip_width(0.0) > 0.99 and UiOccult.flip_width(0.5) < 0.01 and UiOccult.flip_width(1.0) > 0.99)
	assert_false(UiOccult.flip_face_up(0.3))
	assert_true(UiOccult.flip_face_up(0.7))
	assert_eq(UiOccult.shudder(1.0), 0.0, "the shudder dies away")


func test_set_groups_count_completion() -> void:
	var curios: Array[Dictionary] = [{"id": "a", "set": "parlor"}, {"id": "b", "set": "parlor"}, {"id": "c", "set": "attic"}]
	var g: Dictionary = UiOccult.set_groups(curios, {"a": 2, "c": 0})
	assert_eq(int(g["parlor"]["have"]), 1)
	assert_eq(int(g["parlor"]["total"]), 2)
	assert_eq(int(g["attic"]["have"]), 0)
	assert_true(g.has("cellar") and g.has("chapel"), "all four sets listed")
	assert_eq(UiOccult.set_header("parlor", 2, 2), "PARLOR SET  2/2  COMPLETE")
	assert_eq(RelicShopPanel.rsp_set_header("attic", 1, 6), "Attic set  1 / 6")
	assert_true(RelicShopPanel.rsp_cell_text({"name": "A", "rarity": "rare", "text": "It hums."}, 1, 1).contains("It hums."))


func test_find_rows_name_pages_and_curios() -> void:
	var rows: Array[Dictionary] = UiOccult.find_rows([{"kind": "page", "id": "hex"}, {"kind": "curio", "id": "zzz", "name": "Odd Thing"}])
	assert_eq(str(rows[0]["name"]), "Hex")
	assert_eq(str(rows[1]["name"]), "Odd Thing")
	assert_eq(UiOccult.found_line(rows), "PAGE: HEX, ODD THING")


func test_found_popup_queues_and_whispers() -> void:
	var f := UiFound.new()
	f.feed(_evs([{"e": "found_hint", "kind": "page"}]))
	assert_false(f.active())
	assert_true(str(f.whisper["text"]).contains("PAGE"))
	f.feed(_evs([{"e": "found", "kind": "page", "id": "scry", "name": "Scry"}, {"e": "found", "kind": "curio", "id": "c1", "name": "Bell"}]))
	assert_eq(f.popups.size(), 2)
	assert_true(f.whisper.is_empty(), "a find replaces the whisper")
	assert_false(f.dismiss(), "too early to close")
	f.tick(UiFound.SKIP_AFTER + 0.1)
	assert_true(f.dismiss())
	assert_eq(str(f.popups[0]["name"]), "Bell")
	f.tick(UiFound.POP_SECS + 0.1)
	assert_false(f.active(), "popups close themselves")
	var w := UiFound.new()
	w.feed(_evs([{"e": "found_hint", "kind": "curio"}]))
	w.tick(UiFound.WHISPER_SECS + 0.1)
	assert_true(w.whisper.is_empty())


func test_spell_bar_flash_and_shake_from_events() -> void:
	var b := UiSpellBar.new()
	b.feed(_evs([{"e": "cast", "spell": "hex", "ok": true, "backfire": false}]))
	assert_true(b.flashing("hex"))
	assert_false(b.shaking("hex"))
	b.feed(_evs([{"e": "backfire", "spell": "scry", "kind": "dread_spike", "text": "x"}]))
	assert_true(b.shaking("scry"))
	b.tick(1.0)
	assert_false(b.flashing("hex"))
	b.feed(_evs([{"e": "cast", "spell": "seal", "ok": false}]))
	assert_false(b.flashing("seal"), "invalid casts do not flash")
	assert_eq(UiSpellBar.placeholder_icon("scry").get_size(), Vector2(16, 16))
	assert_eq(UiSpellBar.slot_rect(1).position.y, UiSpellBar.Y0 + UiSpellBar.STEP)


func test_table_dice_result_lands_after_the_tumble() -> void:
	var run: RunState = _run()
	var t := UiTable.new()
	t.feed(_evs([{"e": "table_open", "night": 1, "games_left": 3, "lots_left": 1}]))
	assert_eq(t.games_left, 3)
	t.feed(_evs([{"e": "dice", "d1": 3, "d2": 6, "call": "high", "win": true, "stake": 4, "payout": 8}]))
	assert_eq(t.stage, "dice")
	assert_eq(t.games_left, 2)
	t.tick(0.3, run)
	assert_true(t.banner.is_empty(), "no result while the dice still tumble")
	assert_true(t.busy())
	t.tick(1.0, run)
	assert_false(t.banner.is_empty())
	assert_eq(int(t.banner["net"]), 4)
	t.tick(1.0, run)
	assert_false(t.busy())


func test_table_hand_cards_flip_in_one_by_one() -> void:
	var run: RunState = _run()
	var t := UiTable.new()
	t.feed(_evs([{"e": "hand_card", "who": "you", "card": 5, "total": 5}, {"e": "hand_card", "who": "you", "card": 7, "total": 12},
		{"e": "hand_card", "who": "house", "card": 4, "total": 4}]))
	assert_true(t.hand_active)
	assert_true(float(t._hand[1]["born"]) - float(t._hand[0]["born"]) >= UiTable.CARD_GAP - 0.001)
	assert_true(float(t._hand[2]["born"]) > float(t._hand[1]["born"]))
	t.feed(_evs([{"e": "hand_end", "you": 12, "house": 4, "win": false, "stake": 3, "payout": 0}]))
	assert_false(t.hand_active)
	t.tick(3.0, run)
	assert_eq(int(t.banner["net"]), -3)
	assert_eq(t.banner["col"], 13)


func test_table_wheel_spins_then_pays() -> void:
	var run: RunState = _run()
	var t := UiTable.new()
	var segs: Array[Dictionary] = UiOccult.wheel_segments()
	t.feed(_evs([{"e": "wheel", "segment": 2, "name": str(segs[2]["name"]), "mult": 2.0, "stake": 5, "payout": 10, "prize": "", "dread": 0.0}]))
	t.tick(1.0, run)
	assert_true(t.banner.is_empty())
	assert_true(t.wheel_angle > 1.0, "turning")
	t.tick(UiTable.WHEEL_SECS, run)
	assert_eq(UiOccult.wheel_under(t._wheel_edges, t.wheel_angle), 2, "it lands on the named segment")
	assert_eq(int(t.banner["net"]), 5)
	t.tick(1.0, run)
	assert_true(t._coins.size() > 0 or t.banner.size() > 0)


func test_tarot_pairs_flip_match_miss_and_end() -> void:
	var run: RunState = _run()
	var t := UiTable.new()
	t.feed(_evs([{"e": "pairs_deal", "count": 10, "tries": 5}]))
	assert_eq(t._pairs.size(), 10)
	assert_true(t.pairs_active)
	assert_eq(t.pairs_tries, 5)
	t.feed(_evs([{"e": "pairs_flip", "i": 0, "card": "the_sun", "name": "The Sun"}, {"e": "pairs_flip", "i": 4, "card": "the_sun", "name": "The Sun"}]))
	assert_eq(str(t._pairs[0]["state"]), "up")
	t.feed(_evs([{"e": "pairs_match", "card": "the_sun", "name": "The Sun", "mult": 1.5, "dread": 0.0}]))
	assert_eq(str(t._pairs[4]["state"]), "matched")
	assert_eq(t.pairs_tries, 4)
	assert_true(absf(t.pairs_mult - 1.5 * Tuning.shared().pairs_pay_scale) < 0.001, "a match adds mult * pairs_pay_scale, as MidnightTable.pairs_add does")
	t.feed(_evs([{"e": "pairs_flip", "i": 1, "card": "death", "name": "Death"}, {"e": "pairs_flip", "i": 2, "card": "the_fool", "name": "The Fool"}]))
	t.feed(_evs([{"e": "pairs_miss", "a": 1, "b": 2}]))
	assert_eq(str(t._pairs[1]["state"]), "up", "still face up for the beat")
	t.tick(0.1, run)
	assert_eq(str(t._pairs[1]["state"]), "up")
	t.tick(UiTable.FLIP_SECS + UiTable.MISS_BEAT, run)
	assert_eq(str(t._pairs[1]["state"]), "down", "flips back after the beat")
	assert_eq(str(t._pairs[2]["state"]), "down")
	t.tick(1.0, run)
	assert_eq(int(t._pairs[1]["dir"]), -1)
	t.feed(_evs([{"e": "pairs_flip", "i": 7, "card": "death", "name": "Death"}, {"e": "pairs_flip", "i": 8, "card": "death", "name": "Death"}]))
	t.feed(_evs([{"e": "pairs_match", "card": "death", "name": "Death", "mult": 0.0, "dread": 0.0}]))
	assert_true(t.pairs_voided)
	assert_eq(t.pairs_mult, 0.0)
	t.feed(_evs([{"e": "pairs_end", "matches": 2, "stake": 4, "payout": 0, "dread": 0.0}]))
	assert_false(t.pairs_active)
	t.tick(2.0, run)
	assert_eq(int(t.banner["net"]), -4)


func test_table_stake_clamps_to_cash() -> void:
	var run: RunState = _run()
	run.cash = 10
	var t := UiTable.new()
	t.stake = 99
	t.clamp_stake(run)
	assert_true(t.stake <= 10 and t.stake >= 1)
	assert_true(t.stake_max(run) >= 1)


func test_occult_event_log_lines() -> void:
	assert_eq(UiOccult.event_text({"e": "dice", "d1": 1, "d2": 2, "win": false}), "Dice: 1 and 2. The house wins.")
	assert_eq(UiOccult.event_text({"e": "cast", "ok": false}), "")
	assert_true(UiOccult.OCCULT_EVENTS.has("pairs_miss"))
	assert_true(UiOccult.event_text({"e": "found", "name": "Bell"}).contains("Bell"))
