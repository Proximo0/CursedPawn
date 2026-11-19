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

const SK_DARK: Array[int] = [0, 0, 1, 2, 3, 0, 5, 6, 1, 8, 9, 10, 1, 12, 4, 14]
const SK_LIGHT: Array[int] = [1, 2, 3, 4, 4, 6, 7, 7, 9, 10, 11, 15, 13, 13, 15, 15]
const SK_CUST_W: int = 64
const SK_CUST_H: int = 96
const SK_BAND_Y: int = 46
const SK_BAND_H: int = 32
const SK_HL: Array[float] = [3.0, 1.0, 6.0, 3.0, 10.0, 6.0, 14.0, 9.0, 19.0, 11.0, 26.0, 11.0, 31.0, 10.0, 34.0, 8.0,
	37.0, 11.0, 39.0, 16.0, 43.0, 19.0, 50.0, 19.0, 60.0, 17.0, 72.0, 17.0, 84.0, 18.0, 95.0, 20.0]
const SK_HR: Array[float] = [3.0, 2.0, 6.0, 5.0, 10.0, 8.0, 14.0, 10.0, 19.0, 11.0, 26.0, 11.0, 31.0, 10.0, 34.0, 8.0,
	38.0, 10.0, 41.0, 14.0, 46.0, 18.0, 52.0, 20.0, 60.0, 19.0, 72.0, 19.0, 84.0, 20.0, 95.0, 22.0]
const SK_STYLES: Array[String] = ["pin", "hollow", "wide", "slit", "uneven", "three", "four", "blank", "five", "mismatch"]
const SK_EYE_STYLE: Dictionary = {
	"widow": "hollow", "estate_clearer": "pin", "nervous_heir": "wide", "fence": "slit", "haggler": "uneven",
	"medium": "three", "collector": "four", "tourist": "mismatch", "ghost_hunter": "five", "decorator": "pin",
	"priest": "blank", "rival": "slit",
}

static var _sk_cols: PackedColorArray = PackedColorArray()


# ---------------------------------------------------------------- public API

static func object_texture(id: String, category: String) -> ImageTexture:
	return ImageTexture.create_from_image(_sk_object_image(id, category))


static func _sk_draw_object(g: Image, id: String, category: String) -> void:
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


## Customer figure, 64x96 at height 1.0 (taller or shorter types stretch the torso band, never the pixels).
## Gaunt hooded figure, uneven shoulders, long pale fingers; the eyes differ per type (see SK_EYE_STYLE).
static func customer_texture(look: Dictionary) -> ImageTexture:
	return ImageTexture.create_from_image(_sk_cust_image(look, 0))


static func _sk_cust_image(look: Dictionary, frame: int) -> Image:
	var g: Image = _sk_cust_draw(look, frame)
	var h: float = clampf(float(look.get("height", 1.0)), 0.7, 1.3)
	return _sk_cust_stretch(g, roundi(float(SK_CUST_H) * h))


## Rows 48..79 are plain cloak, so rows can be dropped or doubled there without hurting any detail.
static func _sk_cust_stretch(g: Image, target_h: int) -> Image:
	if target_h == SK_CUST_H:
		return g
	var out: Image = _sk_new(SK_CUST_W, target_h)
	var delta: int = target_h - SK_CUST_H
	var dst: int = 0
	for y: int in range(SK_CUST_H):
		var count: int = 1
		if y >= SK_BAND_Y and y < SK_BAND_Y + SK_BAND_H:
			var i: int = y - SK_BAND_Y
			count = 1 + (floori(float((i + 1) * delta) / float(SK_BAND_H)) - floori(float(i * delta) / float(SK_BAND_H)))
		for _k: int in range(maxi(count, 0)):
			if dst < target_h:
				out.blit_rect(g, Rect2i(0, y, SK_CUST_W, 1), Vector2i(0, dst))
				dst += 1
	return out


static func _sk_interp(pts: Array[float], y: float) -> float:
	if y < pts[0]:
		return -1.0
	var n: int = pts.size() / 2
	for i: int in range(n - 1):
		var y0: float = pts[i * 2]
		var y1: float = pts[i * 2 + 2]
		if y <= y1:
			return lerpf(pts[i * 2 + 1], pts[i * 2 + 3], (y - y0) / maxf(y1 - y0, 0.001))
	return pts[n * 2 - 1]


static func _sk_head_shift(ys: float, lean: float, tilt: float) -> float:
	return lean * clampf((34.0 - ys) / 31.0, 0.0, 1.0) + tilt * clampf((36.0 - ys) / 33.0, 0.0, 1.0)


