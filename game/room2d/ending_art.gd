class_name EndingArt
extends RefCounted
## One full-screen 640x360 illustration per ending (docs/full_game_plan.md step 34), drawn in code from the 16-colour
## palette. `tableau(id)` takes an ending id or any text containing one of the keywords in ALIASES:
##   debt_free   dawn, the door open, the last rent paid, a key in a hand
##   cursed      the shop kept you: every shelf turned its eyes to the counter, the door papered over
##   collector   the Collector's case open on the bare counter, one coin spilling into the light
##   regulars    closing time: the regulars around one table with a cake, one empty chair
##   evicted     the lost run: rain, a boarded door, a lone figure with a suitcase
## Unknown ids give the debt_free scene. Same id, same pixels.

const W: int = 640
const H: int = 360
const IDS: Array[String] = ["debt_free", "cursed", "collector", "regulars", "evicted"]
const ALIASES: Array = [["debt", "debt_free"], ["paid", "debt_free"], ["free", "debt_free"], ["curse", "cursed"],
	["kept", "cursed"], ["collector", "collector"], ["bargain", "collector"], ["regular", "regulars"], ["friend", "regulars"],
	["lost", "evicted"], ["evict", "evicted"], ["broke", "evicted"]]
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


static func id_for(text: String) -> String:
	var t: String = text.to_lower()
	if IDS.has(t):
		return t
	for a: Array in ALIASES:
		if t.contains(str(a[0])):
			return str(a[1])
	return "debt_free"


static func tableau(id: String) -> ImageTexture:
	return ImageTexture.create_from_image(tableau_image(id))


static func tableau_image(id: String) -> Image:
	var g: Image = SpriteKit._sk_new(W, H)
	match id_for(id):
		"cursed": ea_cursed(g)
		"collector": ea_collector(g)
		"regulars": ea_regulars(g)
		"evicted": ea_evicted(g)
		_: ea_debt_free(g)
	ea_vignette(g)
	return g


# ---------------------------------------------------------------- helpers

static func ea_band(g: Image, y0: int, y1: int, cols: Array[int]) -> void:
	var n: int = cols.size()
	var span: float = float(y1 - y0)
	for y: int in range(y0, y1):
		var f: float = float(y - y0) / span * float(n - 1)
		var i: int = mini(int(f), n - 2)
		var frac: float = f - float(i)
		for x: int in range(0, W):
			var thr: float = float(BAYER[(y % 4) * 4 + (x % 4)]) / 16.0
			SpriteKit._sk_p(g, x, y, cols[i + 1] if frac > thr else cols[i])


static func ea_glow(g: Image, cx: int, cy: int, r: int, col: int, ry_scale: float = 1.0) -> void:
	for y: int in range(maxi(cy - int(float(r) * ry_scale), 0), mini(cy + int(float(r) * ry_scale) + 1, H)):
		for x: int in range(maxi(cx - r, 0), mini(cx + r + 1, W)):
			var dx: float = float(x - cx) / float(r)
			var dy: float = float(y - cy) / (float(r) * ry_scale)
			var d: float = dx * dx + dy * dy
			if d >= 1.0:
				continue
			var thr: float = float(BAYER[(y % 4) * 4 + (x % 4)]) / 16.0
			if (1.0 - d) * 1.1 > thr + 0.15:
				SpriteKit._sk_p(g, x, y, col)


## Dithered fade of whatever is under it toward `col`: a haze or a shadow of strength 0..1.
static func ea_haze(g: Image, x0: int, y0: int, x1: int, y1: int, col: int, strength: float) -> void:
	for y: int in range(maxi(y0, 0), mini(y1, H)):
		for x: int in range(maxi(x0, 0), mini(x1, W)):
			if float(BAYER[(y % 4) * 4 + (x % 4)]) / 16.0 < strength:
				SpriteKit._sk_p(g, x, y, col)


static func ea_vignette(g: Image) -> void:
	for i: int in range(5):
		ea_haze(g, 0, 0, W, i * 3 + 3, 0, 0.7 - float(i) * 0.14)
		ea_haze(g, 0, H - i * 3 - 3, W, H, 0, 0.7 - float(i) * 0.14)
		ea_haze(g, 0, 0, i * 4 + 4, H, 0, 0.6 - float(i) * 0.12)
		ea_haze(g, W - i * 4 - 4, 0, W, H, 0, 0.6 - float(i) * 0.12)


