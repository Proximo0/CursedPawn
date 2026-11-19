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

## Body plan per customer type, "body[,accessory]". Body: normal, hunched, tall (thin), broad, child. Accessory: veil,
## hat, cane, satchel. A look dictionary may override it with its own "plan" (and "hat": top, soft, wide) key.
const SK_PLAN: Dictionary = {
	"widow": "hunched,veil", "estate_clearer": "broad,satchel", "nervous_heir": "child", "fence": "hunched,hat",
	"haggler": "hunched,cane", "medium": "tall,veil", "collector": "tall,hat", "tourist": "normal,satchel",
	"ghost_hunter": "tall,satchel", "decorator": "normal,cane", "priest": "broad,hat", "rival": "normal,hat",
}
const SK_HAT: Dictionary = {"fence": "soft", "collector": "top", "priest": "wide", "rival": "soft"}

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
## Gaunt hooded figure, uneven shoulders, long pale fingers; the eyes differ per type (see SK_EYE_STYLE) and so does
## the body plan (hunched, tall and thin, broad, child-sized; veil, hat brim, cane or satchel: see SK_PLAN).
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
	var plan: PackedStringArray = str(look.get("plan", SK_PLAN.get(id, "normal"))).split(",")
	var body: String = plan[0]
	var acc: String = plan[1] if plan.size() > 1 else ""
	var wf: float = 1.0
	var hf: float = 1.0
	var drop: float = 0.0
	var hump: float = 0.0
	var kid: bool = body == "child"
	match body:
		"hunched":
			drop = 4.0
			hump = 4.0
			lean = -6.0
		"tall":
			wf = 0.8
			hf = 0.92
		"broad":
			wf = 1.3
	var rise: int = 1 if (frame == 1 and not kid) else 0
	var tilt: float = 4.5 if frame == 3 else 0.0
	for y: int in range(SK_CUST_H):
		var ys: float = float(y + (rise if y < 62 else 0))
		var ysrc: float = ys - drop * clampf((46.0 - float(y)) / 43.0, 0.0, 1.0)
		var hl: float = _sk_interp(SK_HL, ysrc)
		if hl < 0.0:
			continue
		var hr: float = _sk_interp(SK_HR, ysrc)
		var fw: float = lerpf(hf, wf, clampf((ysrc - 34.0) / 8.0, 0.0, 1.0))
		hl *= fw
		hr = hr * fw + hump * sin(PI * clampf((ysrc - 34.0) / 28.0, 0.0, 1.0))
		var widen: float = float(rise) if ysrc > 37.0 and ysrc < 60.0 else 0.0
		var shift: float = _sk_head_shift(ysrc, lean, tilt)
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
		if ysrc >= 44.0:
			for k: int in range(3):
				var fy0: int = [46, 52, 44][k]
				var fy1: int = 95 - k * 5
				if y >= fy0 and y <= fy1:
					var fx: int = xl + roundi([0.30, 0.54, 0.79][k] * span) + (y - fy0) / 14
					_sk_p(g, fx, y, sh2)
					if (y + k) % 3 != 0:
						_sk_p(g, fx - 1, y, lit)
	var hy: int = 25 + roundi(drop)
	var ysh: float = float(hy) - drop * clampf((46.0 - float(hy)) / 43.0, 0.0, 1.0)
	var hx: int = 32 + roundi(_sk_head_shift(ysh, lean, tilt))
	var sy: int = 36 - rise + roundi(drop * 0.5)
	# cloth draped over the shoulders (left catches the light, right falls into shadow)
	_sk_l(g, hx - roundi(8.0 * wf), sy, hx - roundi(15.0 * wf), sy + 9, lit)
	_sk_l(g, hx - roundi(8.0 * wf), sy + 1, hx - roundi(14.0 * wf), sy + 9, sh)
	_sk_l(g, hx + roundi(8.0 * wf), sy + 1, hx + roundi(16.0 * wf), sy + 11, sh2)
	_sk_l(g, hx + roundi(7.0 * wf), sy + 1, hx + roundi(14.0 * wf), sy + 10, base)
	var rx: float = 8.0
	var ry: float = 11.0
	if kid:
		g = _sk_cust_shrink(g, 0.75)
		hx = 32 + roundi(float(hx - 32) * 0.75)
		hy = 95 + roundi(float(hy - 95) * 0.75)
		rx = 6.2
		ry = 8.0
		if frame == 1:
			var src: Image = g.duplicate()
			g.fill_rect(Rect2i(0, 0, SK_CUST_W, 61), Color(0, 0, 0, 0))
			g.blit_rect(src, Rect2i(0, 1, SK_CUST_W, 61), Vector2i(0, 0))
			hy -= 1
	# hood opening with a thick rim of cloth
	for y: int in range(hy - 13, hy + 15):
		for x: int in range(hx - 13, hx + 14):
			var dx: float = float(x - hx) / rx
			var dy: float = float(y - hy) / ry
			var d: float = dx * dx + dy * dy
			if g.get_pixel(x, y).a <= 0.0:
				continue
			if d <= 1.0:
				_sk_p(g, x, y, 0)
			elif d <= 1.5:
				_sk_p(g, x, y, lit if (x - hx) + (y - hy) < 0 else sh2)
	# gaunt hollows inside the dark
	var hol: int = 5 if kid else 6
	_sk_r(g, hx - hol, hy + 4, 1, 2, 1)
	_sk_r(g, hx + hol, hy + 4, 1, 2, 1)
	if acc == "veil":
		for y: int in range(hy - 13, hy + 19):
			var vw: int = roundi(lerpf(9.0, 15.0, clampf(float(y - hy + 13) / 30.0, 0.0, 1.0)) * maxf(wf, 0.9))
			for x: int in range(hx - vw, hx + vw + 1):
				if (x + y) % 2 != 0 and y < hy + 18:
					continue
				var cur: int = _sk_idx(g, x, y)
				if cur < 0:
					_sk_p(g, x, y, 2)
				elif cur == 0:
					_sk_p(g, x, y, 2 if y < hy + 18 else 3)
				else:
					_sk_p(g, x, y, SK_DARK[cur])
	elif acc == "hat":
		_sk_cust_hat(g, hx, hy - 11, str(look.get("hat", SK_HAT.get(id, "soft"))), base, lit, sh, sh2)
	var style: String = str(SK_EYE_STYLE.get(id, SK_STYLES[hsh % SK_STYLES.size()]))
	_sk_cust_eyes(g, hx, hy, eyes, style, frame == 2)
	if acc == "cane":
		var cx: int = 32 - roundi(21.0 * wf) - 3
		_sk_r(g, cx, 60, 2, 36, 9)
		_sk_r(g, cx, 60, 1, 36, 10)
		_sk_r(g, cx - 3, 57, 5, 2, 9)
		_sk_r(g, cx - 3, 57, 5, 1, 10)
		_sk_r(g, cx - 4, 58, 2, 3, 11)
		_sk_r(g, cx, 94, 2, 2, 8)
	elif acc == "satchel":
		var bx: int = mini(32 + roundi(19.0 * wf) - 6, 50)
		_sk_l(g, hx - roundi(8.0 * wf), 38, bx + 5, 62, 9)
		_sk_l(g, hx - roundi(8.0 * wf) + 1, 38, bx + 6, 62, 8)
		_sk_r(g, bx, 62, 12, 15, 9)
		_sk_r(g, bx, 62, 12, 5, 10)
		_sk_r(g, bx, 62, 12, 1, 11)
		_sk_r(g, bx + 5, 66, 2, 3, 11)
		_sk_r(g, bx + 11, 62, 1, 15, 8)
		_sk_r(g, bx, 76, 12, 1, 8)
	_sk_cust_hand(g, 32 - roundi(10.0 * wf), 80, -1, base, lit, sh2, body, acc, hsh)
	_sk_cust_hand(g, 32 + roundi(10.0 * wf), 82, 1, base, lit, sh2, body, acc, hsh)
	_sk_outline(g)
	return g


## Nearest-neighbour shrink about the bottom centre (a child-sized figure standing on the same floor line).
static func _sk_cust_shrink(g: Image, s: float) -> Image:
	var out: Image = _sk_new(SK_CUST_W, SK_CUST_H)
	for y: int in range(SK_CUST_H):
		for x: int in range(SK_CUST_W):
			var sx: int = roundi(32.0 + (float(x) - 32.0) / s)
			var sy: int = roundi(95.0 + (float(y) - 95.0) / s)
			if sx >= 0 and sx < SK_CUST_W and sy >= 0 and sy < SK_CUST_H:
				var c: Color = g.get_pixel(sx, sy)
				if c.a > 0.0:
					out.set_pixel(x, y, c)
	return out


## A hat over the hood: "top" tall and straight, "soft" a pinched fedora, "wide" a low crown with a huge brim.
static func _sk_cust_hat(g: Image, hx: int, brim_y: int, kind: String, base: int, lit: int, sh: int, sh2: int) -> void:
	var crown_h: int = 7
	var cw: int = 7
	var brx: float = 15.0
	match kind:
		"top":
			crown_h = 11
			cw = 6
			brx = 12.0
		"wide":
			crown_h = 5
			cw = 8
			brx = 20.0
	for y: int in range(0, brim_y):
		_sk_r(g, hx - 16, y, 33, 1, -1)
	for y: int in range(brim_y - crown_h, brim_y + 1):
		var t: float = float(brim_y - y) / float(crown_h)
		var hw: int = cw if kind != "soft" else cw - roundi(t * 2.5)
		_sk_r(g, hx - hw, y, hw * 2 + 1, 1, base)
		_sk_p(g, hx - hw, y, lit)
		_sk_p(g, hx + hw, y, sh)
	if kind == "soft":
		_sk_r(g, hx - 1, brim_y - crown_h, 3, 1, sh)
	_sk_r(g, hx - cw, brim_y - 2, cw * 2 + 1, 2, sh2)
	_sk_e(g, float(hx), float(brim_y + 1), brx, 2.2, base)
	_sk_r(g, hx - roundi(brx) + 2, brim_y + 2, roundi(brx) * 2 - 3, 1, sh2)
	_sk_r(g, hx - roundi(brx) + 1, brim_y, 5, 1, lit)


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


## One hand resting on the counter, drawn per body plan so no two types share a pair of hands: normal = long bony
## fingers; hunched = short, knotted and curled with age spots; tall = spidery, far too long; broad = thick and
## stubby with a ring; child = small and smooth. A veil gets lace gloves, a hat gloves of soft leather, a cane a
## white-knuckled grip. `hsh` varies the finger lengths a little within a plan.
static func _sk_cust_hand(g: Image, x: int, y: int, side: int, base: int, lit: int, sh2: int, body: String, acc: String, hsh: int) -> void:
	var skin: int = 14
	var skin_lit: int = 15
	var knuckle: int = 4
	if acc == "veil":  # lace gloves: dark with pale holes
		skin = 2
		skin_lit = 3
		knuckle = 1
	elif acc == "hat":  # soft leather gloves
		skin = 8
		skin_lit = 9
		knuckle = 0
	var lens: Array[int] = [7, 10, 9, 6]
	var pw: int = 9
	var ph: int = 3
	var fw: int = 1
	match body:
		"hunched":
			lens = [4, 6, 6, 3]
			pw = 8
		"tall":
			lens = [9, 14, 13, 8]
			pw = 7
			ph = 4
		"broad":
			lens = [5, 6, 6, 4]
			pw = 11
			ph = 4
			fw = 2
		"child":
			lens = [3, 5, 5, 3]
			pw = 6
			ph = 2
	if side > 0:
		lens = [lens[3], lens[2], lens[1], lens[0]]
	lens[hsh % 4] += 1
	_sk_e(g, x, y, float(pw) * 0.66, 2.5, sh2)
	_sk_r(g, x - 5, y - 2, 6, 1, lit)
	var px: int = x - pw / 2
	_sk_r(g, px, y + 1, pw, ph, skin)
	_sk_r(g, px, y + 1, pw, 1, skin_lit)
	_sk_r(g, px + pw - 1, y + 1, 1, ph, knuckle)
	var spread: int = 2
	if body == "broad":
		spread = 3
	elif body == "child":
		spread = 1
	var n: int = 4
	for i: int in range(n):
		var fx: int = px + 1 + i * spread
		var ln: int = lens[i]
		for k: int in range(ln):
			var tone: int = skin_lit if i == 0 else skin
			if k == 3 and i % 2 == 0:
				tone = knuckle
			elif k >= ln - 1:
				tone = 3 if acc == "" else knuckle
			var splay: int = roundi(float(k) * (float(i) - 1.5) / 5.0)
			if body == "hunched" and k >= 2:  # arthritic curl, each finger bends toward the thumb
				splay -= (k - 1) * side
			if body == "tall":
				splay = roundi(float(splay) * 0.5)
			for w: int in range(fw):
				_sk_p(g, fx + splay + w, y + 1 + ph + k, tone)
		if acc == "veil" and i % 2 == 1:  # a lace hole
			_sk_p(g, fx, y + 1 + ph + 1, 3)
	if body == "hunched":  # age spots
		_sk_p(g, px + 2, y + 2, 13)
		_sk_p(g, px + 5, y + 3, 12)
	elif body == "broad":  # a heavy ring on the second finger
		_sk_r(g, px + 1 + spread, y + ph + 3, 2, 1, 11)
		_sk_p(g, px + 1 + spread, y + ph + 2, 10)
	elif body == "tall":  # a long thumbnail and a tendon
		_sk_l(g, px + 1, y + 1, px + pw - 2, y + 1, 15)
	elif body == "child":  # a chewed nail
		_sk_p(g, px + 1, y + ph + lens[0], 13)
	if acc == "cane" and side > 0 and body != "hunched":
		_sk_r(g, px, y + 1, pw, 1, 15)
	_sk_l(g, x - side * 5, y + 2, x - side * 8, y + 7 - (2 if body == "child" else 0), skin)


