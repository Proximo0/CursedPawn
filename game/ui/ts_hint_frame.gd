class_name TsHintFrame
extends RefCounted
## Draws a one-line hint as a ledger note pinned under the top strip, on the 640x360 grid. Call from any CanvasItem
## (the HUD) with TsHintFrame.ts_draw(self, tracker.text(), tracker.age). It flutters in like pinned paper: drops with
## a small overshoot while swaying from side to side, then hangs from a brass pin.

const Y: float = 22.0
const MAX_W: float = 520.0
const PAD: float = 10.0
const FLUTTER_SECS: float = 0.6
const SWAY_PX: float = 5.0


## Offset of the note from its resting place after `age` seconds (pure, for tests): x sway, y drop.
static func ts_offset(age: float) -> Vector2:
	var u: float = clampf(age / FLUTTER_SECS, 0.0, 1.0)
	if u >= 1.0:
		return Vector2.ZERO
	var drop: float = (1.0 - UiMotion.ui_back(u)) * -18.0
	var sway: float = sin(u * 17.0) * (1.0 - u) * (1.0 - u) * SWAY_PX
	return Vector2(roundf(sway), roundf(drop))


static func ts_size(text: String) -> Vector2:
	var lines: PackedStringArray = UiPixelFont.ui_wrap(text, int(MAX_W - 2.0 * PAD - float(UiFrames.LEDGER_TEXT_X)))
	var w: float = 0.0
	for ln: String in lines:
		w = maxf(w, float(UiPixelFont.ui_width(ln)))
	return Vector2(w + 2.0 * PAD + float(UiFrames.LEDGER_TEXT_X) - 8.0, float(UiPixelFont.LINE_H * lines.size()) + 9.0)


static func ts_draw(ci: CanvasItem, text: String, age: float = 1.0) -> void:
	if text == "":
		return
	var pal: PackedColorArray = RoomPalette.colors()
	var lines: PackedStringArray = UiPixelFont.ui_wrap(text, int(MAX_W - 2.0 * PAD - float(UiFrames.LEDGER_TEXT_X)))
	var sz: Vector2 = ts_size(text)
	var rect := Rect2(Vector2(floorf((640.0 - sz.x) * 0.5), Y) + ts_offset(age), sz)
	UiFrames.ui_draw(ci, rect, "ledger")
	for i: int in range(lines.size()):
		UiPixelFont.ui_draw(ci, rect.position + Vector2(float(UiFrames.LEDGER_TEXT_X), 5.0 + float(UiPixelFont.LINE_H * i)),
			lines[i], pal[0], 1, false)
	var px: float = rect.position.x + rect.size.x * 0.5
	ci.draw_rect(Rect2(px - 1.0, rect.position.y - 2.0, 3.0, 3.0), pal[0])
	ci.draw_rect(Rect2(px - 1.0, rect.position.y - 2.0, 2.0, 2.0), pal[13])
	ci.draw_rect(Rect2(px - 1.0, rect.position.y - 2.0, 1.0, 1.0), pal[14])