## A cloaked figure standing with its feet at (x, base): kind "hat" top hat, "hood", "veil", "cap", "bun", "bare".
static func ea_figure(g: Image, x: int, base: int, h: int, body: int, kind: String, eyes: int = -1) -> void:
	var hw: int = maxi(h / 6, 3)
	var head_y: int = base - h
	for y: int in range(head_y + h / 6, base):
		var k: float = float(y - head_y - h / 6) / float(h - h / 6)
		var half: int = roundi(float(hw) * (0.9 + k * 1.6))
		SpriteKit._sk_r(g, x - half, y, half * 2 + 1, 1, body)
		SpriteKit._sk_p(g, x - half, y, SpriteKit.SK_LIGHT[body])
		SpriteKit._sk_p(g, x + half, y, SpriteKit.SK_DARK[body])
	SpriteKit._sk_e(g, float(x), float(head_y + h / 8), float(hw), float(hw) * 1.1, body)
	match kind:
		"hat":
			SpriteKit._sk_r(g, x - hw, head_y - h / 5, hw * 2, h / 5, body)
			SpriteKit._sk_r(g, x - hw - 3, head_y, hw * 2 + 6, 2, body)
			SpriteKit._sk_r(g, x - hw, head_y - h / 5, hw * 2, 1, SpriteKit.SK_LIGHT[body])
		"hood":
			SpriteKit._sk_e(g, float(x), float(head_y + h / 8 - 1), float(hw) + 2.0, float(hw) + 3.0, body)
		"veil":
			SpriteKit._sk_e(g, float(x), float(head_y + h / 8), float(hw) + 1.0, float(hw) + 2.0, SpriteKit.SK_DARK[body])
			SpriteKit._sk_r(g, x - hw, head_y + h / 8, hw * 2, h / 6, SpriteKit.SK_DARK[body])
		"cap":
			SpriteKit._sk_r(g, x - hw, head_y + h / 8 - hw, hw * 2, hw / 2 + 1, body)
			SpriteKit._sk_r(g, x - hw - 2, head_y + h / 8 - hw / 2, hw + 3, 1, body)
		"bun":
			SpriteKit._sk_e(g, float(x), float(head_y - 1), float(hw) / 2.0 + 1.0, float(hw) / 2.0 + 1.0, body)
	if eyes >= 0:
		SpriteKit._sk_p(g, x - hw / 2, head_y + h / 8, eyes)
		SpriteKit._sk_p(g, x + hw / 2, head_y + h / 8, eyes)


static func ea_candle(g: Image, x: int, y: int, lit: bool = true) -> void:
	SpriteKit._sk_r(g, x - 1, y - 7, 3, 7, 14)
	SpriteKit._sk_r(g, x - 1, y - 7, 3, 1, 15)
	if lit:
		SpriteKit._sk_r(g, x, y - 11, 1, 3, 11)
		SpriteKit._sk_p(g, x, y - 12, 15)
		SpriteKit._sk_p(g, x - 1, y - 9, 10)
		SpriteKit._sk_p(g, x + 1, y - 9, 10)


static func ea_window(g: Image, x: int, y: int, w: int, h: int, lit: int) -> void:
	SpriteKit._sk_r(g, x - 2, y - 2, w + 4, h + 4, 8)
	SpriteKit._sk_r(g, x, y, w, h, lit)
	SpriteKit._sk_r(g, x + w / 2, y, 1, h, 8)
	SpriteKit._sk_r(g, x, y + h / 2, w, 1, 8)


static func ea_cobbles(g: Image, y0: int, c1: int, c2: int) -> void:
	for y: int in range(y0, H):
		var row: int = (y - y0) / 8
		SpriteKit._sk_r(g, 0, y, W, 1, c1)
		if (y - y0) % 8 == 0:
			SpriteKit._sk_r(g, 0, y, W, 1, c2)
		else:
			for x: int in range((row % 2) * 8, W, 16):
				SpriteKit._sk_p(g, x, y, c2)