static func tool_texture(tool: String) -> ImageTexture:
	if tool == "pendulum":
		return pendulum_texture()
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
			if m >= 8 and m <= 14:
				t = 2
			elif m == 15:
				t = 2
			_sk_p(g, x, y, t)
	# damask lozenges on the light stripe, each lit on its upper left
	for o: Vector2i in [Vector2i(4, 6), Vector2i(4, 22)]:
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
	_sk_r(g, 24, 14, 1, 9, 5)
	_sk_p(g, 25, 15, 5)
	_sk_p(g, 24, 23, 6)
	# brown tide mark low on the left, fading by dither
	for y: int in range(22, 30):
		for x: int in range(2, 12):
			var d2: float = pow(float(x - 6) / 5.0, 2.0) + pow(float(y - 26) / 3.0, 2.0)
			if d2 < 0.5 or (d2 < 1.0 and (x + y) % 2 == 0):
				_sk_p(g, x, y, 8 if g.get_pixel(x, y) == _sk_col(2) else 1)
	# one soot smear and one patch of mildew; nothing smaller
	_sk_r(g, 10, 11, 4, 2, 1)
	_sk_r(g, 11, 13, 2, 1, 1)
	_sk_r(g, 27, 24, 3, 3, 5)
	_sk_p(g, 27, 24, 6)
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
	for i: int in range(7):
		var gx: int = rng.randi_range(0, 31)
		var gy: int = rng.randi_range(0, 31)
		var gl: int = rng.randi_range(8, 12)
		for k: int in range(gl):
			var cur: int = _sk_idx(g, (gx + k) % 32, gy)
			if cur == 9:
				_sk_p(g, (gx + k) % 32, gy, 8)
	# joints with a lit right edge and nail heads
	for r: int in range(4):
		var jx2: int = (r * 13 + 5) % 32
		for y: int in range(r * 8 + 1, r * 8 + 6):
			_sk_p(g, jx2, y, 0)
			_sk_p(g, (jx2 + 1) % 32, y, 10 if _sk_idx(g, (jx2 + 1) % 32, y) == 9 else 9)
	# knot
	_sk_art(g, [".888.", "81118", "81018", "81118", ".888."], 20, 13)
	# spilled stain, dithered at the rim
	for y: int in range(1, 9):
		for x: int in range(3, 15):
			var d: float = pow(float(x - 9) / 6.0, 2.0) + pow(float(y - 4) / 3.5, 2.0)
			var cur2: int = _sk_idx(g, x, y)
			if cur2 != 0 and d < 0.8:
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
	# dark ringlets behind and beside a pale cracked face, a faded red dress with a lace hem
	_sk_e(g, 16, 7, 8.0, 6.5, 2)
	_sk_r(g, 8, 7, 3, 11, 2)
	_sk_r(g, 21, 7, 3, 11, 2)
	_sk_r(g, 8, 18, 3, 2, 2)
	_sk_r(g, 21, 18, 3, 2, 2)
	_sk_e(g, 16, 11, 5.5, 6.5, 15)
	_sk_r(g, 11, 4, 10, 3, 2)
	_sk_r(g, 14, 17, 4, 3, 14)
	for y: int in range(19, 31):
		var hw: int = 4 + (y - 19) * 7 / 12
		_sk_r(g, 16 - hw, y, hw * 2, 1, 12)
	_sk_r(g, 12, 19, 8, 2, 14)
	_sk_r(g, 9, 20, 3, 3, 12)
	_sk_r(g, 21, 20, 3, 3, 12)
	_sk_r(g, 9, 23, 3, 4, 14)
	_sk_r(g, 21, 23, 3, 4, 14)
	_sk_outline(g)
	for x: int in range(6, 27, 2):
		_sk_p(g, x, 30, 15)
	_sk_r(g, 15, 19, 2, 11, 13)
	_sk_r(g, 12, 10, 3, 2, 0)
	_sk_p(g, 13, 10, 15)
	_sk_r(g, 18, 10, 3, 3, 0)
	_sk_l(g, 16, 6, 14, 10, 3)
	_sk_l(g, 14, 10, 15, 13, 3)
	_sk_l(g, 15, 13, 13, 16, 3)
	_sk_l(g, 15, 13, 18, 14, 3)
	_sk_r(g, 19, 14, 2, 2, 0)
	_sk_r(g, 15, 14, 3, 1, 13)
	_sk_p(g, 17, 15, 12)
	_sk_p(g, 11, 13, 13)
	_sk_p(g, 16, 12, 14)


static func _sk_o_jack_in_box(g: Image) -> void:
	# painted box with a crank and a sprung lid, a zig-zag spring, a jester head with a far too wide grin
	_sk_r(g, 6, 22, 20, 9, 3)
	_sk_r(g, 5, 21, 22, 2, 10)
	_sk_r(g, 6, 26, 20, 1, 4)
	_sk_l(g, 5, 21, 2, 15, 9)
	_sk_l(g, 6, 21, 3, 15, 9)
	_sk_r(g, 26, 25, 4, 1, 14)
	_sk_r(g, 29, 23, 2, 4, 11)
	for y: int in range(17, 21):
		_sk_r(g, 13 + (y % 2) * 5, y, 3, 1, 14)
	_sk_e(g, 16, 11, 5.5, 5.0, 15)
	for i: int in range(6):
		_sk_r(g, 10 - i, 5 - (i * 4) / 5, 5, 1, 13)
		_sk_r(g, 17 + i, 5 - (i * 4) / 5, 5, 1, 4)
	_sk_r(g, 10, 5, 12, 2, 10)
	_sk_p(g, 5, 0, 11)
	_sk_p(g, 27, 0, 11)
	_sk_outline(g)
	_sk_r(g, 12, 9, 3, 2, 0)
	_sk_r(g, 18, 9, 3, 2, 0)
	_sk_p(g, 13, 10, 11)
	_sk_p(g, 19, 10, 11)
	_sk_r(g, 15, 11, 2, 2, 13)
	_sk_r(g, 11, 13, 11, 3, 0)
	_sk_p(g, 10, 12, 0)
	_sk_p(g, 22, 12, 0)
	for x: int in range(12, 21, 2):
		_sk_p(g, x, 13, 15)
		_sk_p(g, x + 1, 15, 15)
	_sk_r(g, 8, 24, 1, 5, 11)
	_sk_r(g, 23, 24, 1, 5, 11)


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
	# crossed control bars, a wooden puppet with a dropped jaw and a hopelessly tangled set of strings
	_sk_r(g, 3, 0, 26, 2, 9)
	_sk_r(g, 14, 2, 4, 3, 10)
	_sk_e(g, 16, 11, 3.5, 4.0, 10)
	_sk_r(g, 12, 16, 8, 7, 12)
	_sk_r(g, 12, 16, 8, 1, 13)
	_sk_l(g, 12, 17, 7, 20, 12)
	_sk_l(g, 12, 18, 7, 21, 12)
	_sk_l(g, 7, 20, 6, 14, 12)
	_sk_l(g, 8, 20, 7, 14, 12)
	_sk_l(g, 20, 17, 25, 21, 12)
	_sk_l(g, 20, 18, 25, 22, 12)
	_sk_l(g, 25, 21, 26, 27, 12)
	_sk_l(g, 24, 21, 25, 27, 12)
	_sk_r(g, 5, 12, 3, 2, 10)
	_sk_r(g, 25, 27, 3, 2, 10)
	_sk_l(g, 14, 23, 12, 27, 3)
	_sk_l(g, 15, 23, 13, 27, 3)
	_sk_l(g, 12, 27, 9, 30, 3)
	_sk_l(g, 13, 27, 10, 30, 3)
	_sk_l(g, 18, 23, 21, 27, 3)
	_sk_l(g, 19, 23, 22, 27, 3)
	_sk_l(g, 21, 27, 23, 31, 3)
	_sk_l(g, 22, 27, 24, 31, 3)
	_sk_r(g, 11, 26, 3, 2, 10)
	_sk_r(g, 20, 26, 3, 2, 10)
	_sk_r(g, 7, 30, 4, 1, 9)
	_sk_r(g, 22, 30, 4, 1, 9)
	_sk_outline(g)
	_sk_r(g, 14, 9, 2, 2, 0)
	_sk_r(g, 17, 9, 2, 2, 0)
	_sk_p(g, 14, 10, 11)
	_sk_p(g, 18, 10, 11)
	_sk_p(g, 16, 11, 9)
	_sk_p(g, 13, 12, 13)
	_sk_p(g, 19, 12, 13)
	_sk_r(g, 15, 13, 3, 2, 0)
	_sk_p(g, 13, 14, 8)
	_sk_p(g, 19, 14, 8)
	# strings: three clean, straight lines from the bars (head and both hands), none crossing the body
	_sk_l(g, 16, 5, 16, 7, 14)
	_sk_l(g, 4, 2, 6, 12, 14)
	_sk_l(g, 28, 2, 27, 27, 14)
	_sk_p(g, 4, 1, 15)
	_sk_p(g, 28, 1, 15)


static func _sk_o_toy_theatre(g: Image) -> void:
	# a gilt proscenium and a stage with a tight red curtain; something shows in the gap
	_sk_r(g, 2, 27, 28, 4, 9)
	_sk_r(g, 3, 8, 4, 19, 10)
	_sk_r(g, 25, 8, 4, 19, 10)
	_sk_r(g, 7, 8, 18, 19, 1)
	_sk_r(g, 3, 5, 26, 3, 11)
	_sk_r(g, 8, 3, 16, 2, 10)
	_sk_r(g, 12, 1, 8, 2, 11)
	_sk_r(g, 7, 8, 9, 18, 13)
	_sk_r(g, 16, 8, 9, 18, 13)
	_sk_outline(g)
	for x: int in [9, 12, 19, 22]:
		_sk_r(g, x, 11, 1, 15, 12)
	_sk_r(g, 7, 8, 18, 3, 12)
	for x: int in range(7, 25, 2):
		_sk_p(g, x, 11, 11)
	_sk_r(g, 15, 12, 2, 14, 0)
	_sk_p(g, 15, 16, 11)
	_sk_p(g, 16, 19, 11)
	for x: int in [6, 11, 16, 21, 26]:
		_sk_p(g, x, 26, 11)
	_sk_r(g, 4, 27, 24, 1, 8)
	_sk_p(g, 16, 3, 0)
	_sk_p(g, 8, 20, 11)
	_sk_p(g, 23, 20, 11)


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


## Upright book in three-quarter view: spine strip on the left, cover, page block peeking out below.
static func _sk_bk_block(g: Image, x: int, y: int, w: int, h: int, sp: int, cov: int, spc: int) -> void:
	_sk_r(g, x, y, w, h - 2, cov)
	_sk_r(g, x, y, sp, h - 2, spc)
	_sk_r(g, x + sp, y + h - 2, w - sp - 1, 2, 14)
	_sk_r(g, x + sp, y + h - 2, w - sp - 1, 1, 15)
	_sk_p(g, x + sp + 3, y + h - 1, 4)
	_sk_p(g, x + sp + 8, y + h - 1, 4)


## Diary: red cloth, gold spine bands, a leather strap with a big brass padlock and a stained corner.
static func _sk_bk_diary(g: Image) -> void:
	_sk_bk_block(g, 6, 2, 20, 28, 4, 13, 12)
	_sk_outline(g)
	for y: int in [5, 12, 19, 25]:
		_sk_r(g, 6, y, 4, 1, 11)
	_sk_r(g, 10, 14, 16, 3, 9)
	for x: int in range(11, 26, 3):
		_sk_p(g, x, 15, 10)
	_sk_r(g, 16, 17, 6, 6, 11)
	_sk_r(g, 17, 13, 4, 1, 14)
	_sk_r(g, 17, 14, 1, 3, 14)
	_sk_r(g, 20, 14, 1, 3, 14)
	_sk_r(g, 18, 19, 2, 2, 0)
	_sk_p(g, 18, 21, 0)
	_sk_r(g, 12, 4, 12, 1, 11)
	_sk_r(g, 20, 21, 5, 4, 12)
	_sk_p(g, 22, 23, 8)
	_sk_p(g, 12, 7, 11)
	_sk_p(g, 22, 8, 11)


## Hymnal: slim black book, a gold cross split by a crack, brass corners and a red ribbon hanging from the bottom.
static func _sk_bk_hymnal(g: Image) -> void:
	_sk_bk_block(g, 8, 3, 16, 26, 3, 2, 1)
	_sk_r(g, 15, 28, 2, 4, 13)
	_sk_p(g, 15, 31, -1)
	_sk_outline(g)
	for y: int in [6, 12, 18, 23]:
		_sk_r(g, 8, y, 3, 1, 10)
	_sk_r(g, 17, 7, 2, 13, 11)
	_sk_r(g, 14, 10, 8, 2, 11)
	_sk_l(g, 15, 8, 19, 17, 0)
	_sk_r(g, 11, 3, 3, 1, 10)
	_sk_r(g, 11, 3, 1, 3, 10)
	_sk_r(g, 21, 3, 3, 1, 10)
	_sk_r(g, 11, 23, 3, 1, 10)
	_sk_r(g, 11, 21, 1, 3, 10)
	_sk_r(g, 21, 23, 3, 1, 10)
	_sk_r(g, 23, 21, 1, 3, 10)
	_sk_r(g, 13, 22, 8, 1, 3)


## Almanac: floppy tan paperback, a stitched spine, a dog-eared corner, a sun above and a moon below.
static func _sk_bk_almanac(g: Image) -> void:
	_sk_bk_block(g, 7, 3, 19, 26, 2, 9, 8)
	for i: int in range(4):
		for j: int in range(4):
			if i - j >= 1:
				_sk_p(g, 22 + i, 3 + j, -1)
	_sk_p(g, 7, 26, -1)
	_sk_outline(g)
	for y: int in range(5, 26, 3):
		_sk_r(g, 8, y, 1, 2, 14)
	_sk_r(g, 21, 4, 2, 1, 14)
	_sk_r(g, 22, 5, 3, 1, 14)
	_sk_r(g, 23, 6, 2, 1, 14)
	_sk_e(g, 17, 10, 3.0, 3.0, 11)
	for p: Vector2i in [Vector2i(17, 5), Vector2i(17, 15), Vector2i(12, 10), Vector2i(22, 10), Vector2i(13, 6), Vector2i(21, 14)]:
		_sk_p(g, p.x, p.y, 11)
	_sk_e(g, 17, 21, 4.0, 4.0, 15)
	_sk_e(g, 19, 20, 3.5, 3.5, 9)
	_sk_p(g, 12, 18, 11)
	_sk_p(g, 13, 25, 11)
	_sk_r(g, 10, 27, 7, 1, 8)


## Photo album: wide, bound in pale leather the colour of skin (pores, a stitched seam), a window showing a pale
## face, and a brass clasp.
static func _sk_bk_album(g: Image) -> void:
	_sk_bk_block(g, 3, 5, 26, 24, 4, 14, 10)
	_sk_r(g, 28, 14, 3, 4, 11)
	_sk_outline(g)
	for y: int in range(5, 27):
		for x: int in range(7, 29):
			if _sk_idx(g, x, y) == 14:
				if (x * 5 + y * 3) % 7 == 0:
					_sk_p(g, x, y, 10)
				elif (x * 3 + y * 7) % 13 == 0:
					_sk_p(g, x, y, 9)
	for y: int in range(6, 26, 2):
		_sk_p(g, 8, y, 8)
	_sk_r(g, 12, 8, 12, 12, 8)
	_sk_r(g, 13, 9, 10, 10, 2)
	_sk_e(g, 18, 14, 3.0, 4.0, 15)
	_sk_r(g, 16, 13, 1, 2, 0)
	_sk_r(g, 19, 13, 1, 2, 0)
	_sk_r(g, 17, 17, 2, 1, 0)
	_sk_p(g, 30, 16, 0)
	for p: Vector2i in [Vector2i(12, 8), Vector2i(23, 8), Vector2i(12, 19), Vector2i(23, 19)]:
		_sk_p(g, p.x, p.y, 11)


## Herbarium: dark green press-book held shut by two buckled straps, a bone label with a pressed leaf, a fern
## escaping from the top.
static func _sk_bk_herbarium(g: Image) -> void:
	_sk_bk_block(g, 5, 8, 21, 22, 3, 6, 5)
	_sk_l(g, 16, 8, 16, 2, 7)
	for y: int in [2, 4, 6]:
		_sk_r(g, 13, y, 3, 1, 7)
		_sk_r(g, 17, y, 3, 1, 7)
	_sk_e(g, 28, 14, 2.5, 1.5, 7)
	_sk_e(g, 28, 22, 2.5, 1.5, 6)
	_sk_outline(g)
	_sk_r(g, 11, 8, 2, 19, 8)
	_sk_r(g, 20, 8, 2, 19, 8)
	_sk_r(g, 10, 22, 4, 3, 11)
	_sk_r(g, 19, 22, 4, 3, 11)
	_sk_p(g, 11, 23, 0)
	_sk_p(g, 20, 23, 0)
	_sk_r(g, 14, 11, 5, 8, 15)
	_sk_l(g, 15, 18, 17, 12, 6)
	_sk_e(g, 17, 14, 1.2, 1.5, 7)
	_sk_r(g, 8, 8, 1, 20, 7)
	_sk_p(g, 28, 18, 13)


