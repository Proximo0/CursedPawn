class_name UiToasts
extends RefCounted
## Two small pop-ups drawn over the shop. A deed toast: a parchment note drops in, a wax seal stamps down with a thump
## (a ring flashes, the note jolts, the deed sound plays) and the deed's name is written in wet ink. A regular's card:
## a portrait and name slide in from the left ("THE WIDOW MARCH, CHAPTER 2") with the line they open with. Both queue
## and never block input. Pure state plus a draw method; the hud calls feed() / tick() / draw().

const DEED_SECS: float = 3.8
const SEAL_AT: float = 0.5
const DEED_W: float = 244.0
const DEED_H: float = 40.0
const DEED_Y: float = 24.0
const REG_SECS: float = 4.8
const REG_X: float = 8.0
const REG_Y: float = 24.0
const REG_W: float = 214.0
const REG_H: float = 62.0
const SLIDE_SECS: float = 0.4
const OUT_SECS: float = 0.4
const INK_CPS: float = 26.0

var deeds: Array[Dictionary] = []  ## {id, name, age, sounded}; the first is on screen
var regulars: Array[Dictionary] = []  ## {id, name, chapter, line, age}; the first is on screen
var sfx: SfxPlayer


func feed(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		if str(e.get("e", "")) == "regular":
			push_regular(e)


## The name a deed shows: its deeds.json name, or the id spelled out.
static func deed_name(id: String) -> String:
	for d: Dictionary in UiLedger.deed_defs():
		if str(d["id"]) == id:
			return UiEngage.ascii_up(str(d.get("name", id)))
	return UiEngage.ascii_up(id.replace("_", " "))


func push_deed(id: String) -> void:
	for d: Dictionary in deeds:
		if str(d["id"]) == id:
			return
	deeds.append({"id": id, "name": deed_name(id), "age": 0.0, "sounded": false})


## A regular's arrival: the event carries {id, name, chapter, line}. `chapter` is already 1-based.
func push_regular(e: Dictionary) -> void:
	regulars.append({"id": str(e.get("id", "")), "name": UiEngage.ascii_up(str(e.get("name", "A REGULAR"))),
		"chapter": maxi(int(e.get("chapter", 1)), 1), "total": int(e.get("chapters", 0)), "line": UiEngage.ascii_up(str(e.get("line", ""))), "age": 0.0})


func clear() -> void:
	deeds.clear()
	regulars.clear()


func active() -> bool:
	return not deeds.is_empty() or not regulars.is_empty()


func tick(delta: float) -> void:
	if not deeds.is_empty():
		var d: Dictionary = deeds[0]
		d["age"] = float(d["age"]) + delta
		if float(d["age"]) >= SEAL_AT and not bool(d["sounded"]):
			d["sounded"] = true
			if sfx != null:
				sfx.ui("deed")
		if float(d["age"]) >= DEED_SECS:
			deeds.pop_front()
	if not regulars.is_empty():
		var r: Dictionary = regulars[0]
		if float(r["age"]) == 0.0 and sfx != null:
			sfx.ui("regular")
		r["age"] = float(r["age"]) + delta
		if float(r["age"]) >= REG_SECS:
			regulars.pop_front()


## 0..1 slide of a pop-up that comes in over SLIDE_SECS and leaves over the last OUT_SECS of `total`.
static func slide(age: float, total: float) -> float:
	return minf(UiMotion.ui_back(age / SLIDE_SECS), 1.0) * (1.0 - UiMotion.ui_in((age - (total - OUT_SECS)) / OUT_SECS))


func draw(hud: UiHud) -> void:
	if not regulars.is_empty():
		_draw_regular(hud, regulars[0])
	if not deeds.is_empty():
		_draw_deed(hud, deeds[0])


func _draw_deed(hud: UiHud, d: Dictionary) -> void:
	var age: float = float(d["age"])
	var s: float = slide(age, DEED_SECS)
	var jolt: float = 0.0
	if age >= SEAL_AT and age < SEAL_AT + 0.12:
		jolt = 1.0 if int(age * 60.0) % 2 == 0 else -1.0  # the thump shakes the note
	var dx: float = REG_X + REG_W + 10.0 if not regulars.is_empty() else 320.0 - DEED_W * 0.5  # beside a regular's card, else centred
	var rc := Rect2(floorf(dx), floorf(DEED_Y - (1.0 - s) * (DEED_H + DEED_Y)) + jolt, DEED_W, DEED_H)
	hud._frame(rc, "note")
	hud._text(rc.position + Vector2(40.0, 6.0), "DEED EARNED", 12, 1, false)
	var seal_c: Vector2 = rc.position + Vector2(22.0, 20.0)
	var tex: ImageTexture = UiLedger.seal_tex(str(d["id"]))
	if age < SEAL_AT:
		var k: float = UiMotion.ui_in(clampf((age - (SEAL_AT - 0.3)) / 0.3, 0.0, 1.0))  # the seal hangs above, then falls
		if age > SEAL_AT - 0.3:
			var sz: float = float(UiLedger.SEAL_PX) * (1.9 - 0.9 * k)
			hud.draw_texture_rect(tex, Rect2(seal_c - Vector2(sz, sz) * 0.5 - Vector2(0.0, (1.0 - k) * 10.0), Vector2(sz, sz)), false, Color(1, 1, 1, 0.5 + 0.5 * k))
	else:
		var since: float = age - SEAL_AT
		var sz2: float = float(UiLedger.SEAL_PX) * (1.0 + 0.18 * maxf(0.0, 1.0 - since / 0.15))  # a squash on the strike
		hud.draw_texture_rect(tex, Rect2(seal_c - Vector2(sz2, sz2) * 0.5, Vector2(sz2, sz2)), false)
		if since < 0.3:
			var ring: float = UiMotion.ui_out(since / 0.3) * 16.0 + 10.0
			hud.draw_rect(Rect2(seal_c - Vector2(ring, ring), Vector2(ring, ring) * 2.0), hud._c(15 if since < 0.1 else 12), false, 1.0)
		var shown: int = int(maxf(since - 0.1, 0.0) * INK_CPS)
		var nm: String = str(d["name"])
		UiPixelFont.ui_draw_ink(hud, rc.position + Vector2(40.0, 19.0), nm, hud._c(0), hud._c(12), shown, shown < nm.length(), hud._c(0), age)


func _draw_regular(hud: UiHud, r: Dictionary) -> void:
	var age: float = float(r["age"])
	var s: float = slide(age, REG_SECS)
	var rc := Rect2(floorf(REG_X - (1.0 - s) * (REG_W + REG_X)), REG_Y, REG_W, REG_H)
	UiFrames.ui_glow(hud, rc.position + Vector2(24.0, 30.0), 44, 1, 10, 0.5 * s)  # a warm rim of light around the visitor
	hud._frame(rc, "note")
	var pr := Rect2(rc.position + Vector2(8.0, 11.0), Vector2(float(UiLedger.PORTRAIT_W), float(UiLedger.PORTRAIT_H)))
	hud._rect(pr.grow(2.0), 0)
	hud.draw_texture_rect(UiLedger.portrait_tex(str(r["id"])), pr, false)
	hud._rect(Rect2(pr.position.x - 2.0, pr.end.y + 1.0, pr.size.x + 4.0, 1.0), 10)
	var nm: String = str(r["name"])
	var shown: int = int(maxf(age - 0.3, 0.0) * 40.0)
	UiPixelFont.ui_draw_ink(hud, rc.position + Vector2(48.0, 6.0), nm, hud._c(12), hud._c(13), shown, shown < nm.length(), hud._c(0), age)
	hud._text(rc.position + Vector2(48.0, 17.0), ("CHAPTER %d OF %d" % [int(r["chapter"]), int(r["total"])]) if int(r["total"]) > 0 else "CHAPTER %d" % int(r["chapter"]), 8, 1, false)
	var lines: PackedStringArray = UiPixelFont.ui_wrap("\"%s\"" % str(r["line"]), int(REG_W) - 58)
	var fade: float = clampf((age - 0.9) / 0.5, 0.0, 1.0)
	for i: int in range(mini(lines.size(), 3)):
		var ln: String = lines[i]
		if i == 2 and lines.size() > 3:
			ln = ln.substr(0, maxi(ln.length() - 2, 1)) + ".."
		if fade > 0.0:
			hud._text(rc.position + Vector2(48.0, 29.0 + float(i * UiPixelFont.LINE_H)), ln, 0 if fade > 0.6 else 9, 1, false)