## frame 0 neutral, 1 breathe in (body up a pixel, shoulders wider), 2 blink, 3 head tilt.
static func _sk_cust_draw(look: Dictionary, frame: int) -> Image:
	var g: Image = _sk_new(SK_CUST_W, SK_CUST_H)
	var id: String = str(look.get("id", ""))
	var cloak: int = _sk_snap(Color.from_string(str(look.get("cloak", "")), Color(0.14, 0.08, 0.22)))
	var eyes: int = _sk_snap(Color.from_string(str(look.get("eyes", "")), Color(0.9, 0.86, 0.75)))
	var base: int = cloak
	var lit: int = SK_LIGHT[base]
	var rim: int = SK_LIGHT[lit]
	var sh: int = SK_DARK[base]
	var sh2: int = SK_DARK[sh]
	var hsh: int = absi(hash(id))
	var lean: float = [-3.0, -1.0, 2.0, -2.0, 1.0, -4.0, 0.0][hsh % 7]
	var rise: int = 1 if frame == 1 else 0
	var tilt: float = 4.5 if frame == 3 else 0.0
	for y: int in range(SK_CUST_H):
		var ys: float = float(y + (rise if y < 62 else 0))
		var hl: float = _sk_interp(SK_HL, ys)
		if hl < 0.0:
			continue
		var hr: float = _sk_interp(SK_HR, ys)
		var widen: float = float(rise) if ys > 37.0 and ys < 60.0 else 0.0
		var shift: float = _sk_head_shift(ys, lean, tilt)
		var xl: int = roundi(32.0 + shift - hl - widen)
		var xr: int = roundi(32.0 + shift + hr + widen)
		var span: float = float(maxi(xr - xl, 1))
		for x: int in range(xl, xr + 1):
			var tooth: int = ((x * 37 + 11) % 7) / 2
			if y > 95 - tooth:
				continue
			var u: float = float(x - xl) / span
			var t: int = base
			var chk: bool = (x + y) % 2 == 0
			if u < 0.13:
				t = lit
			elif u < 0.2 and chk:
				t = lit
			elif u > 0.82:
				t = sh
			elif u > 0.72 and chk:
				t = sh
			if y > 88:
				t = SK_DARK[t]
			if x == xl and ys < 64.0:
				t = rim
			elif x == xr:
				t = sh2
			_sk_p(g, x, y, t)
		# long vertical folds of heavy cloth: shadow line with a broken highlight beside it
		if ys >= 44.0:
			for k: int in range(3):
				var fy0: int = [46, 52, 44][k]
				var fy1: int = 95 - k * 5
				if y >= fy0 and y <= fy1:
					var fx: int = xl + roundi([0.30, 0.54, 0.79][k] * span) + (y - fy0) / 14
					_sk_p(g, fx, y, sh2)
					if (y + k) % 3 != 0:
						_sk_p(g, fx - 1, y, lit)
	# cloth draped over the shoulders (left catches the light, right falls into shadow)
	var hx: int = 32 + roundi(_sk_head_shift(25.0, lean, tilt))
	var sy: int = 36 + rise * -1
	_sk_l(g, hx - 8, sy, hx - 15, sy + 9, lit)
	_sk_l(g, hx - 8, sy + 1, hx - 14, sy + 9, sh)
	_sk_l(g, hx + 8, sy + 1, hx + 16, sy + 11, sh2)
	_sk_l(g, hx + 7, sy + 1, hx + 14, sy + 10, base)
	# hood opening with a thick rim of cloth
	for y: int in range(12, 40):
		for x: int in range(hx - 12, hx + 13):
			var dx: float = float(x - hx) / 8.0
			var dy: float = float(y - 25) / 11.0
			var d: float = dx * dx + dy * dy
			if g.get_pixel(x, y).a <= 0.0:
				continue
			if d <= 1.0:
				_sk_p(g, x, y, 0)
			elif d <= 1.5:
				_sk_p(g, x, y, lit if (x - hx) + (y - 25) < 0 else sh2)
	# gaunt hollows inside the dark
	_sk_r(g, hx - 6, 29, 1, 2, 1)
	_sk_r(g, hx + 6, 29, 1, 2, 1)
	var style: String = str(SK_EYE_STYLE.get(id, SK_STYLES[hsh % SK_STYLES.size()]))
	_sk_cust_eyes(g, hx, 25, eyes, style, frame == 2)
	_sk_cust_hand(g, 22, 80, -1, base, lit, sh2)
	_sk_cust_hand(g, 42, 82, 1, base, lit, sh2)
	_sk_outline(g)
	return g


