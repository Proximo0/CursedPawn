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
const TAIL_RESERVE: float = 24.0  ## width kept free at the end of the last line for "N3" / "NOW"
const COLLECTOR_ID: String = "collector"
const LINE_H: float = 10.0
const NOTE_GAP: float = 2.0

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
			"collector_omen":
				_pin_collector(str(e.get("text", "")), int(e.get("arrive_night", 5)))
			"collector_arrives":
				var cn: Dictionary = _find(COLLECTOR_ID)
				if cn.is_empty():
					_pin_collector(str(e.get("want_text", "")), 0)
					cn = _find(COLLECTOR_ID)
				cn["due_now"] = true
			"collector_pleased":
				_fate(COLLECTOR_ID, "done")
			"collector_refused":
				_fate(COLLECTOR_ID, "failed")


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
		"due": int(req.get("due", 0)), "age": 0.0, "fate": "", "fate_age": 0.0, "due_now": false, "boss": false})


## The Collector's want, pinned from the night he is announced until he comes (a note with a violet pin).
func _pin_collector(text: String, arrive_night: int) -> void:
	if not _find(COLLECTOR_ID).is_empty():
		return
	notes.append({"id": COLLECTOR_ID, "who": "THE COLLECTOR", "line": UiEngage.collector_line(text), "due": arrive_night, "age": 0.0,
		"fate": "", "fate_age": 0.0, "due_now": false, "boss": true})


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


## The lines a note's text wraps to (one when it fits, else two; the second is cut with dots).
static func note_lines(line: String, reserve: float) -> PackedStringArray:
	var wrap_w: int = int(NOTE_W - 14.0 - reserve)
	var lines: PackedStringArray = UiPixelFont.ui_wrap(line, wrap_w)
	if lines.size() > 2:
		lines = lines.slice(0, 2)
		lines[1] = lines[1].substr(0, maxi(lines[1].length() - 2, 1)) + ".."
	return lines


static func note_height(n: Dictionary) -> float:
	return NOTE_H + LINE_H * float(note_lines(str(n["line"]), TAIL_RESERVE).size() - 1)


func draw(ci: CanvasItem, t: float) -> void:
	var list: Array[Dictionary] = visible_notes()
	if list.is_empty():
		return
	var pal: PackedColorArray = RoomPalette.colors()
	var y: float = 0.0
	for i: int in range(list.size()):
		_draw_note(ci, pal, list[i], BOARD.position + Vector2(0.0, y), t, i)
		y += note_height(list[i]) + NOTE_GAP


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
	var nh: float = note_height(n)
	var rect := Rect2((at + o).floor(), Vector2(NOTE_W, nh))
	var due_now: bool = bool(n["due_now"]) and fate == ""
	var wave: float = 0.0
	if fate == "failed":
		wave = floorf(minf(fa / 0.35, 1.0) * 2.0)
	if fate == "failed" and fa > 0.35:
		# torn in two: the halves fall apart, the left one slower and turning away
		var left := Rect2(rect.position + Vector2(-wave, 0.0), Vector2(floorf(NOTE_W * 0.55), nh))
		var right := Rect2(rect.position + Vector2(floorf(NOTE_W * 0.55) + wave * 2.0, floorf(drop * 14.0)),
			Vector2(NOTE_W - floorf(NOTE_W * 0.55), nh))
		UiFrames.ui_draw(ci, left, "note")
		UiFrames.ui_draw(ci, right, "note")
		_text_line(ci, pal, left, str(n["line"]), 12, TAIL_RESERVE, 1)
		ci.draw_rect(Rect2(left.end.x - 1.0, left.position.y + 2.0, 1.0, 3.0), pal[12])
		return
	UiFrames.ui_draw(ci, rect, "note")
	if due_now and fmod(t, 1.0) < DUE_GLOW:
		ci.draw_rect(Rect2(rect.position.x, rect.position.y, 2.0, rect.size.y), pal[11])
	# the pin: a red head with a bright speck, and a tiny shadow
	var boss: bool = bool(n.get("boss", false))
	if boss:
		ci.draw_rect(Rect2(rect.position.x, rect.position.y, 2.0, rect.size.y), pal[3])  # a violet edge: not a customer's note
	ci.draw_rect(Rect2(rect.position.x + 5.0, rect.position.y + 1.0, 3.0, 3.0), pal[2 if boss else 13])
	ci.draw_rect(Rect2(rect.position.x + 5.0, rect.position.y + 1.0, 1.0, 1.0), pal[15])
	ci.draw_rect(Rect2(rect.position.x + 6.0, rect.position.y + 4.0, 2.0, 1.0), pal[0])
	var line: String = str(n["line"])
	var due: int = int(n["due"])
	var tail: String = "NOW" if due_now else ("N%d" % due if due > 0 else "")
	_text_line(ci, pal, rect, line, 0, TAIL_RESERVE)
	if tail != "":
		var last: int = note_lines(line, TAIL_RESERVE).size() - 1
		UiPixelFont.ui_draw(ci, Vector2(rect.end.x - float(UiPixelFont.ui_width(tail)) - 4.0, rect.position.y + 5.0 + LINE_H * float(last)), tail,
			pal[12 if due_now else 8], 1, false, pal[0])
	if fate == "done":
		var su: float = clampf(fa / STAMP_SECS, 0.0, 1.0)
		var sc: float = 1.0 + (1.0 - UiMotion.ui_out(su)) * 1.0  # slams down from big
		var w: float = float(UiPixelFont.ui_width("DONE", 1)) + 8.0
		var sr := Rect2(rect.position.x + rect.size.x * 0.5 - w * 0.5 * sc, rect.position.y + 1.0 - (sc - 1.0) * 3.0,
			w * sc, (nh - 2.0) * sc)
		if su > 0.0:
			ci.draw_rect(sr, pal[5])
			ci.draw_rect(sr.grow(-1.0), pal[7])
			if su >= 1.0:
				UiPixelFont.ui_draw(ci, Vector2(sr.position.x + 4.0, sr.position.y + 4.0), "DONE", pal[0], 1, false, pal[0])
			if su >= 1.0 and fa < STAMP_SECS + 0.1:
				ci.draw_rect(Rect2(sr.position.x - 2.0, sr.end.y, sr.size.x + 4.0, 1.0), pal[15])  # the thud


static func _text_line(ci: CanvasItem, pal: PackedColorArray, rect: Rect2, line: String, col: int, reserve: float, max_lines: int = 2) -> void:
	var lines: PackedStringArray = note_lines(line, reserve)
	for i: int in range(mini(lines.size(), max_lines)):
		UiPixelFont.ui_draw(ci, Vector2(rect.position.x + 12.0, rect.position.y + 5.0 + LINE_H * float(i)), lines[i], pal[col], 1, false, pal[0])
