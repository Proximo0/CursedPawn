class_name UiTutorial
extends RefCounted
## The guided first night: an overlay that dims everything except the UI element the current tutorial step points at,
## with a bobbing quill pointer and the hint written in ink on a parchment note. It never blocks input: the HUD draws it
## and the player simply does the thing. Fed with `tutorial_step {step, text, focus}` events; the player's next action
## (inspect, offer, buy, sell, pass, cast), a night end or a run end clears it, and it lapses after MAX_SECS. Focus ids: tools, offer, buy, pass, shelf, dread, spells, table.

const DIM_LEVEL: int = 9
const MAX_SECS: float = 40.0
const NOTE_W: float = 236.0
const PAD: float = 5.0
const INK_CPS: float = 50.0
const FALLBACK: Dictionary = {
	"tools": Rect2(201.0, 187.0, 148.0, 36.0), "offer": Rect2(77.0, 271.0, 420.0, 31.0), "buy": Rect2(77.0, 271.0, 420.0, 31.0),
	"pass": Rect2(77.0, 271.0, 420.0, 31.0), "shelf": Rect2(30.0, 60.0, 300.0, 120.0), "dread": Rect2(592.0, 21.0, 42.0, 68.0),
	"spells": Rect2(60.0, 300.0, 330.0, 50.0), "table": Rect2(400.0, 171.0, 32.0, 53.0),
}
const PREFIXES: Dictionary = {
	"tools": ["tool:"], "offer": ["dec", "inc", "offer"], "buy": ["buy", "sell"], "pass": ["pass"], "shelf": ["item:"],
	"spells": ["spell:"], "table": ["tarot", "draw", "t_"],
}

var step: int = -1
var text: String = ""
var focus: String = ""
var age: float = 0.0
var active: bool = false


## Events: tutorial_step sets the hint; the moments that end it clear it.
func feed(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		match str(e.get("e", "")):
			"tutorial_step":
				step = int(e.get("step", 0))
				text = UiEngage.ascii_up(str(e.get("text", "")))
				focus = str(e.get("focus", ""))
				age = 0.0
				active = text != ""
			"inspected", "counter", "bought", "sold", "passed", "left", "cast", "night_end", "run_won", "run_lost":
				clear()  # the player did something (or the night moved on): the hint has done its job


func clear() -> void:
	active = false
	text = ""
	focus = ""
	step = -1


func tick(delta: float) -> void:
	age += delta
	if active and age > MAX_SECS:
		clear()


## The rectangle a focus id points at: the union of the matching live widgets, else a fixed fallback ("" for none).
static func focus_rect(id: String, widgets: Array[Dictionary], extra: Array[Rect2] = []) -> Rect2:
	var out := Rect2()
	var have: bool = false
	var prefixes: Array = PREFIXES.get(id, []) as Array
	for w: Dictionary in widgets:
		var wid: String = str(w.get("id", ""))
		for p: Variant in prefixes:
			if wid == str(p) or ((str(p).ends_with(":") or str(p).ends_with("_")) and wid.begins_with(str(p))):
				out = (w["rect"] as Rect2) if not have else out.merge(w["rect"] as Rect2)
				have = true
	for r: Rect2 in extra:
		out = r if not have else out.merge(r)
		have = true
	if have:
		return out
	return FALLBACK.get(id, Rect2()) as Rect2


func draw(hud: UiHud, extra: Array[Rect2] = []) -> void:
	if not active:
		return
	var more: Array[Rect2] = []
	if focus == "shelf":
		more = extra
	var hole: Rect2 = focus_rect(focus, hud.widgets, more)
	var fade: float = UiMotion.ui_out(age / 0.3)
	if hole.size == Vector2.ZERO:
		hole = Rect2(320.0, 180.0, 0.0, 0.0)
	hole = hole.grow(4.0)
	var level: int = int(round(float(DIM_LEVEL) * fade))
	var view: Vector2 = ShopGame.VIEW
	var tex: ImageTexture = TsCanvas.dim_texture(level)
	for r: Rect2 in [Rect2(0.0, 0.0, view.x, hole.position.y), Rect2(0.0, hole.end.y, view.x, view.y - hole.end.y),
			Rect2(0.0, hole.position.y, hole.position.x, hole.size.y), Rect2(hole.end.x, hole.position.y, view.x - hole.end.x, hole.size.y)]:
		if r.size.x > 0.0 and r.size.y > 0.0:
			hud.draw_texture_rect(tex, r, true)
	if hole.size.x > 8.0:
		var lit: int = 15 if fmod(age, 1.0) < 0.5 else 11
		hud.draw_rect(hole, hud._c(lit), false, 1.0)
		for k: Vector2 in [hole.position, Vector2(hole.end.x, hole.position.y), Vector2(hole.position.x, hole.end.y), hole.end]:  # corner studs
			hud._rect(Rect2(k - Vector2(1.0, 1.0), Vector2(3.0, 3.0)), 11)
	_draw_note(hud, hole, fade)


func _draw_note(hud: UiHud, hole: Rect2, fade: float) -> void:
	var lines: PackedStringArray = UiPixelFont.ui_wrap(text, int(NOTE_W - PAD * 2.0))
	var n: int = mini(lines.size(), 4)
	var h: float = PAD * 2.0 + float(n * UiPixelFont.LINE_H) + 4.0
	var above: bool = hole.get_center().y > 190.0
	var bob: float = floorf(sin(age * 5.0) * 1.5 + 0.5)
	var y: float = hole.position.y - h - 20.0 if above else hole.end.y + 20.0
	y = clampf(y, 22.0, ShopGame.VIEW.y - h - 4.0)
	var x: float = clampf(hole.get_center().x - NOTE_W * 0.5, 6.0, ShopGame.VIEW.x - NOTE_W - 6.0)
	var rise: float = (1.0 - fade) * 8.0
	var rc := Rect2(x, y + rise, NOTE_W, h)
	hud._frame(rc, "note")
	var shown: int = int(age * INK_CPS)
	var done: int = 0
	for i: int in range(n):
		var ln: String = lines[i]
		var k: int = clampi(shown - done, 0, ln.length())
		UiPixelFont.ui_draw_ink(hud, rc.position + Vector2(PAD + 2.0, PAD + float(i * UiPixelFont.LINE_H)), ln, hud._c(0), hud._c(12), k,
			k < ln.length() and k > 0, hud._c(0), age)
		done += ln.length()
	# the quill: a feather pointing down (or up) at the lit element
	var px: float = clampf(hole.get_center().x, rc.position.x + 12.0, rc.end.x - 12.0)
	var py: float = (rc.end.y + 2.0 + bob) if above else (rc.position.y - 14.0 - bob)
	_draw_quill(hud, Vector2(px, py), above)


## A 7x12 quill: a pale vane and a dark nib; the nib points at the hole.
func _draw_quill(hud: UiHud, at: Vector2, down: bool) -> void:
	var rows: Array[String] = ["....vv.", "...vvv.", "..vvvv.", "..vvv..", ".vvv...", ".vv....", "vk.....", "k......"]
	for i: int in range(rows.size()):
		var row: String = rows[i] if down else rows[rows.size() - 1 - i]
		for j: int in range(row.length()):
			var ch: String = row[j]
			if ch == ".":
				continue
			hud._rect(Rect2(at.x - 3.0 + float(j), at.y + float(i), 1.0, 1.0), 15 if ch == "v" else 0)
