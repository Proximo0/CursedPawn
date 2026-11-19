class_name UiPixelFont
extends RefCounted
## Three code-drawn bitmap fonts, every glyph a hard-coded hex table (nothing licensed), baked once into white atlases
## and drawn tinted so each pixel is exactly a palette colour:
##   BODY: 5x7 with real two-row descenders (g j p q y , ;), ASCII 32-126, proportional advance (narrow letters tuck in).
##   HEAD: about 8x11, a flared-serif gothic flavour (thick stems, hairline joins), A-Z 0-9 and a few marks; lowercase
##         is drawn as capitals. For panel titles.
##   DISPLAY: the HEAD bitmaps drawn big with a 1-pixel inner bevel (light top-left, dark bottom-right), a drop shadow and
##         ornamental first capitals, baked per glyph. For title cards and the game title.
## Text effects take a clock `t` (never the wall clock): wave, jitter, flicker, ink-bleed reveal, letters landing.

const FIRST: int = 32
const LAST: int = 126
const CELL_W: int = 6
const CELL_H: int = 10
const GLYPH_W: int = 5
const GLYPH_H: int = 7
const ROWS: int = 9  ## body rows per glyph, including the two descender rows
const LINE_H: int = 10  ## body line pitch that keeps descenders clear of the next line
const BODY: int = 0
const HEAD: int = 1
const HEAD_ROWS: int = 11
const HEAD_BITS_W: int = 12
const HEAD_LINE_H: int = 14
const HEAD_ORDER: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?':-/+()%"
const BITS: PackedStringArray = [
	"00000000000000", "04040404040004", "0A0A0A00000000", "0A0A1F0A1F0A0A", "040F140E051E04", "18190204081303",
	"0C12140815120D", "0C040800000000", "02040808080402", "08040202020408", "0004150E150400", "0004041F040400",
	"000000000C0408", "0000001F000000", "00000000000C0C", "00010204081000", "0E11131519110E", "040C040404040E",
	"0E11010204081F", "1F02040201110E", "02060A121F0202", "1F101E0101110E", "0608101E11110E", "1F010204080808",
	"0E11110E11110E", "0E11110F01020C", "000C0C000C0C00", "000C0C000C0408", "02040810080402", "00001F001F0000",
	"08040201020408", "0E110102040004", "0E11010D15150E", "0E11111F111111", "1E11111E11111E", "0E11101010110E",
	"1C12111111121C", "1F10101E10101F", "1F10101E101010", "0E11101711110F", "1111111F111111", "0E04040404040E",
	"0702020202120C", "11121418141211", "1010101010101F", "111B1515111111", "11111915131111", "0E11111111110E",
	"1E11111E101010", "0E11111115120D", "1E11111E141211", "0F10100E01011E", "1F040404040404", "1111111111110E",
	"11111111110A04", "1111111515150A", "11110A040A1111", "1111110A040404", "1F01020408101F", "0E08080808080E",
	"00100804020100", "0E02020202020E", "040A1100000000", "0000000000001F", "08040200000000", "00000E010F110F",
	"1010161911111E", "00000E1010110E", "01010D1311110F", "00000E111F100E", "0609081C080808", "000F11110F010E",
	"10101619111111", "04000C0404040E", "0200060202120C", "10101214181412", "0C04040404040E", "00001A15151111",
	"00001619111111", "00000E1111110E", "00001E111E1010", "00000D130F0101", "00001619101010", "00000E100E011E",
	"08081C08080906", "0000111111130D", "00001111110A04", "0000111115150A", "0000110A040A11", "000011110F010E",
	"00001F0204081F", "02040408040402", "04040404040404", "08040402040408", "00000815020000",
]
## Nine-row bodies (rows 0-8) for the glyphs that descend below the baseline.
const DESC: Dictionary = {
	"g": "00000F11110F01110E", "j": "02000602020202120C", "p": "00001E11111E101010", "q": "00000F11110F010101",
	"y": "00001111110F01110E", ",": "00000000000C0C0408", ";": "00000C0C000C0C0408",
}
const HEAD_BITS: PackedStringArray = [
	"0001801802C02C02C07E0460830E70000", "000FC06206206407C0620620620FC0000",
	"0003E06206206006006006206203E0000", "000FC0660660660660660660660FC0000",
	"000FE06206006007C0600600620FE0000", "000FE06206006007C0600600600F00000",
	"0003E06206206006F06306306303F0000", "000F786306306307F0630630630F78000",
	"000F00600600600600600600600F00000", "0001E00C00C00C00C00C00C08C0700000",
	"000F706406406807806C06C0660F70000", "000F00600600600600600620620FE0000",
	"000F1E78C78C6CC6DC67C60C60CF1E000", "000F787B07B07B07B06F06F06F0F78000",
	"0003C06606606606606606606603C0000", "000FC06206206407C0600600600F00000",
	"0003C06606606606606606E06603F0018", "000FC06206206407C06C0660660F70000",
	"0003E06206003C00E00600604603E0000", "000FF09909901801801801801803C0000",
	"000F786306306306306306303E01C0000", "000E1C6083103103101A01A00C00C0000",
	"000E07C02C646646B46B469831830C000", "000E1C3103101A01A00C00E00E0F3C000",
	"000E1C3103101A00C00C00C00C01E0000", "0007E04300600C00C01803006207E0000",
	"0003806C06C06C06C06C06C06C0380000", "0001803801801801801801801803C0000",
	"0003804400400600C01803006007E0000", "0007C00400400403C00400404407C0000",
	"0000C01C02C02C04C0FE00C00C01E0000", "0007C0600600600780040040440780000",
	"0003C0600600600780640640640380000", "0007C00600600C00C0180180300300000",
	"000380440440440380440440440380000", "0003806C06C06C03C00C00C08C0700000",
	"000000000000000000000000300300000", "000000000000000000000000300300200",
	"000300300300300300300000300300000", "000380440040040180100000180180000",
	"000300300300000000000000000000000", "000000000300300000000300300000000",
	"000000000000000780000000000000000", "0000600600C00C0180180300300600000",
	"0000000001001007C0100100000000000", "000100100200200200200200200100000",
	"000200200100100100100100100200000", "0006406400800801001002002C04C0000",
]
static var _uf_tex: Array = [null, null]
static var _uf_info: Array = [{}, {}]
static var _uf_disp: Dictionary = {}


