extends SceneTree
## Renders every sprite at 2x on one labelled sheet: /tmp/shots/sprite_sheet.png
## xvfb-run -a godot --path . --resolution 1280x720 -s res://tests/shots/sprite_sheet.gd -- --scripted

const OUT_PATH: String = "/tmp/shots/sprite_sheet.png"
const SCALE: int = 2
const BG: Color = Color("3a2455")
const SHEET_W: int = 1320


func _initialize() -> void:
	var sheet: Image = Image.create_empty(SHEET_W, 1000, false, Image.FORMAT_RGBA8)
	sheet.fill(BG)
	var y: int = 4
	var objs: Array = _load("res://game/data/objects.json")
	var col: int = 0
	var row_h: int = 0
	for o: Dictionary in objs:
		var tex: Image = SpriteKit.object_texture(str(o["id"]), str(o["category"])).get_image()
		_put(sheet, tex, col * 132 + 4, y, str(o["id"]))
		col += 1
		if col == 10:
			col = 0
			y += 88
	y += 4
	var x: int = 4
	row_h = 0
	for c: Dictionary in _load("res://game/data/customers.json"):
		var tex: Image = SpriteKit.customer_texture(c).get_image()
		_put(sheet, tex, x, y, str(c["id"]))
		x += 108
		row_h = maxi(row_h, tex.get_height() * SCALE + 14)
	y += row_h + 8
	x = 4
	for t: String in ["uv", "scale", "listen", "touch"]:
		_put(sheet, SpriteKit.tool_texture(t).get_image(), x, y, t)
		x += 100
	for n: String in ["The Sun", "Wheel of Fortune", "The Fool", "Death", "The Tower"]:
		_put(sheet, SpriteKit.card_texture(n, true).get_image(), x, y, n.substr(0, 12))
		x += 80
	_put(sheet, SpriteKit.card_texture("x", false).get_image(), x, y, "back")
	y += 40 * SCALE + 18
	x = 4
	for k: String in ["wall", "floor", "shelf", "counter", "door"]:
		var tile: Image = SpriteKit.tile_texture(k).get_image()
		# tile twice across so tiling seams show
		_put(sheet, tile, x, y, k)
		_put(sheet, tile, x + tile.get_width() * SCALE, y, "")
		x += tile.get_width() * SCALE * 2 + 16
	y += 48 * SCALE + 18
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	sheet.get_region(Rect2i(0, 0, SHEET_W, mini(y, 1000))).save_png(OUT_PATH)
	print("SPRITE SHEET ", OUT_PATH)
	quit()


func _load(path: String) -> Array:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) as Array


func _put(sheet: Image, tex: Image, x: int, y: int, label: String) -> void:
	var big: Image = tex.duplicate()
	big.resize(tex.get_width() * SCALE, tex.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(x, y))
	var ly: int = y + big.get_height() + 2
	for i: int in range(label.length()):
		_glyph(sheet, label[i].to_upper(), x + i * 8, ly)


func _glyph(sheet: Image, ch: String, x: int, y: int) -> void:
	var rows: String = str(SpriteKit.SK_FONT.get(ch, ""))
	if rows.length() != 15:
		return
	for i: int in range(15):
		if rows[i] == "1":
			sheet.fill_rect(Rect2i(x + (i % 3) * 2, y + (i / 3) * 2, 2, 2), Color("f5efe0"))
