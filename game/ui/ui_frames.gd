class_name UiFrames
extends RefCounted
## Frames, brass buttons, flames and candles for the pixel UI, drawn in RoomPalette colours only. Frames are generated
## per size (cached): aged parchment with foxing, stains and torn corners ("note", "ledger"), blackened wood with grain
## and brass rivets ("panel"), and worn brass ("btn", "gold" families, each with hover and down states).
## Spec keys: m (texture: wood, paper, metal), o outline, hi top-left rim, lo bottom-right rim, fill, s1/s2 speckles.

const KINDS: Dictionary = {
	"panel": {"m": "wood", "o": 0, "hi": 9, "lo": 8, "fill": 1, "rivet": true},
	"note": {"m": "paper", "o": 8, "hi": 15, "lo": 10, "fill": 14},
	"ledger": {"m": "paper", "o": 8, "hi": 15, "lo": 10, "fill": 14, "rules": true},
	"btn": {"m": "metal", "o": 0, "hi": 10, "lo": 9, "fill": 8, "s1": 0, "s2": 9},
	"btn_hover": {"m": "metal", "o": 0, "hi": 11, "lo": 10, "fill": 9, "s1": 8, "s2": 10},
	"btn_down": {"m": "metal", "o": 0, "hi": 8, "lo": 10, "fill": 0, "s1": 1, "s2": 8},
	"btn_off": {"m": "metal", "o": 0, "hi": 3, "lo": 2, "fill": 1, "s1": 0, "s2": 2},
	"gold": {"m": "metal", "o": 0, "hi": 11, "lo": 9, "fill": 10, "s1": 9, "s2": 11},
	"gold_hover": {"m": "metal", "o": 0, "hi": 15, "lo": 10, "fill": 11, "s1": 10, "s2": 15},
	"gold_down": {"m": "metal", "o": 0, "hi": 8, "lo": 11, "fill": 9, "s1": 8, "s2": 10},
	"red": {"m": "metal", "o": 0, "hi": 13, "lo": 0, "fill": 12, "s1": 0, "s2": 13},
	"glow": {"m": "metal", "o": 11, "hi": 15, "lo": 10, "fill": 11, "s1": 10, "s2": 15},
}
const LEDGER_MARGIN: int = 12  ## x of the red margin line; ledger text starts at LEDGER_TEXT_X
const LEDGER_TEXT_X: int = 17
const LEDGER_RULE_Y: int = 12  ## first ruled line (text drawn 5 px below the top, pitch UiPixelFont.LINE_H)
const SQUISH_SECS: float = 0.09
const FLAME: Array = [
	["..o..", ".oyo.", ".oyo.", "oyyyo", "oywyo", "oywyo", ".oyo."],
	[".o...", ".oy..", ".oyo.", "oyyyo", "oywyo", "oywyo", ".oyo."],
	["...o.", "..yo.", ".oyo.", "oyyyo", "oywyo", "oywyo", ".oyo."],
]
const CACHE_MAX: int = 160
static var _uf_cache: Dictionary = {}