static func ea_shelf(g: Image, x: int, y: int, w: int, with_eyes: bool, seed_v: int) -> void:
	SpriteKit._sk_r(g, x, y, w, 4, 9)
	SpriteKit._sk_r(g, x, y, w, 1, 10)
	SpriteKit._sk_r(g, x, y + 4, w, 2, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var cx: int = x + 4
	while cx < x + w - 10:
		var iw: int = rng.randi_range(6, 12)
		var ih: int = rng.randi_range(9, 20)
		var c: int = [1, 2, 8, 9, 12, 3][rng.randi_range(0, 5)]
		SpriteKit._sk_r(g, cx, y - ih, iw, ih, c)
		SpriteKit._sk_r(g, cx, y - ih, 1, ih, SpriteKit.SK_LIGHT[c])
		SpriteKit._sk_r(g, cx, y - ih, iw, 1, SpriteKit.SK_LIGHT[c])
		if with_eyes and iw >= 7:
			var ey: int = y - ih + ih / 3
			SpriteKit._sk_r(g, cx + 1, ey, 2, 2, 13 if rng.randf() < 0.6 else 11)
			SpriteKit._sk_r(g, cx + iw - 3, ey, 2, 2, 13 if rng.randf() < 0.6 else 11)
		cx += iw + rng.randi_range(1, 3)


# ---------------------------------------------------------------- the five scenes

## Dawn after the last night: a pale gold band under a bruised sky, the shop front with its door open and the lamps
## still lit, the owner a small dark figure on the step with a key, a torn rent notice on the cobbles.
static func ea_debt_free(g: Image) -> void:
	ea_band(g, 0, 200, [1, 2, 3, 4, 14, 11, 10])
	for i: int in range(18):  # the last stars
		SpriteKit._sk_p(g, (i * 97) % W, (i * 31) % 70 + 4, 15 if i % 3 == 0 else 4)
	SpriteKit._sk_e(g, 470.0, 176.0, 34.0, 34.0, 11)  # the sun, half risen behind the roofs
	SpriteKit._sk_e(g, 470.0, 176.0, 26.0, 26.0, 15)
	for i: int in range(7):  # roofline across the back
		var bx: int = i * 96 - 20
		SpriteKit._sk_r(g, bx, 168 - (i % 3) * 14, 90, 80, 2)
		SpriteKit._sk_r(g, bx, 168 - (i % 3) * 14, 90, 2, 3)
		SpriteKit._sk_r(g, bx + 20, 150 - (i % 3) * 14, 6, 20, 1)
	ea_cobbles(g, 268, 2, 1)
	# the shop: a narrow, crooked front in the middle
	SpriteKit._sk_r(g, 196, 70, 250, 202, 1)
	SpriteKit._sk_r(g, 196, 70, 250, 4, 3)
	SpriteKit._sk_r(g, 196, 74, 6, 198, 2)
	for y: int in range(80, 262, 12):
		SpriteKit._sk_r(g, 204, y, 234, 1, 0)
	SpriteKit._sk_r(g, 188, 60, 266, 12, 8)  # cornice
	SpriteKit._sk_r(g, 188, 60, 266, 2, 9)
	SpriteKit._sk_r(g, 214, 90, 212, 26, 0)  # signboard
	SpriteKit._sk_r(g, 216, 92, 208, 22, 8)
	for i: int in range(7):  # sign lettering as gilt blocks
		SpriteKit._sk_r(g, 232 + i * 26, 98, 16, 10, 10)
		SpriteKit._sk_r(g, 235 + i * 26, 100, 10, 6, 8)
	ea_window(g, 214, 136, 78, 88, 10)
	ea_glow(g, 253, 180, 60, 11, 1.0)
	ea_window(g, 214, 136, 78, 88, 11)
	for p: Vector2i in [Vector2i(228, 224), Vector2i(250, 224), Vector2i(272, 224)]:  # things in the window
		SpriteKit._sk_e(g, float(p.x), float(p.y - 8), 6.0, 8.0, 8)
	SpriteKit._sk_r(g, 224, 218, 60, 6, 9)
	SpriteKit._sk_p(g, 252, 214, 13)  # one small red point: not finished with you
	SpriteKit._sk_p(g, 255, 214, 13)
	SpriteKit._sk_r(g, 332, 136, 94, 132, 0)  # the open door: a dark frame, warm light spilling out onto the step
	SpriteKit._sk_r(g, 336, 140, 86, 128, 10)
	ea_glow(g, 380, 230, 56, 11, 1.4)
	SpriteKit._sk_r(g, 336, 140, 14, 128, 8)
	SpriteKit._sk_r(g, 336, 140, 14, 128, 9)
	SpriteKit._sk_r(g, 322, 262, 118, 8, 14)  # step
	SpriteKit._sk_r(g, 322, 262, 118, 2, 15)
	SpriteKit._sk_r(g, 270, 270, 220, 14, 3)  # the light on the cobbles
	ea_haze(g, 330, 270, 440, 300, 11, 0.5)
	ea_figure(g, 392, 262, 64, 0, "hood")  # the owner, in silhouette against the light
	SpriteKit._sk_r(g, 404, 222, 3, 12, 0)
	SpriteKit._sk_r(g, 404, 218, 7, 4, 11)  # the key, held up
	SpriteKit._sk_p(g, 410, 217, 15)
	SpriteKit._sk_r(g, 80, 296, 18, 12, 15)  # the torn rent notice
	SpriteKit._sk_r(g, 84, 299, 10, 1, 8)
	SpriteKit._sk_r(g, 84, 302, 8, 1, 8)
	SpriteKit._sk_r(g, 86, 305, 5, 3, 13)  # a red "PAID" stamp
	for i: int in range(26):  # morning motes
		SpriteKit._sk_p(g, 330 + (i * 37) % 130, 160 + (i * 53) % 110, 15 if i % 2 == 0 else 11)


## The shop kept you: shelves to the ceiling and every object has turned its eyes to the counter, the door papered over
## with wallpaper, a huge pale shape in the window, the owner in the chair with their back to us.
static func ea_cursed(g: Image) -> void:
	ea_band(g, 0, H, [0, 1, 12, 1, 0])
	SpriteKit._sk_r(g, 0, 300, W, 60, 8)  # floor
	for x: int in range(0, W, 26):
		SpriteKit._sk_r(g, x, 300, 1, 60, 0)
	for row: int in range(5):
		ea_shelf(g, 20, 70 + row * 46, 250, true, 11 + row)
		ea_shelf(g, 370, 70 + row * 46, 250, true, 41 + row)
	SpriteKit._sk_r(g, 270, 0, 100, 300, 2)  # the back wall between the cases: stained wallpaper and the sealed door
	for x: int in range(272, 370, 10):
		SpriteKit._sk_r(g, x, 0, 4, 300, 1)
	SpriteKit._sk_r(g, 288, 110, 64, 190, 0)  # the door, wallpapered over: seams and a handle still showing
	SpriteKit._sk_r(g, 290, 112, 60, 186, 2)
	SpriteKit._sk_l(g, 290, 160, 350, 170, 1)
	SpriteKit._sk_l(g, 290, 230, 350, 224, 1)
	SpriteKit._sk_r(g, 340, 204, 4, 4, 10)
	ea_haze(g, 288, 112, 352, 298, 0, 0.35)
	SpriteKit._sk_e(g, 320.0, 60.0, 44.0, 30.0, 14)  # a huge pale eye where the clock was
	SpriteKit._sk_e(g, 320.0, 60.0, 44.0, 30.0, 15)
	SpriteKit._sk_e(g, 320.0, 60.0, 20.0, 20.0, 13)
	SpriteKit._sk_e(g, 320.0, 60.0, 6.0, 18.0, 0)
	SpriteKit._sk_r(g, 280, 40, 80, 2, 14)
	ea_glow(g, 320, 60, 70, 12, 0.7)
	SpriteKit._sk_r(g, 60, 262, 520, 12, 9)  # the counter
	SpriteKit._sk_r(g, 60, 262, 520, 2, 10)
	SpriteKit._sk_r(g, 60, 274, 520, 40, 8)
	SpriteKit._sk_r(g, 60, 274, 520, 40, 8)
	ea_candle(g, 160, 262)
	ea_candle(g, 480, 262)
	ea_glow(g, 160, 252, 50, 12, 0.9)
	ea_glow(g, 480, 252, 50, 12, 0.9)
	SpriteKit._sk_r(g, 290, 238, 60, 24, 0)  # the chair and the owner, seen from behind, hands flat on the counter
	ea_figure(g, 320, 262, 100, 1, "hood")
	SpriteKit._sk_r(g, 296, 240, 12, 3, 14)
	SpriteKit._sk_r(g, 332, 240, 12, 3, 14)
	for i: int in range(40):  # eyes that were not there a moment ago, in the black between the shelves
		var ex: int = (i * 151) % 600 + 20
		var ey: int = (i * 89) % 220 + 40
		if ex > 272 and ex < 368:
			continue
		SpriteKit._sk_r(g, ex, ey, 2, 1, 13)
		SpriteKit._sk_r(g, ex + 5, ey, 2, 1, 13)


## The Collector's bargain: a bare shop, the counter lit from a case that stands open, a tall hat and coat from the
## side, one coin falling into the light, the owner's hands out of frame.
static func ea_collector(g: Image) -> void:
	ea_band(g, 0, H, [0, 1, 2, 1, 0])
	SpriteKit._sk_r(g, 0, 300, W, 60, 1)
	for x: int in range(0, W, 30):
		SpriteKit._sk_l(g, x, 300, x - 30, 360, 0)
	ea_window(g, 70, 70, 120, 150, 1)  # a window with a cold moon, the shelves behind us bare
	SpriteKit._sk_e(g, 130.0, 120.0, 22.0, 22.0, 14)
	SpriteKit._sk_e(g, 134.0, 116.0, 19.0, 19.0, 15)
	ea_haze(g, 70, 70, 190, 220, 4, 0.2)
	for row: int in range(3):
		SpriteKit._sk_r(g, 440, 80 + row * 60, 170, 4, 9)
		SpriteKit._sk_r(g, 440, 84 + row * 60, 170, 2, 0)
	SpriteKit._sk_r(g, 40, 264, 560, 14, 9)  # the counter
	SpriteKit._sk_r(g, 40, 264, 560, 2, 10)
	SpriteKit._sk_r(g, 40, 278, 560, 60, 8)
	SpriteKit._sk_r(g, 270, 238, 130, 26, 0)  # the case: lid up, lined with red, a hollow where something sat
	SpriteKit._sk_r(g, 274, 242, 122, 22, 12)
	SpriteKit._sk_r(g, 290, 252, 90, 10, 0)
	SpriteKit._sk_r(g, 270, 196, 6, 46, 0)
	SpriteKit._sk_r(g, 270, 196, 120, 6, 0)
	SpriteKit._sk_r(g, 276, 202, 112, 32, 12)
	SpriteKit._sk_r(g, 280, 206, 104, 24, 13)
	ea_glow(g, 330, 244, 130, 12, 0.8)
	ea_glow(g, 330, 244, 90, 13, 0.7)
	ea_glow(g, 330, 244, 50, 11, 0.7)
	SpriteKit._sk_r(g, 326, 252, 8, 8, 14)  # the thing in the case: a small pale shape that is looking up
	SpriteKit._sk_p(g, 328, 255, 0)
	SpriteKit._sk_p(g, 332, 255, 0)
	for i: int in range(6):  # coins on the wood, one still in the air
		SpriteKit._sk_e(g, float(420 + i * 9), 262.0, 3.0, 1.5, 11)
	SpriteKit._sk_e(g, 346.0, 160.0, 4.0, 4.0, 11)
	SpriteKit._sk_p(g, 345, 159, 15)
	ea_figure(g, 500, 264, 190, 0, "hat", 13)  # the Collector: tall, thin, a hat like a chimney, one red glint
	SpriteKit._sk_r(g, 446, 120, 110, 4, 0)
	SpriteKit._sk_l(g, 470, 200, 410, 250, 0)
	SpriteKit._sk_r(g, 404, 244, 20, 6, 14)  # a long pale hand reaching toward the case
	for f: int in range(4):
		SpriteKit._sk_r(g, 394 - f * 3, 245 + f, 12, 1, 14)
	SpriteKit._sk_e(g, 500.0, 101.0, 12.0, 16.0, 15)  # his face: bone white, hollow sockets, two red pins
	SpriteKit._sk_e(g, 504.0, 104.0, 8.0, 12.0, 14)
	SpriteKit._sk_r(g, 492, 96, 6, 5, 0)
	SpriteKit._sk_r(g, 503, 96, 6, 5, 0)
	SpriteKit._sk_p(g, 495, 98, 13)
	SpriteKit._sk_p(g, 505, 98, 13)
	SpriteKit._sk_r(g, 495, 109, 11, 1, 0)
	SpriteKit._sk_p(g, 494, 108, 0)
	SpriteKit._sk_p(g, 506, 108, 0)
	SpriteKit._sk_r(g, 496, 117, 9, 4, 15)  # collar and a red cravat
	SpriteKit._sk_r(g, 499, 121, 3, 16, 13)
	SpriteKit._sk_r(g, 499, 121, 1, 16, 12)
	for by: int in [150, 168, 186]:
		SpriteKit._sk_r(g, 506, by, 3, 3, 14)
		SpriteKit._sk_p(g, 506, by, 15)
	SpriteKit._sk_l(g, 480, 124, 466, 190, 1)
	SpriteKit._sk_l(g, 520, 124, 534, 190, 1)
	SpriteKit._sk_r(g, 500, 152, 24, 2, 4)  # rim light along the hat
	ea_haze(g, 430, 100, 580, 270, 0, 0.3)


## Closing time with the regulars: a round table, a candle on a small cake, six figures with six different heads (veil,
## cap, collar, top hat, hood, bun) and one chair left empty. Warm, which is the horror.
static func ea_regulars(g: Image) -> void:
	ea_band(g, 0, 300, [1, 8, 8, 9])
	SpriteKit._sk_r(g, 0, 300, W, 60, 8)
	for x: int in range(0, W, 28):
		SpriteKit._sk_r(g, x, 300, 1, 60, 0)
	ea_window(g, 270, 40, 100, 90, 2)
	SpriteKit._sk_e(g, 340.0, 84.0, 16.0, 16.0, 15)
	for x: int in [50, 560]:  # paper lanterns
		SpriteKit._sk_l(g, x, 0, x, 40, 0)
		SpriteKit._sk_e(g, float(x), 50.0, 10.0, 12.0, 10)
		SpriteKit._sk_e(g, float(x), 50.0, 6.0, 8.0, 11)
		ea_glow(g, x, 60, 70, 10, 1.0)
	ea_glow(g, 320, 250, 180, 10, 0.55)
	ea_glow(g, 320, 250, 110, 11, 0.55)
	var kinds: Array[String] = ["veil", "cap", "bare", "hat", "hood", "bun"]
	var cols: Array[int] = [2, 3, 1, 0, 2, 3]
	var xs: Array[int] = [130, 205, 275, 365, 435, 510]
	for i: int in range(6):
		var fh: int = 96 - (8 if kinds[i] == "cap" else 0)
		var fb: int = 252 + (i % 2) * 4
		ea_figure(g, xs[i], fb, fh, cols[i], kinds[i], -1)
		var fy: int = fb - fh + fh / 8 + 2
		SpriteKit._sk_e(g, float(xs[i]), float(fy), 8.0, 10.0, 14 if i % 2 == 0 else 15)  # a lit face, turned to the cake
		SpriteKit._sk_e(g, float(xs[i]) + 2.0, float(fy) + 2.0, 5.0, 8.0, 14)
		SpriteKit._sk_r(g, xs[i] - 4, fy - 2, 3, 2, 0)
		SpriteKit._sk_r(g, xs[i] + 2, fy - 2, 3, 2, 0)
		SpriteKit._sk_p(g, xs[i] - 3, fy - 2, 11)
		SpriteKit._sk_p(g, xs[i] + 3, fy - 2, 11)
		SpriteKit._sk_r(g, xs[i] - 2, fy + 4, 5, 1, 12)
	ea_haze(g, 100, 150, 540, 252, 0, 0.12)
	SpriteKit._sk_e(g, 320.0, 268.0, 190.0, 30.0, 0)  # the table seen as an oval
	SpriteKit._sk_e(g, 320.0, 266.0, 188.0, 28.0, 9)
	SpriteKit._sk_e(g, 320.0, 264.0, 170.0, 22.0, 10)
	SpriteKit._sk_e(g, 320.0, 264.0, 150.0, 18.0, 15)
	SpriteKit._sk_r(g, 180, 296, 280, 8, 0)
	for x: int in [70, 570]:  # chair backs
		SpriteKit._sk_r(g, x - 6, 230, 12, 60, 8)
	SpriteKit._sk_r(g, 300, 238, 40, 22, 14)  # the cake and its one candle
	SpriteKit._sk_r(g, 300, 238, 40, 3, 15)
	SpriteKit._sk_r(g, 302, 246, 36, 3, 13)
	ea_candle(g, 320, 238)
	ea_glow(g, 320, 226, 36, 11, 1.0)
	for x: int in [195, 460]:  # cups and a small stack of objects each one was once sold
		SpriteKit._sk_r(g, x, 256, 8, 8, 14)
		SpriteKit._sk_r(g, x + 8, 258, 2, 4, 14)
	SpriteKit._sk_r(g, 76, 232, 56, 56, 0)  # the empty chair (yours), turned slightly toward the table
	SpriteKit._sk_r(g, 80, 236, 48, 40, 8)
	SpriteKit._sk_r(g, 80, 276, 48, 10, 9)
	SpriteKit._sk_r(g, 86, 262, 36, 14, 13)  # a folded red scarf left on the seat
	SpriteKit._sk_r(g, 86, 262, 36, 2, 15)


## The lost run: rain slanting across a street at night, the shop shuttered and boarded with a notice nailed on, a
## single streetlamp, the owner with one suitcase, and in the dark upper window two small lights watching them go.
static func ea_evicted(g: Image) -> void:
	ea_band(g, 0, 300, [0, 1, 1, 2, 2])
	ea_cobbles(g, 292, 1, 0)
	ea_haze(g, 0, 292, W, H, 4, 0.18)
	SpriteKit._sk_r(g, 150, 60, 340, 240, 1)  # the shop front
	SpriteKit._sk_r(g, 150, 60, 340, 4, 2)
	SpriteKit._sk_r(g, 140, 50, 360, 12, 8)
	ea_window(g, 172, 90, 70, 78, 0)  # dark windows, boarded with planks
	for p: int in range(4):
		SpriteKit._sk_r(g, 164, 94 + p * 20, 86, 8, 9)
		SpriteKit._sk_r(g, 164, 94 + p * 20, 86, 1, 10)
		SpriteKit._sk_r(g, 170 + p * 18, 98 + p * 20, 1, 1, 0)
	SpriteKit._sk_r(g, 260, 100, 130, 24, 0)  # a sign with its letters gone
	SpriteKit._sk_r(g, 262, 102, 126, 20, 8)
	for i: int in range(5):
		SpriteKit._sk_r(g, 270 + i * 22, 108, 12, 8, 9 if i % 2 == 0 else 8)
	SpriteKit._sk_r(g, 268, 150, 88, 150, 0)  # the door, shut and barred
	SpriteKit._sk_r(g, 272, 154, 80, 146, 8)
	SpriteKit._sk_r(g, 262, 180, 100, 10, 9)
	SpriteKit._sk_r(g, 262, 240, 100, 10, 9)
	SpriteKit._sk_r(g, 300, 196, 24, 28, 14)  # the notice
	SpriteKit._sk_r(g, 302, 198, 20, 2, 12)
	for y: int in range(202, 222, 3):
		SpriteKit._sk_r(g, 303, y, 18, 1, 8)
	SpriteKit._sk_r(g, 308, 220, 8, 2, 13)
	ea_window(g, 400, 90, 70, 78, 0)
	SpriteKit._sk_r(g, 410, 70, 8, 3, 13)  # in the dark upper floor: two small lights
	SpriteKit._sk_r(g, 424, 70, 8, 3, 13)
	SpriteKit._sk_r(g, 408, 80, 52, 4, 0)
	SpriteKit._sk_r(g, 520, 130, 4, 170, 0)  # the streetlamp
	SpriteKit._sk_r(g, 508, 120, 28, 14, 0)
	SpriteKit._sk_r(g, 511, 122, 22, 10, 10)
	ea_glow(g, 522, 128, 96, 10, 1.3)
	ea_glow(g, 522, 128, 52, 11, 1.3)
	SpriteKit._sk_r(g, 508, 118, 28, 4, 8)
	ea_figure(g, 470, 296, 74, 0, "hat")  # the owner, hat pulled down, suitcase in hand
	SpriteKit._sk_r(g, 482, 276, 22, 16, 9)
	SpriteKit._sk_r(g, 482, 276, 22, 2, 10)
	SpriteKit._sk_r(g, 490, 272, 6, 4, 0)
	SpriteKit._sk_e(g, 470.0, 302.0, 40.0, 5.0, 0)
	for i: int in range(150):  # rain
		var rx: int = (i * 41) % W
		var ry: int = (i * 67) % 340
		SpriteKit._sk_l(g, rx, ry, rx - 2, ry + 6, 4 if i % 3 != 0 else 14)
	for i: int in range(10):  # puddle rings under the lamp
		SpriteKit._sk_r(g, 480 + (i * 13) % 80, 306 + (i * 7) % 20, 5, 1, 4)