## First edition: black and gold, a brass fore-edge clasp, and a huge open eye with a slit pupil on the cover.
static func _sk_bk_first_edition(g: Image) -> void:
	_sk_bk_block(g, 7, 2, 19, 28, 5, 1, 9)
	_sk_r(g, 25, 19, 3, 4, 11)
	_sk_outline(g)
	for y: int in [5, 11, 17, 23]:
		_sk_r(g, 7, y, 5, 1, 11)
	_sk_r(g, 12, 4, 13, 1, 11)
	_sk_r(g, 12, 25, 13, 1, 11)
	_sk_r(g, 12, 4, 1, 22, 11)
	_sk_r(g, 24, 4, 1, 22, 11)
	_sk_art(g, ["..bbbbbbb..", ".bfffffffb.", "bffaa0aaffb", "bffaa0aaffb", "bffaa0aaffb", ".bfffffffb.", "..bbbbbbb.."], 13, 10)
	_sk_p(g, 14, 14, 13)
	_sk_p(g, 22, 14, 13)
	_sk_r(g, 14, 20, 9, 1, 11)
	_sk_r(g, 16, 22, 5, 1, 11)
	_sk_p(g, 27, 21, 0)


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
##  "silhouette" 40x96: tall wrong figure, black with a lit red rim and two pinprick eyes, standing on a dark red
##     oval backdrop (opaque in the middle, dithered out to transparent at the edges and corners).
##  "hand" 16x12: long pale hand lying palm down, wrist at the left edge, fingers to the right.
##  "moth" 8x7: dusty moth with wings spread, eyespots on the wings and two antennae.
##  "clock" 24x48: grandfather clock; dial centred at (12,12) radius 7, pendulum window x 8..15, y 23..38 left dark
##     (the room draws the pendulum there).
static func horror_texture(kind: String) -> ImageTexture:
	var sizes: Dictionary = {"eyes": Vector2i(24, 10), "portrait": Vector2i(24, 32), "silhouette": Vector2i(64, 144),
		"hand": Vector2i(16, 12), "moth": Vector2i(8, 7), "clock": Vector2i(24, 48)}
	var sz: Vector2i = sizes.get(kind, Vector2i(8, 8))
	var g: Image = _sk_new(sz.x, sz.y)
	match kind:
		"eyes":
			# two big almond eyes: dark red lids, glowing amber irises, black slit pupils, a weeping streak
			var eye_rows: Array = ["...00000...", ".0ddd0ddd0.", "0ddbb0bbdd0", "0dbbb0bbbd0", "0ddbb0bbdd0", ".0ddd0ddd0.", "...00000..."]
			_sk_art(g, eye_rows, 0, 1)
			_sk_art(g, eye_rows, 13, 1)
			_sk_r(g, 2, 0, 7, 1, 12)
			_sk_r(g, 15, 0, 7, 1, 12)
			_sk_p(g, 3, 3, 15)
			_sk_p(g, 16, 3, 15)
			_sk_p(g, 19, 8, 12)
			_sk_p(g, 19, 9, 12)
		"portrait":
			_sk_t_portrait(g)
		"silhouette":
			_sk_t_silhouette(g)
		"hand":
			_sk_t_hand(g)
		"moth":
			_sk_art(g, ["..e..e..", "eee44eee", "e4f44f4e", "e404404e", ".e4ff4e.", "..e44e..", "...44..."], 0, 0)
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
	# textured blood-red backdrop with a vignette: a hot halo behind the head, streaks like torn curtain, a rim that
	# dithers down to black and then to nothing
	for y: int in range(144):
		for x: int in range(64):
			var d: float = pow((float(x) - 31.5) / 32.0, 2.0) + pow((float(y) - 71.5) / 72.0, 2.0)
			if d >= 1.0:
				continue
			var n: int = (x * 7 + y * 13 + (x / 3) * (y / 5)) % 5
			var streak: bool = (x * 5 + y / 9) % 7 == 0
			var chk: bool = (x + y) % 2 == 0
			var c: int = 12
			if d < 0.22:
				c = 13 if n > 0 else 12
			elif d < 0.5:
				c = 13 if (n == 0 or (streak and chk)) else 12
			elif d < 0.74:
				c = 12 if n > 1 else (13 if streak else 0)
			elif d < 0.9:
				c = 12 if chk else 0
			else:
				c = 0 if chk else (-1 if d > 0.96 else 12)
			if c >= 0:
				_sk_p(g, x, y, c)
	var hd: Vector2 = Vector2(30.0, 21.0)
	for y2: int in range(0, 46):
		for x2: int in range(8, 54):
			var hh: float = pow((float(x2) - hd.x) / 20.0, 2.0) + pow((float(y2) - hd.y) / 20.0, 2.0)
			if hh < 0.3 or (hh < 0.6 and (x2 + y2) % 2 == 0):
				_sk_p(g, x2, y2, 13)
	# long coat, narrow sloping shoulders, the head pushed too far forward and tilted
	for y3: int in range(44, 144):
		var hw: float = 17.0 if y3 < 52 else lerpf(17.0, 12.0, clampf(float(y3 - 52) / 30.0, 0.0, 1.0))
		if y3 > 84:
			hw = lerpf(12.0, 17.0, clampf(float(y3 - 84) / 55.0, 0.0, 1.0))
		var off: float = -1.0 if y3 < 60 else 0.0
		_sk_r(g, roundi(32.0 + off - hw), y3, roundi(hw * 2.0), 1, 0)
	for y4: int in range(4, 40):
		var t: float = float(y4 - 4) / 34.0
		var hw2: float = 6.5 + sin(t * PI) * 3.2
		var hc: float = 28.0 + t * 4.0
		_sk_r(g, roundi(hc - hw2), y4, roundi(hw2 * 2.0), 1, 0)
	_sk_r(g, 28, 36, 7, 12, 0)
	# arms hang far too long, the elbows bend the wrong way, spidery fingers
	for i: int in range(3):
		_sk_l(g, 15 + i, 48, 8 + i, 88, 0)
		_sk_l(g, 8 + i, 88, 12 + i, 108, 0)
		_sk_l(g, 47 + i, 48, 55 + i, 90, 0)
		_sk_l(g, 55 + i, 90, 50 + i, 110, 0)
	for k: int in range(5):
		_sk_l(g, 11 + k, 108, 3 + k * 3, 124 + (k % 2) * 4, 0)
		_sk_l(g, 51 + k, 110, 45 + k * 3, 126 - (k % 2) * 3, 0)
	# folds and seams in the coat so the figure is not a flat cut-out
	for y5: int in range(58, 140):
		for fx: int in [24, 32, 40]:
			if (y5 + fx) % 4 != 0:
				_sk_p(g, fx + (y5 - 58) / 30 * (1 if fx > 32 else -1), y5, 1)
	for by: int in [62, 74, 86]:
		_sk_p(g, 32, by, 4)
	# lit red rim on the figure's left and upper edges, where it meets the backdrop
	var src: Image = g.duplicate()
	var ink: Color = _sk_col(0)
	for y6: int in range(144):
		for x6: int in range(64):
			if src.get_pixel(x6, y6) != ink:
				continue
			var l_open: bool = x6 == 0 or src.get_pixel(x6 - 1, y6) != ink
			var t_open: bool = y6 == 0 or src.get_pixel(x6, y6 - 1) != ink
			if (l_open and y6 > 8 and y6 < 135) or (t_open and y6 < 50):
				_sk_p(g, x6, y6, 13 if y6 < 70 else 12)
	# two pinprick eyes, close together, too high, and a thin dashed smile far too wide
	for ex: Vector2i in [Vector2i(27, 15), Vector2i(34, 16)]:
		_sk_r(g, ex.x, ex.y, 2, 2, 15)
		_sk_p(g, ex.x, ex.y + 2, 11)
		_sk_p(g, ex.x + 1, ex.y + 2, 11)
	for sx: int in range(25, 39, 2):
		_sk_p(g, sx, 28 + (1 if sx < 29 or sx > 35 else 0), 14)


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


# ---------------------------------------------------------------- occult round: Midnight Table, grimoire, curios

const SK_DIGITS: Dictionary = {
	"0": "111101101101111", "1": "010110010010111", "2": "110001010100111", "3": "110001010001110",
	"4": "101101111001001", "5": "111100110001110", "6": "011100111101111", "7": "111001010010010",
	"8": "111101111101111", "9": "111101111001110",
}
const SK_PIPS: Dictionary = {
	1: [[1, 1]], 2: [[1, 0], [1, 2]], 3: [[1, 0], [1, 1], [1, 2]], 4: [[0, 0], [2, 0], [0, 2], [2, 2]],
	5: [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]], 6: [[0, 0], [2, 0], [0, 1], [2, 1], [0, 2], [2, 2]],
	7: [[0, 0], [2, 0], [1, 0.5], [0, 1], [2, 1], [0, 2], [2, 2]],
	8: [[0, 0], [2, 0], [1, 0.5], [0, 1], [2, 1], [1, 1.5], [0, 2], [2, 2]],
	9: [[0, 0], [2, 0], [0, 0.67], [2, 0.67], [1, 1], [0, 1.33], [2, 1.33], [0, 2], [2, 2]],
	10: [[0, 0], [2, 0], [1, 0.5], [0, 0.67], [2, 0.67], [0, 1.33], [2, 1.33], [1, 1.5], [0, 2], [2, 2]],
}
const SK_SPELL_IDS: Array[String] = ["scry", "hex", "glamour", "banish", "summon", "seal"]
const SK_CURIO_SHAPES: Array[String] = ["skull", "eye", "key", "candle", "bell", "doll", "mirror", "tooth", "coin", "feather",
	"jar", "book", "hand", "lantern", "dagger", "chalice", "ring", "clock"]
const SK_CURIO_WORDS: Dictionary = {
	"skull": "skull", "eye": "eye", "key": "key", "candle": "candle", "wax": "candle", "bell": "bell", "doll": "doll",
	"puppet": "doll", "mirror": "mirror", "tooth": "tooth", "molar": "tooth", "fang": "tooth", "coin": "coin",
	"penny": "coin", "florin": "coin", "feather": "feather", "raven": "feather", "crow": "feather", "quill": "feather",
	"jar": "jar", "bottle": "jar", "vial": "jar", "specimen": "jar", "book": "book", "tome": "book", "grimoire": "book",
	"ledger": "book", "diary": "book", "hand": "hand", "finger": "hand", "lantern": "lantern", "lamp": "lantern",
	"dagger": "dagger", "knife": "dagger", "blade": "dagger", "razor": "dagger", "chalice": "chalice", "cup": "chalice",
	"goblet": "chalice", "ring": "ring", "clock": "clock", "watch": "clock", "hourglass": "clock",
}
## Accent colour per curio set (palette index): parlor amber, attic bone, cellar green, chapel purple.
const SK_SET_ACCENT: Dictionary = {"parlor": 10, "attic": 14, "cellar": 7, "chapel": 4}


## The croupier of the Midnight Table, 4 idle frames at 64x96: rest, finger drum, blink, head tilt. Pale, gaunt, a
## green eyeshade, hollow eyes, a thin stitched smile and far too many knuckles in each hand.
static func croupier_frames() -> Array[ImageTexture]:
	var out: Array[ImageTexture] = []
	for f: int in range(4):
		out.append(ImageTexture.create_from_image(_sk_croupier(f)))
	return out


static func _sk_croupier(f: int) -> Image:
	var g: Image = _sk_new(SK_CUST_W, SK_CUST_H)
	var bob: int = 1 if f == 1 else 0
	var hx: int = 32 + (2 if f == 3 else 0)
	# tailcoat: narrow uneven shoulders flaring to the table; lit cloth on the left, shadow on the right, long folds
	for y: int in range(34, 96):
		var k: float = float(y - 34) / 61.0
		var xl: int = int(roundf(17.0 - k * 9.0)) + (1 if y < 44 else 0)
		var xr: int = int(roundf(47.0 + k * 8.0)) - (2 if y < 44 else 0)
		for x: int in range(xl, xr):
			var u: float = float(x - xl) / float(maxi(xr - xl, 1))
			var t: int = 1
			if u < 0.1:
				t = 3
			elif u < 0.24:
				t = 2 if (x + y) % 2 == 0 else 1
			elif u > 0.84:
				t = 0
			elif u > 0.68 and (x + y) % 2 == 0:
				t = 0
			_sk_p(g, x, y + bob, t)
	for fx: int in [24, 40, 47]:
		for y2: int in range(52, 95):
			if (y2 + fx) % 5 != 0:
				_sk_p(g, fx + (y2 - 52) / 12, y2 + bob, 0)
				_sk_p(g, fx - 1 + (y2 - 52) / 12, y2 + bob, 2 if fx == 24 else 1)
	# shirt, a blood-red waistcoat with brass buttons, lapels folding back
	_sk_r(g, 29, 35 + bob, 8, 9, 14)
	_sk_r(g, 29, 35 + bob, 2, 9, 15)
	_sk_r(g, 36, 36 + bob, 1, 8, 4)
	_sk_r(g, 28, 44 + bob, 10, 24, 12)
	_sk_r(g, 28, 44 + bob, 2, 24, 13)
	_sk_r(g, 37, 44 + bob, 1, 24, 0)
	for by: int in [48, 54, 60]:
		_sk_p(g, 33, by + bob, 10)
		_sk_p(g, 32, by + bob, 11)
	_sk_l(g, 27, 35 + bob, 25, 62 + bob, 0)
	_sk_l(g, 26, 36 + bob, 24, 62 + bob, 3)
	_sk_l(g, 38, 35 + bob, 40, 62 + bob, 0)
	_sk_r(g, 28, 35 + bob, 9, 3, 12)  # bow tie
	_sk_p(g, 32, 36 + bob, 13)
	_sk_p(g, 29, 35 + bob, 13)
	# neck and a long, pale, gaunt head: lit forehead and cheekbone, deep hollows, a shadowed right side
	_sk_r(g, hx - 2, 27 + bob, 5, 8, 14)
	_sk_r(g, hx - 2, 28 + bob, 1, 6, 15)
	_sk_r(g, hx + 1, 28 + bob, 2, 6, 4)
	_sk_e(g, float(hx), float(17 + bob), 7.0, 11.0, 14)
	_sk_e(g, float(hx) - 1.5, float(16 + bob), 4.5, 9.0, 15)
	_sk_r(g, hx + 4, 12 + bob, 3, 13, 4)
	_sk_r(g, hx + 3, 24 + bob, 2, 3, 4)
	_sk_r(g, hx - 6, 21 + bob, 2, 5, 4)  # hollow cheeks
	_sk_r(g, hx + 4, 21 + bob, 2, 5, 4)
	_sk_p(g, hx - 5, 20 + bob, 15)
	_sk_r(g, hx - 4, 27 + bob, 8, 1, 4)  # jaw shadow
	# eyeshade: a green band and a brim
	_sk_r(g, hx - 10, 10 + bob, 20, 3, 6)
	_sk_r(g, hx - 12, 12 + bob, 24, 2, 5)
	_sk_r(g, hx - 10, 10 + bob, 20, 1, 7)
	_sk_r(g, hx - 12, 14 + bob, 24, 1, 0)
	_sk_r(g, hx - 7, 15 + bob, 14, 1, 4)  # the brim's shadow on the brow
	# eyes: shadowed lids with a small black eye and a pinprick of candle yellow, or shut (not a skull's pits)
	for ex: int in [-4, 3]:
		_sk_r(g, hx + ex - 2, 16 + bob, 5, 5, 4)
		if f == 2:
			_sk_r(g, hx + ex - 1, 19 + bob, 3, 1, 0)
		else:
			_sk_r(g, hx + ex - 1, 17 + bob, 3, 3, 0)
			_sk_p(g, hx + ex, 18 + bob, 11)
		_sk_r(g, hx + ex - 2, 16 + bob, 5, 1, 2)
	_sk_r(g, hx - 1, 21 + bob, 2, 3, 4)  # nose
	# a thin, patient smile with one tooth showing, no stitches
	_sk_r(g, hx - 4, 26 + bob, 9, 1, 0)
	_sk_p(g, hx - 5, 25 + bob, 0)
	_sk_p(g, hx + 5, 25 + bob, 0)
	_sk_p(g, hx + 1, 27 + bob, 15)
	_sk_r(g, hx - 3, 27 + bob, 3, 1, 4)
	# arms bent forward onto the table: cloth sleeves with a lit edge, a shadowed edge and a fold, bone cuffs
	for i: int in range(5):
		var st: int = 2 if i == 0 else (0 if i == 4 else 1)
		_sk_l(g, 15 + i, 46 + bob, 9 + i, 77 + bob, st)
		_sk_l(g, 42 + i, 48 + bob, 49 + i, 77 + bob, 2 if i == 0 else (0 if i == 4 else 1))
	_sk_l(g, 13, 56 + bob, 12, 68 + bob, 0)
	_sk_l(g, 46, 58 + bob, 47, 70 + bob, 0)
	_sk_r(g, 8, 76 + bob, 8, 4, 14)
	_sk_r(g, 48, 76 + bob, 8, 4, 14)
	_sk_r(g, 8, 76 + bob, 8, 1, 15)
	_sk_r(g, 48, 76 + bob, 8, 1, 15)
	_sk_p(g, 14, 78 + bob, 11)
	_sk_p(g, 49, 78 + bob, 11)
	for h: int in range(2):
		var bx: int = 8 if h == 0 else 48
		for i: int in range(5):
			var fx2: int = bx + i * 2 - (1 if h == 0 else 0)
			var lift: int = 2 if (f == 1 and i == (1 if h == 0 else 3)) else 0
			var ln: int = [8, 13, 14, 12, 9][i] - lift
			var drift: int = (i - 2) * (-1 if h == 0 else 1)
			_sk_l(g, fx2, 80 + bob, fx2 + drift, 80 + bob + ln, 14)
			_sk_p(g, fx2 + drift, 80 + bob + ln, 15)
			_sk_p(g, fx2 + drift / 2, 80 + bob + ln / 2, 4)  # knuckle shadow
	_sk_outline(g)
	_sk_polish(g, "croupier", f)
	return g