# ---------------------------------------------------------------- glyph data

## Everything about one glyph of a font: {idx, rows, lo, hi, adv} (adv in font pixels, gap included).
static func _uf_glyph(font: int, code: int) -> Dictionary:
	var cache: Dictionary = _uf_info[font]
	if cache.has(code):
		return cache[code] as Dictionary
	var rows := PackedInt32Array()
	var idx: int = -1
	var bits_w: int = GLYPH_W if font == BODY else HEAD_BITS_W
	if font == BODY:
		var c: int = code if code >= FIRST and code <= LAST else 63
		idx = c - FIRST
		var hex: String = str(DESC[char(c)]) if DESC.has(char(c)) else BITS[idx] + "0000"
		for r: int in range(ROWS):
			rows.append(("0x" + hex.substr(r * 2, 2)).hex_to_int())
		if c == FIRST:
			idx = -1
	else:
		var up: String = char(code).to_upper()
		var at: int = HEAD_ORDER.find(up)
		if up == " ":
			at = -2
		elif at < 0:
			at = HEAD_ORDER.find("?")
		idx = at
		for r: int in range(HEAD_ROWS):
			rows.append(0 if at < 0 else ("0x" + HEAD_BITS[at].substr(r * 3, 3)).hex_to_int())
	var lo: int = bits_w
	var hi: int = -1
	for row: int in rows:
		for b: int in range(bits_w):
			if row & (1 << (bits_w - 1 - b)) != 0:
				lo = mini(lo, b)
				hi = maxi(hi, b)
	var adv: int = hi - lo + 2
	if hi < lo:
		adv = 3 if font == BODY else 4
	var g: Dictionary = {"idx": idx, "rows": rows, "lo": lo, "hi": hi, "adv": adv}
	cache[code] = g
	return g


static func _uf_cells(font: int) -> int:
	return (LAST - FIRST + 1) if font == BODY else HEAD_ORDER.length()


