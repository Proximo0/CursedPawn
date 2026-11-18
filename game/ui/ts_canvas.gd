class_name TsCanvas
extends Control
## The 480x270 drawing surface of a TsScreen (title, pause): lives in a SubViewport scaled like the room. It owns
## the clickable widget list and the draw helpers; the screen decides what to draw. Palette indices as in UiHud.

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
static var _tc_dim: Dictionary = {}

var screen: TsScreen
var widgets: Array[Dictionary] = []  ## {id, rect, enabled}
var t: float = 0.0
var _pal: PackedColorArray = RoomPalette.colors()


func _init() -> void:
	name = "TsCanvas"
	size = ShopGame.VIEW
	custom_minimum_size = ShopGame.VIEW
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	t += delta
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


func frame(rect: Rect2, kind: String) -> void:
	UiFrames.ui_draw(self, rect, kind)


func fill(rect: Rect2, col: int) -> void:
	draw_rect(rect, c(col))


func add(id: String, rect: Rect2, enabled: bool = true) -> void:
	widgets.append({"id": id, "rect": rect, "enabled": enabled})


## A framed text button. Highlight follows the screen's focus (keyboard and mouse hover share it).
func button(id: String, rect: Rect2, label: String, enabled: bool = true, gold: bool = false) -> void:
	add(id, rect, enabled)
	var kind: String = "gold" if gold else "btn"
	var col: int = 0 if gold else 15
	if not enabled:
		kind = "btn_off"
		col = 3
	elif screen.down_id == id:
		kind += "_down"
	elif screen.is_focused(id):
		kind += "_hover"
	frame(rect, kind)
	var nudge: float = 1.0 if enabled and screen.down_id == id else 0.0
	text_c(rect.position.x + rect.size.x * 0.5, rect.position.y + (rect.size.y - 7.0) * 0.5 + nudge, label, col, 1,
		not gold and enabled)


## A flat ordered-dither wash of palette black over rect: level 0..16 of 16 pixels covered. Palette colours only.
func dim(rect: Rect2, level: int) -> void:
	draw_texture_rect(dim_texture(level), rect, true)


static func dim_texture(level: int) -> ImageTexture:
	var lv: int = clampi(level, 0, 16)
	if _tc_dim.has(lv):
		return _tc_dim[lv] as ImageTexture
	var img: Image = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	var black: Color = RoomPalette.colors()[0]
	for y: int in range(4):
		for x: int in range(4):
			if BAYER[y * 4 + x] < lv:
				img.set_pixel(x, y, black)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tc_dim[lv] = tex
	return tex