## Bone dice, 12x12, face 1..6 (other values wrap). The one is red.
static func dice_texture(face: int) -> ImageTexture:
	var n: int = posmod(face - 1, 6) + 1
	var g: Image = _sk_new(12, 12)
	_sk_r(g, 2, 1, 8, 10, 14)
	_sk_r(g, 1, 2, 10, 8, 14)
	_sk_r(g, 2, 2, 7, 7, 15)
	_sk_p(g, 2, 2, 14)
	var spots: Dictionary = {1: [[5, 5]], 2: [[2, 2], [8, 8]], 3: [[2, 2], [5, 5], [8, 8]], 4: [[2, 2], [8, 2], [2, 8], [8, 8]],
		5: [[2, 2], [8, 2], [5, 5], [2, 8], [8, 8]], 6: [[2, 2], [8, 2], [2, 5], [8, 5], [2, 8], [8, 8]]}
	for s: Array in spots[n]:
		var c: int = 13 if n == 1 else 0
		_sk_r(g, int(s[0]), int(s[1]), 2, 2, c)
	_sk_outline(g)
	_sk_polish(g, "dice%d" % n, 3)
	return ImageTexture.create_from_image(g)


## Macabre playing card, 20x30. Rank 1 is the ace (a skull), 2..10 show pips, 11..13 are J, Q, K. Ranks wrap.
static func card_face_texture(rank: int) -> ImageTexture:
	var r: int = posmod(rank - 1, 13) + 1
	var g: Image = _sk_new(20, 30)
	_sk_r(g, 1, 1, 18, 28, 15)
	_sk_r(g, 2, 2, 16, 26, 14)
	_sk_r(g, 3, 3, 14, 24, 15)
	_sk_r(g, 0, 2, 20, 26, 15)
	_sk_r(g, 2, 1, 16, 28, 15)
	_sk_r(g, 3, 3, 14, 24, 15)
	var label: String = "A" if r == 1 else ("J" if r == 11 else ("Q" if r == 12 else ("K" if r == 13 else str(r))))
	var lc: int = 13 if r % 2 == 0 else 0
	_sk_card_label(g, label, 4, 4, lc)
	_sk_card_label(g, label, 15 - (label.length() - 1) * 4, 22, lc)
	if r == 1:
		_sk_art(g, ["..fff..", ".fffff.", "f0fff0f", "f0fff0f", ".ff0ff.", ".fffff.", "..f0f..", "..fff.."], 6, 10)
		_sk_art(g, ["4......4", ".4....4."], 5, 19)
		_sk_p(g, 8, 18, 4)
	elif r <= 10:
		for p: Array in SK_PIPS[r]:
			var px: int = 6 + int(p[0]) * 4
			var py: int = 9 + int(roundf(float(p[1]) * 5.0))
			_sk_r(g, px, py + 1, 3, 1, 13)
			_sk_r(g, px + 1, py, 1, 3, 13)
			_sk_p(g, px + 1, py + 1, 12)
	else:
		# court card: a hooded figure with a crown or hood band and a skull face
		var cr: int = 11 if r == 13 else (13 if r == 12 else 4)
		_sk_art(g, ["..2222..", ".222222.", ".2ffff2.", ".f0ff0f.", ".ffffff.", "..f00f..", ".222222.", "22222222", "22222222"], 6, 10)
		_sk_r(g, 6, 9, 8, 1, cr)
		if r == 13:
			_sk_p(g, 6, 8, cr)
			_sk_p(g, 9, 7, cr)
			_sk_p(g, 13, 8, cr)
		_sk_r(g, 7, 20, 6, 1, 12)
	# stained edge and a burnt corner
	_sk_p(g, 17, 27, 8)
	_sk_p(g, 16, 27, 14)
	_sk_p(g, 17, 26, 9)
	_sk_outline(g)
	_sk_polish(g, "card%d" % r, 4)
	return ImageTexture.create_from_image(g)


static func _sk_card_label(g: Image, s: String, x: int, y: int, c: int) -> void:
	for i: int in range(s.length()):
		var ch: String = s[i]
		var rows: String = str(SK_DIGITS.get(ch, ""))
		if rows == "":
			rows = str(SK_FONT.get(ch, ""))
		if rows.length() != 15:
			continue
		for k: int in range(15):
			if rows[k] == "1":
				_sk_p(g, x + i * 4 + (k % 3), y + (k / 3), c)


## The soul wheel, 64x64: eight wedges of cold purple, rust and green behind a bone rim studded with candle yellow,
## a skull hub and a red pointer at the top.
static func wheel_texture() -> ImageTexture:
	var g: Image = _sk_new(64, 64)
	var cols: Array[int] = [2, 12, 3, 5, 2, 12, 3, 6]
	var cx: float = 31.5
	var cy: float = 32.5
	for y: int in range(64):
		for x: int in range(64):
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			var d: float = sqrt(dx * dx + dy * dy)
			if d > 30.0:
				continue
			var a: float = fposmod(atan2(dy, dx) + PI * 0.5 + PI / 8.0, TAU)
			var seg: int = int(a / (TAU / 8.0))
			var c: int = cols[seg]
			var edge: float = fposmod(a, TAU / 8.0) * d
			if d > 26.0:
				c = 14 if d < 29.0 else 4
				if int(a / (TAU / 16.0)) % 2 == 0 and d > 27.0 and d < 28.6:
					c = 11
			elif edge < 1.2 or edge > (TAU / 8.0) * d - 1.2:
				c = 14
			elif d < 9.0:
				c = 8 if d > 6.0 else 9
			elif (x + y) % 2 == 0 and d > 17.0 and seg % 2 == 0:
				c = SK_DARK[c]
			_sk_p(g, x, y, c)
	# per-wedge sigils (small pale marks) so the wedges read as different fates
	for s: int in range(8):
		var ang: float = -PI * 0.5 + float(s) * TAU / 8.0
		var px: int = int(roundf(cx + cos(ang) * 17.0))
		var py: int = int(roundf(cy + sin(ang) * 17.0))
		if s % 3 == 0:
			_sk_r(g, px - 1, py - 1, 3, 3, 14)
			_sk_p(g, px, py, 0)
		elif s % 3 == 1:
			_sk_r(g, px - 2, py, 5, 1, 14)
			_sk_r(g, px, py - 2, 1, 5, 14)
		else:
			_sk_r(g, px - 1, py - 1, 2, 2, 11)
	# hub skull
	_sk_art(g, ["..fff..", ".fffff.", "f0fff0f", ".fffff.", "..f0f.."], 28, 30)
	_sk_art(g, ["...d...", "..ddd..", ".ddddd."], 28, 0)
	_sk_outline(g)
	_sk_polish(g, "wheel", 5)
	return ImageTexture.create_from_image(g)


## A sealed lot, 32x32: brown paper parcel, black wax seal stamped with an eye, twine and a tag.
static func lot_texture() -> ImageTexture:
	var g: Image = _sk_new(32, 32)
	_sk_r(g, 4, 10, 24, 18, 9)  # front
	_sk_r(g, 6, 6, 22, 4, 10)  # top face
	_sk_r(g, 24, 6, 4, 22, 8)  # side fold
	_sk_r(g, 4, 10, 20, 1, 11)
	for i: int in range(0, 22, 4):
		_sk_p(g, 5 + i, 12 + (i % 8), 8)  # paper creases
		_sk_p(g, 6 + i, 20 - (i % 8), 10)
	# twine: one band down, one across, a knot and loose ends
	_sk_r(g, 13, 7, 2, 21, 14)
	_sk_r(g, 4, 18, 20, 2, 14)
	_sk_r(g, 13, 18, 2, 2, 15)
	_sk_l(g, 14, 7, 10, 3, 14)
	_sk_l(g, 14, 7, 18, 3, 14)
	_sk_p(g, 10, 3, 15)
	_sk_p(g, 18, 3, 15)
	# wax seal with an eye
	_sk_e(g, 14.0, 19.0, 4.5, 4.5, 12)
	_sk_e(g, 13.0, 18.0, 3.0, 3.0, 13)
	_sk_r(g, 11, 18, 5, 1, 0)
	_sk_p(g, 13, 18, 14)
	# tag on a string
	_sk_r(g, 21, 21, 6, 7, 15)
	_sk_p(g, 21, 21, 0)
	_sk_l(g, 22, 21, 17, 19, 14)
	_sk_r(g, 22, 23, 4, 1, 12)
	_sk_r(g, 22, 25, 3, 1, 4)
	_sk_outline(g)
	_sk_polish(g, "lot", 6)
	return ImageTexture.create_from_image(g)


## A page torn from a grimoire, 24x32: parchment, ruled runes, a red sigil and a scorched corner.
static func spell_page_texture() -> ImageTexture:
	var g: Image = _sk_new(24, 32)
	_sk_r(g, 1, 1, 22, 30, 14)
	_sk_r(g, 2, 2, 19, 27, 15)
	_sk_p(g, 1, 1, 0)
	_sk_p(g, 22, 1, 0)
	_sk_p(g, 1, 30, 0)
	_sk_r(g, 0, 8, 1, 3, 0)  # torn edge nicks
	_sk_r(g, 23, 17, 1, 3, 0)
	for ry: int in range(4):
		for rx: int in range(0, 15, 3):
			if (rx + ry * 5) % 7 != 0:
				_sk_r(g, 4 + rx, 4 + ry * 2, 2, 1, 3)
	_sk_ring(g, 12.0, 17.0, 6.0, 6.0, 1, 13)
	_sk_l(g, 12, 11, 8, 21, 12)
	_sk_l(g, 12, 11, 16, 21, 12)
	_sk_l(g, 8, 21, 17, 15, 12)
	_sk_l(g, 16, 21, 7, 15, 12)
	_sk_p(g, 12, 17, 11)
	for rx2: int in range(0, 15, 3):
		_sk_r(g, 4 + rx2, 26, 2, 1, 3)
	# scorched lower right corner
	_sk_art(g, ["...88.", "..8dd8", ".8d00d", "8d0000"], 18, 26)
	_sk_art(g, ["0000.", "000..", "00...", "0...."], 19, 28)
	_sk_outline(g)
	_sk_polish(g, "page", 7)
	return ImageTexture.create_from_image(g)


## 16x16 spell icons: scry, hex, glamour, banish, summon, seal. An unknown id gets a plain rune.
static func spell_icon(id: String) -> ImageTexture:
	var g: Image = _sk_new(16, 16)
	match id:
		"scry":
			_sk_e(g, 8.0, 8.0, 7.0, 4.0, 15)
			_sk_e(g, 8.0, 8.0, 3.0, 3.0, 4)
			_sk_e(g, 8.0, 8.0, 1.5, 1.5, 0)
			_sk_p(g, 6, 6, 15)
			_sk_r(g, 1, 4, 14, 1, 14)
			_sk_p(g, 2, 3, 14)
			_sk_p(g, 13, 3, 14)
		"hex":
			_sk_ring(g, 8.0, 8.0, 6.0, 6.0, 2, 3)
			_sk_l(g, 8, 2, 4, 13, 4)
			_sk_l(g, 8, 2, 12, 13, 4)
			_sk_l(g, 3, 6, 13, 6, 4)
			_sk_l(g, 4, 13, 13, 6, 14)
			_sk_l(g, 12, 13, 3, 6, 14)
			_sk_p(g, 8, 8, 15)
		"glamour":
			_sk_r(g, 7, 1, 2, 14, 11)
			_sk_r(g, 1, 7, 14, 2, 11)
			_sk_r(g, 6, 6, 4, 4, 15)
			_sk_l(g, 3, 3, 12, 12, 10)
			_sk_l(g, 12, 3, 3, 12, 10)
			_sk_r(g, 7, 7, 2, 2, 15)
			_sk_p(g, 12, 2, 11)
			_sk_p(g, 2, 13, 11)
		"banish":
			# a clear bone-white ghost (sheet body, scalloped hem, black eyes) struck through by a red slash
			_sk_e(g, 8.0, 6.0, 4.5, 4.5, 15)
			_sk_r(g, 3, 6, 10, 8, 15)
			_sk_r(g, 3, 6, 2, 8, 14)
			_sk_r(g, 11, 6, 2, 8, 14)
			for hx2: int in [3, 6, 9]:
				_sk_r(g, hx2, 14, 2, 2, 15)
			_sk_r(g, 5, 4, 2, 3, 0)
			_sk_r(g, 9, 4, 2, 3, 0)
			_sk_r(g, 7, 9, 2, 2, 0)
			_sk_l(g, 1, 14, 14, 1, 13)
			_sk_l(g, 2, 14, 15, 1, 13)
			_sk_l(g, 1, 13, 13, 1, 12)
		"summon":
			_sk_ring(g, 8.0, 8.0, 7.0, 7.0, 1, 13)
			_sk_l(g, 8, 2, 3, 12, 13)
			_sk_l(g, 8, 2, 13, 12, 13)
			_sk_l(g, 3, 12, 13, 12, 13)
			_sk_p(g, 8, 8, 11)
			_sk_p(g, 8, 9, 10)
		"seal":
			_sk_ring(g, 8.0, 8.0, 7.0, 7.0, 1, 15)
			_sk_ring(g, 8.0, 8.0, 4.0, 4.0, 1, 14)
			_sk_r(g, 7, 1, 2, 3, 14)
			_sk_r(g, 7, 12, 2, 3, 14)
			_sk_r(g, 1, 7, 3, 2, 14)
			_sk_r(g, 12, 7, 3, 2, 14)
			_sk_r(g, 7, 7, 2, 2, 11)
		_:
			_sk_ring(g, 8.0, 8.0, 6.0, 6.0, 2, 4)
			_sk_r(g, 7, 4, 2, 8, 14)
	_sk_outline(g)
	_sk_polish(g, "spell_" + id, 8)
	return ImageTexture.create_from_image(g)


