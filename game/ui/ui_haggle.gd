class_name UiHaggle
extends RefCounted
## The haggle at the counter: a candle that gutters as the seller's patience runs out, and a chip naming their mood once a
## counter-offer has shown it (until then only the observed behaviour line is in the ledger, so the mood can be read
## from how they act). Pure helpers are tested; draw() paints on the HUD.

const CANDLE_X: float = 66.0
const CANDLE_BASE: float = 222.0
const CANDLE_MAX_H: int = 30
const MOODS: Array[String] = ["calm", "nervous", "greedy"]
const MOOD_COLS: Dictionary = {"calm": 9, "nervous": 4, "greedy": 11}


## 0..1 of the candle left: patience now over the patience the seller arrived with.
static func patience_frac(now: int, start: int) -> float:
	return clampf(float(now) / float(maxi(start, 1)), 0.0, 1.0)


## Flame size for the candle (the HUD's convention: 0 calm, 1 short, 2 guttering, -1 out).
static func flame_for(frac: float) -> int:
	if frac <= 0.0:
		return -1
	return 0 if frac > 0.66 else (1 if frac > 0.33 else 2)


## The chip text for a mood, "" when unknown. `known` turns true on the first counter-offer.
static func mood_chip(mood: String, known: bool) -> String:
	if not known or not MOODS.has(mood):
		return ""
	return "MOOD: " + mood.to_upper()


## The ledger line a counter-offer adds: its tell when it has one.
static func counter_line(e: Dictionary) -> String:
	return str(e.get("tell", ""))


## A tiny face for each mood, 9x7, drawn with rectangles at `at`: calm (flat mouth), nervous (wide eyes, wavy mouth), greedy (grin).
static func draw_face(ci: CanvasItem, mood: String, at: Vector2, col: Color) -> void:
	var dark: Color = RoomPalette.colors()[0]
	ci.draw_rect(Rect2(at.x, at.y, 9.0, 7.0), col)
	ci.draw_rect(Rect2(at.x + 2.0, at.y + 2.0, 1.0, 1.0 if mood != "nervous" else 2.0), dark)
	ci.draw_rect(Rect2(at.x + 6.0, at.y + 2.0, 1.0, 1.0 if mood != "nervous" else 2.0), dark)
	match mood:
		"greedy":
			ci.draw_rect(Rect2(at.x + 2.0, at.y + 5.0, 5.0, 1.0), dark)
			ci.draw_rect(Rect2(at.x + 1.0, at.y + 4.0, 1.0, 1.0), dark)
			ci.draw_rect(Rect2(at.x + 7.0, at.y + 4.0, 1.0, 1.0), dark)
		"nervous":
			ci.draw_rect(Rect2(at.x + 2.0, at.y + 5.0, 2.0, 1.0), dark)
			ci.draw_rect(Rect2(at.x + 4.0, at.y + 4.0, 2.0, 1.0), dark)
			ci.draw_rect(Rect2(at.x + 6.0, at.y + 5.0, 1.0, 1.0), dark)
		_:
			ci.draw_rect(Rect2(at.x + 2.0, at.y + 5.0, 5.0, 1.0), dark)


static func draw(hud: UiHud, r: RunState, start: int, mood: String, known: bool, t: float) -> void:
	var now: int = int(r.customer.get("patience", 0))
	var frac: float = patience_frac(now, start)
	var h: int = maxi(3, int(round(float(CANDLE_MAX_H) * frac)))
	var flame: int = flame_for(frac)
	var rc := Rect2(CANDLE_X - 9.0, CANDLE_BASE - float(CANDLE_MAX_H) - 12.0, 18.0, float(CANDLE_MAX_H) + 22.0)
	hud._add("patience", rc, true)
	UiFrames.ui_candle(hud, CANDLE_X, CANDLE_BASE, 6, h, t, flame, flame == 2, 7)
	if hud.game.hover_id == "patience":
		var tip: String = "PATIENCE: %d LEFT" % now
		var w: float = float(UiPixelFont.ui_width(tip)) + 12.0
		hud._frame(Rect2(CANDLE_X - 4.0, CANDLE_BASE - float(CANDLE_MAX_H) - 30.0, w, 14.0), "note")
		hud._text(Vector2(CANDLE_X + 2.0, CANDLE_BASE - float(CANDLE_MAX_H) - 26.0), tip, 0, 1, false)
	var chip: String = mood_chip(mood, known)
	if chip != "":
		var cw: float = float(UiPixelFont.ui_width(chip)) + 20.0
		var cr := Rect2(78.0, 160.0, cw, 14.0)
		hud._frame(cr, "note")
		draw_face(hud, mood, cr.position + Vector2(4.0, 3.0), hud._c(int(MOOD_COLS.get(mood, 9))))
		hud._text(cr.position + Vector2(16.0, 4.0), chip, 0, 1, false)
