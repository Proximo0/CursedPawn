extends SceneTree
## Renders every sprite on one labelled sheet: /tmp/shots/sprite_sheet.png
## Objects with their cursed overlays, customers (all idle frames), tools, cards, tiles and the horror props.
## xvfb-run -a godot --path . --resolution 1280x720 -s res://tests/shots/sprite_sheet.gd -- --scripted

const OUT_PATH: String = "/tmp/shots/sprite_sheet.png"
const SCALE: int = 2
const BG: Color = Color("3a2455")
const SHEET_W: int = 1320
const SHEET_H: int = 2400


func _initialize() -> void:
	var sheet: Image = Image.create_empty(SHEET_W, SHEET_H, false, Image.FORMAT_RGBA8)
	sheet.fill(BG)
	var y: int = 4
	var objs: Array = _load("res://game/data/objects.json")
	var col: int = 0
	for o: Dictionary in objs:
		var tex: Image = SpriteKit.object_texture(str(o["id"]), str(o["category"])).get_image()
		_put(sheet, tex, col * 132 + 4, y, str(o["id"]), SCALE)
		col += 1
		if col == 10:
			col = 0
			y += 88
	# the same objects again with the cursed overlay composited on top, at 3x for a good look
	y += 4
	col = 0
	for o: Dictionary in objs:
		var base: Image = SpriteKit.object_texture(str(o["id"]), str(o["category"])).get_image()
		base.blend_rect(SpriteKit.object_cursed_overlay(str(o["id"])).get_image(), Rect2i(Vector2i.ZERO, base.get_size()), Vector2i.ZERO)
		_put(sheet, base, col * 132 + 4, y, str(o["id"]), SCALE)
		col += 1
		if col == 10:
			col = 0
			y += 88
	y += 4
	var x: int = 4
	var row_h: int = 0
	var n: int = 0
	for c: Dictionary in _load("res://game/data/customers.json"):
		var tex: Image = SpriteKit.customer_texture(c).get_image()
		_put(sheet, tex, x, y, str(c["id"]), SCALE)
		x += 136
		row_h = maxi(row_h, tex.get_height() * SCALE + 14)
		n += 1
		if n == 9:
			n = 0
			x = 4
			y += row_h + 4
			row_h = 0
	y += row_h + 8
	# idle frames of a few types side by side at 2x
	x = 4
	row_h = 0
	for cid: String in ["widow", "haggler", "priest", "rival"]:
		for c: Dictionary in _load("res://game/data/customers.json"):
			if str(c["id"]) != cid:
				continue
			var fi: int = 0
			for f: ImageTexture in SpriteKit.customer_frames(c):
				_put(sheet, f.get_image(), x, y, cid.substr(0, 4) + str(fi), SCALE)
				x += 136
				row_h = maxi(row_h, f.get_height() * SCALE + 14)
				fi += 1
				if x > SHEET_W - 136:
					x = 4
					y += row_h + 4
					row_h = 0
	y += row_h + 8
	x = 4
	for t: String in ["uv", "scale", "listen", "touch"]:
		_put(sheet, SpriteKit.tool_texture(t).get_image(), x, y, t, SCALE)
		x += 100
	for nm: String in ["The Sun", "Wheel of Fortune", "The Fool", "Death", "The Tower"]:
		_put(sheet, SpriteKit.card_texture(nm, true).get_image(), x, y, nm.substr(0, 12), SCALE)
		x += 80
	_put(sheet, SpriteKit.card_texture("x", false).get_image(), x, y, "back", SCALE)
	y += 40 * SCALE + 18
	x = 4
	for k: String in ["wall", "floor", "shelf", "counter", "door"]:
		var tile: Image = SpriteKit.tile_texture(k).get_image()
		# tile 2x2 across so tiling seams show
		var big: Image = Image.create_empty(tile.get_width() * 2, tile.get_height() * 2, false, Image.FORMAT_RGBA8)
		for i: int in range(4):
			big.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i((i % 2) * tile.get_width(), (i / 2) * tile.get_height()))
		_put(sheet, big, x, y, k, SCALE)
		x += big.get_width() * SCALE + 16
	y += 96 * SCALE + 18
	x = 4
	for k: String in ["eyes", "portrait", "silhouette", "hand", "moth", "clock"]:
		var img: Image = SpriteKit.horror_texture(k).get_image()
		# on black, as the room shows them
		var bg: Image = Image.create_empty(img.get_width() + 8, img.get_height() + 8, false, Image.FORMAT_RGBA8)
		bg.fill(Color("0b0710"))
		bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(4, 4))
		_put(sheet, bg, x, y, k, SCALE)
		x += bg.get_width() * SCALE + 16
	y += 104 * SCALE + 18
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	sheet.get_region(Rect2i(0, 0, SHEET_W, mini(y, SHEET_H))).save_png(OUT_PATH)
	print("SPRITE SHEET ", OUT_PATH, " h=", y)
	quit()


func _load(path: String) -> Array:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) as Array


func _put(sheet: Image, tex: Image, x: int, y: int, label: String, scale: int) -> void:
	var big: Image = tex.duplicate()
	big.resize(tex.get_width() * scale, tex.get_height() * scale, Image.INTERPOLATE_NEAREST)
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