static func _sk_eye_centers(style: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = [Vector2i(-4, 0), Vector2i(4, 0)]
	match style:
		"uneven":
			out = [Vector2i(-4, 0), Vector2i(4, 1)]
		"three":
			out.append(Vector2i(0, -6))
		"four":
			out = [Vector2i(-5, -2), Vector2i(5, -2), Vector2i(-3, 2), Vector2i(3, 2)]
		"five":
			out = [Vector2i(-6, 0), Vector2i(-3, 0), Vector2i(0, 0), Vector2i(3, 0), Vector2i(6, 0)]
	return out


static func _sk_cust_eyes(g: Image, hx: int, ey: int, e: int, style: String, closed: bool) -> void:
	var gl: int = SK_DARK[e]
	var cs: Array[Vector2i] = _sk_eye_centers(style)
	if closed:
		for c: Vector2i in cs:
			if style == "five":
				_sk_p(g, hx + c.x, ey + c.y, gl)
			else:
				_sk_r(g, hx + c.x - 1, ey + c.y, 3, 1, gl)
		return
	for i: int in range(cs.size()):
		var cx: int = hx + cs[i].x
		var cy: int = ey + cs[i].y
		var sgn: int = -1 if cs[i].x < 0 else 1
		var st: String = style
		if style == "uneven":
			st = "wide" if i == 0 else "pin"
		elif style == "mismatch":
			st = "pin" if i == 0 else "hollow"
		match st:
			"pin":
				_sk_p(g, cx, cy, e)
				_sk_p(g, cx - 1, cy, gl)
				_sk_p(g, cx + 1, cy, gl)
			"hollow":
				var hg: int = SK_DARK[gl]
				_sk_r(g, cx - 1, cy - 2, 3, 1, hg)
				_sk_r(g, cx - 1, cy + 2, 3, 1, hg)
				_sk_r(g, cx - 2, cy - 1, 1, 3, hg)
				_sk_r(g, cx + 2, cy - 1, 1, 3, hg)
				_sk_p(g, cx, cy + 1, gl)
			"wide":
				_sk_r(g, cx - 2, cy - 1, 5, 3, 15)
				_sk_r(g, cx - 1, cy - 2, 3, 1, 15)
				_sk_r(g, cx - 1, cy + 2, 3, 1, e)
				_sk_p(g, cx - sgn, cy, 0)
				_sk_p(g, cx - sgn, cy + 1, 0)
			"slit":
				_sk_r(g, cx - 1, cy - 1, 3, 3, e)
				_sk_r(g, cx, cy - 1, 1, 3, 0)
				_sk_p(g, cx - 2, cy, gl)
				_sk_p(g, cx + 2, cy, gl)
			"three", "four":
				_sk_r(g, cx - 1, cy, 2, 2, e)
				_sk_p(g, cx - 1, cy, 15)
			"blank":
				_sk_r(g, cx - 2, cy, 4, 2, e)
				_sk_r(g, cx - 1, cy - 1, 2, 1, e)
				_sk_r(g, cx - 1, cy + 2, 2, 1, gl)
			"five":
				_sk_p(g, cx, cy, 15 if i == 2 else e)
				_sk_p(g, cx, cy + 1, gl)


## One hand resting on the counter: sleeve cuff, a bony palm, four long uneven fingers with knuckles, a thumb.
static func _sk_cust_hand(g: Image, x: int, y: int, side: int, base: int, lit: int, sh2: int) -> void:
	_sk_e(g, x, y, 6.0, 2.5, sh2)
	_sk_r(g, x - 5, y - 2, 6, 1, lit)
	_sk_r(g, x - 4, y + 1, 9, 3, 14)
	_sk_r(g, x - 4, y + 1, 9, 1, 15)
	_sk_r(g, x + 4, y + 1, 1, 3, 4)
	var lens: Array[int] = [7, 10, 9, 6]
	if side > 0:
		lens = [6, 9, 10, 7]
	for i: int in range(4):
		var fx: int = x - 3 + i * 2
		var ln: int = lens[i]
		for k: int in range(ln):
			var tone: int = 15 if i == 0 else 14
			if k == 3 and i % 2 == 0:
				tone = 4
			elif k >= ln - 1:
				tone = 3
			var splay: int = roundi(float(k) * (float(i) - 1.5) / 5.0)
			_sk_p(g, fx + splay, y + 4 + k, tone)
	_sk_l(g, x - side * 5, y + 2, x - side * 8, y + 7, 14)


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
	_sk_polish(g, "tool_" + tool, 2)
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
			g = _sk_t_wall()
		"floor":
			g = _sk_t_floor()
		"shelf":
			g = _sk_t_shelf()
		"counter":
			g = _sk_t_counter()
		"door":
			g = _sk_t_door()
		_:
			g = _sk_new(16, 16)
			_sk_r(g, 0, 0, 16, 16, 2)
			_sk_r(g, 0, 0, 16, 1, 4)
	return ImageTexture.create_from_image(g)


## Stained striped wallpaper (32x32, tiles both ways): damask on the light stripe, seams at x=0 and x=16 with
## one peeling flap, a damp stain with a drip, mildew speckle and a soot smear.
static func _sk_t_wall() -> Image:
	var g: Image = _sk_new(32, 32)
	for y: int in range(32):
		for x: int in range(32):
			var m: int = x % 16
			var t: int = 3
			if m == 8 and y % 2 == 0:
				t = 3
			elif m == 8 or m >= 9 and m <= 14:
				t = 2
			elif m == 15:
				t = 2 if y % 2 == 0 else 1
			_sk_p(g, x, y, t)
	# damask lozenges on the light stripe, each lit on its upper left
	for o: Vector2i in [Vector2i(4, 5), Vector2i(20, 21), Vector2i(20, 3), Vector2i(4, 19)]:
		_sk_art(g, ["..4..", ".434.", "44344", ".434.", "..4.."], o.x - 2, o.y - 2)
	# seams: dark gap, lit paper edge to its right
	for sx: int in [0, 16]:
		_sk_r(g, sx, 0, 1, 32, 1)
		_sk_r(g, sx + 1, 0, 1, 32, 4)
	# peeling flap on the seam at x=16, revealing bare plaster behind it
	_sk_art(g, ["134....", "1344...", "22344..", "222344.", "1222.4.", "11222..", "1.122..", "..12..."], 16, 19)
	# damp stain with drip (upper right quarter) and a dithered mould rim
	for y: int in range(2, 16):
		for x: int in range(20, 31):
			var d: float = pow(float(x - 25) / 5.5, 2.0) + pow(float(y - 8) / 5.5, 2.0)
			if d < 0.45:
				_sk_p(g, x, y, 5)
			elif d < 1.0 and (x + y) % 2 == 0:
				_sk_p(g, x, y, 5)
			elif d < 1.35 and (x * 3 + y) % 5 == 0:
				_sk_p(g, x, y, 5)
	_sk_r(g, 24, 14, 1, 9, 5)
	_sk_p(g, 25, 15, 5)
	_sk_p(g, 24, 23, 6)
	# brown tide mark low on the left, fading by dither
	for y: int in range(22, 30):
		for x: int in range(2, 12):
			var d2: float = pow(float(x - 6) / 5.0, 2.0) + pow(float(y - 26) / 3.0, 2.0)
			if d2 < 0.5 or (d2 < 1.0 and (x + y) % 2 == 0):
				_sk_p(g, x, y, 8 if g.get_pixel(x, y) == _sk_col(2) else 1)
	# soot smear and mildew specks, in clusters of two so nothing is a lone pixel
	for p: Vector2i in [Vector2i(10, 12), Vector2i(12, 28), Vector2i(29, 27), Vector2i(7, 3)]:
		_sk_r(g, p.x, p.y, 2, 1, 1)
		_sk_p(g, p.x + 1, p.y + 1, 1)
	for p: Vector2i in [Vector2i(3, 9), Vector2i(13, 22), Vector2i(28, 19)]:
		_sk_r(g, p.x, p.y, 2, 2, 5)
		_sk_p(g, p.x, p.y, 6)
	return g


## Warped floorboards (32x32, tiles both ways): wobbling dark gaps, lit top edges, grain dashes, a knot, joints with
## nail heads, scuffs and a spilled stain.
static func _sk_t_floor() -> Image:
	var g: Image = _sk_new(32, 32)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var tones: Array[int] = [9, 8, 9, 9, 8, 9, 8, 9]
	for x: int in range(32):
		var b: Array[int] = []
		for r: int in range(4):
			b.append(r * 8 + 7 + roundi(sin(float(x + r * 9) * TAU / 32.0 + 0.8) * 1.2))
		for y: int in range(32):
			var r: int = 0
			var prev: int = b[3] - 32 if y <= b[0] else b[0]
			if y <= b[0]:
				r = 0
				prev = b[3] - 32
			elif y <= b[1]:
				r = 1
				prev = b[0]
			elif y <= b[2]:
				r = 2
				prev = b[1]
			elif y <= b[3]:
				r = 3
				prev = b[2]
			else:
				r = 0
				prev = b[3]
			var jx: int = (r * 13 + 5) % 32
			var seg: int = 0 if ((x - jx + 32) % 32) < 17 else 1
			var t: int = tones[r * 2 + seg]
			if y == b[r]:
				t = 0
			elif y == prev + 1:
				t = 10 if t == 9 else 9
			elif y == b[r] - 1:
				t = 8 if t == 9 else 1
			_sk_p(g, x, y, t)
	# grain dashes
	for i: int in range(26):
		var gx: int = rng.randi_range(0, 31)
		var gy: int = rng.randi_range(0, 31)
		var gl: int = rng.randi_range(4, 9)
		for k: int in range(gl):
			var cur: int = _sk_idx(g, (gx + k) % 32, gy)
			if cur == 9:
				_sk_p(g, (gx + k) % 32, gy, 8)
			elif cur == 8 and k % 2 == 0:
				_sk_p(g, (gx + k) % 32, gy, 1)
	# joints with a lit right edge and nail heads
	for r: int in range(4):
		var jx2: int = (r * 13 + 5) % 32
		for y: int in range(r * 8 + 1, r * 8 + 6):
			_sk_p(g, jx2, y, 0)
			_sk_p(g, (jx2 + 1) % 32, y, 10 if _sk_idx(g, (jx2 + 1) % 32, y) == 9 else 9)
			_sk_p(g, (jx2 + 3) % 32, y, _sk_idx(g, (jx2 + 3) % 32, y) if y != r * 8 + 2 and y != r * 8 + 4 else 1)
	# knot
	_sk_art(g, [".888.", "81118", "81018", "81118", ".888."], 20, 13)
	# spilled stain, dithered at the rim
	for y: int in range(1, 9):
		for x: int in range(3, 15):
			var d: float = pow(float(x - 9) / 6.0, 2.0) + pow(float(y - 4) / 3.5, 2.0)
			var cur2: int = _sk_idx(g, x, y)
			if cur2 != 0 and (d < 0.55 or (d < 1.0 and (x + y) % 2 == 0)):
				_sk_p(g, x, y, SK_DARK[cur2])
	return g


static func _sk_t_shelf() -> Image:
	var g: Image = _sk_new(16, 16)
	_sk_r(g, 0, 0, 16, 1, 10)
	_sk_r(g, 0, 1, 16, 1, 11)
	_sk_r(g, 0, 2, 16, 5, 9)
	_sk_r(g, 0, 7, 16, 1, 8)
	_sk_r(g, 0, 8, 16, 1, 0)
	_sk_r(g, 0, 9, 16, 2, 1)
	_sk_r(g, 0, 11, 16, 1, 0)
	for p: Vector2i in [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5), Vector2i(13, 3), Vector2i(14, 3)]:
		_sk_p(g, p.x, p.y, 8)
	for p: Vector2i in [Vector2i(6, 4), Vector2i(7, 4), Vector2i(12, 2)]:
		_sk_p(g, p.x, p.y, 10)
	_sk_art(g, ["181", "808"], 5, 5)
	_sk_p(g, 14, 1, 9)
	_sk_p(g, 15, 1, 9)
	_sk_p(g, 0, 7, 0)
	return g