static func ui_atlas_of(font: int) -> ImageTexture:
	if _uf_tex[font] != null:
		return _uf_tex[font] as ImageTexture
	var bits_w: int = GLYPH_W if font == BODY else HEAD_BITS_W
	var cell: int = bits_w + 1
	var n_rows: int = ROWS if font == BODY else HEAD_ROWS
	var count: int = _uf_cells(font)
	var img: Image = Image.create_empty(count * cell, n_rows, false, Image.FORMAT_RGBA8)
	for i: int in range(count):
		var code: int = FIRST + i if font == BODY else HEAD_ORDER.unicode_at(i)
		var rows: PackedInt32Array = (_uf_glyph(font, code) as Dictionary)["rows"] as PackedInt32Array
		for y: int in range(n_rows):
			for x: int in range(bits_w):
				if rows[y] & (1 << (bits_w - 1 - x)) != 0:
					img.set_pixel(i * cell + x, y, Color.WHITE)
	_uf_tex[font] = ImageTexture.create_from_image(img)
	return _uf_tex[font] as ImageTexture


static func ui_atlas() -> ImageTexture:
	return ui_atlas_of(BODY)


## The nine row bit patterns (five bits, bit 4 leftmost) of a body character ('?' outside ASCII 32-126).
static func ui_glyph_rows(ch: String) -> PackedInt32Array:
	return (_uf_glyph(BODY, ch.unicode_at(0) if ch != "" else FIRST) as Dictionary)["rows"] as PackedInt32Array


## How many lit pixels a body glyph has (0 for a space).
static func ui_glyph_pixels(ch: String) -> int:
	var n: int = 0
	for row: int in ui_glyph_rows(ch):
		for bit: int in range(GLYPH_W):
			if row & (1 << (GLYPH_W - 1 - bit)) != 0:
				n += 1
	return n


## The eleven row bit patterns (12 bits, bit 11 leftmost) of a heading character; {} rows of zeros for a space.
static func ui_head_rows(ch: String) -> PackedInt32Array:
	return (_uf_glyph(HEAD, ch.unicode_at(0) if ch != "" else 32) as Dictionary)["rows"] as PackedInt32Array


static func ui_head_supports(ch: String) -> bool:
	return HEAD_ORDER.contains(ch.to_upper())


## Width in pixels of text in a font (advance of every glyph, minus the trailing gap).
static func ui_text_width(font: int, text: String, scale: int = 1) -> int:
	var w: int = 0
	for i: int in range(text.length()):
		w += int((_uf_glyph(font, text.unicode_at(i)) as Dictionary)["adv"]) * scale
	return maxi(w - scale, 0)


static func ui_width(text: String, scale: int = 1) -> int:
	return ui_text_width(BODY, text, scale)


static func ui_head_width(text: String, scale: int = 1) -> int:
	return ui_text_width(HEAD, text, scale)


