extends SceneTree
## Contact sheet of the test menu: its two pages, then one frame per tile (half size). Writes /tmp/shots/test_menu_sheet.png.
## xvfb-run -a godot --path . -s res://tests/shots/test_menu_sheet.gd -- --scripted

const OUT_PATH: String = "/tmp/shots/test_menu_sheet.png"
const CELL := Vector2i(320, 180)
const LABEL_H: int = 14
const COLS: int = 6
const SETTLE: int = 20

var _cells: Array[Image] = []
var _names: Array[String] = []
var _game: Node


func _initialize() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame


func _snap(label: String) -> void:
	await _frames(SETTLE)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	_cells.append(img)
	_names.append(label)


func _go() -> void:
	_game = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	await _frames(10)
	_game.open_test_menu()
	await _frames(20)
	await _snap("menu page 1")
	_game.test_menu.ts_activate_menu("page_next")
	await _snap("menu page 2")
	_game.test_menu.page = 0
	var tiles: Array = (load("res://game/ui/test_scenes.gd") as GDScript).call("tiles")
	for t: Dictionary in tiles:
		_game.run_test_tile(str(t["id"]))
		if str(t["label"]).begins_with("END") or str(t["label"]).begins_with("RUN END"):
			await _frames(90)  # ending cards fade in over 1.2 s (UiEndings); snap the settled card, not frame 0
		await _snap(str(t["label"]))
		_game.exit_test_tile()
		await _frames(2)
	await _extras()
	_save_sheet()


## Cells for the detail card and the settings tabs, drawn over a plain run.
func _extras() -> void:
	_game.leave_test_menu()
	_game._hud_view.visible = true
	_game.new_run(6006, {}, {"tutorial": true})
	_game.cards.clear()
	_game.hud.tutorial.clear()
	_game.activate("tool:uv")
	await _frames(6)
	_game.open_inspect(-1)
	await _snap("inspect card: counter object, tell found")
	_game.hud.inspect.close()
	_game.activate("buy")
	await _frames(4)
	_game.cards.clear()
	var held: Array = _game.run.inventory
	if not held.is_empty():
		_game.open_inspect(int(held[0]["uid"]))
		await _snap("inspect card: a held object")
		_game.hud.inspect.close()
	_game.free()
	await _frames(2)
	var t: Variant = (load("res://game/ui/title_screen.gd") as GDScript).new()
	t.settings = (load("res://game/ui/ts_settings.gd") as GDScript).new()
	t.test_on = true
	root.add_child(t)
	await _frames(3)
	t.canvas.t = 12.0
	await _snap("title with TEST MENU entry")
	t.ts_open_settings()
	for tab: String in ["audio", "display", "game", "keys"]:
		t.ts_activate("tab:" + tab)
		await _snap("settings: " + tab)


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
		lb.add_theme_font_size_override("font_size", 11)
		vp.add_child(lb)
	await _frames(3)
	var img: Image = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	img.save_png(OUT_PATH)
	print("SHEET %s %dx%d" % [OUT_PATH, img.get_width(), img.get_height()])
	quit()