## 24x24 icon for one collectable curio. The id is looked up in game/data/curios.json at call time; a shape is picked
## from the id and name (skull, key, candle, bell, doll, mirror ...), and an id with no recognisable word gets a shape
## seeded by the id hash. The accent colour follows the curio's set and rare curios get a glint.
static func curio_icon(id: String) -> ImageTexture:
	var row: Dictionary = _sk_curio_row(id)
	var nm: String = (id + " " + str(row.get("name", ""))).to_lower()
	var shape: String = str(SK_CURIO_BY_ID.get(id, ""))
	var best: int = 9999
	for w: String in SK_CURIO_WORDS:
		if shape != "":
			break
		var at: int = nm.find(w)
		if at >= 0 and at < best:
			best = at
			shape = str(SK_CURIO_WORDS[w])
	var hv: int = absi(hash(id))
	if shape == "":
		shape = SK_CURIO_SHAPES[hv % SK_CURIO_SHAPES.size()]
	var acc: int = int(SK_SET_ACCENT.get(str(row.get("set", "")), 10))
	var g: Image = _sk_new(24, 24)
	_sk_curio_shape(g, shape, acc, hv)
	_sk_outline(g)
	_sk_polish(g, id, 9)
	var rarity: String = str(row.get("rarity", "common"))
	if rarity != "common":
		var spots: int = 1 if rarity == "rare" else 3
		for i: int in range(spots):
			var gx: int = [20, 3, 21][i]
			var gy: int = [3, 4, 19][i]
			_sk_p(g, gx, gy, 11)
			_sk_p(g, gx - 1, gy, 10)
			_sk_p(g, gx + 1, gy, 10)
			_sk_p(g, gx, gy - 1, 10)
			_sk_p(g, gx, gy + 1, 10)
	return ImageTexture.create_from_image(g)