## The frame image of a kind at a size (whole pixels). Pure given kind and size.
static func ui_image(kind: String, w: int, h: int) -> Image:
	var spec: Dictionary = KINDS.get(kind, KINDS["panel"]) as Dictionary
	var pal: PackedColorArray = RoomPalette.colors()
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var sd: int = (kind.hash() & 0xFFFF) + w * 31 + h
	var mode: String = str(spec["m"])
	var o: int = int(spec["o"])
	var hi: int = int(spec["hi"])
	var lo: int = int(spec["lo"])
	var fill: int = int(spec["fill"])
	var blot_c: int = int(UiMotion.ui_hash(sd, 99) * 4.0)
	var bx: float = 0.0 if blot_c % 2 == 0 else float(w - 1)
	var by: float = 0.0 if blot_c < 2 else float(h - 1)
	var blot_r: float = minf(11.0, float(h) * 0.7)
	for y: int in range(h):
		for x: int in range(w):
			var dx: int = mini(x, w - 1 - x)
			var dy: int = mini(y, h - 1 - y)
			var d: int = mini(dx, dy)
			if _uf_cut(mode, dx, dy, x, y, w, h, sd):
				continue
			var n: float = UiMotion.ui_hash(x, y, sd)
			var idx: int = fill
			if d == 0:
				idx = o
			elif d == 1:
				idx = lo if (y == h - 2 or x == w - 2) else (hi if (y == 1 or x == 1) else fill)
			elif mode == "paper":
				idx = fill
				if n < 0.03:
					idx = 15
				elif n > 0.996:
					idx = 10
				if d <= 4 and UiMotion.ui_hash(x, y, sd + 7) < 0.34 - 0.07 * float(d):
					idx = 10
				var dist: float = Vector2(float(x) - bx, float(y) - by).length()
				if dist < blot_r and UiMotion.ui_hash(x, y, sd + 3) < (1.0 - dist / blot_r) * 0.5:
					idx = 10 if dist > blot_r * 0.4 else 9
				if bool(spec.get("rules", false)):
					if x == LEDGER_MARGIN and y > 1 and y < h - 2:
						idx = 13
					elif x > LEDGER_MARGIN + 3 and x < w - 4 and x % 2 == 0 and y >= LEDGER_RULE_Y and y < h - 3 \
							and (y - LEDGER_RULE_Y) % UiPixelFont.LINE_H == 0:
						idx = 4
			elif mode == "wood":
				var row_n: float = UiMotion.ui_hash(y, 0, sd + 11)
				if n < 0.10 or (row_n > 0.82 and n < 0.7):
					idx = 0
				elif row_n < 0.22 and UiMotion.ui_hash(x / 3, y, sd + 2) < 0.7:
					idx = 8
				if d == 2:
					idx = 0
				var dd: float = Vector2(float(x) - bx, float(y) - by).length()
				if dd < blot_r * 0.8 and UiMotion.ui_hash(x, y, sd + 3) < (1.0 - dd / (blot_r * 0.8)) * 0.6:
					idx = 0
			elif mode == "metal":
				if n < 0.035:
					idx = int(spec.get("s1", fill))
				elif n > 0.975:
					idx = int(spec.get("s2", fill))
			img.set_pixel(x, y, pal[idx])
	if mode == "wood" and bool(spec.get("rivet", false)) and w >= 24 and h >= 14:
		for cx: int in [3, w - 5]:
			for cy: int in [3, h - 5]:
				img.set_pixel(cx, cy, pal[11])
				img.set_pixel(cx + 1, cy, pal[10])
				img.set_pixel(cx, cy + 1, pal[10])
				img.set_pixel(cx + 1, cy + 1, pal[9])
	return img


## True when the pixel is cut away: every corner loses its tip, paper loses more (torn, per corner).
static func _uf_cut(mode: String, dx: int, dy: int, x: int, y: int, w: int, h: int, sd: int) -> bool:
	if dx == 0 and dy == 0:
		return true
	if mode != "paper" or dx + dy > 2:
		return false
	var corner: int = (0 if x < w / 2 else 1) + (0 if y < h / 2 else 2)
	var r: float = UiMotion.ui_hash(sd, corner, 5)
	return (r < 0.55 and dx + dy <= 1) or (r > 0.88 and dx + dy <= 2)


static func ui_texture(kind: String, size: Vector2i = Vector2i(24, 16)) -> ImageTexture:
	var key: String = "%s_%d_%d" % [kind, size.x, size.y]
	if _uf_cache.has(key):
		return _uf_cache[key] as ImageTexture
	if _uf_cache.size() > CACHE_MAX:
		_uf_cache.clear()
	var tex: ImageTexture = ImageTexture.create_from_image(ui_image(kind, size.x, size.y))
	_uf_cache[key] = tex
	return tex


## Draws a frame of the given kind filling rect (whole pixels; rects under 6 px are skipped).
static func ui_draw(ci: CanvasItem, rect: Rect2, kind: String) -> void:
	var r := Rect2(rect.position.floor(), rect.size.floor())
	if r.size.x < 6.0 or r.size.y < 6.0:
		return
	ci.draw_texture(ui_texture(kind, Vector2i(r.size)), r.position)


## Which frame kind a button shows. Hover flickers (alternates with the resting frame) for its first moments.
static func ui_button_kind(gold: bool, enabled: bool, hovered: bool, down: bool, hover_age: float) -> String:
	var base: String = "gold" if gold else "btn"
	if not enabled:
		return "btn_off"
	if down:
		return base + "_down"
	if hovered:
		if hover_age < 0.2 and int(hover_age / 0.05) % 2 == 1:
			return base
		return base + "_hover"
	return base


