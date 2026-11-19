class_name TestOverlay
extends Control
## The strip over a test scene: its name, what to do, how to leave, and (on the dread tile) a live Dread slider.
## Drawn on the 640x360 grid scaled like the rest of the UI. It takes no input; ShopGame maps the slider clicks.

const BAR := Rect2(190.0, 33.0, 260.0, 9.0)

var game: ShopGame
var label: String = ""
var note: String = ""
var slider: bool = false
var frac: float = 0.0  ## slider value 0..1 of the slider's span
var _pal: PackedColorArray = RoomPalette.colors()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 90


func _process(_delta: float) -> void:
	queue_redraw()


## Slider position (0..1) for a click at grid point p, or -1 when p misses the bar.
static func frac_at(p: Vector2) -> float:
	if not BAR.grow(3.0).has_point(p):
		return -1.0
	return clampf((p.x - BAR.position.x) / BAR.size.x, 0.0, 1.0)


func _draw() -> void:
	var r: Rect2 = ShopGame.ui_rect(size)
	var s: float = ShopGame.ui_scale(size)
	draw_set_transform(r.position, 0.0, Vector2(s, s))
	var text: String = "%s: %s   [ESC] MENU" % [label, note]
	draw_rect(Rect2(0.0, 18.0, 640.0, 13.0), _pal[0])
	UiPixelFont.ui_draw(self, Vector2(6.0, 21.0), text, _pal[11], 1, true, _pal[0])
	if slider:
		draw_rect(Rect2(0.0, 31.0, 640.0, 14.0), _pal[0])
		UiPixelFont.ui_draw(self, Vector2(6.0, 34.0), "DREAD %d%%" % int(round(frac * 100.0)), _pal[14], 1, true, _pal[0])
		draw_rect(BAR, _pal[1])
		draw_rect(Rect2(BAR.position, Vector2(BAR.size.x * frac, BAR.size.y)), _pal[13] if frac > 0.8 else _pal[9])
		draw_rect(Rect2(BAR.position.x + BAR.size.x * frac - 1.0, BAR.position.y - 2.0, 3.0, BAR.size.y + 4.0), _pal[15])