static func _sk_curio_row(id: String) -> Dictionary:
	var f: FileAccess = FileAccess.open("res://game/data/curios.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		for r: Variant in parsed as Array:
			if r is Dictionary and str((r as Dictionary).get("id", "")) == id:
				return r as Dictionary
	return {}


static func _sk_curio_shape(g: Image, shape: String, acc: int, hv: int) -> void:
	match shape:
		"skull":
			_sk_e(g, 12.0, 10.0, 8.0, 7.0, 14)
			_sk_r(g, 8, 14, 9, 7, 14)
			_sk_r(g, 7, 9, 4, 4, 0)
			_sk_r(g, 13, 9, 4, 4, 0)
			_sk_p(g, 8, 10, acc)
			_sk_p(g, 14, 10, acc)
			_sk_r(g, 11, 13, 2, 2, 1)
			for tx: int in [9, 11, 13, 15]:
				_sk_r(g, tx, 17, 1, 4, 0)
		"eye":
			_sk_e(g, 12.0, 12.0, 10.0, 6.0, 15)
			_sk_e(g, 12.0, 12.0, 4.0, 4.0, acc)
			_sk_e(g, 12.0, 12.0, 2.0, 2.0, 0)
			_sk_p(g, 10, 10, 15)
			_sk_r(g, 2, 12, 3, 1, 12)
			_sk_r(g, 19, 12, 3, 1, 12)
		"key":
			_sk_ring(g, 7.0, 7.0, 6.0, 6.0, 2, acc)
			_sk_thick(g, 11, 11, 20, 20, 3)
			_sk_r(g, 17, 19, 3, 3, acc)
			_sk_r(g, 20, 16, 3, 3, acc)
		"candle":
			_sk_r(g, 9, 9, 6, 12, 14)
			_sk_r(g, 9, 9, 2, 12, 15)
			_sk_e(g, 12.0, 5.0, 2.0, 3.0, 11)
			_sk_p(g, 12, 6, 10)
			_sk_p(g, 12, 8, 0)
			_sk_r(g, 5, 21, 14, 2, acc)
			_sk_r(g, 14, 12, 1, 4, 14)
		"bell":
			_sk_e(g, 12.0, 11.0, 7.0, 8.0, acc)
			_sk_r(g, 5, 12, 14, 6, acc)
			_sk_r(g, 4, 18, 16, 2, 11)
			_sk_e(g, 12.0, 21.0, 2.0, 2.0, 9)
			_sk_r(g, 11, 1, 2, 3, 9)
			_sk_r(g, 8, 6, 2, 8, 15)
		"doll":
			_sk_r(g, 5, 2, 14, 5, 8)
			_sk_e(g, 12.0, 10.0, 7.0, 7.0, 15)
			_sk_r(g, 8, 9, 2, 2, 0)
			_sk_r(g, 14, 9, 2, 2, 0)
			_sk_p(g, 8, 12, 13)
			_sk_r(g, 10, 14, 4, 1, 12)
			_sk_l(g, 15, 5, 13, 11, 4)
			_sk_r(g, 7, 17, 10, 5, acc)
		"mirror":
			_sk_e(g, 12.0, 10.0, 8.0, 9.0, 10)
			_sk_e(g, 12.0, 10.0, 6.0, 7.0, 4)
			_sk_l(g, 9, 6, 14, 3, 15)
			_sk_l(g, 8, 9, 13, 6, 14)
			_sk_r(g, 11, 19, 2, 4, 9)
			_sk_p(g, 14, 12, acc)
		"tooth":
			_sk_r(g, 6, 3, 12, 9, 15)
			_sk_r(g, 5, 5, 14, 5, 15)
			_sk_r(g, 7, 12, 4, 9, 14)
			_sk_r(g, 13, 12, 4, 9, 14)
			_sk_p(g, 12, 11, 14)
			_sk_r(g, 8, 5, 1, 2, 4)
			_sk_p(g, 15, 8, acc)
		"coin":
			_sk_e(g, 12.0, 12.0, 9.0, 9.0, 11)
			_sk_e(g, 12.0, 12.0, 7.0, 7.0, 10)
			_sk_r(g, 11, 7, 2, 10, 11)
			_sk_r(g, 8, 10, 8, 2, 11)
			_sk_p(g, 12, 11, 0)
			_sk_p(g, 8, 7, 15)
		"feather":
			_sk_thick(g, 3, 20, 19, 4, 3)
			_sk_thick(g, 6, 20, 20, 7, 2)
			_sk_l(g, 3, 21, 19, 5, 4)
			_sk_l(g, 8, 15, 13, 17, 2)
			_sk_l(g, 12, 11, 17, 13, 2)
			_sk_p(g, 19, 4, acc)
		"jar":
			_sk_r(g, 6, 6, 12, 15, 4)
			_sk_r(g, 7, 10, 10, 10, acc)
			_sk_r(g, 7, 7, 2, 12, 15)
			_sk_r(g, 7, 3, 10, 3, 9)
			_sk_e(g, 12.0, 15.0, 2.0, 2.0, 15)
			_sk_p(g, 12, 15, 0)
			_sk_r(g, 6, 21, 12, 1, 8)
		"book":
			_sk_r(g, 4, 3, 16, 18, 12)
			_sk_r(g, 4, 3, 3, 18, 8)
			_sk_r(g, 20, 5, 1, 14, 14)
			_sk_ring(g, 13.0, 12.0, 4.0, 4.0, 1, acc)
			_sk_p(g, 13, 12, acc)
			_sk_r(g, 9, 6, 8, 1, 13)
		"hand":
			_sk_r(g, 7, 13, 10, 8, 14)
			for fi: int in range(4):
				_sk_r(g, 7 + fi * 3, [5, 3, 4, 7][fi], 2, 10, 14)
				_sk_p(g, 7 + fi * 3, [5, 3, 4, 7][fi], 15)
			_sk_r(g, 3, 13, 4, 2, 14)
			_sk_p(g, 3, 13, 15)
			_sk_r(g, 11, 15, 2, 2, acc)
		"lantern":
			_sk_r(g, 7, 6, 10, 15, acc)
			_sk_r(g, 8, 8, 8, 11, 11)
			_sk_e(g, 12.0, 15.0, 2.0, 3.0, 13)
			_sk_r(g, 6, 20, 12, 2, 8)
			_sk_ring(g, 12.0, 4.0, 4.0, 3.0, 1, 14)
		"dagger":
			_sk_thick(g, 18, 3, 8, 13, 3)
			_sk_l(g, 19, 3, 9, 13, 15)
			_sk_thick(g, 5, 11, 12, 18, 2)
			_sk_thick(g, 7, 15, 4, 21, 3)
			_sk_p(g, 8, 13, acc)
			_sk_p(g, 5, 20, acc)
		"chalice":
			_sk_r(g, 5, 4, 14, 7, 11)
			_sk_e(g, 12.0, 11.0, 7.0, 4.0, 11)
			_sk_r(g, 5, 4, 14, 2, 12)
			_sk_r(g, 11, 14, 2, 6, 10)
			_sk_r(g, 7, 19, 10, 3, 10)
			_sk_p(g, 7, 7, 15)
			_sk_p(g, 12, 8, acc)
		"ring":
			_sk_ring(g, 12.0, 14.0, 8.0, 8.0, 3, 11)
			_sk_e(g, 12.0, 5.0, 3.0, 3.0, acc)
			_sk_p(g, 11, 4, 15)
		"teacup":
			_sk_r(g, 5, 9, 12, 7, 15)
			_sk_e(g, 11.0, 16.0, 6.0, 3.0, 15)
			_sk_r(g, 5, 9, 12, 1, 14)
			_sk_r(g, 6, 10, 10, 1, 9)
			_sk_ring(g, 19.0, 12.0, 3.0, 3.0, 1.0, 15)
			_sk_r(g, 3, 20, 18, 2, acc)
			_sk_r(g, 3, 20, 18, 1, 15)
			_sk_r(g, 7, 12, 2, 2, acc)
			_sk_l(g, 8, 6, 9, 3, 14)
			_sk_l(g, 12, 7, 11, 3, 4)
			_sk_l(g, 15, 6, 15, 2, 14)
		"veil":
			for vy: int in range(3, 22):
				var vw: int = 4 + (vy - 3) / 2
				for vx: int in range(12 - vw, 12 + vw + 1):
					if (vx + vy) % 2 == 0 or vx % 5 == 0:
						_sk_p(g, vx, vy, 14 if vx % 5 != 0 else 4)
					else:
						_sk_p(g, vx, vy, 4)
			for hp: Vector2i in [Vector2i(10, 10), Vector2i(14, 14), Vector2i(11, 17), Vector2i(15, 9)]:
				_sk_r(g, hp.x, hp.y, 2, 2, 0)
			_sk_r(g, 8, 2, 8, 2, acc)
			_sk_r(g, 7, 21, 11, 1, 0)
		"envelope":
			_sk_r(g, 8, 3, 10, 6, 15)
			_sk_r(g, 10, 5, 6, 1, 3)
			_sk_r(g, 6, 6, 16, 11, 14)
			_sk_r(g, 3, 11, 16, 11, 15)
			_sk_l(g, 3, 11, 11, 17, 14)
			_sk_l(g, 19, 11, 11, 17, 14)
			_sk_r(g, 3, 21, 16, 1, 4)
			_sk_e(g, 11.0, 17.0, 2.0, 2.0, 13)
			_sk_p(g, 10, 16, 15)
			_sk_r(g, 19, 14, 2, 6, acc)
		"planchette":
			_sk_e(g, 9.0, 9.0, 6.0, 6.0, 9)
			_sk_e(g, 15.0, 9.0, 6.0, 6.0, 9)
			for py: int in range(10, 22):
				var pw: int = maxi(11 - (py - 10), 1)
				_sk_r(g, 12 - pw, py, pw * 2, 1, 9)
			_sk_r(g, 5, 6, 3, 2, 10)
			_sk_ring(g, 12.0, 11.0, 3.5, 3.5, 1.0, 11)
			_sk_e(g, 12.0, 11.0, 2.0, 2.0, 4)
			_sk_p(g, 11, 10, 15)
			_sk_l(g, 3, 3, 8, 1, 14)
			_sk_l(g, 3, 3, 5, 7, 14)
			_sk_p(g, acc % 3 + 12, 19, acc)
		"cradle":
			_sk_r(g, 4, 10, 16, 8, 9)
			_sk_r(g, 4, 10, 16, 1, 10)
			_sk_e(g, 7.0, 10.0, 5.0, 5.0, 8)
			_sk_r(g, 8, 13, 12, 3, 15)
			_sk_r(g, 8, 13, 12, 1, 14)
			_sk_r(g, 10, 11, 4, 2, 14)
			_sk_p(g, 11, 12, 0)
			_sk_p(g, 13, 12, 0)
			for lx: int in [6, 10, 14, 18]:
				_sk_r(g, lx, 17, 1, 3, 8)
			_sk_e(g, 12.0, 19.0, 10.0, 3.0, acc)
			_sk_e(g, 12.0, 18.0, 9.0, 2.0, 0)
			_sk_r(g, 2, 8, 1, 4, 4)
			_sk_r(g, 21, 8, 1, 4, 4)
		"teeth_jar":
			_sk_r(g, 6, 5, 12, 17, 4)
			_sk_r(g, 6, 5, 1, 17, 15)
			_sk_r(g, 7, 2, 10, 3, 9)
			_sk_r(g, 7, 2, 10, 1, 10)
			_sk_r(g, 7, 12, 10, 9, 1)
			for tp: Vector2i in [Vector2i(8, 13), Vector2i(11, 15), Vector2i(14, 12), Vector2i(9, 18), Vector2i(13, 18), Vector2i(15, 16), Vector2i(11, 12)]:
				_sk_r(g, tp.x, tp.y, 2, 3, 15)
				_sk_p(g, tp.x + 1, tp.y + 2, 14)
			_sk_r(g, 17, 6, 1, 15, 3)
		"wine":
			_sk_r(g, 10, 4, 4, 7, 5)
			_sk_r(g, 10, 1, 4, 3, 9)
			_sk_r(g, 7, 10, 10, 12, 5)
			_sk_r(g, 7, 10, 2, 12, 6)
			_sk_r(g, 8, 14, 8, 5, 15)
			_sk_r(g, 9, 15, 6, 1, 14)
			_sk_p(g, 12, 17, acc)
			_sk_r(g, 10, 4, 1, 6, 7)
			_sk_r(g, 7, 21, 10, 1, 0)
		"tin":
			_sk_r(g, 3, 8, 18, 12, 14)
			_sk_r(g, 3, 8, 18, 4, 15)
			_sk_r(g, 3, 8, 18, 1, 14)
			_sk_r(g, 3, 19, 18, 1, 4)
			_sk_art(g, [".dd.dd.", "ddddddd", "ddddddd", ".ddddd.", "..ddd..", "...d..."], 5, 12)
			_sk_r(g, 14, 13, 5, 5, 10)
			_sk_r(g, 14, 13, 5, 1, 11)
			_sk_ring(g, 16.0, 12.0, 2.5, 2.5, 1.0, 14)
			_sk_p(g, 16, 15, 0)
			_sk_l(g, 2, 5, 4, 3, 13)
			_sk_l(g, 22, 5, 20, 3, 13)
		"rosary":
			for b: int in range(14):
				if b == 0:
					continue
				var ba: float = -PI * 0.5 + float(b) * TAU / 14.0
				var bx: int = 12 + roundi(cos(ba) * 8.0)
				var by: int = 8 + roundi(sin(ba) * 7.0)
				_sk_r(g, bx - 1, by - 1, 2, 2, 14 if b % 3 != 0 else 4)
				_sk_p(g, bx - 1, by - 1, 15)
			_sk_l(g, 12, 15, 12, 18, 14)
			_sk_r(g, 11, 18, 2, 5, acc)
			_sk_r(g, 9, 19, 6, 2, acc)
			_sk_r(g, 11, 18, 1, 5, 15)
		"reliquary":
			_sk_ring(g, 12.0, 2.0, 2.5, 2.0, 1.0, 10)
			_sk_e(g, 12.0, 13.0, 8.0, 8.5, 10)
			_sk_e(g, 12.0, 13.0, 5.5, 6.0, 4)
			_sk_e(g, 11.0, 12.0, 3.0, 3.5, 3)
			_sk_l(g, 9, 16, 15, 10, 15)
			_sk_l(g, 10, 16, 16, 10, 14)
			_sk_r(g, 11, 3, 2, 3, 11)
			_sk_r(g, 5, 8, 2, 2, 11)
			_sk_r(g, 17, 8, 2, 2, 11)
			_sk_r(g, 8, 20, 8, 1, 8)
			_sk_p(g, 15, 12, acc)
		"candle_out":
			_sk_r(g, 9, 10, 6, 11, 14)
			_sk_r(g, 9, 10, 2, 11, 15)
			_sk_r(g, 14, 10, 1, 11, 4)
			_sk_r(g, 11, 8, 2, 2, 0)
			_sk_r(g, 5, 21, 14, 2, acc)
			_sk_r(g, 13, 13, 1, 4, 15)
			for sp: Vector2i in [Vector2i(12, 6), Vector2i(13, 4), Vector2i(12, 2), Vector2i(11, 1), Vector2i(10, 3)]:
				_sk_p(g, sp.x, sp.y, 4)
				_sk_p(g, sp.x + 1, sp.y, 3)
		"vial":
			_sk_r(g, 9, 1, 6, 3, 9)
			_sk_r(g, 10, 4, 4, 5, 4)
			_sk_e(g, 12.0, 15.0, 7.0, 6.5, 4)
			_sk_e(g, 12.0, 17.0, 5.5, 4.0, 15)
			_sk_r(g, 7, 12, 2, 6, 14)
			_sk_l(g, 13, 8, 10, 20, 0)
			_sk_l(g, 14, 8, 11, 20, 1)
			_sk_p(g, 11, 22, 15)
			_sk_p(g, 11, 23, 14)
		"spoon":
			_sk_e(g, 7.0, 17.0, 4.5, 6.0, 14)
			_sk_e(g, 7.0, 17.0, 3.0, 4.5, 4)
			_sk_thick(g, 10, 13, 20, 3, 3)
			_sk_l(g, 11, 12, 21, 3, 15)
			for tp2: Vector2i in [Vector2i(6, 15), Vector2i(8, 19), Vector2i(14, 9), Vector2i(17, 6)]:
				_sk_r(g, tp2.x, tp2.y, 2, 2, 0)
			_sk_p(g, 19, 3, acc)
		"dummy":
			_sk_r(g, 10, 1, 4, 3, 9)
			for dy: int in range(4, 17):
				var dw: int = 5 + mini((dy - 4) / 2, 4)
				_sk_r(g, 12 - dw, dy, dw * 2, 1, 15 if dy % 4 != 3 else 14)
			_sk_r(g, 5, 4, 3, 13, 14)
			_sk_r(g, 5, 4, 1, 13, 15)
			_sk_r(g, 16, 4, 2, 13, 4)
			_sk_l(g, 12, 6, 12, 16, 4)
			_sk_l(g, 8, 9, 10, 12, 4)
			_sk_r(g, 11, 17, 2, 5, 9)
			_sk_r(g, 6, 21, 12, 2, 9)
			_sk_p(g, 16, 8, 13)
			_sk_p(g, 8, 14, acc)
			_sk_r(g, 9, 6, 2, 1, 4)
			_sk_r(g, 14, 12, 2, 1, 4)
		"eyebox":
			_sk_r(g, 3, 13, 18, 9, 9)
			_sk_r(g, 3, 13, 18, 1, 10)
			_sk_r(g, 3, 21, 18, 1, 8)
			_sk_r(g, 3, 6, 18, 2, 8)
			_sk_l(g, 3, 6, 4, 13, 8)
			_sk_l(g, 20, 6, 20, 13, 8)
			for ep: Vector2i in [Vector2i(7, 10), Vector2i(12, 8), Vector2i(17, 10), Vector2i(10, 12), Vector2i(15, 12)]:
				_sk_e(g, float(ep.x), float(ep.y), 2.2, 2.2, 15)
				_sk_p(g, ep.x, ep.y, acc)
				_sk_p(g, ep.x, ep.y + 1, 0)
			_sk_p(g, 12, 17, 11)
		"grille":
			_sk_r(g, 2, 2, 20, 20, 8)
			_sk_r(g, 2, 2, 20, 2, 9)
			_sk_r(g, 2, 2, 2, 20, 9)
			_sk_r(g, 4, 4, 16, 16, 0)
			for gx: int in range(-16, 17, 4):
				_sk_l(g, 4 + gx, 4, 20 + gx, 20, 9)
				_sk_l(g, 20 - gx, 4, 4 - gx, 20, 9)
			_sk_r(g, 4, 4, 16, 1, 0)
			_sk_r(g, 4, 19, 16, 1, 0)
			_sk_r(g, 2, 22, 20, 1, 0)
			_sk_p(g, 10, 11, acc)
			_sk_p(g, 14, 11, acc)
		"ouija":
			_sk_r(g, 2, 4, 20, 16, 9)
			_sk_r(g, 2, 4, 20, 1, 10)
			_sk_r(g, 3, 5, 18, 14, 8)
			for lx2: int in range(5, 20, 2):
				_sk_p(g, lx2, 8 + absi(lx2 - 12) / 4, 14)
			for lx3: int in range(5, 20, 2):
				_sk_p(g, lx3, 13 + absi(lx3 - 12) / 5, 4)
			_sk_p(g, 4, 6, 11)
			_sk_p(g, 19, 6, 11)
			_sk_e(g, 12.0, 11.0, 2.5, 2.5, 4)
			_sk_p(g, 11, 10, 15)
			_sk_r(g, 15, 15, 6, 4, 0)
			_sk_r(g, 14, 17, 2, 2, 0)
			_sk_p(g, 17, 16, 13)
			_sk_p(g, 19, 17, 12)
		_:  # clock
			_sk_e(g, 12.0, 13.0, 9.0, 9.0, 11)
			_sk_e(g, 12.0, 13.0, 7.0, 7.0, 15)
			_sk_l(g, 12, 13, 12, 8, 0)
			_sk_l(g, 12, 13, 16, 15, 0)
			_sk_r(g, 11, 2, 2, 3, 10)
			_sk_p(g, 12, 13, 13)
	# a seeded mark so two ids that share a shape still differ: a tiny gem, rune dot or crack in the accent colour
	var mx: int = 4 + (hv / 7) % 16
	var my: int = 4 + (hv / 131) % 16
	if _sk_idx(g, mx, my) >= 0:
		_sk_p(g, mx, my, acc)


# ---------------------------------------------------------------- round 5: the Collector, omens, altar, upgrades

const SK_COL_W: int = 72
const SK_COL_H: int = 110
const SK_OMEN_W: int = 48
const SK_OMEN_H: int = 40
const SK_ALTAR_W: int = 96
const SK_ALTAR_H: int = 64
const SK_UPG_SHAPES: Array[String] = ["shelf", "scroll", "cast", "eye", "coin", "pendulum", "candle", "purse", "hourglass", "bell"]
const SK_UPG_WORDS: Dictionary = {
	"shelf": "shelf", "shelves": "shelf", "slot": "shelf", "spell": "scroll", "page": "scroll", "grimoire": "scroll",
	"cast": "cast", "bolt": "cast", "tell": "eye", "eye": "eye", "sight": "eye", "rent": "coin", "landlord": "coin",
	"coin": "coin", "pendulum": "pendulum", "candle": "candle", "dread": "candle", "altar": "candle",
	"cash": "purse", "purse": "purse", "keep": "purse", "salvage": "purse", "hour": "hourglass", "time": "hourglass",
	"bell": "bell",
}
const SK_CURIO_BY_ID: Dictionary = {
	"curio_01": "dagger", "curio_02": "candle", "curio_03": "teacup", "curio_04": "veil", "curio_05": "envelope",
	"curio_06": "mirror", "curio_07": "planchette", "curio_08": "cradle", "curio_09": "teeth_jar", "curio_10": "bell",
	"curio_11": "wine", "curio_12": "tin", "curio_13": "rosary", "curio_14": "reliquary", "curio_15": "candle_out",
	"curio_16": "vial", "curio_17": "clock", "curio_18": "spoon", "curio_19": "dummy", "curio_20": "eyebox",
	"curio_21": "grille", "curio_22": "ouija", "curio_23": "key", "curio_24": "chalice",
}


## The Collector, the night-5 boss: 4 idle frames at 72x110 (rest, breath, blink, a tiny drawer slides open). A very
## tall figure in a long coat and top hat, a thin bone-white face, and a velvet case of tiny drawers held to his chest
## in long gloveless fingers. Elegant and wrong.
static func collector_frames() -> Array[ImageTexture]:
	var out: Array[ImageTexture] = []
	for f: int in range(4):
		out.append(ImageTexture.create_from_image(_sk_collector(f)))
	return out


static func _sk_collector(f: int) -> Image:
	var g: Image = _sk_new(SK_COL_W, SK_COL_H)
	var up: int = 1 if f == 1 else 0
	var cx: int = 36
	# the long coat: sloped shoulders, a tight waist, a hem that flares and tears into points
	for y: int in range(36, SK_COL_H):
		var hw: float = 14.0
		if y > 40:
			hw = lerpf(14.0, 15.0, clampf(float(y - 40) / 20.0, 0.0, 1.0))
		if y > 70:
			hw = lerpf(15.0, 27.0, clampf(float(y - 70) / 39.0, 0.0, 1.0))
		var xl: int = cx - roundi(hw)
		var xr: int = cx + roundi(hw)
		var tooth: int = ((y * 31 + 7) % 9) / 4 if y > 100 else 0
		var yd: int = y - up if y <= 60 else y
		for x: int in range(xl, xr + 1):
			if y > 105 and ((x * 37 + 11) % 7) / 2 > 109 - y + tooth:
				continue
			var u: float = float(x - xl) / float(maxi(xr - xl, 1))
			var t: int = 1
			if u < 0.1:
				t = 3
			elif u < 0.24:
				t = 2 if (x + y) % 2 == 0 else 1
			elif u > 0.86:
				t = 0
			elif u > 0.72 and (x + y) % 2 == 0:
				t = 0
			_sk_p(g, x, yd, t)
		if up == 1 and y == 60:
			for x2: int in range(xl, xr + 1):
				_sk_p(g, x2, 60, 1)
	# long vertical folds that open into the hem, and the dark red lining showing in the front slit
	for fx: int in [-18, -9, 8, 17]:
		for y2: int in range(72, SK_COL_H - 2):
			if (y2 + fx) % 6 != 0:
				_sk_p(g, cx + fx + (y2 - 72) * fx / 60, y2, 0)
				_sk_p(g, cx + fx - 1 + (y2 - 72) * fx / 60, y2, 2 if fx < 0 else 1)
	_sk_r(g, cx - 1, 86, 3, 22, 12)
	_sk_r(g, cx - 1, 86, 1, 22, 13)
	# cravat, standing collar, a watch chain and brass buttons
	_sk_r(g, cx - 9, 30 - up, 18, 8, 2)
	_sk_r(g, cx - 9, 30 - up, 3, 8, 3)
	_sk_r(g, cx + 6, 30 - up, 3, 8, 0)
	_sk_r(g, cx - 3, 33 - up, 6, 7, 15)
	_sk_l(g, cx - 3, 33 - up, cx, 40 - up, 14)
	_sk_l(g, cx + 3, 33 - up, cx, 40 - up, 14)
	for by: int in [43, 49, 55]:
		_sk_p(g, cx - 4, by - up, 10)
		_sk_p(g, cx - 5, by - up, 11)
	_sk_l(g, cx - 4, 49 - up, cx + 2, 53 - up, 10)
	_sk_l(g, cx + 2, 53 - up, cx + 5, 50 - up, 11)
	# neck, a very long pale face with hollow cheeks, deep sockets, a thin mouth
	var hy: int = 22 - up
	_sk_r(g, cx - 2, hy + 8, 5, 8, 14)
	_sk_r(g, cx + 1, hy + 8, 2, 8, 4)
	_sk_e(g, float(cx), float(hy), 6.0, 9.5, 14)
	_sk_e(g, float(cx) - 1.5, float(hy) - 1.0, 4.0, 8.0, 15)
	_sk_r(g, cx + 3, hy - 6, 3, 13, 4)
	_sk_r(g, cx - 5, hy + 1, 2, 5, 4)
	_sk_r(g, cx + 3, hy + 1, 2, 5, 4)
	_sk_p(g, cx - 4, hy, 15)
	_sk_r(g, cx - 3, hy + 8, 6, 1, 4)
	_sk_r(g, cx - 1, hy + 2, 2, 4, 4)  # nose
	_sk_r(g, cx - 3, hy + 6, 7, 1, 0)  # mouth, with a slight, patient curl
	_sk_p(g, cx + 4, hy + 5, 0)
	_sk_p(g, cx - 4, hy + 5, 0)
	# the top hat: a tall crown, a red band, a curled brim that shades the eyes
	_sk_r(g, cx - 8, hy - 21, 17, 15, 1)
	_sk_r(g, cx - 8, hy - 21, 3, 15, 2)
	_sk_r(g, cx + 5, hy - 21, 4, 15, 0)
	_sk_r(g, cx - 8, hy - 21, 17, 2, 3)
	_sk_r(g, cx - 8, hy - 9, 17, 2, 12)
	_sk_r(g, cx - 8, hy - 9, 3, 2, 13)
	_sk_e(g, float(cx), float(hy - 5), 14.0, 2.3, 1)
	_sk_r(g, cx - 14, hy - 5, 10, 1, 2)
	_sk_r(g, cx - 12, hy - 3, 24, 1, 0)
	_sk_r(g, cx - 6, hy - 2, 12, 1, 4)  # the brim's shadow across the brow
	for ex: int in [-3, 2]:
		if f == 2:
			_sk_r(g, _sk_eye_x(cx, ex), hy + 1, 3, 1, 0)
		else:
			_sk_r(g, _sk_eye_x(cx, ex), hy - 1, 3, 3, 0)
			_sk_p(g, _sk_eye_x(cx, ex) + 1, hy, 11)
	# the case: red velvet, brass edge, a grid of tiny drawers with brass pulls (one slides open in frame 3)
	var by0: int = 60 - up
	_sk_r(g, 22, by0, 28, 23, 12)
	_sk_r(g, 22, by0, 28, 1, 13)
	_sk_r(g, 22, by0, 1, 23, 13)
	_sk_r(g, 49, by0, 1, 23, 0)
	_sk_r(g, 22, by0 + 22, 28, 1, 0)
	_sk_r(g, 23, by0 + 1, 26, 1, 10)
	_sk_r(g, 23, by0 + 21, 26, 1, 8)
	_sk_p(g, 23, by0 + 1, 11)
	_sk_p(g, 48, by0 + 1, 11)
	for r: int in range(3):
		for c: int in range(4):
			var dx: int = 24 + c * 6
			var dy: int = by0 + 3 + r * 6
			var open: bool = f == 3 and r == 0 and c == 2
			if open:
				_sk_r(g, dx, dy, 5, 5, 0)
				_sk_p(g, dx + 1, dy + 1, 15)
				_sk_p(g, dx + 2, dy + 1, 11)
				dy += 3
			_sk_r(g, dx, dy, 5, 5, 8)
			_sk_r(g, dx, dy, 5, 1, 9)
			_sk_r(g, dx, dy + 4, 5, 1, 0)
			_sk_p(g, dx + 2, dy + 2, 11 if (r + c) % 3 != 1 else 10)
	# long white fingers wrapped under the case from the cuffs, thumbs over the front
	for h: int in range(2):
		var hx2: int = 16 if h == 0 else 50
		var sgn: int = 1 if h == 0 else -1
		_sk_r(g, hx2 - 2 * (1 - h), 42 - up, 8, 41 + up, 1)
		_sk_r(g, hx2 - 2 * (1 - h), 42 - up, 1, 41 + up, 2 if h == 0 else 0)
		_sk_r(g, hx2 - 2 * (1 - h) + 7 * h, 42 - up, 1, 41 + up, 0)
		_sk_r(g, hx2 - 1, 80, 8, 3, 15)
		_sk_r(g, hx2 - 1, 80, 8, 1, 14)
		_sk_p(g, hx2 + 3, 82, 11)
		for i: int in range(4):
			var fxp: int = hx2 + (i * 2 if h == 0 else 6 - i * 2)
			var ln: int = [8, 12, 11, 7][i if h == 0 else 3 - i]
			for k: int in range(ln):
				var tone: int = 15 if i == 0 else 14
				if k == 3 and i % 2 == 0:
					tone = 4
				elif k == ln - 1:
					tone = 3
				_sk_p(g, fxp + sgn * k / 5, 83 + k, tone)
		_sk_r(g, 22 + h * 24 + sgn * 0, by0 + 12, 4, 1, 15)  # a thumb laid across the case edge
	_sk_outline(g)
	_sk_polish(g, "collector_boss", f)
	return g


static func _sk_eye_x(cx: int, ex: int) -> int:
	return cx + ex - 1


## A 48x40 illustration for one of the 12 omens, shown on the omen card. Each is a small framed night scene on its
## own backdrop; an unknown id gets a plain moon.
static func omen_art(id: String) -> ImageTexture:
	var g: Image = _sk_new(SK_OMEN_W, SK_OMEN_H)
	_sk_omen_back(g, id)
	match id:
		"gravedigger":
			_sk_e(g, 38.0, 9.0, 5.0, 5.0, 15)
			_sk_e(g, 39.5, 8.0, 3.5, 3.5, 14)
			_sk_e(g, 24.0, 38.0, 22.0, 8.0, 8)
			_sk_e(g, 22.0, 37.0, 16.0, 5.0, 9)
			_sk_r(g, 7, 19, 9, 13, 14)
			_sk_e(g, 11.0, 19.0, 4.5, 3.0, 14)
			_sk_r(g, 7, 19, 2, 13, 15)
			_sk_r(g, 14, 19, 2, 13, 4)
			_sk_r(g, 11, 22, 1, 6, 0)
			_sk_r(g, 9, 24, 5, 1, 0)
			_sk_l(g, 30, 8, 26, 27, 9)
			_sk_l(g, 31, 8, 27, 27, 8)
			_sk_r(g, 28, 7, 6, 2, 9)
			_sk_art(g, ["4444", "4f44", ".444", ".44."], 24, 27)
			_sk_r(g, 20, 34, 3, 2, 8)
			_sk_r(g, 33, 33, 3, 2, 8)
		"blind_lamp":
			_sk_r(g, 15, 6, 18, 9, 3)
			_sk_r(g, 15, 6, 18, 2, 4)
			_sk_r(g, 15, 13, 18, 2, 2)
			_sk_r(g, 22, 15, 4, 16, 9)
			_sk_r(g, 22, 15, 1, 16, 10)
			_sk_r(g, 17, 31, 14, 3, 8)
			_sk_r(g, 17, 31, 14, 1, 9)
			for y: int in range(16, 36):  # a cone of nothing: sparse grey dither and no light
				var hwid: int = (y - 15) / 2 + 2
				for x: int in range(24 - hwid, 24 + hwid + 1):
					if (x + y) % 4 == 0 and (x < 21 or x > 27 or y > 30):
						_sk_p(g, x, y, 2)
			_sk_l(g, 19, 7, 29, 14, 13)
			_sk_l(g, 29, 7, 19, 14, 13)
			_sk_l(g, 19, 8, 29, 15, 12)
			_sk_l(g, 29, 8, 19, 15, 12)
		"deaf_ear":
			_sk_e(g, 27.0, 16.0, 9.0, 11.0, 14)
			_sk_e(g, 26.0, 33.0 - 3.0, 4.0, 5.0, 14)
			_sk_e(g, 25.5, 15.0, 7.0, 9.5, 15)
			_sk_e(g, 28.0, 17.0, 5.0, 8.0, 14)
			_sk_e(g, 28.5, 19.0, 3.0, 5.5, 4)
			_sk_r(g, 28, 21, 3, 4, 0)
			_sk_r(g, 28, 21, 3, 2, 11)  # a plug of wax in the canal
			_sk_l(g, 22, 14, 24, 25, 4)
			_sk_r(g, 33, 12, 2, 12, 4)
			for ax: int in [6, 10, 14]:
				_sk_e_arc(g, ax + 6, 18, 3 + (ax - 6) / 2)
			_sk_l(g, 4, 31, 18, 9, 13)
			_sk_l(g, 5, 31, 19, 9, 12)
		"numb_hands":
			_sk_r(g, 17, 22, 15, 12, 4)
			_sk_r(g, 17, 22, 15, 2, 15)
			for fi: int in range(4):
				var fy: int = [10, 7, 8, 12][fi]
				_sk_r(g, 17 + fi * 4, fy, 3, 22 - fy + 2, 4)
				_sk_r(g, 17 + fi * 4, fy, 1, 22 - fy, 15)
				_sk_r(g, 17 + fi * 4, fy, 3, 2, 15)
				_sk_l(g, 18 + fi * 4, fy + 3, 18 + fi * 4, fy + 10, 3)
			_sk_r(g, 11, 24, 6, 3, 4)
			_sk_r(g, 11, 24, 6, 1, 15)
			_sk_r(g, 17, 33, 15, 2, 3)
			for fp: Vector2i in [Vector2i(8, 8), Vector2i(40, 12), Vector2i(12, 32), Vector2i(38, 30), Vector2i(34, 5)]:
				_sk_p(g, fp.x, fp.y, 15)
				_sk_p(g, fp.x - 1, fp.y, 4)
				_sk_p(g, fp.x + 1, fp.y, 4)
				_sk_p(g, fp.x, fp.y - 1, 4)
				_sk_p(g, fp.x, fp.y + 1, 4)
			for ix: int in [19, 27]:
				_sk_r(g, ix, 34, 1, 3, 15)
		"open_book":
			_sk_ring(g, 24.0, 8.0, 5.0, 5.0, 1.0, 11)
			_sk_l(g, 24, 3, 21, 11, 10)
			_sk_l(g, 24, 3, 27, 11, 10)
			_sk_l(g, 20, 7, 28, 7, 10)
			_sk_p(g, 24, 8, 15)
			for rx: int in [10, 14, 34, 38]:
				_sk_l(g, rx, 24, rx + (rx - 24) / 3, 13, 10 if rx % 8 == 2 else 11)
			_sk_r(g, 5, 15, 19, 19, 14)
			_sk_r(g, 24, 15, 19, 19, 14)
			_sk_r(g, 6, 14, 18, 18, 15)
			_sk_r(g, 24, 14, 18, 18, 15)
			_sk_r(g, 23, 14, 2, 19, 12)
			_sk_r(g, 4, 33, 40, 3, 12)
			_sk_r(g, 4, 33, 40, 1, 13)
			for ry: int in range(5):
				_sk_r(g, 8, 18 + ry * 3, 11 - (ry % 2) * 3, 1, 3)
				_sk_r(g, 28, 18 + ry * 3, 10 - (ry % 3) * 2, 1, 3)
			_sk_r(g, 6, 14, 1, 18, 14)
			_sk_r(g, 41, 14, 1, 18, 4)
			_sk_r(g, 31, 18, 6, 6, 11)  # a glowing rune
			_sk_r(g, 32, 19, 4, 4, 15)
		"hungry_pages":
			_sk_r(g, 9, 6, 30, 28, 12)
			_sk_r(g, 9, 6, 4, 28, 8)
			_sk_r(g, 9, 6, 30, 2, 13)
			_sk_r(g, 36, 8, 2, 24, 14)  # page edges
			_sk_r(g, 11, 17, 26, 9, 0)  # the mouth
			for tx: int in range(12, 36, 4):
				_sk_art(g, ["fff", ".f."], tx, 17)
				_sk_art(g, [".f.", "fff"], tx + 2, 24)
			_sk_e(g, 24.0, 23.0, 6.0, 2.0, 13)
			_sk_r(g, 20, 21, 8, 1, 12)
			_sk_e(g, 24.0, 12.0, 3.5, 3.0, 15)  # one open eye above it
			_sk_r(g, 23, 11, 2, 2, 0)
			_sk_p(g, 23, 11, 11)
			_sk_r(g, 26, 26, 1, 4, 13)  # drool
			_sk_p(g, 26, 31, 14)
		"gamblers_moon":
			_sk_e(g, 18.0, 17.0, 13.0, 13.0, 15)
			_sk_e(g, 20.0, 16.0, 10.0, 11.0, 14)
			_sk_e(g, 25.0, 15.0, 11.0, 12.0, 1)
			_sk_r(g, 29, 20, 11, 11, 15)
			_sk_r(g, 30, 21, 9, 9, 14)
			_sk_r(g, 29, 20, 11, 1, 15)
			_sk_r(g, 29, 20, 1, 11, 15)
			_sk_r(g, 39, 21, 1, 10, 4)
			_sk_r(g, 30, 30, 10, 1, 4)
			for pp: Vector2i in [Vector2i(32, 23), Vector2i(36, 27), Vector2i(36, 23), Vector2i(32, 27)]:
				_sk_r(g, pp.x, pp.y, 2, 2, 0)
			_sk_r(g, 34, 25, 2, 2, 13)
			_sk_art(g, ["f.f", ".f.", "f.f"], 7, 28)
			_sk_r(g, 5, 33, 16, 4, 12)
			_sk_r(g, 5, 33, 16, 1, 13)
		"regular_crowd":
			for fx: int in [8, 24, 40]:
				_sk_e(g, float(fx), 14.0, 5.0, 6.0, 3)
				_sk_e(g, float(fx), 15.0, 3.5, 4.0, 0)
				_sk_p(g, fx - 2, 15, 14)
				_sk_p(g, fx + 2, 15, 14)
				for y: int in range(19, 36):
					var hwid: int = 4 + (y - 19) / 3
					_sk_r(g, fx - hwid, y, hwid * 2, 1, 3 if (y + fx) % 5 != 0 else 2)
					_sk_p(g, fx - hwid, y, 4)
					_sk_p(g, fx + hwid - 1, y, 0)
			_sk_r(g, 2, 36, 44, 2, 0)
		"long_night":
			_sk_e(g, 24.0, 20.0, 15.0, 15.0, 11)
			_sk_e(g, 24.0, 20.0, 13.0, 13.0, 15)
			_sk_e(g, 24.0, 20.0, 11.0, 11.0, 14)
			for a: int in range(12):
				var ang: float = float(a) * TAU / 12.0
				_sk_p(g, 24 + roundi(cos(ang) * 11.0), 20 + roundi(sin(ang) * 11.0), 0)
			_sk_l(g, 24, 20, 24, 11, 0)
			_sk_l(g, 25, 20, 25, 11, 0)
			_sk_l(g, 24, 20, 27, 14, 12)
			_sk_r(g, 23, 19, 3, 3, 13)
			_sk_r(g, 21, 4, 6, 2, 10)
			_sk_art(g, ["..f..", ".fff.", "..f.."], 40, 6)
			_sk_art(g, ["f", "."], 6, 8)
		"landlords_pity":
			_sk_r(g, 10, 20, 28, 15, 8)
			_sk_r(g, 10, 20, 4, 15, 9)
			_sk_r(g, 34, 20, 4, 15, 1)
			for rw: int in range(9):
				_sk_r(g, 8 + rw * 1, 11 + rw, 32 - rw * 2, 1, 12 if rw % 2 == 0 else 13)
			_sk_r(g, 30, 5, 4, 8, 1)
			_sk_r(g, 15, 24, 6, 6, 11)
			_sk_r(g, 17, 24, 2, 6, 10)
			_sk_r(g, 15, 26, 6, 2, 10)
			_sk_r(g, 25, 25, 7, 10, 0)
			_sk_r(g, 26, 27, 5, 4, 15)  # the notice pinned to the door
			_sk_r(g, 27, 28, 3, 1, 12)
			_sk_p(g, 28, 27, 13)
			_sk_e(g, 41.0, 8.0, 3.0, 3.0, 11)
			_sk_p(g, 40, 7, 15)
			_sk_r(g, 40, 9, 2, 1, 10)
		"thin_veil":
			_sk_r(g, 5, 4, 38, 2, 9)
			_sk_p(g, 5, 4, 11)
			_sk_p(g, 42, 4, 11)
			_sk_e(g, 24.0, 20.0, 7.0, 9.0, 14)
			_sk_e(g, 23.0, 19.0, 4.5, 7.0, 15)
			_sk_r(g, 28, 14, 3, 12, 4)
			_sk_r(g, 20, 18, 3, 3, 0)
			_sk_r(g, 26, 18, 3, 3, 0)
			_sk_r(g, 21, 26, 6, 1, 0)
			_sk_p(g, 21, 19, 11)
			_sk_p(g, 27, 19, 11)
			for y: int in range(6, 38):
				var sway: int = roundi(sin(float(y) * 0.5) * 1.5)
				for x: int in range(6, 20 + sway):
					if (x + y) % 2 == 0 or x < 9:
						_sk_p(g, x, y, 3 if x % 4 != 0 else 2)
				for x2: int in range(28 - sway, 43):
					if (x2 + y) % 2 == 0 or x2 > 38:
						_sk_p(g, x2, y, 3 if x2 % 4 != 1 else 2)
			for y2: int in range(24, 38):  # the thin veil across the lower face
				for x3: int in range(17, 32):
					if (x3 + y2) % 3 == 0:
						_sk_p(g, x3, y2, 4)
		"hollow_coin":
			_sk_e(g, 24.0, 20.0, 15.0, 15.0, 10)
			_sk_e(g, 24.0, 20.0, 14.0, 14.0, 11)
			_sk_e(g, 24.0, 20.0, 11.0, 11.0, 10)
			_sk_r(g, 9, 11, 3, 3, 15)
			_sk_e(g, 24.0, 20.0, 8.0, 8.0, 0)  # the hollow: a hole into nowhere
			_sk_e(g, 24.0, 20.0, 6.5, 6.5, 1)
			_sk_p(g, 21, 19, 11)
			_sk_p(g, 22, 19, 15)
			_sk_p(g, 26, 19, 11)
			_sk_p(g, 27, 19, 15)
			_sk_l(g, 36, 10, 30, 17, 0)
			_sk_l(g, 24, 33, 20, 38, 0)
			_sk_l(g, 12, 25, 6, 31, 12)
		_:
			_sk_e(g, 24.0, 18.0, 9.0, 9.0, 15)
			_sk_e(g, 27.0, 16.0, 8.0, 8.0, 2)
	_sk_omen_vignette(g)
	return ImageTexture.create_from_image(g)


static func _sk_e_arc(g: Image, cx: int, cy: int, r: int) -> void:
	for a: int in range(-5, 6):
		var ang: float = float(a) * 0.28
		_sk_p(g, cx - roundi(cos(ang) * float(r)), cy + roundi(sin(ang) * float(r) * 1.8), 4)


## Backdrop of an omen card: a dusk gradient dithered in three bands, a few seeded stars, a 1 px frame.
static func _sk_omen_back(g: Image, id: String) -> void:
	var w: int = g.get_width()
	var h: int = g.get_height()
	for y: int in range(h):
		for x: int in range(w):
			var t: float = float(y) / float(h - 1)
			var c: int = 2
			if t > 0.7:
				c = 0 if (x + y) % 2 == 0 or t > 0.9 else 1
			elif t > 0.45:
				c = 1 if (x + y) % 2 == 0 or t > 0.58 else 2
			_sk_p(g, x, y, c)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(id) + 5
	for i: int in range(7):
		_sk_p(g, rng.randi_range(2, w - 3), rng.randi_range(2, 14), 4 if i % 3 != 0 else 14)


static func _sk_omen_vignette(g: Image) -> void:
	var w: int = g.get_width()
	var h: int = g.get_height()
	for y: int in range(h):
		for x: int in range(w):
			var edge: int = mini(mini(x, w - 1 - x), mini(y, h - 1 - y))
			if edge == 0:
				_sk_p(g, x, y, 4 if (x + y) % 2 == 0 else 3)
			elif edge == 1:
				_sk_p(g, x, y, 0 if (x + y) % 2 == 0 else _sk_idx(g, x, y))
			elif edge == 2 and (x + y) % 3 == 0 and _sk_idx(g, x, y) > 0:
				_sk_p(g, x, y, SK_DARK[_sk_idx(g, x, y)])
	for p: Vector2i in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		_sk_p(g, p.x, p.y, 0)


## The altar of the meta screen, 96x64: a stone slab under a black cloth sewn with a red sigil, four candles, a skull,
## a closed grimoire and a bowl of green ectoplasm with wisps. Candle flames are drawn static; the UI animates its own.
static func altar_texture() -> ImageTexture:
	var g: Image = _sk_new(SK_ALTAR_W, SK_ALTAR_H)
	# the slab: a dressed stone top and a block-built front, lit from the left
	_sk_r(g, 6, 28, 84, 36, 2)
	for y: int in range(28, 64):
		for x: int in range(6, 90):
			var row: int = (y - 28) / 9
			var seam_x: int = (x + (row % 2) * 11) % 22
			if seam_x == 0 or (y - 28) % 9 == 0:
				_sk_p(g, x, y, 1)
			elif x < 12:
				_sk_p(g, x, y, 3 if (x + y) % 2 == 0 else 2)
			elif x > 82:
				_sk_p(g, x, y, 1 if (x + y) % 2 == 0 else 0)
			elif (x * 7 + y * 3) % 11 == 0:
				_sk_p(g, x, y, 3)
	_sk_r(g, 2, 24, 92, 6, 3)
	_sk_r(g, 2, 24, 92, 2, 4)
	_sk_r(g, 2, 29, 92, 1, 1)
	_sk_r(g, 2, 24, 2, 6, 4)
	_sk_r(g, 92, 24, 2, 6, 2)
	# the cloth runner hanging over the front, with a red hem and a sigil
	_sk_r(g, 27, 30, 42, 34, 0)
	_sk_r(g, 27, 30, 3, 34, 1)
	_sk_r(g, 66, 30, 3, 34, 0)
	for fx: int in [36, 46, 56]:
		for y2: int in range(32, 62):
			if (y2 + fx) % 4 != 0:
				_sk_p(g, fx + (y2 - 32) / 14 * (1 if fx > 46 else -1), y2, 1)
	_sk_r(g, 27, 60, 42, 3, 12)
	for tx: int in range(27, 69, 3):
		_sk_r(g, tx, 63, 2, 1, 12)
	_sk_ring(g, 48.0, 46.0, 9.0, 9.0, 1.0, 13)
	_sk_l(g, 48, 38, 43, 52, 13)
	_sk_l(g, 48, 38, 53, 52, 13)
	_sk_l(g, 42, 44, 54, 44, 13)
	_sk_l(g, 43, 52, 54, 44, 12)
	_sk_l(g, 53, 52, 42, 44, 12)
	_sk_p(g, 48, 46, 11)
	_sk_p(g, 48, 47, 10)
	# the things on it: four candles, a skull, a book, the ectoplasm bowl
	for cd: Vector2i in [Vector2i(10, 13), Vector2i(20, 8), Vector2i(76, 9), Vector2i(86, 14)]:
		_sk_r(g, cd.x - 2, cd.y, 5, 24 - cd.y, 14)
		_sk_r(g, cd.x - 2, cd.y, 2, 24 - cd.y, 15)
		_sk_r(g, cd.x + 2, cd.y, 1, 24 - cd.y, 4)
		_sk_r(g, cd.x - 4, 22, 9, 2, 10)
		_sk_r(g, cd.x - 4, 22, 9, 1, 11)
		_sk_p(g, cd.x + 1, cd.y + 3, 15)
		_sk_p(g, cd.x + 1, cd.y + 4, 15)
		_sk_p(g, cd.x, cd.y - 1, 0)
	_sk_e(g, 34.0, 18.0, 5.0, 4.5, 14)
	_sk_r(g, 31, 20, 7, 4, 14)
	_sk_r(g, 29, 14, 3, 4, 15)
	_sk_r(g, 31, 17, 2, 2, 0)
	_sk_r(g, 36, 17, 2, 2, 0)
	_sk_p(g, 34, 20, 4)
	_sk_r(g, 32, 23, 1, 1, 0)
	_sk_r(g, 34, 23, 1, 1, 0)
	_sk_r(g, 36, 23, 1, 1, 0)
	_sk_r(g, 62, 18, 11, 6, 12)
	_sk_r(g, 62, 18, 11, 1, 13)
	_sk_r(g, 62, 18, 2, 6, 8)
	_sk_r(g, 72, 19, 1, 4, 14)
	_sk_ring(g, 68.0, 21.0, 2.0, 2.0, 1.0, 10)
	_sk_r(g, 41, 18, 15, 6, 14)
	_sk_e(g, 48.0, 19.0, 8.0, 3.0, 14)
	_sk_r(g, 40, 18, 17, 1, 15)
	_sk_r(g, 43, 23, 11, 1, 4)
	_sk_outline(g)
	_sk_r(g, 43, 18, 11, 1, 6)
	_sk_r(g, 44, 19, 9, 1, 7)
	_sk_r(g, 46, 18, 4, 1, 15)
	for w: Vector2i in [Vector2i(46, 14), Vector2i(48, 10), Vector2i(47, 6), Vector2i(50, 12), Vector2i(51, 8), Vector2i(49, 3)]:
		_sk_p(g, w.x, w.y, 7 if (w.x + w.y) % 2 == 0 else 6)
	_sk_p(g, 47, 2, 5)
	for cd2: Vector2i in [Vector2i(10, 13), Vector2i(20, 8), Vector2i(76, 9), Vector2i(86, 14)]:
		_sk_art(g, ["..b..", ".bab.", ".bfb.", ".bfb.", "..b.."], cd2.x - 2, cd2.y - 6)
	return ImageTexture.create_from_image(g)


## The Pendulum tool prop, 24x24: a brass anchor ring, a fine chain and a smoky crystal weight, hanging straight.
static func pendulum_texture() -> ImageTexture:
	var g: Image = _sk_new(24, 24)
	_sk_ring(g, 12.0, 2.0, 3.0, 2.0, 1.0, 10)
	_sk_l(g, 12, 4, 12, 13, 14)
	_sk_p(g, 11, 6, 4)
	_sk_p(g, 13, 9, 4)
	_sk_art(g, ["...44...", "..4f44..", ".4f4444.", ".4f4344.", ".444334.", "..4333..", "..2333..", "...22...", "...2...."], 8, 13)
	_sk_r(g, 11, 12, 2, 2, 10)
	_sk_outline(g)
	_sk_p(g, 10, 16, 15)
	_sk_p(g, 9, 17, 15)
	_sk_polish(g, "tool_pendulum", 2)
	return ImageTexture.create_from_image(g)


## A 16x16 icon for one altar upgrade. The id is looked up in game/data/upgrades.json at call time when that file
## exists (its name picks the shape: shelf, scroll, bolt, eye, coin, pendulum, candle, purse...); an id that matches
## nothing gets a shape seeded by the id hash. Repeatable: the same id always gives the same bytes.
static func upgrade_icon(id: String) -> ImageTexture:
	var nm: String = id.to_lower()
	var row: Dictionary = _sk_upgrade_row(id)
	var shape: String = _sk_upg_find(nm + " " + str(row.get("name", "")).to_lower())
	if shape == "" and not row.is_empty():
		shape = _sk_upg_find(str(row.get("text", "")).to_lower())
	var hv: int = absi(hash(id))
	if shape == "":
		shape = SK_UPG_SHAPES[hv % SK_UPG_SHAPES.size()]
	var g: Image = _sk_new(16, 16)
	match shape:
		"shelf":
			_sk_r(g, 1, 8, 14, 2, 9)
			_sk_r(g, 1, 8, 14, 1, 10)
			_sk_r(g, 2, 10, 2, 4, 8)
			_sk_r(g, 12, 10, 2, 4, 8)
			_sk_r(g, 3, 3, 3, 5, 5)
			_sk_r(g, 3, 3, 1, 5, 7)
			_sk_r(g, 7, 4, 4, 4, 12)
			_sk_r(g, 7, 4, 1, 4, 13)
			_sk_r(g, 12, 1, 3, 1, 11)
			_sk_r(g, 13, 0, 1, 3, 11)
		"scroll":
			_sk_r(g, 3, 2, 10, 12, 15)
			_sk_r(g, 2, 1, 12, 2, 14)
			_sk_r(g, 2, 13, 12, 2, 14)
			_sk_ring(g, 8.0, 8.0, 3.0, 3.0, 1.0, 13)
			_sk_p(g, 8, 8, 13)
			_sk_r(g, 4, 4, 3, 1, 3)
			_sk_r(g, 10, 12, 2, 1, 3)
		"cast":
			_sk_art(g, ["...bbbb.", "..bbbb..", ".bbbb...", "bbbbbbb.", "..bbbb..", "...bb...", "..bb....", ".b......"], 4, 0)
			_sk_p(g, 2, 3, 15)
			_sk_p(g, 13, 11, 15)
			_sk_p(g, 12, 2, 10)
		"eye":
			_sk_e(g, 8.0, 8.0, 7.0, 4.0, 15)
			_sk_e(g, 8.0, 8.0, 3.0, 3.0, 7)
			_sk_e(g, 8.0, 8.0, 1.5, 1.5, 0)
			_sk_p(g, 6, 6, 15)
			_sk_r(g, 1, 4, 14, 1, 14)
		"coin":
			_sk_e(g, 8.0, 8.0, 6.5, 6.5, 11)
			_sk_e(g, 8.0, 8.0, 4.5, 4.5, 10)
			_sk_r(g, 5, 7, 6, 2, 11)
			_sk_r(g, 5, 7, 6, 1, 15)
			_sk_p(g, 4, 4, 15)
		"pendulum":
			_sk_ring(g, 8.0, 1.0, 2.0, 1.0, 1.0, 10)
			_sk_l(g, 8, 2, 8, 8, 14)
			_sk_art(g, ["..44..", ".4f44.", "4f4444", "4f4344", ".4333.", "..33.."], 5, 8)
		"candle":
			_sk_r(g, 6, 7, 4, 7, 15)
			_sk_r(g, 6, 7, 1, 7, 14)
			_sk_r(g, 9, 7, 1, 7, 4)
			_sk_r(g, 4, 14, 8, 2, 10)
			_sk_art(g, [".b.", "bfb", "bfb", ".b."], 6, 2)
		"purse":
			_sk_e(g, 8.0, 10.0, 6.0, 5.0, 9)
			_sk_e(g, 7.0, 9.0, 3.0, 3.0, 10)
			_sk_r(g, 5, 4, 6, 2, 8)
			_sk_r(g, 4, 6, 8, 1, 11)
			_sk_r(g, 7, 1, 2, 3, 11)
			_sk_p(g, 12, 13, 11)
			_sk_p(g, 13, 14, 10)
		"hourglass":
			_sk_r(g, 3, 1, 10, 2, 9)
			_sk_r(g, 3, 13, 10, 2, 9)
			for hy: int in range(3, 13):
				var hw: int = absi(hy - 8) + 1
				_sk_r(g, 8 - hw, hy, hw * 2, 1, 15 if absi(hy - 8) > 2 else 4)
			for sy: int in range(9, 13):
				_sk_r(g, 8 - (sy - 8), sy, (sy - 8) * 2, 1, 11)
			_sk_r(g, 7, 7, 2, 1, 11)
		_:  # bell
			_sk_e(g, 8.0, 8.0, 5.0, 6.0, 10)
			_sk_r(g, 3, 9, 10, 4, 10)
			_sk_r(g, 2, 13, 12, 1, 11)
			_sk_r(g, 7, 1, 2, 2, 9)
			_sk_e(g, 8.0, 14.0, 1.5, 1.5, 9)
			_sk_r(g, 5, 5, 1, 5, 15)
	_sk_outline(g)
	_sk_polish(g, "upg_" + id, 6)
	return ImageTexture.create_from_image(g)


static func _sk_upg_find(text: String) -> String:
	var shape: String = ""
	var best: int = 9999
	for w: String in SK_UPG_WORDS:
		var at: int = text.find(w)
		if at >= 0 and at < best:
			best = at
			shape = str(SK_UPG_WORDS[w])
	return shape


static func _sk_upgrade_row(id: String) -> Dictionary:
	var f: FileAccess = FileAccess.open("res://game/data/upgrades.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and (parsed as Dictionary).get("upgrades", null) is Array:
		parsed = (parsed as Dictionary)["upgrades"]
	if parsed is Array:
		for r: Variant in parsed as Array:
			if r is Dictionary and str((r as Dictionary).get("id", "")) == id:
				return r as Dictionary
	return {}
