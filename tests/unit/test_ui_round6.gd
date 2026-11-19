extends TestCase
## Round 6 UI: the Ledger (deeds and regulars), deed and regular toasts, the tutorial overlay, the title entries and
## the curio display list. Everything is data-driven, so these run with or without the logic worker's files.

func _deeds() -> Array:
	return [
		{"id": "first_win", "name": "First Light", "text": "Survive a run.", "secret": false},
		{"id": "hush", "name": "The Hush", "text": "Do something odd.", "secret": true},
	]


func _regulars() -> Array:
	return [{"id": "widow", "name": "The Widow March", "tid": "x", "chapters": [
		{"line": "It came home again.", "kind": "seller"}, {"line": "She wants it gone.", "kind": "buyer"}]}]


func after_each() -> void:
	UiLedger.force_deeds = []
	UiLedger.force_regulars = []


func test_deed_rows_ink_the_earned_and_hide_the_secret() -> void:
	var d: Array = _deeds()
	var earned := PackedStringArray(["first_win"])
	var a: Dictionary = UiLedger.deed_row(d[0], earned)
	assert_eq(a["state"], "earned")
	assert_eq(a["name"], "FIRST LIGHT")
	var b: Dictionary = UiLedger.deed_row(d[1], earned)
	assert_eq(b["state"], "secret")
	assert_eq(b["name"], UiLedger.SECRET_NAME, "a secret deed shows no name")
	assert_false("HUSH" in str(b["text"]), "or its text")
	assert_eq(UiLedger.deed_row(d[0], PackedStringArray())["state"], "open")
	assert_eq(UiLedger.deed_row(d[1], PackedStringArray(["hush"]))["state"], "earned", "once earned the secret is named")


func test_regular_rows_show_only_the_lines_seen() -> void:
	var def: Dictionary = _regulars()[0]
	var none: Dictionary = UiLedger.regular_row(def, 0)
	assert_false(bool(none["met"]))
	assert_eq((none["lines"] as Array).size(), 0)
	var one: Dictionary = UiLedger.regular_row(def, 1)
	assert_true(bool(one["met"]))
	assert_eq(one["lines"], ["IT CAME HOME AGAIN."])
	assert_eq(one["total"], 2)
	assert_eq(UiLedger.regular_row(def, 9)["chapter"], 2, "clamped to the arc length")


func test_ledger_pages_tabs_and_focus() -> void:
	var many: Array = []
	for i: int in range(30):
		many.append({"id": "d%d" % i, "name": "Deed %d" % i, "text": "t", "secret": i % 5 == 0})
	UiLedger.force_deeds = many
	UiLedger.force_regulars = _regulars()
	var l := UiLedger.new()
	assert_eq(l.pages(), 3, "30 deeds, 12 a page")
	assert_true(l.focus_ids().has("ledger_next"))
	l.turn(1)
	l.turn(1)
	l.turn(1)
	assert_eq(l.page, 2, "clamped at the last page")
	assert_true(l.activate("ledger_tab_regulars"))
	assert_eq(l.tab, UiLedger.TAB_REGULARS)
	assert_eq(l.page, 0, "a tab starts on its first page")
	assert_eq(l.pages(), 1)
	assert_false(l.focus_ids().has("ledger_next"), "one page: no page buttons")
	assert_false(l.activate("nope"))


func test_profile_readers_tolerate_a_profile_without_the_fields() -> void:
	assert_eq(UiLedger.profile_deeds(null).size(), 0)
	assert_eq(UiLedger.profile_regulars(null).size(), 0)
	var o := RefCounted.new()
	assert_eq(UiLedger.profile_deeds(o).size(), 0)


func test_ledger_draws_on_a_canvas_without_errors() -> void:
	UiLedger.force_deeds = _deeds()
	UiLedger.force_regulars = _regulars()
	assert_true(UiLedger.seal_tex("first_win") != null)
	assert_eq(UiLedger.seal_tex("first_win").get_size(), Vector2(20, 20))
	assert_eq(UiLedger.portrait_tex("widow").get_size(), Vector2(32, 40))


func test_toasts_queue_and_expire() -> void:
	var t := UiToasts.new()
	t.push_deed("first_win")
	t.push_deed("first_win")
	assert_eq(t.deeds.size(), 1, "a deed is toasted once")
	t.push_deed("other")
	assert_true(t.active())
	t.tick(0.1)
	t.tick(UiToasts.DEED_SECS)
	assert_eq(t.deeds.size(), 1, "the second one is up next")
	t.tick(UiToasts.DEED_SECS)
	assert_eq(t.deeds.size(), 0)
	t.feed([{"e": "regular", "id": "widow", "name": "The Widow March", "chapter": 2, "line": "It came home."}] as Array[Dictionary])
	assert_eq(t.regulars[0]["chapter"], 2, "the event chapter is already 1-based")
	assert_eq(t.regulars[0]["name"], "THE WIDOW MARCH")
	t.tick(UiToasts.REG_SECS + 0.1)
	assert_false(t.active())
	assert_true(UiToasts.slide(0.0, 3.0) < 0.001)
	assert_true(absf(UiToasts.slide(1.0, 3.0) - 1.0) < 0.001)
	assert_true(UiToasts.slide(2.9, 3.0) < 0.5, "leaves at the end")