## Worn counter (32x32): the top edge is a chipped, rubbed lip of old wood, below it panelled doors with scratches.
static func _sk_t_counter() -> Image:
	var g: Image = _sk_new(32, 32)
	_sk_r(g, 0, 0, 32, 2, 10)
	_sk_r(g, 0, 2, 32, 1, 11)
	_sk_r(g, 0, 3, 32, 1, 9)
	_sk_r(g, 0, 4, 32, 1, 8)
	_sk_r(g, 0, 5, 32, 1, 0)
	_sk_r(g, 0, 6, 32, 1, 1)
	_sk_r(g, 0, 7, 32, 25, 8)
	# top surface grain and rubbed bright patches where hands rest
	for p: Vector2i in [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(13, 1), Vector2i(14, 1), Vector2i(15, 1), Vector2i(16, 1), Vector2i(24, 0), Vector2i(25, 0), Vector2i(29, 1)]:
		_sk_p(g, p.x, p.y, 9)
	for p: Vector2i in [Vector2i(8, 1), Vector2i(9, 1), Vector2i(20, 0), Vector2i(21, 0), Vector2i(22, 0)]:
		_sk_p(g, p.x, p.y, 11)
	# chips in the lip, dark inside, and burn rings of old cups on the edge
	for p: Vector2i in [Vector2i(6, 2), Vector2i(7, 2), Vector2i(18, 2), Vector2i(26, 2), Vector2i(27, 2), Vector2i(27, 3)]:
		_sk_p(g, p.x, p.y, 9)
	_sk_p(g, 7, 3, 8)
	_sk_p(g, 18, 3, 8)
	_sk_p(g, 19, 3, 8)
	_sk_art(g, [".999.", "9...9"], 10, 2)
	# panels: lit frame top-left, shadow bottom-right, recessed field
	for px: int in [1, 17]:
		_sk_r(g, px, 9, 14, 20, 9)
		_sk_r(g, px, 9, 14, 1, 10)
		_sk_r(g, px, 9, 1, 20, 10)
		_sk_r(g, px + 13, 9, 1, 20, 8)
		_sk_r(g, px, 28, 14, 1, 8)
		_sk_r(g, px + 2, 11, 10, 16, 8)
		_sk_r(g, px + 2, 11, 10, 1, 1)
		_sk_r(g, px + 2, 11, 1, 16, 1)
		_sk_r(g, px + 11, 12, 1, 15, 9)
		_sk_r(g, px + 2, 26, 10, 1, 9)
	# deep scratches and a gouge on the panels
	_sk_l(g, 5, 14, 9, 22, 1)
	_sk_l(g, 6, 14, 10, 22, 9)
	_sk_l(g, 22, 13, 25, 19, 1)
	_sk_l(g, 23, 25, 27, 23, 9)
	_sk_r(g, 20, 20, 2, 1, 1)
	# grime pooling along the foot, lit seams
	_sk_r(g, 0, 29, 32, 1, 1)
	_sk_r(g, 0, 30, 32, 2, 0)
	for x: int in range(0, 32, 3):
		_sk_p(g, x, 29, 0)
	_sk_r(g, 0, 7, 1, 23, 0)
	_sk_r(g, 16, 7, 1, 23, 0)
	_sk_r(g, 15, 7, 1, 2, 1)
	return g


