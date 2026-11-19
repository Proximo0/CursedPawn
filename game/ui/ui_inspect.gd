class_name UiInspect
extends RefCounted
## The detail card: click an object on the counter or the shelf (or press I) to see it large. Art at 2x, name, category,
## its flavour text, where it has been (provenance, or the pass-it-on history), the tells found so far and its curse when
## those tells have named it. Never shows value or the true curse of something not yet identified.
## State is a target `{kind: "counter"|"held", uid}`; `card()` turns it into the data the card draws.

const RECT := Rect2(140.0, 26.0, 360.0, 196.0)
const ART_BOX := Rect2(156.0, 66.0, 84.0, 84.0)
const TEXT_X: float = 252.0
const TEXT_W: int = 238

var target: Dictionary = {}
var age: float = 0.0
var _tex: Dictionary = {}


func is_open() -> bool:
	return not target.is_empty()


func open_counter() -> void:
	target = {"kind": "counter", "uid": -1}
	age = 0.0


func open_held(uid: int) -> void:
	target = {"kind": "held", "uid": uid}
	age = 0.0


var sfx: SfxPlayer  ## set by the HUD owner: the card plays a soft click when it closes


func close() -> void:
	if not target.is_empty() and sfx != null:
		sfx.ui("click")
	target = {}


func tick(delta: float) -> void:
	age += delta


## The curse a set of found tells names: the curse name when a tell matches the true curse's tell for its tool, "CURSED"
## when the Pendulum said so, else "". `tells` is tool -> text.
static func curse_label(curse_id: String, tells: Dictionary, cat: Catalog) -> String:
	if curse_id == "":
		for t: Variant in tells.values():
			if str(t) == "clean":
				return "CLEAN, THE PENDULUM SAYS"
		return ""
	var c: Dictionary = cat.curse(curse_id)
	var told: Dictionary = c.get("tells", {}) as Dictionary
	for tool: Variant in tells.keys():
		if told.has(str(tool)) and str(told[str(tool)]) == str(tells[tool]):
			return str(c.get("name", curse_id)).to_upper()
	if tells.has("pendulum") and str(tells["pendulum"]) == "cursed":
		return "CURSED, KIND UNKNOWN"
	return ""


## What the card shows for the target: {name, category, id, text, provenance, tells: Array[String], curse} or {}.
func card(r: RunState, tell_texts: Dictionary, held_tells: Dictionary) -> Dictionary:
	if target.is_empty() or r == null:
		return {}
	var item: Dictionary = {}
	var tells: Dictionary = {}
	if str(target["kind"]) == "counter":
		if str(r.customer.get("kind", "")) != RunState.SELLER:
			return {}
		item = r.customer.get("item", {}) as Dictionary
		tells = tell_texts
	else:
		for it: Dictionary in r.inventory:
			if int(it["uid"]) == int(target["uid"]):
				item = it
		tells = held_tells.get(int(target["uid"]), {}) as Dictionary
	if item.is_empty():
		return {}
	var lines: Array[String] = []
	for tool: Variant in tells.keys():
		lines.append("%s: %s" % [ShopDebug.sd_tool_name(str(tool)).to_upper(), str(tells[tool])])
	var cat_text: String = ""
	for o: Dictionary in r.catalog.objects:
		if str(o["id"]) == str(item.get("id", "")):
			cat_text = str(o.get("text", ""))
	return {"name": str(item.get("name", "?")), "category": str(item.get("category", "")), "id": str(item.get("id", "")),
		"text": str(item.get("text", cat_text)), "provenance": provenance_of(item), "tells": lines,
		"curse": curse_label(str(item.get("curse", "")), tells, r.catalog)}


## The provenance line: the item's own, else the last pass-it-on history entry, else "".
static func provenance_of(item: Dictionary) -> String:
	var p: String = str(item.get("provenance", ""))
	if p != "":
		return p
	var hist: Variant = item.get("history", [])
	if hist is Array and not (hist as Array).is_empty():
		var last: Variant = (hist as Array)[(hist as Array).size() - 1]
		if last is Array and (last as Array).size() >= 2:
			return "Passed on by %s, who reached night %d." % [str((last as Array)[0]), int((last as Array)[1])]
	return ""


