class_name UiPixelFont
extends RefCounted
## Procedural 5x7 bitmap font for the pixel UI, ASCII 32-126. The bit table below is the only source: seven rows per
## glyph, five bits per row (bit 4 = leftmost pixel), written as hex pairs. Glyphs are baked once into a white atlas
## (6x8 cells in one row) and drawn tinted, so every pixel is exactly a palette colour. Advance is 6 px per scale.

const FIRST: int = 32
const LAST: int = 126
const CELL_W: int = 6
const CELL_H: int = 8
const GLYPH_W: int = 5
const GLYPH_H: int = 7
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
static var _uf_tex: ImageTexture = null


## The seven row bit patterns of a character ('?' for anything outside ASCII 32-126).
static func ui_glyph_rows(ch: String) -> PackedInt32Array:
	var code: int = ch.unicode_at(0) if ch != "" else FIRST
	if code < FIRST or code > LAST:
		code = 63
	var hex: String = BITS[code - FIRST]
	var out := PackedInt32Array()
	for r: int in range(GLYPH_H):
		out.append(("0x" + hex.substr(r * 2, 2)).hex_to_int())
	return out


## How many lit pixels a glyph has (0 for a space).
static func ui_glyph_pixels(ch: String) -> int:
	var n: int = 0
	for row: int in ui_glyph_rows(ch):
		for bit: int in range(GLYPH_W):
			if row & (1 << (GLYPH_W - 1 - bit)) != 0:
				n += 1
	return n


static func ui_atlas() -> ImageTexture:
	if _uf_tex != null:
		return _uf_tex
	var count: int = LAST - FIRST + 1
	var img: Image = Image.create_empty(count * CELL_W, CELL_H, false, Image.FORMAT_RGBA8)
	for i: int in range(count):
		var rows: PackedInt32Array = ui_glyph_rows(char(FIRST + i))
		for y: int in range(GLYPH_H):
			for x: int in range(GLYPH_W):
				if rows[y] & (1 << (GLYPH_W - 1 - x)) != 0:
					img.set_pixel(i * CELL_W + x, y, Color.WHITE)
	_uf_tex = ImageTexture.create_from_image(img)
	return _uf_tex


static func ui_width(text: String, scale: int = 1) -> int:
	return maxi(text.length() * CELL_W * scale - scale, 0)


## Draws one line at pos (top-left), tinted col, with an optional one-pixel drop shadow in shadow_col.
static func ui_draw(ci: CanvasItem, pos: Vector2, text: String, col: Color, scale: int = 1, shadow: bool = true,
		shadow_col: Color = Color.BLACK) -> void:
	var tex: ImageTexture = ui_atlas()
	var at: Vector2 = pos.floor()  # whole pixels only, or nearest filtering garbles glyphs
	if shadow:
		_uf_draw_run(ci, tex, at + Vector2(scale, scale), text, shadow_col, scale)
	_uf_draw_run(ci, tex, at, text, col, scale)


static func _uf_draw_run(ci: CanvasItem, tex: ImageTexture, pos: Vector2, text: String, col: Color, scale: int) -> void:
	for i: int in range(text.length()):
		var code: int = text.unicode_at(i)
		if code <= FIRST or code > LAST:
			continue  # space and unknown characters leave a gap
		ci.draw_texture_rect_region(tex, Rect2(pos.x + float(i * CELL_W * scale), pos.y, float(GLYPH_W * scale),
			float(GLYPH_H * scale)), Rect2(float((code - FIRST) * CELL_W), 0.0, float(GLYPH_W), float(GLYPH_H)), col)


## Word-wraps text to max_w pixels (long words are split).
static func ui_wrap(text: String, max_w: int, scale: int = 1) -> PackedStringArray:
	var per: int = maxi((max_w + scale) / (CELL_W * scale), 1)
	var out := PackedStringArray()
	for para: String in text.split("\n"):
		var line: String = ""
		for word: String in para.split(" ", false):
			var w: String = word
			while w.length() > per:
				if line != "":
					out.append(line)
					line = ""
				out.append(w.substr(0, per))
				w = w.substr(per)
			if line == "":
				line = w
			elif line.length() + 1 + w.length() <= per:
				line += " " + w
			else:
				out.append(line)
				line = w
		out.append(line)
	return out