## Scratched door (32x48): planks with gaps, iron straps and rivets, claw marks that bare the wood, a worn handle.
static func _sk_t_door() -> Image:
	var g: Image = _sk_new(32, 48)
	_sk_r(g, 0, 0, 32, 48, 0)
	_sk_r(g, 1, 1, 30, 47, 8)
	for x: int in range(2, 30, 7):
		_sk_r(g, x, 2, 6, 46, 9)
		_sk_r(g, x, 2, 1, 46, 10)
		_sk_r(g, x + 5, 2, 1, 46, 8)
		_sk_r(g, x + 6, 2, 1, 46, 0)
		var gx: int = x + 2 + (x / 7) % 3
		for y: int in range(4 + (x * 3) % 9, 46, 11):
			_sk_r(g, gx, y, 1, 4, 8)
	# iron straps: lit top edge, shadow underneath, rivets with a highlight
	for y: int in [8, 36]:
		_sk_r(g, 1, y, 30, 4, 1)
		_sk_r(g, 1, y, 30, 1, 3)
		_sk_r(g, 1, y + 3, 30, 1, 0)
		for x: int in range(4, 30, 8):
			_sk_r(g, x, y + 1, 2, 2, 2)
			_sk_p(g, x, y + 1, 14)
	# claw marks: three gouges, bright bare wood with a dark edge, one of them splintering
	for k: int in range(3):
		_sk_l(g, 8 + k * 3, 12 + k, 12 + k * 3, 33 - k * 2, 0)
		_sk_l(g, 9 + k * 3, 12 + k, 13 + k * 3, 33 - k * 2, 10)
	_sk_art(g, ["0.0", ".1.", "0.0"], 17, 27)
	# handle: ring pull on a dark plate, tarnished
	_sk_r(g, 23, 21, 5, 9, 1)
	_sk_r(g, 23, 21, 5, 1, 3)
	_sk_ring(g, 25.0, 25.0, 2.5, 2.5, 1.2, 10)
	_sk_p(g, 24, 24, 15)
	_sk_p(g, 25, 28, 6)
	_sk_r(g, 24, 29, 3, 1, 0)
	# wet rot at the foot and light under the door
	for x: int in range(2, 30):
		if (x * 5) % 4 != 0:
			_sk_p(g, x, 44 + (x % 2), 1)
	_sk_r(g, 1, 47, 30, 1, 1)
	for x: int in range(3, 29, 5):
		_sk_p(g, x, 47, 4)
	return g


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


# ---------------------------------------------------------------- horror additions (docs/horror_polish_brief.md)

## Idle animation frames for a customer, always 4: 0 neutral, 1 breathing in, 2 blink (eyes shut), 3 head tilt.
## All the same size as customer_texture(look). Play 0,1,0,2 / 0,3 etc. at 6-8 fps.
static func customer_frames(look: Dictionary) -> Array[ImageTexture]:
	var out: Array[ImageTexture] = []
	for f: int in range(4):
		out.append(ImageTexture.create_from_image(_sk_cust_image(look, f)))
	return out


## A faint "wrongness" overlay for a cursed object, same size as object_texture(id), shown once a tell is found.
## Only covers pixels the object itself covers: a glowing hairline crack, a hidden face, a fingerprint smear or
## a scatter of tiny eyes, chosen per id (a few ids have a fixed kind).
static func object_cursed_overlay(id: String) -> ImageTexture:
	var base: Image = _sk_object_image(id, "")
	var w: int = base.get_width()
	var h: int = base.get_height()
	var g: Image = _sk_new(w, h)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) + 4242
	var kind: int = absi(hash(id)) % 4
	var fixed: Dictionary = {"hand_mirror": 1, "oil_portrait": 3, "porcelain_doll": 0, "taxidermy_owl": 3, "snow_globe": 1,
		"photo_album": 1, "marionette": 1, "cameo_brooch": 1, "pocket_watch": 0, "violin": 0}
	kind = int(fixed.get(id, kind))
	var solid: Array[Vector2i] = []
	for y: int in range(h):
		for x: int in range(w):
			if base.get_pixel(x, y).a > 0.5 and _sk_idx(base, x, y) != 0:
				solid.append(Vector2i(x, y))
	if solid.is_empty():
		return ImageTexture.create_from_image(g)
	var minp: Vector2i = solid[0]
	var maxp: Vector2i = solid[0]
	for p: Vector2i in solid:
		minp = Vector2i(mini(minp.x, p.x), mini(minp.y, p.y))
		maxp = Vector2i(maxi(maxp.x, p.x), maxi(maxp.y, p.y))
	var ctr: Vector2i = (minp + maxp) / 2
	var on: Callable = func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < w and y < h and base.get_pixel(x, y).a > 0.5 and _sk_idx(base, x, y) != 0
	match kind:
		0:
			# hairline crack: jagged, red core with a dim halo, a branch and a hot spark
			var x: int = ctr.x + rng.randi_range(-3, 3)
			var y: int = minp.y + 1
			var sx: int = 1 if rng.randf() < 0.5 else -1
			for i: int in range(maxi((maxp.y - minp.y) - 2, 6)):
				if on.call(x, y):
					_sk_p(g, x, y, 13)
					if on.call(x + sx, y) and i % 2 == 0:
						_sk_p(g, x + sx, y, 12)
				y += 1
				if i % 3 == 1:
					x += sx
					sx = -sx if rng.randf() < 0.5 else sx
					if on.call(x, y):
						_sk_p(g, x, y, 13)
				if i == 5:
					_sk_l(g, x, y, x + 3 * sx, y + 2, 12)
			_sk_p(g, ctr.x, ctr.y, 15)
		1:
			# a hidden face: pale pinpricks in two dark sockets and a thin mouth
			var fx: int = ctr.x
			var fy: int = ctr.y - 1
			for p: Vector2i in [Vector2i(fx - 3, fy), Vector2i(fx - 2, fy), Vector2i(fx + 2, fy), Vector2i(fx + 3, fy),
					Vector2i(fx - 3, fy + 1), Vector2i(fx - 2, fy + 1), Vector2i(fx + 2, fy + 1), Vector2i(fx + 3, fy + 1)]:
				if on.call(p.x, p.y):
					_sk_p(g, p.x, p.y, 0)
			for p: Vector2i in [Vector2i(fx - 2, fy), Vector2i(fx + 3, fy)]:
				if on.call(p.x, p.y):
					_sk_p(g, p.x, p.y, 15)
			for i: int in range(-3, 4):
				if on.call(fx + i, fy + 5 - absi(i) / 2) and i % 2 != 0:
					_sk_p(g, fx + i, fy + 5 - absi(i) / 2, 0)
					_sk_p(g, fx + i, fy + 6 - absi(i) / 2, 12)
		2:
			# fingerprint smear: dithered whorls, light on dark materials and dark on light ones
			var c2: Vector2i = ctr + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-1, 3))
			for p: Vector2i in solid:
				var dx: float = float(p.x - c2.x) / 1.0
				var dy: float = float(p.y - c2.y) / 1.3
				var r: float = sqrt(dx * dx + dy * dy)
				if r < 6.5 and (int(r) % 2 == 1) and (p.x + p.y) % 2 == 0:
					var under: int = _sk_idx(base, p.x, p.y)
					_sk_p(g, p.x, p.y, 14 if under < 10 else 2)
		_:
			# tiny eyes opening in the object
			for i: int in range(3):
				var q: Vector2i = solid[rng.randi_range(0, solid.size() - 1)]
				if on.call(q.x + 2, q.y):
					_sk_p(g, q.x, q.y, 13)
					_sk_p(g, q.x + 2, q.y, 13)
					if on.call(q.x + 1, q.y):
						_sk_p(g, q.x + 1, q.y, 0)
	if _sk_opaque(g) < 3:
		for i: int in range(3):
			var q: Vector2i = solid[(i * 7 + 3) % solid.size()]
			_sk_p(g, q.x, q.y, 13)
			if on.call(q.x + 1, q.y + 1):
				_sk_p(g, q.x + 1, q.y + 1, 12)
	return ImageTexture.create_from_image(g)


