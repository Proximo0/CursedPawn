class_name TsHintFrame
extends RefCounted
## Draws a one-line hint in a small bone note under the top strip, at the 480x270 grid. Call from any CanvasItem
## (the HUD) with TsHintFrame.ts_draw(self, tracker.text(), tracker.age). It slides in over 0.12 s.

const Y: float = 19.0
const MAX_W: float = 440.0
const PAD: float = 6.0


static func ts_draw(ci: CanvasItem, text: String, age: float = 1.0) -> void:
	if text == "":
		return
	var pal: PackedColorArray = RoomPalette.colors()
	var lines: PackedStringArray = UiPixelFont.ui_wrap(text, int(MAX_W - 2.0 * PAD))
	var w: float = 0.0
	for ln: String in lines:
		w = maxf(w, float(UiPixelFont.ui_width(ln)))
	var rect := Rect2(0.0, Y, w + 2.0 * PAD + 2.0, 8.0 * float(lines.size()) + 6.0)
	rect.position.x = floorf((480.0 - rect.size.x) * 0.5)
	var slide: float = clampf(age / 0.12, 0.0, 1.0)
	rect.position.y -= (1.0 - slide) * 8.0
	UiFrames.ui_draw(ci, rect, "note")
	for i: int in range(lines.size()):
		UiPixelFont.ui_draw(ci, rect.position + Vector2(PAD, 4.0 + 8.0 * float(i)), lines[i], pal[0], 1, false)
