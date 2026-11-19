class_name TsCanvas
extends Control
## The 640x360 drawing surface of a TsScreen (title, pause): lives in a SubViewport scaled like the room. It owns
## the clickable widget list and the draw helpers; the screen decides what to draw. Palette indices as in UiHud.

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
static var _tc_dim: Dictionary = {}
static var _tc_dim_img: Dictionary = {}
static var _tc_light: Dictionary = {}

var screen: TsScreen
var widgets: Array[Dictionary] = []  ## {id, rect, enabled}
var t: float = 0.0
var _pal: PackedColorArray = RoomPalette.colors()
var _foc_prev: String = ""
var _foc_age: float = 0.0
var _down_prev: String = ""
var _down_age: float = 0.0


func _init() -> void:
	name = "TsCanvas"
	size = ShopGame.VIEW
	custom_minimum_size = ShopGame.VIEW
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	t += delta
	if screen != null:
		_foc_age = 0.0 if screen.focus_id != _foc_prev else _foc_age + delta
		_foc_prev = screen.focus_id
		_down_age = 0.0 if screen.down_id != _down_prev else _down_age + delta
		_down_prev = screen.down_id
	queue_redraw()


func _draw() -> void:
	widgets.clear()
	if screen != null:
		screen.ts_draw(self)


func widget_at(p: Vector2) -> String:
	for i: int in range(widgets.size() - 1, -1, -1):
		if (widgets[i]["rect"] as Rect2).has_point(p):
			return str(widgets[i]["id"]) if bool(widgets[i]["enabled"]) else ""
	return ""


func c(i: int) -> Color:
	return _pal[i]


func text(pos: Vector2, s: String, col: int, scale: int = 1, shadow: bool = true) -> void:
	UiPixelFont.ui_draw(self, pos, s, c(col), scale, shadow, c(0))


func text_c(cx: float, y: float, s: String, col: int, scale: int = 1, shadow: bool = true) -> void:
	text(Vector2(cx - float(UiPixelFont.ui_width(s, scale)) * 0.5, y), s, col, scale, shadow)


## A gothic heading, centred on cx.
func head_c(cx: float, y: float, s: String, col: int, scale: int = 1) -> void:
	UiPixelFont.ui_head_draw(self, Vector2(cx - float(UiPixelFont.ui_head_width(s, scale)) * 0.5, y), s, c(col), scale,
		true, c(0))


func frame(rect: Rect2, kind: String) -> void:
	UiFrames.ui_draw(self, rect, kind)


func fill(rect: Rect2, col: int) -> void:
	draw_rect(rect, c(col))


func add(id: String, rect: Rect2, enabled: bool = true) -> void:
	widgets.append({"id": id, "rect": rect, "enabled": enabled})


## A brass button. Highlight follows the screen's focus (keyboard and mouse hover share it).
func button(id: String, rect: Rect2, label: String, enabled: bool = true, gold: bool = false) -> void:
	add(id, rect, enabled)
	var big: bool = screen.settings.text_scale == 2 and rect.size.y >= 18.0 and UiPixelFont.ui_width(label, 2) <= int(rect.size.x) - 6
	UiFrames.ui_button(self, rect, "" if big else label, enabled, gold, screen.is_focused(id), screen.down_id == id, _foc_age, _down_age)
	if big:  # the 2x text size: the label drawn here, centred, in the button's own colours
		var pressed: bool = enabled and screen.down_id == id
		var col: int = 3 if not enabled else (0 if gold and not pressed else (11 if gold else 15))
		var lw: int = UiPixelFont.ui_width(label, 2)
		UiPixelFont.ui_draw(self, Vector2(rect.position.x + floorf((rect.size.x - float(lw)) * 0.5), rect.position.y + floorf((rect.size.y - 14.0) * 0.5) + (1.0 if pressed else 0.0)),
			label, c(col), 2, enabled and not gold, c(0))
	if TsPad.active and enabled and screen.is_focused(id):
		ring(rect)


## The controller focus ring: a pulsing bright outline just outside `rect`.
func ring(rect: Rect2) -> void:
	var col: int = 15 if fmod(t, 0.8) < 0.5 else 11
	draw_rect(rect.grow(2.0), c(col), false, 1.0)
	draw_rect(rect.grow(3.0), c(0), false, 1.0)


## The menu cursor: a flickering flame beside the focused entry.
func cursor_flame(at: Vector2) -> void:
	UiFrames.ui_flame(self, at, t, 0, false, 5)


## A flat ordered-dither wash of palette black over rect: level 0..16 of 16 pixels covered. Palette colours only.
func dim(rect: Rect2, level: int) -> void:
	draw_texture_rect(dim_texture(level), rect, true)


## Darkness with a pool of light: black dither that thins towards `center` (level 0 inside r0, max_level beyond r1).
func light_pool(center: Vector2i, r0: float, r1: float, max_level: int) -> void:
	draw_texture(light_texture(center, r0, r1, max_level), Vector2.ZERO)


static func dim_image(level: int) -> Image:
	var lv: int = clampi(level, 0, 16)
	if _tc_dim_img.has(lv):
		return _tc_dim_img[lv] as Image
	var img: Image = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	var black: Color = RoomPalette.colors()[0]
	for y: int in range(4):
		for x: int in range(4):
			if BAYER[y * 4 + x] < lv:
				img.set_pixel(x, y, black)
	_tc_dim_img[lv] = img
	return img


static func dim_texture(level: int) -> ImageTexture:
	var lv: int = clampi(level, 0, 16)
	if _tc_dim.has(lv):
		return _tc_dim[lv] as ImageTexture
	var tex: ImageTexture = ImageTexture.create_from_image(dim_image(lv))
	_tc_dim[lv] = tex
	return tex


## Full-screen dither mask, built in 4x4 blocks and cached per argument set.
static func light_texture(center: Vector2i, r0: float, r1: float, max_level: int) -> ImageTexture:
	var key: String = "%d_%d_%d_%d_%d" % [center.x, center.y, int(r0), int(r1), max_level]
	if _tc_light.has(key):
		return _tc_light[key] as ImageTexture
	var w: int = int(ShopGame.VIEW.x)
	var h: int = int(ShopGame.VIEW.y)
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for by: int in range(h / 4):
		for bx: int in range(w / 4):
			var d: float = Vector2(float(bx * 4 + 2), float(by * 4 + 2)).distance_to(Vector2(center))
			var lv: int = int(round(smoothstep(r0, r1, d) * float(max_level)))
			if lv > 0:
				img.blit_rect(dim_image(lv), Rect2i(0, 0, 4, 4), Vector2i(bx * 4, by * 4))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tc_light[key] = tex
	return tex