static func _sk_opaque(g: Image) -> int:
	var n: int = 0
	for y: int in range(g.get_height()):
		for x: int in range(g.get_width()):
			if g.get_pixel(x, y).a > 0.5:
				n += 1
	return n


## Room horror props, all with transparent surroundings:
##  "eyes" 16x6: a pair of slit-pupilled amber eyes, the right one lower and half-lidded.
##  "portrait" 24x32: gilt frame, pale gaunt sitter; the two eye sockets are LEFT BLANK (dark) at (9,13) and (13,13),
##     each 2x2, so the room can draw pupils that follow the player.
##  "silhouette" 40x96: tall wrong figure, black with a faint red rim light on its left edges and two pinprick eyes.
##  "hand" 16x12: long pale hand lying palm down, wrist at the left edge, fingers to the right.
##  "moth" 6x5: dusty moth with wings spread.
##  "clock" 24x48: grandfather clock; dial centred at (12,12) radius 7, pendulum window x 8..15, y 23..38 left dark
##     (the room draws the pendulum there).
static func horror_texture(kind: String) -> ImageTexture:
	var sizes: Dictionary = {"eyes": Vector2i(16, 6), "portrait": Vector2i(24, 32), "silhouette": Vector2i(40, 96),
		"hand": Vector2i(16, 12), "moth": Vector2i(6, 5), "clock": Vector2i(24, 48)}
	var sz: Vector2i = sizes.get(kind, Vector2i(8, 8))
	var g: Image = _sk_new(sz.x, sz.y)
	match kind:
		"eyes":
			_sk_art(g, ["..000..", ".0aaa0.", "0aa0aa0", ".0aaa0.", "..000.."], 0, 0)
			_sk_p(g, 2, 1, 15)
			_sk_art(g, ["..000..", ".0aaa0.", "0aa0aa0", ".00000."], 9, 1)
			_sk_p(g, 11, 2, 15)
		"portrait":
			_sk_t_portrait(g)
		"silhouette":
			_sk_t_silhouette(g)
		"hand":
			_sk_t_hand(g)
		"moth":
			_sk_art(g, [".e..e.", "eeffee", "e4ff4e", ".e44e.", "..44.."], 0, 0)
		"clock":
			_sk_t_clock(g)
		_:
			_sk_r(g, 0, 0, sz.x, sz.y, 0)
	return ImageTexture.create_from_image(g)


static func _sk_t_portrait(g: Image) -> void:
	# gilt frame, lit top-left, with bead corners
	_sk_r(g, 0, 0, 24, 32, 9)
	_sk_r(g, 0, 0, 24, 1, 11)
	_sk_r(g, 0, 0, 1, 32, 11)
	_sk_r(g, 1, 1, 22, 1, 10)
	_sk_r(g, 1, 1, 1, 30, 10)
	_sk_r(g, 23, 1, 1, 31, 8)
	_sk_r(g, 1, 31, 23, 1, 8)
	_sk_r(g, 2, 2, 20, 28, 8)
	for p: Vector2i in [Vector2i(0, 0), Vector2i(21, 0), Vector2i(0, 29), Vector2i(21, 29)]:
		_sk_art(g, ["fa9", "a99", "98."], p.x, p.y)
	# canvas: dark room behind, a pale narrow face, black hair and a high collar
	_sk_r(g, 3, 3, 18, 26, 1)
	_sk_r(g, 3, 3, 9, 14, 2)
	_sk_r(g, 3, 3, 4, 8, 3)
	_sk_art(g, ["..00000..", ".0000000.", "000eee000", "00eeeee00", "00eeeee00", "00eeeee00", "0eeeeeee0", "0eeeeeee0", ".0eeeee0.", ".0eeeee0.", "..0eee0..", "...0e0..."], 8, 6)
	_sk_g_face(g)
	# shoulders and collar
	_sk_r(g, 3, 24, 18, 5, 0)
	_sk_art(g, ["..e....e..", ".ee....ee.", "eee....eee"], 7, 24)
	_sk_art(g, ["4.", "4."], 4, 3)
	# craquelure and a stain creeping in from the corner
	for p: Vector2i in [Vector2i(17, 5), Vector2i(18, 6), Vector2i(18, 7), Vector2i(19, 8), Vector2i(6, 20), Vector2i(5, 21), Vector2i(6, 22), Vector2i(13, 27), Vector2i(14, 28)]:
		_sk_p(g, p.x, p.y, 2 if _sk_idx(g, p.x, p.y) == 1 else 1)
	_sk_art(g, ["5.", "55", ".5"], 19, 3)
	# blank eye sockets (the room draws pupils here)
	_sk_r(g, 9, 13, 2, 2, 0)
	_sk_r(g, 13, 13, 2, 2, 0)


