extends TestCase

const TT_PATH: String = "user://test_ui_title_settings.json"


func tt_run() -> RunState:
	var run := RunState.new()
	run.start(3, Catalog.load_default(), Tuning.new())
	run.customer = {"kind": RunState.SELLER, "tools": [], "tells": [], "ask": 40}
	return run


func test_first_seller_gets_the_inspect_hint() -> void:
	var h: Dictionary = TutorialHints.next(tt_run(), [])
	assert_eq(h.get("id", ""), "seller")
	assert_true(str(h["text"]).begins_with("Inspect with 1-4"), "text")


func test_nothing_to_say_when_everything_is_seen_or_not_due() -> void:
	var run: RunState = tt_run()
	assert_eq(TutorialHints.next(run, ["seller"]), {}, "no tell, no buyer, no dread yet")
	assert_eq(TutorialHints.next(run, TutorialHints.IDS), {}, "all seen")
	assert_eq(TutorialHints.next(null, []), {}, "no run")


func test_hints_come_in_teaching_order_and_only_once() -> void:
	var run: RunState = tt_run()
	run.customer["tells"] = ["uv"]
	run.dread = run.tuning.wake_threshold * 0.6
	run.wake_nights.append(1)
	run.night = 2
	var seen: Array[String] = []
	var order: Array[String] = []
	for _i: int in range(10):
		var h: Dictionary = TutorialHints.next(run, seen)
		if h.is_empty():
			break
		order.append(str(h["id"]))
		seen.append(str(h["id"]))
	assert_eq(order, ["seller", "tell", "dread_half", "wake", "rent"], "buyer is skipped: no buyer here")
	run.customer = {"kind": RunState.BUYER, "category": "x"}
	assert_eq(TutorialHints.next(run, seen).get("id", ""), "buyer")
	seen.append("buyer")
	assert_eq(TutorialHints.next(run, seen), {}, "each hint once ever")


func test_dread_hint_waits_for_half_the_wake_threshold() -> void:
	var run: RunState = tt_run()
	run.dread = run.tuning.wake_threshold * 0.49
	assert_false(TutorialHints.applies("dread_half", run))
	run.dread = run.tuning.wake_threshold * 0.5
	assert_true(TutorialHints.applies("dread_half", run))


func test_no_hint_on_a_finished_run() -> void:
	var run: RunState = tt_run()
	run.phase = RunState.PHASE_OVER
	assert_eq(TutorialHints.next(run, []), {})


func test_every_hint_has_text_that_fits_the_grid() -> void:
	for id: String in TutorialHints.IDS:
		var text: String = str(TutorialHints.TEXTS[id])
		assert_true(text != "", id)
		assert_true(UiPixelFont.ui_wrap(text, 428).size() <= 2, "%s fits two lines" % id)


func test_tracker_marks_seen_at_once_and_expires() -> void:
	var s := TsSettings.new()
	var tr := TsHintTracker.new(s)
	var run: RunState = tt_run()
	tr.refresh(run)
	assert_eq(tr.current.get("id", ""), "seller")
	assert_true(s.has_seen("seller"), "marked when shown")
	tr.refresh(run)
	assert_eq(tr.current.get("id", ""), "seller", "one hint at a time")
	tr.tick(TsHintTracker.SHOW_SECS + 0.1)
	assert_eq(tr.text(), "")
	tr.refresh(run)
	assert_eq(tr.text(), "", "seller never returns")


func test_settings_round_trip() -> void:
	var a := TsSettings.new()
	a.master = 0.4
	a.muted = true
	a.dither = false
	a.fullscreen = true
	a.mark_seen("seller")
	a.mark_seen("tell")
	a.mark_seen("tell")
	assert_eq(a.seen.size(), 2, "no duplicates")
	assert_eq(a.save(TT_PATH), OK)
	var b := TsSettings.new()
	assert_true(b.load_from(TT_PATH))
	assert_near(b.master, 0.4)
	assert_true(b.muted)
	assert_false(b.dither)
	assert_true(b.fullscreen)
	assert_eq(b.seen, ["seller", "tell"] as Array[String])
	assert_false(FileAccess.file_exists(TT_PATH + ".tmp"), "temp file renamed away")
	b.reset_hints()
	assert_true(b.seen.is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TT_PATH))


func test_settings_load_failures_keep_defaults() -> void:
	var s := TsSettings.new()
	assert_false(s.load_from("user://no_such_settings.json"))
	var f := FileAccess.open(TT_PATH, FileAccess.WRITE)
	f.store_string("{\"version\": 99, \"master\": 0.1}")
	f.close()
	assert_false(s.load_from(TT_PATH), "newer version ignored")
	assert_near(s.master, 1.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TT_PATH))


func test_volume_steps_snap_and_clamp() -> void:
	var s := TsSettings.new()
	s.step_volume(1)
	assert_near(s.master, 1.0)
	for _i: int in range(3):
		s.step_volume(-1)
	assert_eq(s.volume_percent(), 70)
	for _i: int in range(20):
		s.step_volume(-1)
	assert_near(s.master, 0.0)