func art(id: String, category: String) -> ImageTexture:
	var key: String = id + "/" + category
	if not _tex.has(key):
		if UiOccult.static_has(SpriteKit as GDScript, "object_detail"):
			_tex[key] = (SpriteKit as GDScript).call("object_detail", id, category)
		else:
			_tex[key] = SpriteKit.object_texture(id, category)
	return _tex[key] as ImageTexture


func draw(hud: UiHud, r: RunState, tell_texts: Dictionary, held_tells: Dictionary) -> void:
	var c: Dictionary = card(r, tell_texts, held_tells)
	if c.is_empty():
		return
	var k: float = UiMotion.ui_out(age / 0.22)
	hud.draw_texture_rect(TsCanvas.dim_texture(int(round(8.0 * k))), Rect2(Vector2.ZERO, ShopGame.VIEW), true)
	var rc := Rect2(RECT.position + Vector2(0.0, (1.0 - k) * 10.0), RECT.size)
	hud._frame(rc, "panel")
	var dy: float = rc.position.y - RECT.position.y
	var name_s: String = str(c["name"]).to_upper()
	hud.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UiPixelFont.ui_head_draw(hud, Vector2(floorf(rc.position.x + (rc.size.x - float(UiPixelFont.ui_head_width(name_s, 2))) * 0.5), rc.position.y + 12.0),
		name_s, hud._c(11), 2, true, hud._c(0))
	hud._frame(Rect2(ART_BOX.position + Vector2(0.0, dy), ART_BOX.size), "note")
	var tex: ImageTexture = art(str(c["id"]), str(c["category"]))
	var ts: Vector2 = tex.get_size() * 2.0
	hud.draw_texture_rect(tex, Rect2(ART_BOX.position + Vector2(0.0, dy) + ((ART_BOX.size - ts) * 0.5).floor(), ts), false)
	hud._text_c(ART_BOX.get_center().x, ART_BOX.end.y + dy + 5.0, str(c["category"]).to_upper(), 9)
	var y: float = rc.position.y + 40.0
	y = _para(hud, str(c["text"]), y, 14, 3)
	if str(c["provenance"]) != "":
		y = _para(hud, "WHERE IT HAS BEEN: " + str(c["provenance"]).to_upper(), y + 3.0, 8, 3)
	hud._rect(Rect2(TEXT_X, y + 2.0, float(TEXT_W), 1.0), 8)
	y += 7.0
	var tells: Array = c["tells"] as Array
	if tells.is_empty():
		hud._text(Vector2(TEXT_X, y), "NO TELLS FOUND YET.", 4)
		y += float(UiPixelFont.LINE_H)
	else:
		for t: Variant in tells:
			y = _para(hud, str(t), y, 15, 2)
	if str(c["curse"]) != "":
		hud._text(Vector2(TEXT_X, rc.end.y - 28.0), "CURSE: " + str(c["curse"]), 13 if not str(c["curse"]).begins_with("CLEAN") else 7)
	hud._text_c(rc.get_center().x, rc.end.y - 13.0, "CLICK OR ESC TO CLOSE", 3, 1, false)


func _para(hud: UiHud, text: String, y: float, col: int, max_lines: int) -> float:
	var lines: PackedStringArray = UiPixelFont.ui_wrap(text, TEXT_W)
	for i: int in range(mini(lines.size(), max_lines)):
		var ln: String = lines[i]
		if i == max_lines - 1 and lines.size() > max_lines:
			ln = ln.substr(0, maxi(ln.length() - 2, 1)) + ".."
		hud._text(Vector2(TEXT_X, y), ln, col, 1, false)
		y += float(UiPixelFont.LINE_H)
	return y