static func _sk_g_face(g: Image) -> void:
	# the face is bone grey: lit planes on the left, hollow cheeks and a shaded right side by hand
	for y: int in range(6, 18):
		for x: int in range(8, 17):
			if _sk_idx(g, x, y) == 14:
				var t: int = 14
				if x <= 10 and y >= 9 and y <= 15:
					t = 15
				elif x >= 15:
					t = 4
				if (y == 15 or y == 16) and (x == 10 or x == 14):
					t = 4
				_sk_p(g, x, y, t)
	_sk_r(g, 12, 14, 1, 2, 4)
	_sk_r(g, 11, 16, 3, 1, 4)
	_sk_p(g, 10, 16, 13)
	_sk_p(g, 14, 16, 13)


static func _sk_t_silhouette(g: Image) -> void:
	var cx: float = 20.0
	# torso and long coat, narrow at the shoulders, with the head too far forward
	for y: int in range(26, 96):
		var hw: float = 11.0 if y < 32 else lerpf(11.0, 8.0, clampf(float(y - 32) / 20.0, 0.0, 1.0))
		if y > 60:
			hw = lerpf(8.0, 11.0, clampf(float(y - 60) / 35.0, 0.0, 1.0))
		var off: float = -1.0 if y < 40 else 0.0
		_sk_r(g, roundi(cx + off - hw), y, roundi(hw * 2.0), 1, 0)
	# head: too tall, tilted toward the left
	for y: int in range(3, 26):
		var t: float = float(y - 3) / 22.0
		var hw2: float = 4.5 + sin(t * PI) * 2.0
		var hc: float = cx - 3.0 + t * 3.0
		_sk_r(g, roundi(hc - hw2), y, roundi(hw2 * 2.0), 1, 0)
	_sk_r(g, 17, 24, 5, 5, 0)
	# arms hang far too long, elbows bent the wrong way, spidery fingers
	_sk_thick(g, 10, 28, 7, 52, 2)
	_sk_thick(g, 7, 52, 9, 78, 2)
	_sk_thick(g, 30, 28, 34, 54, 2)
	_sk_thick(g, 34, 54, 31, 80, 2)
	for i: int in range(4):
		_sk_l(g, 8 + i, 78, 6 + i * 2, 88 + (i % 2) * 2, 0)
		_sk_l(g, 30 + i, 80, 29 + i * 2, 91 - (i % 2), 0)
	# faint red rim light on the left and upper edges
	var src: Image = g.duplicate()
	for y: int in range(96):
		for x: int in range(40):
			if src.get_pixel(x, y).a <= 0.0:
				continue
			var l_open: bool = x == 0 or src.get_pixel(x - 1, y).a <= 0.0
			var t_open: bool = y == 0 or src.get_pixel(x, y - 1).a <= 0.0
			if l_open or (t_open and y < 30):
				_sk_p(g, x, y, 12)
	# two pinprick eyes, close together, too high
	_sk_p(g, 16, 10, 13)
	_sk_p(g, 21, 11, 13)
	_sk_p(g, 16, 11, 12)
	_sk_p(g, 21, 12, 12)


static func _sk_thick(g: Image, x0: int, y0: int, x1: int, y1: int, w: int) -> void:
	for i: int in range(w):
		_sk_l(g, x0 + i, y0, x1 + i, y1, 0)


static func _sk_t_hand(g: Image) -> void:
	_sk_r(g, 0, 5, 4, 4, 14)
	_sk_r(g, 3, 3, 6, 7, 14)
	_sk_r(g, 3, 3, 6, 1, 15)
	_sk_r(g, 0, 5, 4, 1, 15)
	_sk_l(g, 5, 3, 9, 0, 14)
	_sk_l(g, 4, 3, 8, 0, 15)
	var lens: Array[int] = [7, 8, 7, 5]
	for i: int in range(4):
		var fy: int = 3 + i * 2
		for k: int in range(lens[i]):
			var t: int = 15 if i == 0 else 14
			if k == 2 or k == 3:
				t = 4
			if k == lens[i] - 1:
				t = 3
			_sk_p(g, 9 + k, fy, t)
	_sk_outline(g)
	_sk_p(g, 4, 9, 4)
	_sk_p(g, 5, 9, 4)


static func _sk_t_clock(g: Image) -> void:
	# base, trunk, hood: wood lit from the left, black gaps, brass dial and finials
	_sk_r(g, 2, 42, 20, 6, 8)
	_sk_r(g, 2, 42, 20, 1, 9)
	_sk_r(g, 5, 18, 14, 25, 8)
	_sk_r(g, 5, 18, 2, 25, 9)
	_sk_r(g, 17, 18, 2, 25, 1)
	_sk_r(g, 3, 40, 18, 3, 9)
	_sk_r(g, 3, 40, 18, 1, 10)
	_sk_r(g, 2, 3, 20, 17, 8)
	_sk_r(g, 2, 3, 3, 17, 9)
	_sk_r(g, 19, 3, 3, 17, 1)
	_sk_e(g, 12, 6, 9.0, 5.0, 9)
	_sk_r(g, 10, 0, 4, 2, 11)
	_sk_outline(g)
	_sk_e(g, 12, 12, 7.0, 7.0, 11)
	_sk_e(g, 12, 12, 6.0, 6.0, 14)
	_sk_e(g, 12, 12, 4.0, 4.0, 15)
	for p: Vector2i in [Vector2i(12, 6), Vector2i(12, 18), Vector2i(6, 12), Vector2i(18, 12), Vector2i(8, 8), Vector2i(16, 8), Vector2i(8, 16), Vector2i(16, 16)]:
		_sk_p(g, p.x, p.y, 0)
	_sk_l(g, 12, 12, 12, 7, 0)
	_sk_l(g, 12, 12, 16, 14, 12)
	_sk_p(g, 12, 12, 0)
	_sk_r(g, 7, 8, 3, 1, 15)
	# pendulum window: left dark for the room's pendulum, with a lit left frame and a keyhole
	_sk_r(g, 7, 22, 10, 17, 9)
	_sk_r(g, 8, 23, 8, 15, 0)
	_sk_r(g, 8, 23, 1, 15, 1)
	_sk_r(g, 15, 23, 1, 15, 1)
	_sk_p(g, 8, 24, 4)
	_sk_p(g, 8, 25, 4)
	_sk_p(g, 19, 30, 11)
	# veneer cracks, grime at the foot
	_sk_l(g, 5, 28, 5, 34, 1)
	_sk_l(g, 18, 20, 17, 26, 0)
	for x: int in range(3, 21, 2):
		_sk_p(g, x, 46, 1)
	_sk_r(g, 2, 47, 20, 1, 0)