## A brass button: a resting drop shadow, a two-frame squish when pressed (one pixel shorter, then sunk with the label
## nudged down), and a flicker when the pointer arrives.
static func ui_button(ci: CanvasItem, rect: Rect2, label: String, enabled: bool, gold: bool, hovered: bool, down: bool,
		hover_age: float, down_age: float) -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var kind: String = ui_button_kind(gold, enabled, hovered, down, hover_age)
	var r := Rect2(rect.position.floor(), rect.size.floor())
	var pressed: bool = enabled and down
	if pressed and down_age < SQUISH_SECS:
		r = Rect2(r.position + Vector2(0.0, 1.0), r.size - Vector2(0.0, 1.0))
	elif not pressed and enabled:
		ci.draw_rect(Rect2(r.position.x + 1.0, r.end.y, r.size.x - 1.0, 1.0), pal[0])
	ui_draw(ci, r, kind)
	var col: int = 3 if not enabled else (0 if gold and not pressed else (11 if gold else 15))
	var tw: int = UiPixelFont.ui_width(label)
	var at := Vector2(r.position.x + floorf((r.size.x - float(tw)) * 0.5),
		r.position.y + floorf((r.size.y - 7.0) * 0.5) + (1.0 if pressed else 0.0))
	UiPixelFont.ui_draw(ci, at, label, pal[col], 1, enabled and not gold, pal[0])


## A small flame (5 wide) with its top-left at tl. size 0 full (7 rows), 1 short (5), 2 tiny (3). warm false is the
## normal amber; true shades it to guttering red. The shape changes about eight times a second.
static func ui_flame(ci: CanvasItem, tl: Vector2, t: float, size: int = 0, red: bool = false, seed_in: int = 1) -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var frame: Array = FLAME[int(UiMotion.ui_hash(int(t * 8.0), seed_in) * 3.0) % 3] as Array
	var rows: int = 7 - size * 2
	var cm: Dictionary = {"o": 12 if red else 10, "y": 13 if red else 11, "w": 10 if red else 15}
	for i: int in range(rows):
		var line: String = str(frame[7 - rows + i])
		for x: int in range(line.length()):
			var ch: String = line[x]
			if ch != ".":
				ci.draw_rect(Rect2(tl.x + float(x), tl.y + float(i + size * 2), 1.0, 1.0), pal[int(cm[ch])])


## A candle: brass dish at base_y, wax body (body_w wide, body_h tall, drips down its side), a wick and a flame.
## flame_size -1 draws a snuffed wick with smoke, -2 a bare glowing wick. Returns the y of the wax top.
static func ui_candle(ci: CanvasItem, cx: float, base_y: float, body_w: int, body_h: int, t: float, flame_size: int = 0,
		red: bool = false, seed_in: int = 1) -> float:
	var pal: PackedColorArray = RoomPalette.colors()
	var x0: float = floorf(cx - float(body_w) * 0.5)
	var top: float = base_y - float(body_h)
	var w: float = float(body_w)
	ci.draw_rect(Rect2(x0 - 3.0, base_y, w + 6.0, 1.0), pal[11])
	ci.draw_rect(Rect2(x0 - 2.0, base_y + 1.0, w + 4.0, 2.0), pal[9])
	ci.draw_rect(Rect2(x0 - 1.0, base_y + 3.0, w + 2.0, 1.0), pal[8])
	ci.draw_rect(Rect2(x0, top, w, float(body_h)), pal[14])
	ci.draw_rect(Rect2(x0, top, 1.0, float(body_h)), pal[15])
	ci.draw_rect(Rect2(x0 + w - 1.0, top, 1.0, float(body_h)), pal[3])
	ci.draw_rect(Rect2(x0 + w - 2.0, top, 1.0, float(body_h)), pal[4])
	ci.draw_rect(Rect2(x0, top, w, 1.0), pal[15])
	ci.draw_rect(Rect2(x0 + 2.0, top + 1.0, w - 4.0, 1.0), pal[15])
	for k: int in range(3):
		var len_k: int = mini(2 + int(UiMotion.ui_hash(seed_in, k) * 6.0), maxi(body_h - 3, 0))
		ci.draw_rect(Rect2(x0 + 1.0 + float(k) * floorf(w / 3.0), top + 1.0, 1.0, float(len_k)), pal[15])
	ci.draw_rect(Rect2(cx, top - 3.0, 1.0, 3.0), pal[0])
	if flame_size >= 0:
		ci.draw_rect(Rect2(cx, top - 3.0, 1.0, 1.0), pal[9])
		ui_flame(ci, Vector2(floorf(cx) - 2.0, top - 9.0), t, flame_size, red, seed_in)
	elif flame_size == -2:
		ci.draw_rect(Rect2(cx, top - 3.0, 1.0, 1.0), pal[9])
	elif flame_size == -1:
		for i: int in range(4):
			var sx: float = floorf(cx + sin(t * 2.0 + float(i) * 1.3) * float(i))
			ci.draw_rect(Rect2(sx, top - 5.0 - float(i) * 3.0, 1.0, 2.0), pal[3 if i > 1 else 14])
	return top
