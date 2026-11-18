extends SceneTree
## Contact sheet of the title and pause UI: title (no save), title with Continue and the parcel line, pause menu,
## settings panel, and a hint shown over the shop. Writes /tmp/shots/title_sheet.png. Never touches player data.
## xvfb-run -a godot --path . --resolution 960x540 -s res://tests/shots/title_sheet.gd -- --scripted

const OUT_PATH: String = "/tmp/shots/title_sheet.png"
const CELL := Vector2i(480, 270)
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
	await _frames(6)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_NEAREST)
	_cells.append(img)
	_names.append(label)
	print("CELL %s" % label)


## Classes that name the Flags autoload are loaded at run time: a -s script cannot see autoloads at parse time.
func _make(path: String) -> Variant:
	return (load(path) as GDScript).new()


func _title(has_save: bool, parcel: bool) -> Variant:
	var t: Variant = _make("res://game/ui/title_screen.gd")
	t.settings = _make("res://game/ui/ts_settings.gd")
	t.has_save = has_save
	t.parcel = parcel
	root.add_child(t)
	return t


func _go() -> void:
	var t1: Variant = _title(false, false)
	await _frames(10)
	await _snap("title, no save")
	t1.free()
	await _frames(2)
	var t2: Variant = _title(true, true)
	await _frames(10)
	t2.ts_key(KEY_DOWN)
	await _snap("title, continue + parcel")
	t2.ts_open_settings()
	t2.settings.master = 0.7
	t2.settings.fullscreen = false
	t2.ts_key(KEY_DOWN)
	await _snap("settings panel")
	t2.free()
	await _frames(2)
	var game: Variant = (load("res://game/ui/shop_game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await _frames(10)
	var pause: Variant = _make("res://game/ui/pause_menu.gd")
	pause.settings = _make("res://game/ui/ts_settings.gd")
	pause.pauses_tree = false
	game.add_child(pause)
	await _frames(2)
	game.cards.clear()
	game.room.settle_visuals()
	var hints: Variant = (load("res://game/ui/ts_hint_tracker.gd") as GDScript).new(_make("res://game/ui/ts_settings.gd"))
	hints.refresh(game.run)
	await _frames(2)
	var hint_view := _HintDraw.new()
	hint_view.text = hints.text()
	hint_view.age = 1.0
	game.add_child(hint_view)
	await _snap("hint over the shop")
	hint_view.free()
	pause.open()
	pause.ts_key(KEY_DOWN)
	await _snap("pause menu")
	_save_sheet()


## Draws a hint at the top of the window the way the HUD would (same 480x270 grid, scaled to the window).
class _HintDraw extends Control:
	var text: String = ""
	var age: float = 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var s: float = minf(size.x / 480.0, size.y / 270.0)
		draw_set_transform((size - Vector2(480.0, 270.0) * s) * 0.5, 0.0, Vector2(s, s))
		TsHintFrame.ts_draw(self, text, age)


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