# ---------------------------------------------------------------- shading helpers

static var _sk_lut_d: Dictionary = {}


## Palette index of the pixel at x,y (-1 when transparent or out of bounds).
static func _sk_idx(g: Image, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= g.get_width() or y >= g.get_height():
		return -1
	var c: Color = g.get_pixel(x, y)
	if c.a < 0.5:
		return -1
	if _sk_lut_d.is_empty():
		var pal: PackedColorArray = _sk_pal()
		for i: int in range(pal.size()):
			_sk_lut_d[pal[i].to_rgba32()] = i
	return int(_sk_lut_d.get(c.to_rgba32(), -1))


## Draws a tiny hand-placed sprite: one char per pixel, hex digit = palette index, '.' or ' ' = leave alone.
static func _sk_art(g: Image, rows: Array, ox: int, oy: int) -> void:
	for ry: int in range(rows.size()):
		var row: String = str(rows[ry])
		for rx: int in range(row.length()):
			var i: int = "0123456789abcdef".find(row[rx])
			if i >= 0:
				_sk_p(g, ox + rx, oy + ry, i)


static func _sk_object_image(id: String, category: String) -> Image:
	var g: Image = _sk_new(SK_OBJ, SK_OBJ)
	_sk_draw_object(g, id, category)
	_sk_polish(g, id, 1)
	return g


## Pixel-art finishing for a hand-drawn sprite. Light comes from the top left: a one-step ramp shift gives a lit
## upper-left zone and a shaded lower-right zone (dithered at the transition), silhouette edges facing the light get
## a lighter inner edge and the others a darker one (the outside stays the black outline), then deterministic age:
## a few grime clusters, verdigris creeping on brass, and one hairline crack.
static func _sk_polish(g: Image, id: String, kind: int) -> void:
	var w: int = g.get_width()
	var h: int = g.get_height()
	var idx: PackedInt32Array = PackedInt32Array()
	idx.resize(w * h)
	var minx: int = w
	var maxx: int = 0
	var miny: int = h
	var maxy: int = 0
	for y: int in range(h):
		for x: int in range(w):
			var i: int = _sk_idx(g, x, y)
			idx[y * w + x] = i
			if i >= 0:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	if maxx <= minx or maxy <= miny:
		return
	# solid = opaque and not the dark silhouette outline
	var solid: PackedByteArray = PackedByteArray()
	solid.resize(w * h)
	for y: int in range(h):
		for x: int in range(w):
			var i2: int = idx[y * w + x]
			var is_outline: bool = false
			if i2 == 0:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < 0 or ny < 0 or nx >= w or ny >= h or idx[ny * w + nx] < 0:
						is_outline = true
			solid[y * w + x] = 1 if (i2 >= 0 and not is_outline) else 0
	var out: PackedInt32Array = idx.duplicate()
	var span: float = float((maxx - minx) + (maxy - miny))
	for y: int in range(h):
		for x: int in range(w):
			var p: int = y * w + x
			if solid[p] == 0 or idx[p] == 0:
				continue
			var diag: float = float((x - minx) + (y - miny)) / span
			var c: int = idx[p]
			var chk: bool = (x + y) % 2 == 0
			if diag > 0.7 or (diag > 0.62 and chk):
				c = SK_DARK[c]
			elif diag < 0.1 or (diag < 0.17 and chk):
				c = SK_LIGHT[c]
			# edge bevel: lighter where the neighbour above or left is open, darker below or right
			var top_open: bool = y == 0 or solid[p - w] == 0 or x == 0 or solid[p - 1] == 0
			var bot_open: bool = y == h - 1 or solid[p + w] == 0 or x == w - 1 or solid[p + 1] == 0
			if top_open and not bot_open:
				c = SK_LIGHT[idx[p]] if c == idx[p] else c
			elif bot_open and not top_open:
				c = SK_DARK[c]
			out[p] = c
	# age: seeded so a given id always looks the same
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) + kind
	var cells: Array[Vector2i] = []
	for y: int in range(miny, maxy + 1):
		for x: int in range(minx, maxx + 1):
			if solid[y * w + x] == 1 and out[y * w + x] > 0:
				cells.append(Vector2i(x, y))
	if cells.size() > 30:
		for n: int in range(3):
			var q: Vector2i = cells[rng.randi_range(cells.size() / 3, cells.size() - 1)]
			for d2: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				var qx: int = q.x + d2.x
				var qy: int = q.y + d2.y
				if qx < w and qy < h and solid[qy * w + qx] == 1 and out[qy * w + qx] > 0:
					out[qy * w + qx] = SK_DARK[out[qy * w + qx]]
		# verdigris on brass and tarnish on silver, in pairs along the lower edges
		for q2: Vector2i in cells:
			var o: int = out[q2.y * w + q2.x]
			var below_open: bool = q2.y + 1 >= h or solid[(q2.y + 1) * w + q2.x] == 0
			if below_open and (o == 10 or o == 11 or o == 9) and (q2.x * 7 + q2.y * 13 + hash(id)) % 5 == 0:
				out[q2.y * w + q2.x] = 6
				if q2.x + 1 < w and solid[q2.y * w + q2.x + 1] == 1 and out[q2.y * w + q2.x + 1] > 8:
					out[q2.y * w + q2.x + 1] = 6
		# one hairline crack
		var s0: Vector2i = cells[rng.randi_range(cells.size() / 4, cells.size() / 2)]
		var sx: int = 1 if rng.randf() < 0.5 else -1
		var cx: int = s0.x
		var cy: int = s0.y
		for step: int in range(rng.randi_range(5, 7)):
			if cx < 0 or cy < 0 or cx >= w or cy >= h or solid[cy * w + cx] == 0:
				break
			var cur: int = out[cy * w + cx]
			if cur > 0:
				out[cy * w + cx] = SK_DARK[SK_DARK[cur]]
			cy += 1
			if step % 2 == 1:
				cx += sx
	for y: int in range(h):
		for x: int in range(w):
			var v: int = out[y * w + x]
			if v >= 0 and v != idx[y * w + x]:
				_sk_p(g, x, y, v)
