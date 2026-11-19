extends TestCase
## Controller support: every screen can be driven by ui_* actions alone, and the shop screen's focus ring moves.


func tp_press(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func tp_root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_actions_map_to_keys() -> void:
	assert_eq(TsPad.key_for(tp_press("ui_down")), KEY_DOWN)
	assert_eq(TsPad.key_for(tp_press("ui_accept")), KEY_ENTER)
	assert_eq(TsPad.key_for(tp_press("ui_cancel")), KEY_ESCAPE)
	assert_eq(TsPad.key_for(tp_press("ui_focus_next")), 0)
	var k := InputEventKey.new()
	k.keycode = KEY_DOWN
	k.pressed = true
	assert_eq(TsPad.key_for(k), 0, "keys keep their own path")


func test_the_title_and_its_settings_by_actions_only() -> void:
	var t := TitleScreen.new()
	t.settings = TsSettings.new()
	t.test_on = true
	tp_root().add_child(t)
	t.canvas.t = 12.0
	var start: String = t.focus_id
	t._input(tp_press("ui_down"))
	assert_true(t.focus_id != start, "down moves focus")
	assert_true(TsPad.active, "a controller is in use")
	t.focus_id = "settings"
	t._input(tp_press("ui_accept"))
	assert_true(t.settings_open)
	t._input(tp_press("ui_down"))
	t._input(tp_press("ui_right"))
	assert_true(t.settings.sfx_volume <= 1.0)
	t._input(tp_press("ui_page_down"))
	assert_eq(t.settings_tab, "display")
	t._input(tp_press("ui_cancel"))
	assert_false(t.settings_open)
	t.free()


func test_pause_menu_by_actions_only() -> void:
	var p := PauseMenu.new()
	p.settings = TsSettings.new()
	p.pauses_tree = false
	tp_root().add_child(p)
	p.open()
	p._input(tp_press("ui_down"))
	assert_eq(p.focus_id, "grimoire")
	p._input(tp_press("ui_accept"))
	assert_true(p.grimoire_open)
	p._input(tp_press("ui_cancel"))
	assert_false(p.grimoire_open)
	p.free()


func test_altar_setup_and_test_menu_by_actions_only() -> void:
	var a := UiAltar.new()
	a.settings = TsSettings.new()
	tp_root().add_child(a)
	var first: String = a.focus_id
	a._input(tp_press("ui_right"))
	assert_true(a.focus_id != first)
	var closed: Array[bool] = []
	a.closed.connect(func() -> void: closed.append(true))
	a._input(tp_press("ui_cancel"))
	assert_eq(closed.size(), 1)
	a.free()
	var m := TestMenu.new()
	m.settings = TsSettings.new()
	tp_root().add_child(m)
	var f0: String = m.focus_id
	m._input(tp_press("ui_down"))
	assert_true(m.focus_id != f0)
	var picked: Array[String] = []
	m.picked.connect(func(id: String, _o: Dictionary) -> void: picked.append(id))
	m._input(tp_press("ui_accept"))
	assert_eq(picked.size(), 1)
	m.free()
	var s := UiRunSetup.new()
	s.settings = TsSettings.new()
	s.unlocked = 3
	s.omen_ids = UiEngage.omen_offer(5)
	tp_root().add_child(s)
	var s0: String = s.focus_id
	s._input(tp_press("ui_down"))
	assert_true(s.focus_id != s0 or s.ts_menu_ids().size() == 1)
	s.free()


func test_journal_host_by_actions_only() -> void:
	var h := TestJournalHost.new()
	h.settings = TsSettings.new()
	tp_root().add_child(h)
	var closed: Array[bool] = []
	h.closed.connect(func() -> void: closed.append(true))
	h._input(tp_press("ui_right"))
	h._input(tp_press("ui_cancel"))
	assert_eq(closed.size(), 1)
	h.free()


func test_shop_focus_ring_and_activation() -> void:
	var g: ShopGame = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate() as ShopGame
	tp_root().add_child(g)
	g.cards.clear()
	g.run.customer = {"kind": RunState.SELLER, "tools": [], "tells": [], "ask": 40, "reserve": 20, "patience": 3, "noise_u": 0.1, "imposter": false,
		"item": {"id": "hand_bell", "name": "Hand bell", "category": "instrument", "value": 10, "curse": ""}}
	g.hud.widgets.clear()
	g.hud.widgets.append({"id": "offer", "rect": Rect2(100.0, 276.0, 60.0, 20.0), "enabled": true})
	g.hud.widgets.append({"id": "buy", "rect": Rect2(170.0, 276.0, 60.0, 20.0), "enabled": true})
	g.hud.widgets.append({"id": "pass", "rect": Rect2(240.0, 276.0, 60.0, 20.0), "enabled": false})
	g._unhandled_input(tp_press("ui_right"))
	assert_eq(g.pad_focus, "offer", "the first move lands on the main button")
	g._unhandled_input(tp_press("ui_right"))
	assert_eq(g.pad_focus, "buy")
	g._unhandled_input(tp_press("ui_right"))
	assert_eq(g.pad_focus, "buy", "a disabled widget is skipped")
	g._unhandled_input(tp_press("ui_left"))
	assert_eq(g.pad_focus, "offer")
	var cash: int = g.run.cash
	g._unhandled_input(tp_press("ui_down"))
	assert_eq(g.pad_focus, "offer", "nothing below")
	assert_eq(g.run.cash, cash)
	g.queue_free()


func test_next_widget_geometry() -> void:
	var ws: Array[Dictionary] = [{"id": "a", "rect": Rect2(0, 0, 10, 10), "enabled": true}, {"id": "b", "rect": Rect2(30, 0, 10, 10), "enabled": true},
		{"id": "c", "rect": Rect2(0, 40, 10, 10), "enabled": true}]
	assert_eq(TsPad.next_widget(ws, "a", Vector2.RIGHT), "b")
	assert_eq(TsPad.next_widget(ws, "a", Vector2.DOWN), "c")
	assert_eq(TsPad.next_widget(ws, "a", Vector2.LEFT), "")
	assert_eq(TsPad.next_widget(ws, "", Vector2.RIGHT), "a")
