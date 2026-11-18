class_name SpriteKit
extends RefCounted
## Procedural pixel-art sprites for the 2D shop (docs/room2d_brief.md). Every pixel is one of the 16 RoomPalette
## colours (or transparent). Palette indices used below: 0 black, 1-4 purples dark to light, 5-7 greens,
## 8 dark wood, 9 wood, 10 amber, 11 candle yellow, 12 dark red, 13 red, 14 bone grey, 15 bone white.

const SK_OBJ: int = 32
const SK_FONT: Dictionary = {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
	"E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
	"I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
	"Q": "010101101111011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
	"U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111", "_": "000000000000111", " ": "000000000000000",
}

static var _sk_cols: PackedColorArray = PackedColorArray()


# ---------------------------------------------------------------- public API

static func object_texture(id: String, category: String) -> ImageTexture:
	var g: Image = _sk_new(SK_OBJ, SK_OBJ)
	match id:
		"music_box": _sk_o_music_box(g)
		"tin_soldier": _sk_o_tin_soldier(g)
		"porcelain_doll": _sk_o_porcelain_doll(g)
		"jack_in_box": _sk_o_jack_in_box(g)
		"rocking_horse": _sk_o_rocking_horse(g)
		"spinning_top": _sk_o_spinning_top(g)
		"marionette": _sk_o_marionette(g)
		"toy_theatre": _sk_o_toy_theatre(g)
		"silver_locket": _sk_o_silver_locket(g)
		"signet_ring": _sk_o_signet_ring(g)
		"pocket_watch": _sk_o_pocket_watch(g)
		"cameo_brooch": _sk_o_cameo_brooch(g)
		"mourning_ring": _sk_o_mourning_ring(g)
		"pearl_necklace": _sk_o_pearl_necklace(g)
		"hatpin": _sk_o_hatpin(g)
		"charm_bracelet": _sk_o_charm_bracelet(g)
		"violin": _sk_o_violin(g)
		"harmonica": _sk_o_harmonica(g)
		"hand_bell": _sk_o_hand_bell(g)
		"tuning_fork": _sk_o_tuning_fork(g)
		"accordion": _sk_o_accordion(g)
		"ocarina": _sk_o_ocarina(g)
		"metronome": _sk_o_metronome(g)
		"gramophone": _sk_o_gramophone(g)
		"ledger", "atlas", "diary", "hymnal", "almanac", "photo_album", "herbarium", "first_edition":
			_sk_o_book(g, id)
		"hand_mirror": _sk_o_hand_mirror(g)
		"candlestick": _sk_o_candlestick(g)
		"oil_portrait": _sk_o_oil_portrait(g)
		"brass_key": _sk_o_brass_key(g)
		"snow_globe": _sk_o_snow_globe(g)
		"taxidermy_owl": _sk_o_taxidermy_owl(g)
		"ship_bottle": _sk_o_ship_bottle(g)
		"mantel_clock": _sk_o_mantel_clock(g)
		_: _sk_o_fallback(g, category, id)
	return ImageTexture.create_from_image(g)


