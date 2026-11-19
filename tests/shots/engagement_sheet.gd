extends SceneTree
## Contact sheet of the engagement round UI: the Haunting picker, the Omen draw dealing in and with a card turned up,
## the title with Daily Seance and "played today", the request board (a note pinning, a DONE stamp, a tearing note)
## with the omen/haunting badge tip, and the run end of a daily with "Haunting N unlocked" and Copy result.
## xvfb-run -a godot --path . -s res://tests/shots/engagement_sheet.gd -- --scripted
## Writes /tmp/shots/engagement_sheet.png. Never touches player data.

const OUT_PATH: String = "/tmp/shots/engagement_sheet.png"
const CELL := Vector2i(640, 360)
const LABEL_H: int = 16
const COLS: int = 3

var _cells: Array[Image] = []
var _names: Array[String] = []


func _initialize() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame


func _snap(label: String) -> void:
	await _frames(5)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_NEAREST)
	_cells.append(img)
	_names.append(label)
	print("CELL %s" % label)


func _make(path: String) -> Variant:
	return (load(path) as GDScript).new()


func _setup(ue: GDScript, unlocked: int, omens: Array[String]) -> Variant:
	var s: Variant = _make("res://game/ui/ui_run_setup.gd")
	s.settings = _make("res://game/ui/ts_settings.gd")
	s.unlocked = unlocked
	s.omen_ids = omens
	root.add_child(s)
	return s


func _go() -> void:
	var ue: GDScript = load("res://game/ui/ui_engage.gd") as GDScript
	var omens: Array[String] = ue.call("omen_offer", 7)
	var s1: Variant = _setup(ue, 4, omens)
	await _frames(3)
	s1.level = 3
	s1.canvas.t = 2.0
	s1._stage_t = 0.0
	await _snap("haunting picker, level 3 (stacked rules)")
	s1.free()
	await _frames(2)
	var s2: Variant = _setup(ue, 0, omens)
	await _frames(3)
	s2.canvas.t = 0.6
	await _snap("omen draw, cards dealing in face down")
	s2.canvas.t = 3.0
	s2.focus_id = "card1"
	s2.flips = [1.0, 1.0, 0.45] as Array[float]
	s2._seen = [true, true, false] as Array[bool]
	await _snap("omen draw: two read, one turning, focus lift")
	s2.free()
	await _frames(2)
	var t: Variant = _make("res://game/ui/title_screen.gd")
	t.settings = _make("res://game/ui/ts_settings.gd")
	t.daily_on = true
	t.daily_number = 12
	t.daily_line = "NIGHT 5, 412 COINS"
	root.add_child(t)
	await _frames(3)
	t.canvas.t = 12.0
	t.ts_key(KEY_DOWN)
	t.ts_key(KEY_DOWN)
	await _snap("title: Daily Seance #12, played today")
	t.free()
	await _frames(2)
	var game: Variant = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(20)
	game.new_run(3)
	await _frames(2)
	game.cards.clear()
	game.room.settle_visuals()
	ue.force_run_opts = {"haunting": 3, "omen": omens[0] if not omens.is_empty() else "", "daily": false}
	var b: Variant = game.hud.requests
	b.feed([{"e": "request_new", "id": "a", "who": "Mrs Pell", "want": {"category": "doll", "cursed": true}, "due": 3},
		{"e": "request_new", "id": "b", "who": "Old Voss", "want": {"category": "clock", "cursed": false}, "due": 2},
		{"e": "request_new", "id": "c", "who": "The Tall One", "want": {"category": "", "cursed": true}, "due": 4}] as Array[Dictionary])
	b.notes[0]["age"] = 2.0
	b.notes[1]["age"] = 2.0
	b.notes[2]["age"] = 0.18
	b.feed([{"e": "request_due", "id": "b"}, {"e": "request_done", "id": "b"}] as Array[Dictionary])
	b.notes[1]["fate_age"] = 0.6
	game.hover_id = "badge"
	game.hud._hov_age = 1.0
	await _snap("shop: request board (pin-in, DONE stamp), badge tip")
	game.hover_id = ""
	b.feed([{"e": "request_failed", "id": "a"}] as Array[Dictionary])
	b.notes[0]["fate_age"] = 0.6
	b.notes[1]["fate_age"] = 1.3
	await _snap("shop: a failed note tearing, badge")
	var bot := ShopBot.new(ShopBot.STYLES[0])
	game.new_run(3, {}, {"haunting": 0, "omen": "", "daily": true})
	while not game.run.is_over():
		game.act(bot.decide(game.run))
		game.room.settle_visuals()
	game.cards.clear()
	game.handle = "MORTIMER"
	game.unlocked_text = "HAUNTING 3 UNLOCKED"
	await _frames(3)
	game.hud._end_t = 3.0
	ue.force_run_opts = {"haunting": 2, "omen": "", "daily": true}
	await _snap("run end (daily): Haunting unlocked, Copy result")
	ue.force_run_opts = {}
	_save_sheet()


func _save_sheet() -> void:
	var rows: int = int(ceil(float(_cells.size()) / float(COLS)))
	var size := Vector2i(COLS * CELL.x, rows * (CELL.y + LABEL_H))
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.07)
	bg.size = Vector2(size)
	vp.add_child(bg)
	for i: int in range(_cells.size()):
		var x: int = (i % COLS) * CELL.x
		var y: int = (i / COLS) * (CELL.y + LABEL_H)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(_cells[i])
		tr.position = Vector2(x, y + LABEL_H)
		vp.add_child(tr)
		var lb := Label.new()
		lb.text = "%d. %s" % [i + 1, _names[i]]
		lb.position = Vector2(x + 4, y)
		lb.add_theme_font_size_override("font_size", 12)
		vp.add_child(lb)
	await _frames(3)
	var img: Image = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	img.save_png(OUT_PATH)
	print("SHEET %s %dx%d" % [OUT_PATH, img.get_width(), img.get_height()])
	quit()
