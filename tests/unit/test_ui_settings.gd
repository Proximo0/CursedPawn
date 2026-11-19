extends TestCase
## The complete settings: every row, persistence, defaults, key rebinding and the panel's tabs.

const TS_PATH: String = "user://test_ui_settings_file.json"


func test_every_row_has_a_value_and_steps() -> void:
	var s := TsSettings.new()
	for tab: String in TsScreen.TABS:
		for id: String in TsScreen.ts_tab_rows(tab, true):
			if id.begins_with("key:") or id == "reset_hints" or id == "diag":
				continue
			assert_true(s.value_text(id) != "", "value of " + id)
			assert_true(s.adjust(id, 1), "adjust " + id)
	assert_false(s.adjust("no_such_row", 1))


func test_sliders_clamp_and_snap() -> void:
	var s := TsSettings.new()
	s.adjust("sfx", -1)
	assert_near(s.sfx_volume, 0.9)
	for _i: int in range(20):
		s.adjust("music", -1)
	assert_near(s.music_volume, 0.0)
	for _i: int in range(10):
		s.adjust("shake", -1)
	assert_eq(s.shake, 0)
	s.adjust("shake", 1)
	assert_eq(s.shake, 25)
	s.adjust("text_speed", 1)
	assert_eq(s.text_speed, 2)
	assert_true(s.text_cps() > 70.0)
	s.adjust("text_size", 1)
	assert_eq(s.text_scale, 2)
	s.adjust("window", -1)
	assert_eq(s.window_scale, 3, "wraps")


func test_everything_persists_and_old_files_load() -> void:
	var a := TsSettings.new()
	a.sfx_volume = 0.4
	a.music_volume = 0.2
	a.shake = 50
	a.flash_reduce = true
	a.text_speed = 3
	a.text_scale = 2
	a.colorblind = true
	a.window_scale = 2
	a.keys = TsKeys.rebind({}, "buy", KEY_V)
	assert_eq(a.save(TS_PATH), OK)
	var b := TsSettings.new()
	assert_true(b.load_from(TS_PATH))
	assert_near(b.sfx_volume, 0.4)
	assert_near(b.music_volume, 0.2)
	assert_eq(b.shake, 50)
	assert_true(b.flash_reduce)
	assert_eq(b.text_speed, 3)
	assert_eq(b.text_scale, 2)
	assert_true(b.colorblind)
	assert_eq(b.window_scale, 2)
	assert_eq(int(b.keys["buy"]), KEY_V)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TS_PATH))
	var old := TsSettings.new()
	old.from_dict({"version": 1, "master": 0.5, "muted": true})
	assert_near(old.master, 0.5)
	assert_eq(old.shake, 100, "new settings default")
	assert_eq(old.keys, {})


func test_garbage_in_a_file_is_tamed() -> void:
	var s := TsSettings.new()
	s.from_dict({"shake": 900, "text_speed": -4, "text_scale": 9, "window_scale": 77, "sfx": "x", "keys": {"buy": KEY_ESCAPE, "nope": 5, "pass": "z"}})
	assert_eq(s.shake, 100)
	assert_eq(s.text_speed, 0)
	assert_eq(s.text_scale, 2)
	assert_eq(s.window_scale, 3)
	assert_eq(s.keys, {}, "reserved or unknown keys are dropped")


func test_reset_to_default_keeps_seen_hints() -> void:
	var s := TsSettings.new()
	s.shake = 10
	s.colorblind = true
	s.keys = TsKeys.rebind({}, "pass", KEY_X)
	s.mark_seen("seller")
	s.reset_defaults()
	assert_eq(s.shake, 100)
	assert_false(s.colorblind)
	assert_eq(s.keys, {})
	assert_true(s.has_seen("seller"))


func test_rebinding_swaps_and_frees_keys() -> void:
	var b: Dictionary = TsKeys.rebind({}, "buy", KEY_V)
	TsKeys.set_bindings(b)
	assert_eq(TsKeys.canonical(KEY_V), KEY_B, "V now means buy")
	assert_eq(TsKeys.canonical(KEY_B), 0, "B is free and does nothing")
	assert_eq(TsKeys.canonical(KEY_P), KEY_P, "others untouched")
	var swapped: Dictionary = TsKeys.rebind(b, "pass", KEY_V)
	assert_eq(int(swapped["buy"]), KEY_P, "the one that held V takes pass's old key")
	assert_eq(TsKeys.rebind({}, "buy", KEY_ESCAPE), {}, "reserved")
	assert_eq(TsKeys.rebind(b, "buy", KEY_B), {}, "back on the default stores nothing")
	TsKeys.set_bindings({})
	assert_eq(TsKeys.label_of("buy"), "B")


func test_rebound_key_drives_the_command() -> void:
	TsKeys.set_bindings(TsKeys.rebind({}, "buy", KEY_V))
	var run := RunState.new()
	run.start(3, Catalog.load_default(), Tuning.new())
	run.customer = {"kind": RunState.SELLER, "tools": [], "tells": [], "ask": 40}
	assert_eq(ShopGame.ui_key_command(TsKeys.canonical(KEY_V), run, 5, -1), {"t": "buy"})
	assert_eq(ShopGame.ui_key_command(TsKeys.canonical(KEY_B), run, 5, -1), {})
	TsKeys.set_bindings({})


func test_panel_tabs_and_rebinding_flow() -> void:
	var t := TitleScreen.new()
	t.settings = TsSettings.new()
	t.web = false
	t.ts_open_settings()
	assert_eq(t.settings_tab, "audio")
	t.ts_key(KEY_PAGEDOWN)
	assert_eq(t.settings_tab, "display")
	t.ts_activate("tab:keys")
	t.ts_activate("key:buy")
	assert_eq(t.rebinding, "buy")
	t.ts_key(KEY_V)
	assert_eq(t.rebinding, "")
	assert_eq(int(t.settings.keys["buy"]), KEY_V)
	t.ts_activate("key:buy")
	t.ts_key(KEY_ESCAPE)
	assert_eq(int(t.settings.keys["buy"]), KEY_V, "Esc cancels the rebind, not the binding")
	t.ts_activate("reset_all")
	assert_eq(t.settings.keys, {})
	for tab: String in TsScreen.TABS:
		for id: String in TsScreen.ts_tab_rows(tab, true):
			assert_true(t.ts_focus_ids().has(id) or tab != t.settings_tab, id)
	TsKeys.set_bindings({})
	t.free()


func test_big_text_draws_without_errors() -> void:
	var t := TitleScreen.new()
	t.settings = TsSettings.new()
	t.settings.text_scale = 2
	(Engine.get_main_loop() as SceneTree).root.add_child(t)
	t.canvas.t = 12.0
	t.canvas.queue_redraw()
	t.ts_open_settings()
	t.canvas.queue_redraw()
	assert_true(UiPixelFont.ui_width("DAILY SEANCE #12", 2) <= int(TitleScreen.BTN_W + 46.0) - 6, "the longest menu label fits at 2x")
	t.free()


func test_colourblind_hud_and_buyer_offer_draw() -> void:
	var g: ShopGame = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate() as ShopGame
	(Engine.get_main_loop() as SceneTree).root.add_child(g)
	g.test_begin(5)
	g.settings.colorblind = true
	g.run.dread = g.run.tuning.wake_threshold * 0.9
	TestScenes.build("buyer_offer", g, {})
	g.hud.queue_redraw()
	assert_true(ShopGame.buyer_offering(g.run))
	g.queue_free()