func test_save_player_skips_scripted_runs() -> void:
	assert_true(Flags.is_scripted_run())
	var before: bool = FileAccess.file_exists(TsSettings.PATH)
	var s := TsSettings.new()
	s.mark_seen("seller")
	s.save_player()
	assert_eq(FileAccess.file_exists(TsSettings.PATH), before, "player data untouched")


func test_menu_entries_hide_continue_without_a_save() -> void:
	var ids: Array[String] = []
	for e: Dictionary in TitleScreen.ts_entries(false, false):
		ids.append(str(e["id"]))
	assert_eq(ids, ["new", "settings", "quit"] as Array[String])
	ids.clear()
	for e: Dictionary in TitleScreen.ts_entries(true, false):
		ids.append(str(e["id"]))
	assert_eq(ids, ["continue", "new", "settings", "quit"] as Array[String])


func test_quit_is_hidden_on_the_web() -> void:
	var ids: Array[String] = []
	for e: Dictionary in TitleScreen.ts_entries(true, true):
		ids.append(str(e["id"]))
	assert_eq(ids, ["continue", "new", "settings"] as Array[String])


func test_title_keys_and_signals() -> void:
	var t := TitleScreen.new()
	t.settings = TsSettings.new()
	t.has_save = true
	t.web = false
	t.focus_id = "continue"
	var got: Array[String] = []
	t.continue_run.connect(func() -> void: got.append("continue"))
	t.start_new.connect(func() -> void: got.append("new"))
	t.quit.connect(func() -> void: got.append("quit"))
	t.ts_key(KEY_ENTER)
	t.ts_key(KEY_DOWN)
	assert_eq(t.focus_id, "new")
	t.ts_key(KEY_ENTER)
	t.ts_key(KEY_UP)
	t.ts_key(KEY_UP)
	assert_eq(t.focus_id, "quit", "focus wraps")
	t.ts_key(KEY_ENTER)
	assert_eq(got, ["continue", "new", "quit"] as Array[String])
	t.free()


func test_title_settings_panel_edits_and_closes() -> void:
	var t := TitleScreen.new()
	t.settings = TsSettings.new()
	t.web = false
	t.desktop = true
	t.focus_id = "settings"
	t.ts_key(KEY_ENTER)
	assert_true(t.settings_open)
	assert_eq(t.focus_id, "volume")
	t.ts_key(KEY_LEFT)
	assert_eq(t.settings.volume_percent(), 90)
	t.ts_key(KEY_RIGHT)
	t.ts_key(KEY_RIGHT)
	assert_eq(t.settings.volume_percent(), 100, "clamped")
	t.ts_key(KEY_DOWN)
	t.ts_key(KEY_ENTER)
	assert_true(t.settings.muted)
	t.ts_key(KEY_DOWN)
	t.ts_key(KEY_ENTER)
	assert_false(t.settings.dither)
	t.settings.mark_seen("seller")
	t.ts_activate("reset_hints")
	assert_true(t.settings.seen.is_empty())
	t.ts_key(KEY_ESCAPE)
	assert_false(t.settings_open)
	assert_eq(t.focus_id, "settings")
	t.free()


func test_fullscreen_row_is_desktop_only() -> void:
	assert_true(TsScreen.ts_settings_ids(true).has("fullscreen"))
	assert_false(TsScreen.ts_settings_ids(false).has("fullscreen"))


func test_pause_menu_choices() -> void:
	var p := PauseMenu.new()
	p.settings = TsSettings.new()
	p.pauses_tree = false
	assert_eq(p.ts_menu_ids(), ["resume", "settings", "quit_title"] as Array[String])
	var got: Array[String] = []
	p.resumed.connect(func() -> void: got.append("resumed"))
	p.quit_to_title.connect(func() -> void: got.append("quit_to_title"))
	p.focus_id = "resume"
	p.ts_key(KEY_ESCAPE)
	p.open()
	p.focus_id = "quit_title"
	p.ts_key(KEY_ENTER)
	assert_eq(got, ["resumed", "quit_to_title"] as Array[String])
	assert_false(p.is_open())
	p.free()


func test_scares_setting_round_trips_and_toggles_from_the_panel() -> void:
	var s := TsSettings.new()
	assert_true(s.scares_full, "full by default")
	s.scares_full = false
	var back := TsSettings.new()
	back.from_dict(s.to_dict())
	assert_false(back.scares_full)
	assert_eq(str(s.to_dict()["scares"]), "gentle")
	back.from_dict({"version": 1})
	assert_true(back.scares_full, "older files read as full")
	assert_true(TsScreen.ts_settings_ids(false).has("scares"))
	var t := TitleScreen.new()
	t.settings = TsSettings.new()
	t.web = false
	t.ts_open_settings()
	t.focus_id = "scares"
	t.ts_key(KEY_ENTER)
	assert_false(t.settings.scares_full)
	t.free()
