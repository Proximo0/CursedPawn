class_name UiRequests
extends RefCounted
## The request board: up to three pinned notes at the top right of the shop screen, one per open customer request
## ("MRS PELL WANTS CURSED DOLL / DUE NIGHT 3"). A note pins in with a small overshoot, a request that is done gets a
## green DONE stamp that slams down and then the note drops away, a failed one tears in half and falls. Fed with the
## request events and reading run.requests (both may be absent on older logic). Pure state plus a draw method.

const BOARD := Rect2(446.0, 94.0, 142.0, 56.0)
const NOTE_W: float = 138.0
const NOTE_H: float = 16.0
const NOTE_STEP: float = 18.0
const MAX_NOTES: int = 3
const PIN_SECS: float = 0.4
const STAMP_SECS: float = 0.25
const STAMP_HOLD: float = 0.9
const TEAR_SECS: float = 0.9
const DUE_GLOW: float = 0.5

var notes: Array[Dictionary] = []  ## {id, who, line, due, age, fate: "" | "done" | "failed", fate_age, due_now}


## Events: request_new pins a note, request_due lights it, request_done stamps it, request_failed tears it.
func feed(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		var id: String = str(e.get("id", ""))
		match str(e["e"]):
			"request_new":
				_pin(e)
			"request_due":
				var n: Dictionary = _find(id)
				if not n.is_empty():
					n["due_now"] = true
			"request_done":
				_fate(id, "done")
			"request_failed":
				_fate(id, "failed")


## Pins any open request (run.requests) that is not on the board yet: a resumed run, or logic that sends no events.
func sync(open: Array) -> void:
	for r: Variant in open:
		_pin(r as Dictionary)


func clear() -> void:
	notes.clear()


func _find(id: String) -> Dictionary:
	for n: Dictionary in notes:
		if str(n["id"]) == id:
			return n
	return {}


func _pin(req: Dictionary) -> void:
	var id: String = str(req.get("id", ""))
	if id == "" or not _find(id).is_empty():
		return
	notes.append({"id": id, "who": str(req.get("who", "")), "line": UiEngage.request_line(req),
		"due": int(req.get("due", 0)), "age": 0.0, "fate": "", "fate_age": 0.0, "due_now": false})


func _fate(id: String, fate: String) -> void:
	var n: Dictionary = _find(id)
	if not n.is_empty() and str(n["fate"]) == "":
		n["fate"] = fate
		n["fate_age"] = 0.0


func tick(delta: float) -> void:
	for n: Dictionary in notes:
		n["age"] = float(n["age"]) + delta
		if str(n["fate"]) != "":
			n["fate_age"] = float(n["fate_age"]) + delta
	for i: int in range(notes.size() - 1, -1, -1):
		if str(notes[i]["fate"]) != "" and float(notes[i]["fate_age"]) > fate_total(str(notes[i]["fate"])):
			notes.remove_at(i)


static func fate_total(fate: String) -> float:
	return STAMP_SECS + STAMP_HOLD + 0.35 if fate == "done" else TEAR_SECS


## Notes on screen now (open ones first, then those finishing), capped to the board.
func visible_notes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Dictionary in notes:
		if out.size() < MAX_NOTES:
			out.append(n)
	return out


## The y offset (0..1 of a full drop) of a note falling away; 0 while it is not leaving.
static func drop_amount(fate: String, fate_age: float) -> float:
	if fate == "done":
		return UiMotion.ui_in((fate_age - STAMP_SECS - STAMP_HOLD) / 0.35)
	if fate == "failed":
		return UiMotion.ui_in((fate_age - 0.35) / (TEAR_SECS - 0.35))
	return 0.0


func draw(ci: CanvasItem, t: float) -> void:
	var list: Array[Dictionary] = visible_notes()
	if list.is_empty():
		return
	var pal: PackedColorArray = RoomPalette.colors()
	for i: int in range(list.size()):
		_draw_note(ci, pal, list[i], BOARD.position + Vector2(0.0, NOTE_STEP * float(i)), t, i)


func _draw_note(ci: CanvasItem, pal: PackedColorArray, n: Dictionary, at: Vector2, t: float, slot: int) -> void:
	var age: float = float(n["age"])
	var fate: String = str(n["fate"])
	var fa: float = float(n["fate_age"])
	var pin_u: float = UiMotion.ui_back(age / PIN_SECS)
	var o := Vector2(0.0, -(1.0 - pin_u) * 26.0)  # swings down from above and settles
	var tilt: float = float(slot % 2) - 0.5  # alternate notes sit a pixel off, like they were pinned by hand
	o.x += floorf(tilt * 2.0)
	var drop: float = drop_amount(fate, fa)
	o.y += floorf(drop * 40.0)
	if age < 0.0 or pin_u <= 0.02:
		return
	var rect := Rect2((at + o).floor(), Vector2(NOTE_W, NOTE_H))
	var due_now: bool = bool(n["due_now"]) and fate == ""
	var wave: float = 0.0
	if fate == "failed":
		wave = floorf(minf(fa / 0.35, 1.0) * 2.0)
	if fate == "failed" and fa > 0.35:
		# torn in two: the halves fall apart, the left one slower and turning away
		var left := Rect2(rect.position + Vector2(-wave, 0.0), Vector2(floorf(NOTE_W * 0.55), NOTE_H))
		var right := Rect2(rect.position + Vector2(floorf(NOTE_W * 0.55) + wave * 2.0, floorf(drop * 14.0)),
			Vector2(NOTE_W - floorf(NOTE_W * 0.55), NOTE_H))
		UiFrames.ui_draw(ci, left, "note")
		UiFrames.ui_draw(ci, right, "note")
		_text_line(ci, pal, left, str(n["line"]), 12, 0.0)
		ci.draw_rect(Rect2(left.end.x - 1.0, left.position.y + 2.0, 1.0, 3.0), pal[12])
		return
	UiFrames.ui_draw(ci, rect, "note")
	if due_now and fmod(t, 1.0) < DUE_GLOW:
		ci.draw_rect(Rect2(rect.position.x, rect.position.y, 2.0, rect.size.y), pal[11])
	# the pin: a red head with a bright speck, and a tiny shadow
	ci.draw_rect(Rect2(rect.position.x + 5.0, rect.position.y + 1.0, 3.0, 3.0), pal[13])
	ci.draw_rect(Rect2(rect.position.x + 5.0, rect.position.y + 1.0, 1.0, 1.0), pal[15])
	ci.draw_rect(Rect2(rect.position.x + 6.0, rect.position.y + 4.0, 2.0, 1.0), pal[0])
	var line: String = str(n["line"])
	var due: int = int(n["due"])
	var tail: String = "NOW" if due_now else ("N%d" % due if due > 0 else "")
	_text_line(ci, pal, rect, line, 0, UiPixelFont.ui_width(tail) + 4 if tail != "" else 0)
	if tail != "":
		UiPixelFont.ui_draw(ci, Vector2(rect.end.x - float(UiPixelFont.ui_width(tail)) - 4.0, rect.position.y + 5.0), tail,
			pal[12 if due_now else 8], 1, false, pal[0])
	if fate == "done":
		var su: float = clampf(fa / STAMP_SECS, 0.0, 1.0)
		var sc: float = 1.0 + (1.0 - UiMotion.ui_out(su)) * 1.0  # slams down from big
		var w: float = float(UiPixelFont.ui_width("DONE", 1)) + 8.0
		var sr := Rect2(rect.position.x + rect.size.x * 0.5 - w * 0.5 * sc, rect.position.y + 1.0 - (sc - 1.0) * 3.0,
			w * sc, (NOTE_H - 2.0) * sc)
		if su > 0.0:
			ci.draw_rect(sr, pal[5])
			ci.draw_rect(sr.grow(-1.0), pal[7])
			if su >= 1.0:
				UiPixelFont.ui_draw(ci, Vector2(sr.position.x + 4.0, sr.position.y + 4.0), "DONE", pal[0], 1, false, pal[0])
			if su >= 1.0 and fa < STAMP_SECS + 0.1:
				ci.draw_rect(Rect2(sr.position.x - 2.0, sr.end.y, sr.size.x + 4.0, 1.0), pal[15])  # the thud


static func _text_line(ci: CanvasItem, pal: PackedColorArray, rect: Rect2, line: String, col: int, reserve: float) -> void:
	var room_w: int = int(rect.size.x - 14.0 - reserve)
	var s: String = line
	while UiPixelFont.ui_width(s) > room_w and s.length() > 3:
		s = s.substr(0, s.length() - 1)
	if s != line:
		s = s.substr(0, maxi(s.length() - 1, 0)) + "."
	UiPixelFont.ui_draw(ci, Vector2(rect.position.x + 12.0, rect.position.y + 5.0), s, pal[col], 1, false, pal[0])