static func customer_texture(look: Dictionary) -> ImageTexture:
	var g: Image = _sk_new(48, 64)
	var cloak: int = _sk_snap(Color.from_string(str(look.get("cloak", "")), Color(0.14, 0.08, 0.22)))
	var eyes: int = _sk_snap(Color.from_string(str(look.get("eyes", "")), Color(0.9, 0.86, 0.75)))
	var cc: Color = _sk_pal()[cloak]
	var dark: int = _sk_snap(cc.lerp(Color.BLACK, 0.45))
	var light: int = _sk_snap(cc.lerp(Color.WHITE, 0.35))
	if light == cloak:
		light = _sk_snap(cc.lerp(Color.WHITE, 0.6))
	if light == cloak:
		light = 4
	var glow: int = _sk_snap(_sk_pal()[eyes].lerp(Color.BLACK, 0.6))
	# shoulders and body
	for y: int in range(34, 64):
		var hw: int = 11 + int(float(y - 34) * 10.0 / 29.0)
		_sk_r(g, 24 - hw, y, hw * 2 + 1, 1, cloak)
	# hood
	_sk_e(g, 24, 21, 12.0, 17.0, cloak)
	_sk_r(g, 14, 30, 21, 8, cloak)
	# cloak folds
	_sk_l(g, 16, 40, 12, 63, dark)
	_sk_l(g, 32, 40, 36, 63, dark)
	_sk_l(g, 24, 46, 24, 63, dark)
	_sk_r(g, 10, 62, 28, 2, dark)
	_sk_outline(g)
	# light rim along hood and shoulders
	_sk_e_ring(g, 24, 21, 12.0, 17.0, light, 0.18, -1.2)
	_sk_l(g, 14, 36, 4, 56, light)
	_sk_l(g, 34, 36, 44, 56, light)
	# the dark opening and eyes
	_sk_e(g, 24, 24, 8.0, 9.0, 0)
	_sk_r(g, 17, 22, 5, 3, glow)
	_sk_r(g, 26, 22, 5, 3, glow)
	_sk_r(g, 18, 23, 3, 2, eyes)
	_sk_r(g, 27, 23, 3, 2, eyes)
	_sk_p(g, 19, 23, 15)
	_sk_p(g, 28, 23, 15)
	var h: float = clampf(float(look.get("height", 1.0)), 0.7, 1.3)
	if not is_equal_approx(h, 1.0):
		g.resize(48, int(64.0 * h), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(g)


static func tool_texture(tool: String) -> ImageTexture:
	var g: Image = _sk_new(24, 24)
	match tool:
		"uv":
			_sk_r(g, 9, 1, 6, 6, 3)
			_sk_r(g, 9, 1, 1, 6, 4)
			_sk_r(g, 10, 3, 4, 1, 2)
			_sk_r(g, 10, 5, 4, 1, 2)
			for y: int in range(7, 12):
				_sk_r(g, 12 - (3 + (y - 7)), y, 2 * (3 + (y - 7)), 1, 3)
			_sk_r(g, 4, 12, 16, 2, 15)
			_sk_outline(g)
			for y: int in range(14, 23):
				var hw: int = 8 + (y - 14)
				for x: int in range(12 - hw, 12 + hw):
					if x >= 0 and x < 24 and (x + y) % 2 == 0:
						_sk_p(g, x, y, 4)
			_sk_r(g, 11, 14, 2, 9, 15)
			_sk_p(g, 6, 17, 15)
			_sk_p(g, 17, 19, 15)
			_sk_p(g, 3, 21, 15)
			_sk_p(g, 21, 15, 15)
		"scale":
			_sk_r(g, 11, 6, 3, 15, 11)
			_sk_r(g, 6, 20, 13, 3, 10)
			_sk_r(g, 2, 5, 21, 2, 11)
			_sk_e(g, 12, 5, 2.0, 2.0, 10)
			_sk_l(g, 3, 7, 1, 15, 14)
			_sk_l(g, 3, 7, 7, 15, 14)
			_sk_l(g, 21, 7, 17, 14, 14)
			_sk_l(g, 21, 7, 23, 14, 14)
			_sk_r(g, 1, 15, 7, 2, 11)
			_sk_r(g, 17, 14, 7, 2, 11)
			_sk_outline(g)
		"listen":
			for i: int in range(0, 16):
				var t: float = float(i) / 15.0
				var r: float = lerpf(6.0, 1.8, t)
				_sk_e(g, 7.0 + t * 11.0, 7.0 + t * 10.0, r, r, 10)
			_sk_r(g, 18, 16, 5, 4, 14)
			_sk_r(g, 21, 19, 2, 4, 14)
			_sk_outline(g)
			for i: int in range(0, 16):
				var t2: float = float(i) / 15.0
				var r2: float = lerpf(6.0, 1.8, t2)
				_sk_e(g, 6.0 + t2 * 11.0, 6.0 + t2 * 10.0, r2 - 1.5, r2 - 1.5, 11)
			_sk_e(g, 7, 7, 4.5, 4.5, 8)
			_sk_e(g, 8, 8, 2.5, 2.5, 0)
			_sk_r(g, 18, 16, 4, 1, 15)
			_sk_r(g, 21, 20, 1, 2, 15)
			_sk_p(g, 1, 12, 15)
			_sk_p(g, 2, 14, 15)
			_sk_p(g, 12, 1, 15)
			_sk_p(g, 14, 2, 15)
		"touch":
			_sk_r(g, 7, 11, 11, 9, 14)
			_sk_r(g, 8, 4, 2, 8, 14)
			_sk_r(g, 11, 2, 2, 10, 14)
			_sk_r(g, 14, 3, 2, 9, 14)
			_sk_r(g, 17, 5, 2, 7, 14)
			_sk_r(g, 4, 12, 4, 4, 14)
			_sk_r(g, 6, 19, 12, 4, 12)
			_sk_outline(g)
			_sk_l(g, 10, 5, 10, 11, 4)
			_sk_l(g, 13, 3, 13, 11, 4)
			_sk_l(g, 16, 4, 16, 11, 4)
			_sk_r(g, 6, 19, 12, 1, 13)
			_sk_r(g, 8, 13, 2, 1, 15)
		_:
			_sk_r(g, 6, 6, 12, 12, 4)
			_sk_outline(g)
	return ImageTexture.create_from_image(g)


static func card_texture(card_name: String, face_up: bool) -> ImageTexture:
	var g: Image = _sk_new(24, 40)
	if not face_up:
		_sk_r(g, 1, 1, 22, 38, 11)
		_sk_r(g, 3, 3, 18, 34, 12)
		for y: int in range(4, 36):
			for x: int in range(4, 20):
				if (x + y) % 6 == 0 or (x - y + 60) % 6 == 0:
					_sk_p(g, x, y, 13)
		_sk_e(g, 12, 20, 6.0, 4.0, 11)
		_sk_e(g, 12, 20, 4.0, 2.0, 15)
		_sk_e(g, 12, 20, 1.0, 1.0, 0)
		_sk_p(g, 12, 13, 11)
		_sk_p(g, 12, 27, 11)
		_sk_outline(g)
		return ImageTexture.create_from_image(g)
	_sk_r(g, 1, 1, 22, 38, 11)
	_sk_r(g, 3, 3, 18, 34, 15)
	_sk_r(g, 3, 3, 18, 1, 14)
	var key: String = card_name.to_lower()
	var initial: String = card_name.strip_edges().substr(0, 1).to_upper()
	if key.begins_with("the "):
		initial = key.substr(4, 1).to_upper()
	_sk_glyph(g, initial, 9, 5, 2, 12)
	_sk_r(g, 5, 17, 14, 1, 14)
	var cx: int = 12
	var cy: int = 27
	if key.contains("sun"):
		_sk_e(g, cx, cy, 4.0, 4.0, 10)
		for a: int in range(8):
			var v: Vector2 = Vector2.from_angle(float(a) * PI / 4.0)
			_sk_l(g, cx + int(v.x * 6.0), cy + int(v.y * 6.0), cx + int(v.x * 8.0), cy + int(v.y * 8.0), 10)
		_sk_p(g, cx - 1, cy - 1, 11)
	elif key.contains("wheel"):
		_sk_e(g, cx, cy, 7.0, 7.0, 12)
		_sk_e(g, cx, cy, 5.0, 5.0, 15)
		_sk_l(g, cx - 6, cy, cx + 6, cy, 12)
		_sk_l(g, cx, cy - 6, cx, cy + 6, 12)
		_sk_l(g, cx - 4, cy - 4, cx + 4, cy + 4, 12)
		_sk_l(g, cx - 4, cy + 4, cx + 4, cy - 4, 12)
		_sk_e(g, cx, cy, 1.0, 1.0, 10)
	elif key.contains("fool"):
		_sk_r(g, 5, 33, 14, 3, 9)
		_sk_r(g, 10, 24, 4, 8, 3)
		_sk_e(g, cx, 22, 2.0, 2.0, 14)
		_sk_r(g, 9, 19, 6, 2, 13)
		_sk_l(g, 15, 24, 18, 30, 9)
		_sk_e(g, 18, 31, 2.0, 2.0, 4)
	elif key.contains("death"):
		_sk_e(g, cx, cy - 2, 6.0, 6.0, 14)
		_sk_r(g, cx - 4, cy + 2, 9, 5, 14)
		_sk_r(g, cx - 4, cy - 3, 3, 3, 0)
		_sk_r(g, cx + 2, cy - 3, 3, 3, 0)
		_sk_p(g, cx, cy, 0)
		for i: int in range(3):
			_sk_p(g, cx - 3 + i * 3, cy + 5, 0)
	elif key.contains("tower"):
		_sk_r(g, 9, 20, 7, 15, 8)
		_sk_r(g, 8, 18, 9, 3, 9)
		_sk_p(g, 8, 17, 9)
		_sk_p(g, 11, 17, 9)
		_sk_p(g, 14, 17, 9)
		_sk_r(g, 11, 26, 2, 3, 0)
		_sk_l(g, 19, 19, 16, 25, 11)
		_sk_l(g, 16, 25, 20, 26, 11)
		_sk_l(g, 20, 26, 15, 32, 11)
	else:
		_sk_e(g, cx, cy, 6.0, 6.0, 4)
		_sk_e(g, cx + 3, cy - 1, 5.0, 5.0, 15)
	_sk_r(g, 8, 36, 8, 1, 14)
	_sk_outline(g)
	return ImageTexture.create_from_image(g)


static func tile_texture(kind: String) -> ImageTexture:
	var g: Image
	match kind:
		"wall":
			g = _sk_new(32, 32)
			for x: int in range(32):
				var m: int = x % 16
				var c: int = 3 if m < 8 else 1
				_sk_r(g, x, 0, 1, 32, c)
			for x: int in [0, 16]:
				_sk_r(g, x, 0, 1, 32, 4)
			# small damask diamonds on the light stripes
			for y: int in [6, 22]:
				var dy: int = y
				_sk_p(g, 4, dy, 4)
				_sk_p(g, 3, dy + 1, 4)
				_sk_p(g, 5, dy + 1, 4)
				_sk_p(g, 4, dy + 2, 4)
				_sk_p(g, 20, dy + 8, 4)
				_sk_p(g, 19, dy + 9, 4)
				_sk_p(g, 21, dy + 9, 4)
				_sk_p(g, 20, dy + 10, 4)
		"floor":
			g = _sk_new(32, 32)
			for row: int in range(4):
				var y: int = row * 8
				var base: int = 9 if row % 2 == 0 else 8
				_sk_r(g, 0, y, 32, 8, base)
				_sk_r(g, 0, y, 32, 1, 10 if base == 9 else 9)
				_sk_r(g, 0, y + 7, 32, 1, 0)
				var joint: int = (row * 13 + 5) % 32
				_sk_r(g, joint, y, 1, 8, 0)
				_sk_p(g, (joint + 9) % 32, y + 3, 8 if base == 9 else 0)
				_sk_p(g, (joint + 10) % 32, y + 4, 8 if base == 9 else 0)
				_sk_p(g, (joint + 20) % 32, y + 5, 8 if base == 9 else 1)
		"shelf":
			g = _sk_new(16, 16)
			_sk_r(g, 0, 0, 16, 1, 11)
			_sk_r(g, 0, 1, 16, 6, 9)
			_sk_r(g, 0, 7, 16, 1, 8)
			_sk_r(g, 0, 8, 16, 1, 0)
			_sk_r(g, 0, 9, 16, 1, 1)
			for x: int in [2, 3, 4, 9, 10, 13]:
				_sk_p(g, x, 3 if x < 8 else 5, 8)
			_sk_p(g, 6, 2, 10)
			_sk_p(g, 12, 4, 10)
		"counter":
			g = _sk_new(32, 32)
			_sk_r(g, 0, 0, 32, 3, 10)
			_sk_r(g, 0, 3, 32, 1, 11)
			_sk_r(g, 0, 3, 32, 1, 9)
			_sk_r(g, 0, 4, 32, 2, 0)
			_sk_r(g, 0, 6, 32, 26, 8)
			for px: int in [1, 17]:
				_sk_r(g, px, 8, 14, 21, 9)
				_sk_r(g, px + 2, 10, 10, 17, 8)
				_sk_r(g, px + 2, 10, 10, 1, 1)
				_sk_r(g, px, 8, 14, 1, 10)
			_sk_r(g, 0, 29, 32, 3, 1)
			_sk_r(g, 0, 6, 1, 26, 0)
			_sk_r(g, 16, 6, 1, 26, 0)
		"door":
			g = _sk_new(32, 48)
			_sk_r(g, 0, 0, 32, 48, 0)
			_sk_r(g, 1, 1, 30, 47, 8)
			for x: int in range(2, 30, 7):
				_sk_r(g, x, 2, 6, 46, 9)
				_sk_r(g, x, 2, 1, 46, 10)
				_sk_r(g, x + 6, 2, 1, 46, 0)
			for y: int in [8, 36]:
				_sk_r(g, 1, y, 30, 3, 1)
				_sk_r(g, 1, y, 30, 1, 2)
				for x: int in range(4, 30, 8):
					_sk_p(g, x, y + 1, 14)
			_sk_e(g, 25, 24, 2.0, 2.0, 11)
			_sk_p(g, 24, 23, 15)
			_sk_r(g, 24, 28, 3, 2, 10)
		_:
			g = _sk_new(16, 16)
			_sk_r(g, 0, 0, 16, 16, 2)
			_sk_r(g, 0, 0, 16, 1, 4)
	return ImageTexture.create_from_image(g)


# ---------------------------------------------------------------- primitives

static func _sk_pal() -> PackedColorArray:
	if _sk_cols.is_empty():
		_sk_cols = RoomPalette.colors()
	return _sk_cols


static func _sk_col(c: int) -> Color:
	if c < 0:
		return Color(0, 0, 0, 0)
	return _sk_pal()[c]


static func _sk_new(w: int, h: int) -> Image:
	var g: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	g.fill(Color(0, 0, 0, 0))
	return g


## Index of the nearest palette colour (perceptual-ish weights).
static func _sk_snap(c: Color) -> int:
	var best: int = 0
	var best_d: float = 1000.0
	var pal: PackedColorArray = _sk_pal()
	for i: int in range(pal.size()):
		var dr: float = (c.r - pal[i].r) * 0.30
		var dg: float = (c.g - pal[i].g) * 0.59
		var db: float = (c.b - pal[i].b) * 0.11
		var d: float = dr * dr + dg * dg + db * db
		if d < best_d:
			best_d = d
			best = i
	return best


static func _sk_p(g: Image, x: int, y: int, c: int) -> void:
	if x >= 0 and y >= 0 and x < g.get_width() and y < g.get_height():
		g.set_pixel(x, y, _sk_col(c))


static func _sk_r(g: Image, x: int, y: int, w: int, h: int, c: int) -> void:
	var col: Color = _sk_col(c)
	for yy: int in range(maxi(y, 0), mini(y + h, g.get_height())):
		for xx: int in range(maxi(x, 0), mini(x + w, g.get_width())):
			g.set_pixel(xx, yy, col)


static func _sk_e(g: Image, cx: float, cy: float, rx: float, ry: float, c: int) -> void:
	var x0: int = int(floorf(cx - rx))
	var x1: int = int(ceilf(cx + rx))
	var y0: int = int(floorf(cy - ry))
	var y1: int = int(ceilf(cy + ry))
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var dx: float = (float(x) - cx) / (rx + 0.3)
			var dy: float = (float(y) - cy) / (ry + 0.3)
			if dx * dx + dy * dy <= 1.0:
				_sk_p(g, x, y, c)


## Ellipse ring: draws pixels between radius (1 - thick) and 1 of the ellipse, offset shifts the rim inwards.
static func _sk_e_ring(g: Image, cx: float, cy: float, rx: float, ry: float, c: int, thick: float, shift: float) -> void:
	var x0: int = int(floorf(cx - rx - 2.0))
	var x1: int = int(ceilf(cx + rx + 2.0))
	var y0: int = int(floorf(cy - ry - 2.0))
	var y1: int = int(ceilf(cy + ry + 2.0))
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var dx: float = (float(x) - cx) / (rx + shift)
			var dy: float = (float(y) - cy) / (ry + shift)
			var d: float = dx * dx + dy * dy
			if d <= 1.0 and d >= (1.0 - thick) * (1.0 - thick) and y < int(cy) + 8:
				if g.get_pixel(x, y).a > 0.0:
					_sk_p(g, x, y, c)


static func _sk_ring(g: Image, cx: float, cy: float, rx: float, ry: float, t: float, c: int) -> void:
	_sk_e(g, cx, cy, rx, ry, c)
	_sk_e(g, cx, cy, rx - t, ry - t, -1)


static func _sk_l(g: Image, x0: int, y0: int, x1: int, y1: int, c: int) -> void:
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var x: int = x0
	var y: int = y0
	for _i: int in range(512):
		_sk_p(g, x, y, c)
		if x == x1 and y == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


## 1 px outline in the darkest colour around every opaque pixel.
static func _sk_outline(g: Image) -> void:
	var src: Image = g.duplicate()
	var w: int = g.get_width()
	var h: int = g.get_height()
	var col: Color = _sk_col(0)
	for y: int in range(h):
		for x: int in range(w):
			if src.get_pixel(x, y).a > 0.0:
				continue
			var near: bool = false
			if x > 0 and src.get_pixel(x - 1, y).a > 0.0:
				near = true
			elif x < w - 1 and src.get_pixel(x + 1, y).a > 0.0:
				near = true
			elif y > 0 and src.get_pixel(x, y - 1).a > 0.0:
				near = true
			elif y < h - 1 and src.get_pixel(x, y + 1).a > 0.0:
				near = true
			if near:
				g.set_pixel(x, y, col)


static func _sk_glyph(g: Image, ch: String, x: int, y: int, scale: int, c: int) -> void:
	var rows: String = str(SK_FONT.get(ch, ""))
	if rows.length() != 15:
		return
	for i: int in range(15):
		if rows[i] == "1":
			_sk_r(g, x + (i % 3) * scale, y + (i / 3) * scale, scale, scale, c)


# ---------------------------------------------------------------- objects: toys

static func _sk_o_music_box(g: Image) -> void:
	_sk_r(g, 4, 18, 24, 11, 9)
	_sk_r(g, 4, 18, 24, 2, 10)
	_sk_r(g, 4, 27, 24, 2, 8)
	_sk_r(g, 5, 9, 22, 8, 8)
	_sk_r(g, 5, 9, 22, 1, 9)
	_sk_r(g, 8, 11, 16, 5, 11)
	_sk_r(g, 8, 11, 16, 1, 15)
	_sk_l(g, 27, 24, 30, 24, 11)
	_sk_r(g, 29, 22, 2, 4, 10)
	_sk_r(g, 14, 22, 4, 3, 11)
	_sk_p(g, 15, 23, 0)
	_sk_outline(g)
	for x: int in range(9, 24, 2):
		_sk_p(g, x, 13, 10)


static func _sk_o_tin_soldier(g: Image) -> void:
	_sk_r(g, 8, 28, 16, 2, 9)
	_sk_r(g, 12, 2, 8, 6, 12)
	_sk_r(g, 12, 2, 8, 1, 13)
	_sk_p(g, 16, 1, 15)
	_sk_r(g, 13, 8, 6, 5, 14)
	_sk_r(g, 11, 13, 10, 9, 13)
	_sk_r(g, 9, 14, 2, 8, 13)
	_sk_r(g, 21, 14, 2, 8, 13)
	_sk_r(g, 12, 22, 3, 6, 3)
	_sk_r(g, 17, 22, 3, 6, 3)
	_sk_r(g, 25, 8, 1, 20, 9)
	_sk_r(g, 25, 4, 1, 4, 14)
	_sk_outline(g)
	_sk_p(g, 15, 10, 0)
	_sk_p(g, 17, 10, 0)
	_sk_p(g, 16, 15, 11)
	_sk_p(g, 16, 18, 11)
	_sk_r(g, 11, 20, 10, 1, 1)


static func _sk_o_porcelain_doll(g: Image) -> void:
	_sk_e(g, 16, 9, 6.0, 6.0, 15)
	_sk_r(g, 9, 3, 14, 4, 8)
	_sk_r(g, 9, 5, 3, 9, 8)
	_sk_r(g, 20, 5, 3, 9, 8)
	for y: int in range(15, 30):
		var hw: int = 4 + (y - 15) * 8 / 15
		_sk_r(g, 16 - hw, y, hw * 2, 1, 14)
	_sk_r(g, 12, 15, 8, 4, 13)
	_sk_r(g, 8, 17, 3, 6, 15)
	_sk_r(g, 21, 17, 3, 6, 15)
	_sk_outline(g)
	_sk_p(g, 13, 9, 0)
	_sk_p(g, 19, 9, 0)
	_sk_p(g, 16, 11, 13)
	_sk_p(g, 12, 11, 13)
	_sk_p(g, 20, 11, 13)
	_sk_r(g, 10, 27, 12, 1, 4)
	_sk_l(g, 13, 18, 11, 28, 4)
	_sk_l(g, 19, 18, 21, 28, 4)


static func _sk_o_jack_in_box(g: Image) -> void:
	_sk_r(g, 6, 19, 20, 10, 13)
	_sk_r(g, 6, 19, 20, 2, 12)
	_sk_r(g, 6, 24, 20, 1, 11)
	_sk_r(g, 15, 19, 2, 10, 11)
	_sk_r(g, 5, 17, 5, 2, 9)
	_sk_l(g, 16, 18, 12, 16, 14)
	_sk_l(g, 12, 16, 20, 14, 14)
	_sk_l(g, 20, 14, 12, 12, 14)
	_sk_e(g, 16, 8, 5.0, 5.0, 15)
	_sk_r(g, 11, 1, 10, 3, 3)
	_sk_p(g, 16, 0, 11)
	_sk_outline(g)
	_sk_r(g, 13, 7, 2, 1, 0)
	_sk_r(g, 17, 7, 2, 1, 0)
	_sk_r(g, 15, 9, 2, 2, 13)
	_sk_r(g, 13, 11, 6, 1, 12)


static func _sk_o_rocking_horse(g: Image) -> void:
	_sk_r(g, 3, 28, 26, 2, 9)
	_sk_r(g, 2, 26, 2, 2, 9)
	_sk_r(g, 28, 26, 2, 2, 9)
	_sk_r(g, 8, 14, 14, 6, 14)
	_sk_r(g, 8, 14, 14, 1, 15)
	_sk_l(g, 10, 20, 7, 28, 9)
	_sk_l(g, 11, 20, 10, 28, 9)
	_sk_l(g, 19, 20, 22, 28, 9)
	_sk_l(g, 20, 20, 25, 28, 9)
	_sk_r(g, 20, 8, 4, 8, 14)
	_sk_r(g, 22, 6, 7, 5, 14)
	_sk_r(g, 8, 9, 14, 5, 13)
	_sk_r(g, 5, 14, 3, 6, 8)
	_sk_r(g, 19, 6, 3, 8, 8)
	_sk_outline(g)
	_sk_p(g, 25, 8, 0)
	_sk_r(g, 10, 11, 6, 1, 11)


static func _sk_o_spinning_top(g: Image) -> void:
	_sk_r(g, 14, 2, 4, 6, 10)
	_sk_r(g, 13, 1, 6, 2, 11)
	for y: int in range(8, 29):
		var hw: int = 0
		if y < 15:
			hw = 5 + (y - 8) * 6 / 6
		else:
			hw = 11 - (y - 15) * 11 / 14
		var c: int = 13 if ((y - 8) / 3) % 2 == 0 else 14
		_sk_r(g, 16 - hw, y, hw * 2, 1, c)
	_sk_r(g, 15, 28, 2, 3, 4)
	_sk_outline(g)
	_sk_r(g, 8, 10, 2, 4, 15)
	_sk_r(g, 11, 16, 1, 3, 15)
	_sk_r(g, 15, 3, 1, 4, 11)
	_sk_l(g, 27, 10, 29, 14, 4)
	_sk_l(g, 29, 14, 27, 18, 4)
	_sk_l(g, 4, 10, 2, 14, 4)
	_sk_l(g, 2, 14, 4, 18, 4)
	_sk_r(g, 9, 31, 14, 1, 2)


static func _sk_o_marionette(g: Image) -> void:
	_sk_r(g, 3, 1, 26, 2, 9)
	_sk_r(g, 14, 3, 4, 2, 9)
	_sk_p(g, 3, 1, 11)
	_sk_p(g, 28, 1, 11)
	for i: int in range(5):
		_sk_r(g, 13 + i, 6 - i, 6 - i * 2 if i < 3 else 1, 1, 13)
	_sk_e(g, 16, 10, 4.0, 4.0, 14)
	_sk_r(g, 11, 14, 10, 8, 13)
	_sk_r(g, 11, 14, 10, 1, 11)
	_sk_l(g, 11, 15, 6, 21, 13)
	_sk_l(g, 12, 15, 7, 21, 13)
	_sk_l(g, 20, 15, 25, 21, 13)
	_sk_l(g, 19, 15, 24, 21, 13)
	_sk_r(g, 5, 21, 3, 3, 14)
	_sk_r(g, 24, 21, 3, 3, 14)
	_sk_r(g, 11, 22, 4, 8, 3)
	_sk_r(g, 17, 22, 4, 4, 3)
	_sk_r(g, 20, 25, 4, 4, 3)
	_sk_r(g, 9, 29, 7, 2, 9)
	_sk_r(g, 22, 28, 5, 2, 9)
	_sk_outline(g)
	_sk_p(g, 14, 10, 0)
	_sk_p(g, 18, 10, 0)
	_sk_p(g, 13, 12, 13)
	_sk_p(g, 19, 12, 13)
	_sk_p(g, 16, 17, 11)
	_sk_p(g, 16, 19, 11)
	_sk_l(g, 4, 3, 6, 21, 15)
	_sk_l(g, 27, 3, 25, 21, 15)
	_sk_l(g, 8, 3, 12, 24, 15)
	_sk_l(g, 24, 3, 22, 25, 15)


static func _sk_o_toy_theatre(g: Image) -> void:
	_sk_r(g, 3, 6, 26, 3, 11)
	_sk_r(g, 5, 3, 22, 3, 10)
	_sk_r(g, 3, 9, 26, 20, 12)
	_sk_r(g, 8, 11, 16, 14, 1)
	_sk_r(g, 8, 25, 16, 3, 9)
	_sk_r(g, 3, 9, 6, 18, 13)
	_sk_r(g, 23, 9, 6, 18, 13)
	_sk_outline(g)
	_sk_l(g, 8, 11, 8, 24, 12)
	_sk_l(g, 23, 11, 23, 24, 12)
	_sk_r(g, 15, 17, 2, 7, 14)
	_sk_e(g, 16, 15, 1.0, 1.0, 14)
	_sk_p(g, 14, 12, 11)
	_sk_p(g, 18, 12, 11)


# ---------------------------------------------------------------- objects: jewelry

static func _sk_o_silver_locket(g: Image) -> void:
	_sk_ring(g, 16.0, 8.0, 7.0, 7.0, 1.0, 14)
	_sk_e(g, 12, 20, 5.0, 5.0, 14)
	_sk_e(g, 20, 20, 5.0, 5.0, 14)
	for y: int in range(22, 30):
		var hw: int = 9 - (y - 22) * 9 / 8
		_sk_r(g, 16 - hw, y, hw * 2, 1, 14)
	_sk_outline(g)
	_sk_p(g, 10, 18, 15)
	_sk_p(g, 11, 17, 15)
	_sk_p(g, 11, 19, 15)
	_sk_r(g, 15, 20, 3, 3, 13)
	_sk_p(g, 15, 20, 15)


static func _sk_o_signet_ring(g: Image) -> void:
	_sk_ring(g, 16.0, 20.0, 9.0, 9.0, 3.0, 11)
	_sk_r(g, 11, 5, 10, 8, 11)
	_sk_r(g, 13, 7, 6, 4, 13)
	_sk_outline(g)
	_sk_p(g, 13, 7, 15)
	_sk_p(g, 14, 7, 15)
	_sk_l(g, 9, 23, 10, 26, 10)
	_sk_l(g, 23, 23, 22, 26, 10)
	_sk_p(g, 8, 18, 15)


static func _sk_o_pocket_watch(g: Image) -> void:
	_sk_r(g, 14, 1, 4, 4, 11)
	_sk_ring(g, 16.0, 3.0, 4.0, 3.0, 1.0, 11)
	_sk_e(g, 16, 18, 11.0, 11.0, 11)
	_sk_e(g, 16, 18, 8.0, 8.0, 15)
	_sk_outline(g)
	_sk_p(g, 16, 11, 0)
	_sk_p(g, 16, 25, 0)
	_sk_p(g, 9, 18, 0)
	_sk_p(g, 23, 18, 0)
	_sk_l(g, 16, 18, 16, 13, 0)
	_sk_l(g, 16, 18, 20, 20, 12)
	_sk_p(g, 16, 18, 0)
	_sk_p(g, 8, 12, 15)
	_sk_p(g, 7, 14, 15)


static func _sk_o_cameo_brooch(g: Image) -> void:
	_sk_e(g, 16, 16, 12.0, 14.0, 11)
	_sk_e(g, 16, 16, 9.0, 11.0, 3)
	_sk_outline(g)
	_sk_e(g, 15, 12, 3.0, 4.0, 15)
	_sk_p(g, 19, 12, 15)
	_sk_p(g, 19, 13, 15)
	_sk_r(g, 11, 17, 10, 5, 15)
	_sk_r(g, 11, 22, 10, 1, 3)
	_sk_r(g, 12, 7, 6, 2, 8)
	for a: int in range(12):
		var v: Vector2 = Vector2.from_angle(float(a) * TAU / 12.0)
		_sk_p(g, 16 + int(v.x * 11.0), 16 + int(v.y * 13.0), 15)


static func _sk_o_mourning_ring(g: Image) -> void:
	_sk_ring(g, 16.0, 21.0, 10.0, 9.0, 3.0, 10)
	_sk_e(g, 16, 9, 7.0, 6.0, 11)
	_sk_e(g, 16, 9, 5.0, 4.0, 1)
	_sk_outline(g)
	_sk_r(g, 15, 7, 3, 1, 15)
	_sk_p(g, 15, 8, 15)
	_sk_p(g, 17, 8, 15)
	_sk_r(g, 15, 9, 3, 1, 15)
	_sk_p(g, 16, 8, 0)
	_sk_p(g, 11, 9, 14)
	_sk_p(g, 21, 9, 14)
	_sk_p(g, 16, 3, 14)
	_sk_p(g, 16, 15, 14)
	_sk_l(g, 8, 21, 9, 26, 11)
	_sk_l(g, 7, 17, 6, 20, 11)


static func _sk_o_pearl_necklace(g: Image) -> void:
	for i: int in range(0, 9):
		var t: float = float(i) / 8.0
		var x: int = 4 + int(t * 24.0)
		var y: int = 5 + int(sin(t * PI) * 18.0)
		_sk_e(g, x, y, 2.0, 2.0, 15)
	for i: int in range(0, 9):
		var t: float = (float(i) + 0.5) / 8.0
		if i < 8:
			_sk_e(g, 4 + int(t * 24.0), 5 + int(sin(t * PI) * 18.0), 1.0, 1.0, 14)
	_sk_r(g, 14, 25, 5, 4, 11)
	_sk_outline(g)
	_sk_p(g, 16, 26, 13)


static func _sk_o_hatpin(g: Image) -> void:
	_sk_l(g, 3, 29, 22, 10, 14)
	_sk_l(g, 4, 29, 22, 11, 15)
	_sk_e(g, 25, 7, 4.0, 4.0, 13)
	_sk_l(g, 20, 12, 23, 9, 11)
	_sk_l(g, 21, 13, 24, 10, 11)
	_sk_outline(g)
	_sk_p(g, 24, 5, 15)
	_sk_p(g, 25, 5, 15)
	_sk_p(g, 27, 9, 12)


static func _sk_o_charm_bracelet(g: Image) -> void:
	_sk_ring(g, 16.0, 11.0, 14.0, 10.0, 2.0, 14)
	for a: int in range(0, 48, 3):
		var v: Vector2 = Vector2.from_angle(float(a) * TAU / 48.0)
		_sk_p(g, 16 + int(v.x * 13.0), 11 + int(v.y * 9.0), 15)
	_sk_r(g, 8, 20, 5, 1, 14)
	# heart
	_sk_r(g, 6, 22, 2, 1, 13)
	_sk_r(g, 9, 22, 2, 1, 13)
	_sk_r(g, 5, 23, 7, 2, 13)
	_sk_r(g, 6, 25, 5, 1, 13)
	_sk_r(g, 7, 26, 3, 1, 13)
	_sk_p(g, 8, 27, 13)
	# key
	_sk_ring(g, 16.0, 25.0, 2.5, 2.5, 1.3, 11)
	_sk_r(g, 16, 27, 1, 4, 11)
	_sk_r(g, 17, 29, 2, 1, 11)
	# star
	_sk_r(g, 24, 22, 1, 7, 11)
	_sk_r(g, 21, 25, 7, 1, 11)
	_sk_r(g, 22, 23, 5, 5, 11)
	_sk_outline(g)
	_sk_p(g, 8, 23, 15)
	_sk_p(g, 23, 24, 15)
	_sk_p(g, 8, 21, 14)
	_sk_p(g, 24, 21, 14)
	_sk_p(g, 16, 22, 14)


# ---------------------------------------------------------------- objects: instruments

static func _sk_o_violin(g: Image) -> void:
	_sk_r(g, 15, 1, 3, 11, 8)
	_sk_r(g, 14, 1, 5, 3, 9)
	_sk_e(g, 16, 22, 9.0, 7.0, 9)
	_sk_e(g, 16, 13, 6.0, 5.0, 9)
	_sk_r(g, 12, 16, 9, 4, 9)
	_sk_outline(g)
	_sk_r(g, 9, 20, 3, 4, 10)
	_sk_p(g, 11, 12, 10)
	_sk_r(g, 13, 19, 1, 4, 0)
	_sk_r(g, 19, 19, 1, 4, 0)
	_sk_r(g, 13, 24, 7, 1, 15)
	_sk_l(g, 16, 3, 16, 27, 14)
	_sk_r(g, 15, 27, 3, 3, 8)


static func _sk_o_harmonica(g: Image) -> void:
	_sk_r(g, 2, 10, 28, 12, 14)
	_sk_r(g, 2, 10, 28, 2, 15)
	_sk_r(g, 2, 20, 28, 2, 4)
	_sk_r(g, 2, 10, 3, 12, 13)
	_sk_r(g, 27, 10, 3, 12, 13)
	_sk_outline(g)
	for x: int in range(7, 26, 2):
		_sk_r(g, x, 14, 1, 4, 0)
	_sk_r(g, 5, 13, 22, 1, 4)
	_sk_r(g, 5, 18, 22, 1, 4)


static func _sk_o_hand_bell(g: Image) -> void:
	_sk_r(g, 14, 2, 4, 9, 9)
	_sk_r(g, 14, 2, 1, 9, 10)
	_sk_e(g, 16, 17, 8.0, 7.0, 11)
	_sk_r(g, 8, 17, 17, 8, 11)
	_sk_r(g, 5, 23, 23, 4, 10)
	_sk_outline(g)
	_sk_r(g, 11, 12, 2, 9, 15)
	_sk_r(g, 5, 23, 23, 1, 11)
	_sk_r(g, 15, 28, 3, 2, 8)
	_sk_p(g, 16, 28, 0)


static func _sk_o_tuning_fork(g: Image) -> void:
	_sk_r(g, 10, 2, 4, 17, 14)
	_sk_r(g, 18, 2, 4, 17, 14)
	_sk_r(g, 10, 16, 12, 4, 14)
	_sk_r(g, 14, 20, 4, 8, 14)
	_sk_e(g, 16, 28, 2.0, 1.0, 14)
	_sk_outline(g)
	_sk_r(g, 11, 3, 1, 14, 15)
	_sk_r(g, 19, 3, 1, 14, 15)
	_sk_p(g, 15, 21, 15)


static func _sk_o_accordion(g: Image) -> void:
	_sk_r(g, 9, 7, 14, 20, 12)
	for x: int in range(10, 23, 3):
		_sk_r(g, x, 7, 1, 20, 13)
		_sk_r(g, x + 1, 7, 1, 20, 1)
	_sk_r(g, 2, 4, 8, 24, 9)
	_sk_r(g, 22, 4, 8, 24, 9)
	_sk_outline(g)
	_sk_r(g, 2, 4, 8, 2, 10)
	_sk_r(g, 22, 4, 8, 2, 10)
	for i: int in range(5):
		_sk_p(g, 25, 9 + i * 4, 15)
		_sk_p(g, 27, 9 + i * 4, 15)
		_sk_r(g, 4, 9 + i * 4, 4, 2, 15)
	_sk_r(g, 2, 26, 8, 2, 8)
	_sk_r(g, 22, 26, 8, 2, 8)


static func _sk_o_ocarina(g: Image) -> void:
	_sk_e(g, 15, 18, 12.0, 7.0, 10)
	_sk_r(g, 1, 19, 5, 3, 10)
	_sk_r(g, 22, 7, 6, 9, 9)
	_sk_e(g, 15, 21, 10.0, 4.0, 9)
	_sk_r(g, 1, 21, 5, 1, 9)
	_sk_outline(g)
	_sk_r(g, 24, 9, 2, 3, 0)
	_sk_r(g, 7, 13, 6, 1, 11)
	for p: Vector2i in [Vector2i(10, 15), Vector2i(14, 14), Vector2i(18, 15), Vector2i(12, 19), Vector2i(17, 19), Vector2i(7, 19)]:
		_sk_r(g, p.x, p.y, 2, 2, 0)
		_sk_p(g, p.x - 1, p.y - 1, 11)
	_sk_p(g, 3, 20, 0)


static func _sk_o_metronome(g: Image) -> void:
	for y: int in range(4, 28):
		var hw: int = 4 + (y - 4) * 8 / 23
		_sk_r(g, 16 - hw, y, hw * 2, 1, 9)
		_sk_r(g, 16 - hw, y, 2, 1, 8)
	_sk_r(g, 3, 27, 26, 3, 8)
	_sk_r(g, 3, 27, 26, 1, 9)
	for y: int in range(9, 26):
		var hw2: int = 2 + (y - 4) * 8 / 23 - 3
		_sk_r(g, 16 - hw2, y, hw2 * 2, 1, 10)
		if y % 3 == 0:
			_sk_r(g, 16 - hw2, y, 3 if y % 6 == 0 else 2, 1, 0)
	_sk_l(g, 16, 25, 23, 1, 15)
	_sk_l(g, 17, 25, 24, 1, 15)
	_sk_r(g, 19, 8, 6, 4, 13)
	_sk_outline(g)
	_sk_r(g, 19, 8, 6, 1, 15)
	_sk_r(g, 14, 25, 4, 3, 11)
	_sk_p(g, 28, 17, 11)
	_sk_r(g, 28, 16, 2, 3, 11)


static func _sk_o_gramophone(g: Image) -> void:
	for i: int in range(0, 13):
		var t: float = float(i) / 12.0
		_sk_e(g, 9.0 + t * 12.0, 7.0 + t * 12.0, lerpf(8.0, 1.5, t), lerpf(8.0, 1.5, t), 11)
	_sk_r(g, 6, 20, 24, 10, 9)
	_sk_r(g, 6, 20, 24, 2, 10)
	_sk_r(g, 6, 28, 24, 2, 8)
	_sk_outline(g)
	_sk_e(g, 9, 7, 6.0, 6.0, 8)
	_sk_e(g, 8, 6, 3.0, 3.0, 0)
	_sk_l(g, 3, 4, 6, 1, 15)
	_sk_r(g, 15, 18, 3, 3, 14)
	_sk_l(g, 29, 25, 31, 25, 11)
	_sk_r(g, 22, 22, 4, 2, 0)
	_sk_r(g, 10, 24, 8, 3, 8)


# ---------------------------------------------------------------- objects: books

static func _sk_o_book(g: Image, id: String) -> void:
	match id:
		"ledger":
			_sk_bk_ledger(g)
		"atlas":
			_sk_bk_atlas(g)
		"diary":
			_sk_bk_diary(g)
		"hymnal":
			_sk_bk_hymnal(g)
		"almanac":
			_sk_bk_almanac(g)
		"photo_album":
			_sk_bk_album(g)
		"herbarium":
			_sk_bk_herbarium(g)
		_:
			_sk_bk_first_edition(g)


## Thick ledger lying flat: dark brown boards, bone page block, amber strap and buckle.
static func _sk_bk_ledger(g: Image) -> void:
	_sk_r(g, 2, 11, 28, 4, 8)
	_sk_r(g, 3, 15, 26, 8, 14)
	_sk_r(g, 2, 23, 28, 4, 8)
	_sk_r(g, 2, 11, 4, 16, 12)
	_sk_outline(g)
	_sk_r(g, 2, 11, 28, 1, 9)
	for y: int in [17, 19, 21]:
		_sk_r(g, 7, y, 22, 1, 15)
	_sk_r(g, 6, 15, 23, 1, 13)
	_sk_r(g, 21, 10, 3, 18, 10)
	_sk_r(g, 21, 10, 1, 18, 11)
	_sk_r(g, 20, 17, 5, 4, 11)
	_sk_r(g, 21, 18, 3, 2, 8)
	_sk_r(g, 8, 12, 8, 2, 11)
	_sk_r(g, 2, 11, 2, 2, 11)
	_sk_r(g, 2, 25, 2, 2, 11)
	_sk_r(g, 6, 12, 1, 14, 0)


## Atlas lying open: two bone pages, sea and green land, a red dotted route and an X.
static func _sk_bk_atlas(g: Image) -> void:
	_sk_r(g, 1, 8, 30, 19, 3)
	_sk_r(g, 2, 8, 14, 17, 14)
	_sk_r(g, 16, 8, 14, 17, 14)
	_sk_outline(g)
	_sk_r(g, 3, 10, 12, 13, 4)
	_sk_r(g, 17, 10, 12, 13, 4)
	_sk_e(g, 8, 15, 3.0, 2.0, 7)
	_sk_r(g, 5, 17, 3, 2, 6)
	_sk_e(g, 12, 20, 2.0, 1.0, 6)
	_sk_e(g, 23, 14, 4.0, 3.0, 7)
	_sk_r(g, 20, 16, 3, 4, 6)
	_sk_e(g, 26, 20, 2.0, 1.0, 6)
	for p: Vector2i in [Vector2i(5, 12), Vector2i(8, 12), Vector2i(11, 13), Vector2i(19, 12), Vector2i(21, 12), Vector2i(23, 11), Vector2i(26, 15)]:
		_sk_p(g, p.x, p.y, 13)
	_sk_r(g, 26, 17, 3, 1, 13)
	_sk_r(g, 27, 16, 1, 3, 13)
	_sk_r(g, 15, 8, 2, 17, 2)
	_sk_r(g, 3, 24, 12, 1, 13)
	_sk_r(g, 17, 24, 12, 1, 13)
	_sk_p(g, 4, 11, 15)
	_sk_p(g, 18, 11, 15)


## Diary: slim upright red book, big gold padlock hanging on a strap across the cover.
static func _sk_bk_diary(g: Image) -> void:
	_sk_r(g, 7, 2, 18, 27, 13)
	_sk_r(g, 25, 3, 2, 25, 14)
	_sk_r(g, 7, 2, 3, 27, 12)
	_sk_r(g, 20, 17, 6, 3, 11)
	_sk_r(g, 13, 11, 2, 7, 14)
	_sk_r(g, 19, 11, 2, 7, 14)
	_sk_r(g, 13, 10, 8, 2, 14)
	_sk_r(g, 11, 17, 12, 10, 11)
	_sk_outline(g)
	_sk_r(g, 11, 24, 12, 3, 10)
	_sk_r(g, 16, 20, 2, 3, 0)
	_sk_p(g, 17, 22, 0)
	_sk_p(g, 12, 18, 15)
	_sk_p(g, 12, 19, 15)
	_sk_r(g, 15, 11, 4, 1, 4)
	_sk_p(g, 12, 5, 11)
	_sk_p(g, 22, 6, 11)
	_sk_p(g, 14, 7, 11)
	_sk_r(g, 10, 3, 1, 25, 11)


## Hymnal: small tall black book, gold cross, a red ribbon bookmark hanging out of the bottom.
static func _sk_bk_hymnal(g: Image) -> void:
	_sk_r(g, 10, 2, 13, 25, 2)
	_sk_r(g, 10, 2, 3, 25, 1)
	_sk_r(g, 11, 26, 12, 2, 14)
	_sk_r(g, 17, 27, 3, 4, 13)
	_sk_p(g, 18, 30, -1)
	_sk_outline(g)
	_sk_r(g, 17, 5, 2, 12, 11)
	_sk_r(g, 14, 8, 8, 2, 11)
	_sk_r(g, 15, 21, 6, 1, 10)
	_sk_p(g, 16, 28, 15)
	_sk_r(g, 13, 2, 1, 24, 3)


## Almanac: floppy stitched paperback with a dog-eared corner, sun above and moon below.
static func _sk_bk_almanac(g: Image) -> void:
	_sk_r(g, 7, 3, 19, 26, 4)
	_sk_r(g, 7, 28, 19, 1, 3)
	for y: int in range(4):
		for x: int in range(4):
			if x - y >= 1:
				_sk_p(g, 22 + x, 3 + y, -1)
	_sk_p(g, 25, 28, -1)
	_sk_p(g, 7, 28, -1)
	_sk_outline(g)
	_sk_r(g, 21, 4, 2, 1, 14)
	_sk_r(g, 21, 5, 3, 1, 14)
	_sk_r(g, 22, 6, 2, 1, 14)
	for y: int in range(5, 28, 3):
		_sk_r(g, 9, y, 1, 2, 15)
	_sk_e(g, 17, 11, 3.0, 3.0, 11)
	for p: Vector2i in [Vector2i(17, 5), Vector2i(17, 17), Vector2i(11, 11), Vector2i(23, 11), Vector2i(13, 7), Vector2i(21, 15), Vector2i(21, 7), Vector2i(13, 15)]:
		_sk_p(g, p.x, p.y, 11)
	_sk_e(g, 17, 23, 4.0, 4.0, 15)
	_sk_e(g, 19, 22, 3.5, 3.5, 4)
	_sk_p(g, 12, 21, 11)
	_sk_p(g, 13, 26, 11)


## Photo album: tall open album, two tiny photographs with corner tabs, caption lines.
static func _sk_bk_album(g: Image) -> void:
	_sk_r(g, 2, 4, 28, 24, 9)
	_sk_r(g, 4, 6, 11, 20, 14)
	_sk_r(g, 17, 6, 11, 20, 14)
	_sk_outline(g)
	_sk_r(g, 15, 5, 2, 22, 8)
	_sk_r(g, 5, 8, 8, 9, 15)
	_sk_r(g, 6, 9, 6, 7, 3)
	_sk_e(g, 9, 12, 1.5, 1.5, 14)
	_sk_r(g, 7, 15, 4, 1, 14)
	_sk_r(g, 19, 14, 8, 8, 15)
	_sk_r(g, 20, 15, 6, 6, 4)
	_sk_p(g, 24, 16, 11)
	_sk_r(g, 20, 19, 6, 2, 6)
	for p: Vector2i in [Vector2i(5, 8), Vector2i(12, 16), Vector2i(19, 14), Vector2i(26, 21)]:
		_sk_p(g, p.x, p.y, 13)
	_sk_r(g, 6, 20, 6, 1, 13)
	_sk_r(g, 6, 22, 4, 1, 13)
	_sk_r(g, 19, 8, 7, 1, 13)
	_sk_r(g, 19, 10, 5, 1, 13)


## Herbarium: dark green press-book, bone label, fern and leaves poking out of the pages.
static func _sk_bk_herbarium(g: Image) -> void:
	_sk_r(g, 5, 8, 19, 21, 5)
	_sk_r(g, 24, 9, 2, 19, 14)
	_sk_r(g, 5, 8, 3, 21, 0)
	_sk_e(g, 28, 13, 3.0, 2.0, 7)
	_sk_e(g, 28, 22, 3.0, 2.0, 6)
	_sk_l(g, 14, 8, 14, 1, 7)
	for y: int in [2, 4, 6]:
		_sk_r(g, 11, y, 3, 1, 7)
		_sk_r(g, 15, y, 3, 1, 7)
	_sk_e(g, 20, 5, 2.0, 3.0, 6)
	_sk_outline(g)
	_sk_r(g, 10, 13, 10, 10, 14)
	_sk_r(g, 10, 13, 10, 1, 15)
	_sk_l(g, 12, 22, 17, 15, 6)
	_sk_e(g, 17, 17, 2.0, 1.0, 7)
	_sk_e(g, 13, 19, 1.0, 1.0, 7)
	_sk_r(g, 8, 8, 1, 21, 6)
	_sk_p(g, 27, 13, 5)
	_sk_p(g, 28, 22, 5)


## First edition: upright, brown spine with gold ridged bands, red dust jacket with a bone title panel and crest.
static func _sk_bk_first_edition(g: Image) -> void:
	_sk_r(g, 6, 2, 5, 27, 9)
	_sk_r(g, 11, 2, 15, 27, 12)
	_sk_r(g, 22, 2, 4, 27, 13)
	_sk_outline(g)
	for y: int in [4, 9, 14, 19, 24]:
		_sk_r(g, 6, y, 5, 1, 11)
		_sk_r(g, 6, y + 1, 5, 1, 8)
	_sk_r(g, 22, 2, 1, 27, 0)
	_sk_r(g, 13, 6, 8, 7, 14)
	_sk_r(g, 14, 8, 6, 1, 12)
	_sk_r(g, 14, 10, 4, 1, 12)
	_sk_r(g, 11, 2, 15, 1, 11)
	_sk_r(g, 11, 28, 15, 1, 11)
	_sk_r(g, 16, 17, 3, 3, 11)
	_sk_p(g, 17, 16, 11)
	_sk_p(g, 17, 20, 11)
	_sk_r(g, 13, 23, 8, 1, 11)


# ---------------------------------------------------------------- objects: relics

static func _sk_o_hand_mirror(g: Image) -> void:
	_sk_e(g, 15, 12, 10.0, 10.0, 11)
	_sk_r(g, 13, 21, 4, 9, 11)
	_sk_e(g, 15, 30, 2.0, 1.0, 11)
	_sk_outline(g)
	_sk_e(g, 15, 12, 8.0, 8.0, 4)
	_sk_l(g, 9, 14, 13, 8, 15)
	_sk_l(g, 10, 16, 14, 10, 15)
	_sk_p(g, 13, 13, 7)
	_sk_p(g, 17, 13, 7)
	_sk_r(g, 14, 23, 1, 5, 10)


static func _sk_o_candlestick(g: Image) -> void:
	_sk_e(g, 16, 28, 8.0, 2.0, 11)
	_sk_r(g, 15, 15, 3, 13, 11)
	_sk_e(g, 16, 21, 3.0, 2.0, 11)
	_sk_r(g, 11, 13, 11, 2, 11)
	_sk_r(g, 14, 5, 5, 8, 15)
	_sk_r(g, 14, 5, 1, 8, 14)
	_sk_e(g, 16, 2, 1.5, 2.0, 10)
	_sk_outline(g)
	_sk_p(g, 16, 3, 11)
	_sk_p(g, 16, 4, 0)
	_sk_p(g, 12, 27, 15)
	_sk_p(g, 16, 16, 15)


static func _sk_o_oil_portrait(g: Image) -> void:
	_sk_r(g, 4, 2, 24, 28, 11)
	_sk_r(g, 4, 2, 24, 1, 15)
	_sk_r(g, 7, 5, 18, 22, 10)
	_sk_r(g, 8, 6, 16, 20, 1)
	_sk_outline(g)
	_sk_e(g, 16, 13, 4.0, 5.0, 14)
	_sk_r(g, 9, 19, 14, 7, 2)
	_sk_r(g, 12, 8, 8, 3, 8)
	_sk_p(g, 14, 13, 7)
	_sk_p(g, 18, 13, 7)
	_sk_r(g, 15, 17, 2, 1, 12)
	_sk_p(g, 4, 29, 10)
	_sk_p(g, 27, 29, 10)


static func _sk_o_brass_key(g: Image) -> void:
	_sk_ring(g, 8.0, 15.0, 6.0, 6.0, 3.0, 11)
	_sk_r(g, 13, 14, 17, 3, 11)
	_sk_r(g, 23, 17, 3, 4, 11)
	_sk_r(g, 27, 17, 3, 3, 11)
	_sk_outline(g)
	_sk_p(g, 5, 11, 15)
	_sk_r(g, 14, 14, 8, 1, 15)
	_sk_r(g, 12, 13, 2, 5, 10)


static func _sk_o_snow_globe(g: Image) -> void:
	_sk_e(g, 16, 13, 12.0, 12.0, 4)
	_sk_e(g, 16, 13, 10.0, 10.0, 3)
	_sk_r(g, 9, 24, 14, 5, 9)
	_sk_r(g, 6, 27, 20, 3, 8)
	_sk_outline(g)
	_sk_r(g, 8, 21, 16, 3, 15)
	_sk_r(g, 13, 17, 7, 5, 9)
	_sk_r(g, 12, 15, 9, 2, 13)
	_sk_r(g, 14, 12, 5, 3, 13)
	_sk_p(g, 15, 19, 11)
	_sk_p(g, 11, 11, 15)
	_sk_p(g, 21, 8, 15)
	_sk_p(g, 8, 17, 15)
	_sk_p(g, 24, 15, 15)
	_sk_p(g, 17, 6, 15)
	_sk_l(g, 9, 8, 12, 4, 15)
	_sk_l(g, 8, 10, 8, 9, 15)


static func _sk_o_taxidermy_owl(g: Image) -> void:
	_sk_r(g, 5, 28, 22, 2, 8)
	_sk_e(g, 16, 19, 8.0, 9.0, 9)
	_sk_e(g, 16, 21, 5.0, 6.0, 14)
	_sk_e(g, 16, 10, 9.0, 7.0, 9)
	_sk_r(g, 8, 3, 4, 5, 9)
	_sk_r(g, 20, 3, 4, 5, 9)
	_sk_p(g, 8, 2, 9)
	_sk_p(g, 23, 2, 9)
	_sk_outline(g)
	_sk_e(g, 16, 11, 7.0, 5.0, 14)
	_sk_e(g, 12, 10, 2.5, 2.5, 11)
	_sk_e(g, 20, 10, 2.5, 2.5, 11)
	_sk_r(g, 12, 10, 1, 2, 0)
	_sk_r(g, 20, 10, 1, 2, 0)
	_sk_r(g, 15, 12, 2, 3, 10)
	_sk_p(g, 14, 20, 9)
	_sk_p(g, 17, 22, 9)
	_sk_p(g, 15, 24, 9)
	_sk_p(g, 12, 17, 10)
	_sk_p(g, 20, 17, 10)
	_sk_r(g, 12, 27, 2, 1, 10)
	_sk_r(g, 18, 27, 2, 1, 10)


static func _sk_o_ship_bottle(g: Image) -> void:
	_sk_r(g, 1, 8, 22, 18, 6)
	_sk_r(g, 22, 13, 7, 8, 6)
	_sk_r(g, 29, 14, 2, 6, 9)
	_sk_r(g, 2, 9, 20, 16, 1)
	_sk_r(g, 22, 14, 7, 6, 1)
	_sk_r(g, 2, 20, 20, 5, 4)
	_sk_r(g, 22, 20, 1, 1, 6)
	_sk_r(g, 7, 17, 14, 3, 9)
	_sk_r(g, 8, 20, 12, 1, 8)
	_sk_r(g, 5, 15, 3, 2, 9)
	_sk_r(g, 9, 9, 1, 8, 8)
	_sk_r(g, 15, 8, 1, 9, 8)
	_sk_r(g, 10, 10, 5, 6, 15)
	_sk_r(g, 16, 9, 5, 7, 14)
	_sk_r(g, 10, 14, 5, 2, 14)
	_sk_p(g, 15, 8, 13)
	_sk_p(g, 9, 9, 13)
	_sk_outline(g)
	_sk_r(g, 2, 8, 20, 1, 7)
	_sk_r(g, 3, 10, 1, 4, 15)
	_sk_r(g, 3, 21, 3, 1, 3)
	_sk_r(g, 12, 22, 4, 1, 3)
	_sk_r(g, 18, 21, 3, 1, 3)
	_sk_r(g, 23, 14, 5, 1, 7)
	_sk_r(g, 30, 15, 1, 4, 10)


static func _sk_o_mantel_clock(g: Image) -> void:
	_sk_r(g, 4, 25, 24, 4, 8)
	_sk_r(g, 4, 25, 24, 1, 9)
	_sk_r(g, 6, 7, 20, 18, 9)
	_sk_e(g, 16, 8, 10.0, 5.0, 9)
	_sk_r(g, 14, 1, 4, 3, 11)
	_sk_r(g, 11, 4, 10, 2, 11)
	_sk_r(g, 5, 29, 4, 2, 11)
	_sk_r(g, 23, 29, 4, 2, 11)
	_sk_outline(g)
	_sk_e(g, 16, 15, 7.0, 7.0, 11)
	_sk_e(g, 16, 15, 6.0, 6.0, 15)
	_sk_l(g, 16, 15, 16, 10, 0)
	_sk_l(g, 16, 15, 19, 17, 12)
	_sk_p(g, 16, 9, 0)
	_sk_p(g, 16, 21, 0)
	_sk_p(g, 10, 15, 0)
	_sk_p(g, 22, 15, 0)
	_sk_r(g, 7, 8, 1, 16, 10)


## Category fallback for ids without a hand-drawn routine.
static func _sk_o_fallback(g: Image, category: String, id: String) -> void:
	var tint: int = 3 + absi(hash(id)) % 3
	match category:
		"toy":
			_sk_e(g, 16, 17, 9.0, 9.0, 13)
			_sk_r(g, 8, 17, 16, 2, 15)
			_sk_e(g, 16, 6, 2.0, 2.0, 11)
		"jewelry":
			_sk_ring(g, 16.0, 20.0, 8.0, 8.0, 3.0, 11)
			_sk_r(g, 13, 6, 6, 6, tint)
		"instrument":
			_sk_e(g, 11, 24, 5.0, 4.0, 9)
			_sk_r(g, 15, 5, 2, 20, 9)
			_sk_r(g, 17, 5, 6, 3, 9)
		"book":
			_sk_r(g, 7, 4, 18, 25, tint)
			_sk_r(g, 7, 4, 3, 25, 0)
			_sk_r(g, 25, 5, 2, 23, 14)
			_sk_r(g, 13, 10, 8, 2, 11)
		"relic":
			_sk_e(g, 16, 18, 8.0, 9.0, 9)
			_sk_r(g, 12, 5, 8, 6, 9)
			_sk_r(g, 10, 27, 12, 2, 8)
			_sk_r(g, 12, 15, 8, 2, 11)
		_:
			_sk_e(g, 16, 16, 9.0, 9.0, tint)
			_sk_r(g, 15, 12, 2, 8, 15)
	_sk_outline(g)