## X offset (pixels) where each character starts.
static func _uf_xs(font: int, text: String, scale: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var x: int = 0
	for i: int in range(text.length()):
		out.append(float(x))
		x += int((_uf_glyph(font, text.unicode_at(i)) as Dictionary)["adv"]) * scale
	return out


static func _uf_put(ci: CanvasItem, font: int, pos: Vector2, code: int, col: Color, scale: int) -> void:
	var g: Dictionary = _uf_glyph(font, code)
	var lo: int = int(g["lo"])
	var hi: int = int(g["hi"])
	if int(g["idx"]) < 0 or hi < lo:
		return
	var bits_w: int = GLYPH_W if font == BODY else HEAD_BITS_W
	var n_rows: int = ROWS if font == BODY else HEAD_ROWS
	ci.draw_texture_rect_region(ui_atlas_of(font), Rect2(pos.x, pos.y, float((hi - lo + 1) * scale), float(n_rows * scale)),
		Rect2(float(int(g["idx"]) * (bits_w + 1) + lo), 0.0, float(hi - lo + 1), float(n_rows)), col)


static func _uf_run(ci: CanvasItem, font: int, pos: Vector2, text: String, col: Color, scale: int) -> void:
	var xs: PackedFloat32Array = _uf_xs(font, text, scale)
	for i: int in range(text.length()):
		_uf_put(ci, font, pos + Vector2(xs[i], 0.0), text.unicode_at(i), col, scale)


# ---------------------------------------------------------------- plain drawing

## Draws one body line at pos (top-left), tinted col, with an optional one-pixel drop shadow in shadow_col.
static func ui_draw(ci: CanvasItem, pos: Vector2, text: String, col: Color, scale: int = 1, shadow: bool = true,
		shadow_col: Color = Color.BLACK) -> void:
	var at: Vector2 = pos.floor()  # whole pixels only, or nearest filtering garbles glyphs
	if shadow:
		_uf_run(ci, BODY, at + Vector2(scale, scale), text, shadow_col, scale)
	_uf_run(ci, BODY, at, text, col, scale)


## A heading line in the gothic HEAD face (capitals), with an optional drop shadow.
static func ui_head_draw(ci: CanvasItem, pos: Vector2, text: String, col: Color, scale: int = 1, shadow: bool = true,
		shadow_col: Color = Color.BLACK) -> void:
	var at: Vector2 = pos.floor()
	if shadow:
		_uf_run(ci, HEAD, at + Vector2(scale, scale), text, shadow_col, scale)
	_uf_run(ci, HEAD, at, text, col, scale)


## Word-wraps body text to max_w pixels (long words are split).
static func ui_wrap(text: String, max_w: int, scale: int = 1) -> PackedStringArray:
	var out := PackedStringArray()
	for para: String in text.split("\n"):
		var line: String = ""
		for word: String in para.split(" ", false):
			var w: String = word
			while ui_width(w, scale) > max_w and w.length() > 1:
				if line != "":
					out.append(line)
					line = ""
				var cut: int = 1
				while cut < w.length() and ui_width(w.substr(0, cut + 1), scale) <= max_w:
					cut += 1
				out.append(w.substr(0, cut))
				w = w.substr(cut)
			if line == "":
				line = w
			elif ui_width(line + " " + w, scale) <= max_w:
				line += " " + w
			else:
				out.append(line)
				line = w
		out.append(line)
	return out


# ---------------------------------------------------------------- text effects (clock t in seconds)

## Per-letter wave and jitter. wave = amplitude in font pixels, jitter 0..1 = how often a letter slips a pixel. A
## shadow_col with alpha 0 means no drop shadow.
static func ui_draw_fx(ci: CanvasItem, pos: Vector2, text: String, col: Color, font: int, scale: int, t: float,
		wave: float = 0.0, jitter: float = 0.0, shadow_col: Color = Color(0.0, 0.0, 0.0, 0.0), seed_in: int = 3) -> void:
	var at: Vector2 = pos.floor()
	var xs: PackedFloat32Array = _uf_xs(font, text, scale)
	var tick: int = int(t * 11.0)
	for pass_i: int in range(2):
		if pass_i == 0 and shadow_col.a <= 0.0:
			continue
		for i: int in range(text.length()):
			var off := Vector2(xs[i], floorf(sin(t * 4.0 + float(i) * 0.7) * wave * float(scale) + 0.5))
			if UiMotion.ui_hash(i, tick, seed_in) < 0.06 * jitter:
				off += Vector2(float(int(UiMotion.ui_hash(i, tick, seed_in + 1) * 3.0) - 1),
					float(int(UiMotion.ui_hash(i, tick, seed_in + 2) * 3.0) - 1)) * float(maxi(scale / 2, 1))
			if pass_i == 0:
				_uf_put(ci, font, at + off + Vector2(float(scale), float(scale)), text.unicode_at(i), shadow_col, scale)
			else:
				_uf_put(ci, font, at + off, text.unicode_at(i), col, scale)


## Draws the first `shown` characters like wet ink: the last two in wet_col, and while writing a quill blot at the pen.
static func ui_draw_ink(ci: CanvasItem, pos: Vector2, text: String, col: Color, wet_col: Color, shown: int,
		writing: bool, blot_col: Color, t: float = 0.0) -> void:
	var at: Vector2 = pos.floor()
	var n: int = clampi(shown, 0, text.length())
	var xs: PackedFloat32Array = _uf_xs(BODY, text, 1)
	for i: int in range(n):
		_uf_put(ci, BODY, at + Vector2(xs[i], 0.0), text.unicode_at(i), wet_col if i >= n - 2 else col, 1)
	if writing:
		var bx: float = at.x + (xs[n] if n < xs.size() else float(ui_width(text) + 1))
		var by: float = at.y + 5.0 + (1.0 if fmod(t, 0.4) < 0.2 else 0.0)
		ci.draw_rect(Rect2(bx, by, 2.0, 2.0), blot_col)
		ci.draw_rect(Rect2(bx + 1.0, by - 4.0, 1.0, 4.0), wet_col)  # the quill nib


## Ink-bleed reveal: each font pixel appears when progress (0..1) passes its own noise threshold mixed with a
## left-to-right sweep; a freshly wet pixel is drawn one font pixel larger in bleed_col before it dries to col.
static func ui_draw_reveal(ci: CanvasItem, pos: Vector2, text: String, col: Color, bleed_col: Color, font: int,
		scale: int, progress: float, seed_in: int = 1) -> void:
	var at: Vector2 = pos.floor()
	var xs: PackedFloat32Array = _uf_xs(font, text, scale)
	var total: float = float(maxi(text.length(), 1))
	var bits_w: int = GLYPH_W if font == BODY else HEAD_BITS_W
	var half: float = floorf(float(scale) * 0.5)
	for i: int in range(text.length()):
		var g: Dictionary = _uf_glyph(font, text.unicode_at(i))
		var rows: PackedInt32Array = g["rows"] as PackedInt32Array
		var lo: int = int(g["lo"])
		for r: int in range(rows.size()):
			for b: int in range(lo, bits_w):
				if rows[r] & (1 << (bits_w - 1 - b)) == 0:
					continue
				var thr: float = UiMotion.ui_hash(i * 16 + b, r, seed_in) * 0.45 + (float(i) / total) * 0.45
				var k: float = (progress * 1.1 - thr) / 0.12
				if k <= 0.0:
					continue
				var px := Vector2(at.x + xs[i] + float((b - lo) * scale), at.y + float(r * scale))
				if k < 1.0:
					ci.draw_rect(Rect2(px - Vector2(half, half), Vector2(float(scale) + 2.0 * half, float(scale) + 2.0 * half)),
						bleed_col)
				else:
					ci.draw_rect(Rect2(px, Vector2(float(scale), float(scale))), col)


## Letters that drop in one by one and land with a puff of dust and a one-pixel squash. age in seconds.
static func ui_draw_land(ci: CanvasItem, pos: Vector2, text: String, col: Color, shadow_col: Color, dust_col: Color,
		font: int, scale: int, age: float, delay: float = 0.07, fall: float = 0.22) -> void:
	var at: Vector2 = pos.floor()
	var xs: PackedFloat32Array = _uf_xs(font, text, scale)
	var n_rows: int = ROWS if font == BODY else HEAD_ROWS
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		var u: float = (age - float(i) * delay) / fall
		if u <= 0.0:
			continue
		var gx: float = at.x + xs[i]
		var dy: float = 0.0
		if u < 1.0:
			dy = floorf(-(1.0 - UiMotion.ui_in(u)) * 14.0 * float(scale))
		elif u < 1.0 + 0.12 / fall:
			dy = 1.0
		_uf_put(ci, font, Vector2(gx, at.y + dy) + Vector2(float(scale), float(scale)), code, shadow_col, scale)
		_uf_put(ci, font, Vector2(gx, at.y + dy), code, col, scale)
		var pa: float = (age - float(i) * delay - fall) / 0.4
		if pa > 0.0 and pa < 1.0 and code != 32:
			var base: float = at.y + float(n_rows * scale)
			var spread: float = UiMotion.ui_out(pa) * 3.5 * float(scale)
			var sz: float = 2.0 if pa < 0.5 else 1.0
			var mid: float = gx + float(int((_uf_glyph(font, code) as Dictionary)["adv"]) * scale) * 0.5
			for sgn: float in [-1.0, 1.0]:
				ci.draw_rect(Rect2(floorf(mid + sgn * (spread + 2.0)), floorf(base - pa * 4.0 - 1.0), sz, sz), dust_col)


# ---------------------------------------------------------------- DISPLAY face (big, beveled, shadowed)

## cols = [main, highlight, lowlight, shadow] as palette indices. The glyph (HEAD bitmap) is drawn scale x scale per
## pixel with a one-art-pixel bevel on lit edges, plus a drop shadow of max(scale/2, 1) pixels. Cached per glyph.
static func ui_display_tex(code: int, scale: int, cols: PackedInt32Array) -> ImageTexture:
	var key: String = "%d_%d_%d_%d_%d_%d" % [code, scale, cols[0], cols[1], cols[2], cols[3]]
	if _uf_disp.has(key):
		return _uf_disp[key] as ImageTexture
	var g: Dictionary = _uf_glyph(HEAD, code)
	var rows: PackedInt32Array = g["rows"] as PackedInt32Array
	var lo: int = int(g["lo"])
	var hi: int = int(g["hi"])
	var gw: int = maxi(hi - lo + 1, 1)
	var sh: int = maxi(scale / 2, 1)
	var img: Image = Image.create_empty(gw * scale + sh, HEAD_ROWS * scale + sh, false, Image.FORMAT_RGBA8)
	var pal: PackedColorArray = RoomPalette.colors()
	for pass_i: int in range(2):
		for gy: int in range(HEAD_ROWS):
			for gx: int in range(gw):
				if not _uf_lit(rows, lo + gx, gy):
					continue
				if pass_i == 0:
					img.fill_rect(Rect2i(gx * scale + sh, gy * scale + sh, scale, scale), pal[cols[3]])
					continue
				var up: bool = _uf_lit(rows, lo + gx, gy - 1)
				var left: bool = _uf_lit(rows, lo + gx - 1, gy)
				var down: bool = _uf_lit(rows, lo + gx, gy + 1)
				var right: bool = _uf_lit(rows, lo + gx + 1, gy)
				for py: int in range(scale):
					for px: int in range(scale):
						var c: int = cols[0]
						if not up and py == 0:
							c = cols[1]
						elif not left and px == 0:
							c = cols[1]
						elif not down and py == scale - 1:
							c = cols[2]
						elif not right and px == scale - 1:
							c = cols[2]
						img.set_pixel(gx * scale + px, gy * scale + py, pal[c])
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_uf_disp[key] = tex
	return tex


static func _uf_lit(rows: PackedInt32Array, x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or x < 0 or x >= HEAD_BITS_W:
		return false
	return rows[y] & (1 << (HEAD_BITS_W - 1 - x)) != 0


static func ui_display_width(text: String, scale: int, ornate: bool = false) -> int:
	return ui_text_width(HEAD, text, scale) + (HEAD_ROWS if ornate and text.length() > 0 else 0) + maxi(scale / 2, 1)


## A title in the DISPLAY face. wave/jitter as ui_draw_fx. ornate makes the first letter one step bigger with a
## flourish under it (the ornamental capital of a title card).
static func ui_display_draw(ci: CanvasItem, pos: Vector2, text: String, scale: int, cols: PackedInt32Array, t: float = 0.0,
		wave: float = 0.0, jitter: float = 0.0, ornate: bool = false, seed_in: int = 3) -> void:
	var at: Vector2 = pos.floor()
	var pal: PackedColorArray = RoomPalette.colors()
	var x: float = 0.0
	var tick: int = int(t * 11.0)
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		var g: Dictionary = _uf_glyph(HEAD, code)
		var s: int = scale + 1 if (ornate and i == 0) else scale
		var off := Vector2(x, floorf(sin(t * 3.2 + float(i) * 0.8) * wave * float(scale) + 0.5))
		if UiMotion.ui_hash(i, tick, seed_in) < 0.05 * jitter:
			off += Vector2(float(int(UiMotion.ui_hash(i, tick, seed_in + 1) * 3.0) - 1),
				float(int(UiMotion.ui_hash(i, tick, seed_in + 2) * 3.0) - 1))
		if ornate and i == 0:
			off.y -= float(HEAD_ROWS)  # the capital rises above the line, sharing its baseline
		if int(g["idx"]) >= 0 and int(g["hi"]) >= int(g["lo"]):
			var tex: ImageTexture = ui_display_tex(code, s, cols)
			ci.draw_texture(tex, at + off)
			if ornate and i == 0:
				var w: float = float((int(g["hi"]) - int(g["lo"]) + 1) * s)
				var fy: float = at.y + off.y + float(HEAD_ROWS * s) + float(maxi(s / 2, 1)) + 2.0
				ci.draw_rect(Rect2(at.x + off.x - 3.0, fy, w + 8.0, 1.0), pal[cols[1]])
				ci.draw_rect(Rect2(at.x + off.x - 5.0, fy - 1.0, 2.0, 3.0), pal[cols[0]])
				ci.draw_rect(Rect2(at.x + off.x + w + 5.0, fy - 1.0, 2.0, 3.0), pal[cols[0]])
				ci.draw_rect(Rect2(at.x + off.x + w * 0.5 - 1.0, fy + 1.0, 3.0, 1.0), pal[cols[3]])
		x += float(int(g["adv"]) * s)
