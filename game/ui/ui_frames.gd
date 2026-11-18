class_name UiFrames
extends RefCounted
## 9-slice frames for the pixel UI, drawn from small Images (8x8, 3 px borders) in RoomPalette colours only.
## Each kind is four palette indices: outline, edge, highlight, fill. Corners are clipped for a soft pixel corner.

const SIZE: int = 8
const BORDER: int = 3
const KINDS: Dictionary = {
	"panel": [0, 9, 8, 1],
	"note": [8, 15, 14, 14],
	"btn": [0, 11, 9, 8],
	"btn_hover": [0, 15, 10, 9],
	"btn_down": [0, 9, 8, 12],
	"btn_off": [0, 3, 2, 1],
	"gold": [0, 15, 11, 10],
	"gold_hover": [0, 15, 11, 11],
	"gold_down": [0, 10, 9, 9],
	"red": [0, 14, 13, 12],
	"glow": [11, 15, 11, 11],
}
static var _uf_cache: Dictionary = {}


static func ui_texture(kind: String) -> ImageTexture:
	if _uf_cache.has(kind):
		return _uf_cache[kind] as ImageTexture
	var idx: Array = KINDS.get(kind, KINDS["panel"]) as Array
	var pal: PackedColorArray = RoomPalette.colors()
	var img: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var ring: int = mini(mini(x, y), mini(SIZE - 1 - x, SIZE - 1 - y))
			var corner: bool = (x == 0 or x == SIZE - 1) and (y == 0 or y == SIZE - 1)
			if corner:
				continue
			img.set_pixel(x, y, pal[int(idx[mini(ring, 3)])])
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_uf_cache[kind] = tex
	return tex


## Draws a frame of the given kind filling rect (whole pixels; rects under 6 px are skipped).
static func ui_draw(ci: CanvasItem, rect: Rect2, kind: String) -> void:
	if rect.size.x < 6.0 or rect.size.y < 6.0:
		return
	var tex: ImageTexture = ui_texture(kind)
	var b: float = float(BORDER)
	var mid: float = float(SIZE - 2 * BORDER)
	var xs: Array[float] = [rect.position.x, rect.position.x + b, rect.end.x - b]
	var ws: Array[float] = [b, rect.size.x - 2.0 * b, b]
	var ys: Array[float] = [rect.position.y, rect.position.y + b, rect.end.y - b]
	var hs: Array[float] = [b, rect.size.y - 2.0 * b, b]
	var sx: Array[float] = [0.0, b, b + mid]
	var sw: Array[float] = [b, mid, b]
	for j: int in range(3):
		for i: int in range(3):
			ci.draw_texture_rect_region(tex, Rect2(xs[i], ys[j], ws[i], hs[j]), Rect2(sx[i], sx[j], sw[i], sw[j]))