func test_tutorial_steps_set_and_clear() -> void:
	var u := UiTutorial.new()
	u.feed([{"e": "tutorial_step", "step": 2, "text": "Try the lamp.", "focus": "tools"}] as Array[Dictionary])
	assert_true(u.active)
	assert_eq(u.text, "TRY THE LAMP.")
	assert_eq(u.focus, "tools")
	u.feed([{"e": "customer", "tutorial": 3}] as Array[Dictionary])
	assert_true(u.active, "a customer arriving keeps the hint")
	u.feed([{"e": "inspected", "tool": "uv", "tell": ""}] as Array[Dictionary])
	assert_false(u.active, "the player acting ends it")
	u.feed([{"e": "tutorial_step", "step": 7, "text": "Spells.", "focus": "spells"}, {"e": "customer", "kind": "seller"}] as Array[Dictionary])
	assert_true(u.active, "a step and a customer in one batch: the step stays")
	u.tick(UiTutorial.MAX_SECS + 1.0)
	assert_false(u.active, "and lapses on its own")
	u.feed([{"e": "tutorial_step", "step": 1, "text": "Hi.", "focus": "pass"}, {"e": "night_end", "night": 1}] as Array[Dictionary])
	assert_false(u.active)


func test_tutorial_focus_rect_unions_widgets_and_falls_back() -> void:
	var w: Array[Dictionary] = [
		{"id": "tool:uv", "rect": Rect2(10, 10, 20, 20), "enabled": true},
		{"id": "tool:scale", "rect": Rect2(40, 10, 20, 20), "enabled": true},
		{"id": "buy", "rect": Rect2(100, 100, 50, 10), "enabled": true},
	]
	assert_eq(UiTutorial.focus_rect("tools", w), Rect2(10, 10, 50, 20))
	assert_eq(UiTutorial.focus_rect("buy", w), Rect2(100, 100, 50, 10))
	assert_eq(UiTutorial.focus_rect("dread", w), UiHud.DREAD_RECT, "no widget: the fixed rectangle")
	assert_eq(UiTutorial.focus_rect("shelf", w, [Rect2(1, 2, 3, 4)] as Array[Rect2]), Rect2(1, 2, 3, 4))
	for id: String in ["tools", "offer", "buy", "pass", "shelf", "dread", "spells", "table"]:
		assert_true(UiTutorial.FALLBACK.has(id), id)


func test_title_entries_offer_ledger_and_skip() -> void:
	var ids: Array[String] = []
	for e: Dictionary in TitleScreen.ts_entries(false, false, false, 0, false, true, true):
		ids.append(str(e["id"]))
	assert_eq(ids, ["new", "skip_tutorial", "ledger", "settings", "quit"] as Array[String])
	assert_false(TitleScreen.ts_entries(false, false).any(func(e: Dictionary) -> bool: return str(e["id"]) == "skip_tutorial"))


func test_displayed_curios_are_rarest_first_and_capped() -> void:
	var owned: Dictionary = {}
	var rar: Dictionary = {}
	for i: int in range(15):
		owned["c%02d" % i] = 1
		rar["c%02d" % i] = "common"
	owned["gone"] = 0
	rar["c07"] = "legendary"
	rar["c03"] = "rare"
	var out: PackedStringArray = ShopGame.ui_displayed_curios(owned, rar)
	assert_eq(out.size(), 12)
	assert_eq(out[0], "c07")
	assert_eq(out[1], "c03")
	assert_false(out.has("gone"), "zero copies are not shown")


func test_regular_and_deed_events_have_log_lines_and_sounds() -> void:
	assert_eq(ShopGame.ui_event_line({"e": "tutorial_step"}), "")
	assert_true(ShopGame.ui_event_line({"e": "regular", "name": "Mr Vane", "chapter": 1}).contains("Chapter 1"))
	assert_eq(ShopGame.ui_event_line({"e": "regular_done", "line": "Thank you."}), "Thank you.")
	assert_true(SfxSynth.NAMES.has("deed") and SfxSynth.NAMES.has("regular"))
	assert_true(SfxPlayer.UI_SOUNDS.has("deed") and SfxPlayer.UI_SOUNDS.has("regular"))


func test_run_options_for_regulars_and_the_tutorial_are_not_dropped() -> void:
	assert_true(UiEngage.opts_empty({}))
	assert_false(UiEngage.opts_empty({"tutorial": true}), "the tutorial run must reach RunRecording.begin")
	assert_false(UiEngage.opts_empty({"regulars": {"widow": 1}}), "so must the regulars switch")
	assert_true(UiEngage.opts_empty({"tutorial": false}))


func test_tool_tip_names_the_clock_cost() -> void:
	var run := RunState.new()
	run.start(3, Catalog.load_default(), Tuning.new())
	assert_true(UiHud.ui_tool_tip("pendulum", run).ends_with("COSTS %d MIN" % int(round(run.tuning.pendulum_minutes))))
	assert_true(UiHud.ui_tool_tip("uv", run).begins_with("UV LAMP"))
