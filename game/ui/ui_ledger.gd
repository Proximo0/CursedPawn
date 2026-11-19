class_name UiLedger
extends RefCounted
## The Ledger: a parchment book with two tabs, DEEDS (earned ones inked with their wax seal, secret ones "????") and
## REGULARS (each regular's arc so far: the lines already seen, then "..." for the chapter still to come). Opened from
## the title and the pause menu (TsScreen owns one). It reads game/data/deeds.json and regulars.json at call time and
## the player's `deeds` / `regulars` from the profile object, and shows an empty book when the logic has none.
## Pure data helpers are static and unit-tested; draw() paints onto a TsCanvas.

const DEEDS_PATH: String = "res://game/data/deeds.json"
const REGULARS_PATH: String = "res://game/data/regulars.json"
const BOOK := Rect2(60.0, 16.0, 520.0, 328.0)
const TAB_DEEDS: String = "deeds"
const TAB_REGULARS: String = "regulars"
const DEEDS_PER_PAGE: int = 12
const REGULARS_PER_PAGE: int = 6
const DEED_ROW_H: float = 38.0
const REG_ROW_H: float = 76.0
const COL_W: float = 248.0
const SEAL_PX: int = 20
const PORTRAIT_W: int = 32
const PORTRAIT_H: int = 40
const SECRET_NAME: String = "? ? ? ?"
const SEAL_COLS: Array[int] = [13, 12, 10, 7, 4]

static var force_deeds: Array = []  ## tests: used instead of the data file when not empty
static var force_regulars: Array = []
static var _ul_tex: Dictionary = {}

var tab: String = TAB_DEEDS
var page: int = 0
var age: float = 0.0
var earned: PackedStringArray = PackedStringArray()
var progress: Dictionary = {}  ## regular id -> chapters finished


# ---------------------------------------------------------------- data (pure)

static func _rows_of(raw: Variant, key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if raw is Dictionary and (raw as Dictionary).has(key):
		raw = (raw as Dictionary)[key]
	if raw is Array:
		for d: Variant in raw:
			if d is Dictionary and str((d as Dictionary).get("id", "")) != "":
				out.append(d as Dictionary)
	return out


static func deed_defs() -> Array[Dictionary]:
	return _rows_of(force_deeds if not force_deeds.is_empty() else UiOccult.read_json(DEEDS_PATH), "deeds")


static func regular_defs() -> Array[Dictionary]:
	return _rows_of(force_regulars if not force_regulars.is_empty() else UiOccult.read_json(REGULARS_PATH), "regulars")


## The deed ids a profile object has earned ("deeds" property), empty when it has none.
static func profile_deeds(p: Object) -> PackedStringArray:
	if p != null and "deeds" in p:
		return PackedStringArray(p.get("deeds"))
	return PackedStringArray()


## Chapters finished per regular ("regulars" property: {id: chapter_index}).
static func profile_regulars(p: Object) -> Dictionary:
	if p != null and "regulars" in p and p.get("regulars") is Dictionary:
		return (p.get("regulars") as Dictionary).duplicate()
	return {}


static func page_count(n: int, per: int) -> int:
	return maxi(1, (n + per - 1) / per)


## One deed row: {name, text, state}. state is "earned", "open" (known, not earned yet) or "secret" (hidden).
static func deed_row(def: Dictionary, earned_ids: PackedStringArray) -> Dictionary:
	var id: String = str(def.get("id", ""))
	var got: bool = earned_ids.has(id)
	var secret: bool = bool(def.get("secret", false))
	if got:
		return {"name": UiEngage.ascii_up(str(def.get("name", id))), "text": UiEngage.ascii_up(str(def.get("text", ""))), "state": "earned"}
	if secret:
		return {"name": SECRET_NAME, "text": "A SECRET DEED. IT WILL SHOW ITSELF.", "state": "secret"}
	return {"name": UiEngage.ascii_up(str(def.get("name", id))), "text": UiEngage.ascii_up(str(def.get("text", ""))), "state": "open"}


## One regular row: {met, name, chapter, total, lines (the lines already seen, in order)}.
static func regular_row(def: Dictionary, done: int) -> Dictionary:
	var chapters: Array = def.get("chapters", []) as Array if def.get("chapters") is Array else []
	var lines: Array[String] = []
	for i: int in range(mini(done, chapters.size())):
		if chapters[i] is Dictionary:
			lines.append(UiEngage.ascii_up(str((chapters[i] as Dictionary).get("line", ""))))
	return {"met": done > 0, "name": UiEngage.ascii_up(str(def.get("name", def.get("id", "")))), "chapter": mini(done, chapters.size()),
		"total": chapters.size(), "lines": lines}


## The seal and portrait textures: the art worker's SpriteKit ones when present, else drawn stand-ins.
static func seal_tex(id: String) -> ImageTexture:
	return _tex("seal:" + id, "deed_seal", id, SEAL_PX, SEAL_PX)


static func portrait_tex(id: String) -> ImageTexture:
	return _tex("port:" + id, "regular_portrait", id, PORTRAIT_W, PORTRAIT_H)


static func _tex(key: String, method: String, id: String, w: int, h: int) -> ImageTexture:
	if _ul_tex.has(key):
		return _ul_tex[key] as ImageTexture
	var tex: ImageTexture = null
	var sk: GDScript = load("res://game/room2d/sprite_kit.gd") as GDScript
	if sk != null and UiOccult.static_has(sk, method):
		tex = sk.call(method, id) as ImageTexture
	if tex == null:
		tex = _seal_stand_in(id) if w == SEAL_PX else _portrait_stand_in(id)
	_ul_tex[key] = tex
	return tex


## A wax seal: a lumpy disc in a colour from the id's hash, a pressed ring and a rune.
static func _seal_stand_in(id: String) -> ImageTexture:
	var pal: PackedColorArray = RoomPalette.colors()
	var h: int = id.hash() & 0x7FFFFFFF
	var col: int = SEAL_COLS[h % SEAL_COLS.size()]
	var img: Image = Image.create_empty(SEAL_PX, SEAL_PX, false, Image.FORMAT_RGBA8)
	for y: int in range(SEAL_PX):
		for x: int in range(SEAL_PX):
			var dx: float = float(x) - 9.5
			var dy: float = float(y) - 9.5
			var d: float = sqrt(dx * dx + dy * dy)
			var lump: float = 8.6 + 1.2 * sin(atan2(dy, dx) * 5.0 + float(h % 7))
			if d <= lump:
				var tone: Color = pal[col]
				if d > lump - 1.2:
					tone = pal[0]
				elif absf(d - 5.4) < 0.7:
					tone = pal[col].lightened(0.25)
				elif dx + dy < -5.0:
					tone = pal[col].lightened(0.12)
				img.set_pixel(x, y, tone)
	for k: int in range(-2, 3):
		if (h >> (k + 2)) & 1 == 1:
			img.set_pixel(10, 10 + k, pal[col].darkened(0.4))
		else:
			img.set_pixel(10 + k, 10, pal[col].darkened(0.4))
	return ImageTexture.create_from_image(img)


## A stand-in regular: a hooded bust in the dark, a bone face, two points of eye.
static func _portrait_stand_in(id: String) -> ImageTexture:
	var pal: PackedColorArray = RoomPalette.colors()
	var h: int = id.hash() & 0x7FFFFFFF
	var cloth: int = [3, 6, 12, 9, 2][h % 5]
	var img: Image = Image.create_empty(PORTRAIT_W, PORTRAIT_H, false, Image.FORMAT_RGBA8)
	for y: int in range(PORTRAIT_H):
		for x: int in range(PORTRAIT_W):
			var dx: float = float(x) - 15.5
			var shoulders: bool = y >= 26 and absf(dx) < 6.0 + float(y - 26) * 1.1
			var head: bool = (dx * dx) / 64.0 + (float(y - 15) * float(y - 15)) / 100.0 < 1.0
			var hood: bool = (dx * dx) / 110.0 + (float(y - 15) * float(y - 15)) / 160.0 < 1.0
			if shoulders:
				img.set_pixel(x, y, pal[cloth])
			elif head:
				img.set_pixel(x, y, pal[14] if y > 10 else pal[cloth])
			elif hood:
				img.set_pixel(x, y, pal[cloth].darkened(0.3))
	img.set_pixel(12, 16, pal[0])
	img.set_pixel(19, 16, pal[0])
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- state

## Reads the profile into the book and shows the first page of the first tab.
func open_from(p: Object) -> void:
	earned = profile_deeds(p)
	progress = profile_regulars(p)
	tab = TAB_DEEDS
	page = 0
	age = 0.0


func focus_ids() -> Array[String]:
	var out: Array[String] = ["ledger_tab_deeds", "ledger_tab_regulars"]
	if pages() > 1:
		out.append("ledger_prev")
		out.append("ledger_next")
	out.append("ledger_back")
	return out


func pages() -> int:
	if tab == TAB_DEEDS:
		return page_count(deed_defs().size(), DEEDS_PER_PAGE)
	return page_count(regular_defs().size(), REGULARS_PER_PAGE)


## Handles a tab or page button. True when `id` was one of them.
func activate(id: String) -> bool:
	match id:
		"ledger_tab_deeds":
			_set_tab(TAB_DEEDS)
		"ledger_tab_regulars":
			_set_tab(TAB_REGULARS)
		"ledger_prev":
			turn(-1)
		"ledger_next":
			turn(1)
		_:
			return false
	return true


func turn(dir: int) -> void:
	var n: int = clampi(page + dir, 0, pages() - 1)
	if n != page:
		page = n
		age = 0.0


func _set_tab(t: String) -> void:
	if t != tab:
		tab = t
		page = 0
		age = 0.0


# ---------------------------------------------------------------- drawing

func draw(c: TsCanvas, screen: TsScreen) -> void:
	c.dim(Rect2(Vector2.ZERO, ShopGame.VIEW), 10)
	c.frame(BOOK, "panel")
	var cx: float = BOOK.position.x + BOOK.size.x * 0.5
	var defs: Array[Dictionary] = deed_defs()
	c.head_c(cx, BOOK.position.y + 8.0, "LEDGER OF DEEDS" if tab == TAB_DEEDS else "THE REGULARS", 11, 2)
	_tab_button(c, screen, "ledger_tab_deeds", Rect2(BOOK.position.x + 14.0, BOOK.position.y + 12.0, 76.0, 18.0), "DEEDS", tab == TAB_DEEDS)
	_tab_button(c, screen, "ledger_tab_regulars", Rect2(BOOK.end.x - 90.0, BOOK.position.y + 12.0, 76.0, 18.0), "REGULARS", tab == TAB_REGULARS)
	var sub: String
	if tab == TAB_DEEDS:
		var got: int = 0
		for d: Dictionary in defs:
			if earned.has(str(d["id"])):
				got += 1
		sub = "%d OF %d DEEDS EARNED" % [got, defs.size()]
	else:
		var met: int = 0
		for rd: Dictionary in regular_defs():
			if int(progress.get(str(rd["id"]), 0)) > 0:
				met += 1
		sub = "%d OF %d REGULARS MET" % [met, regular_defs().size()]
	c.text_c(cx, BOOK.position.y + 38.0, sub, 14)
	var paper := Rect2(BOOK.position.x + 14.0, BOOK.position.y + 50.0, BOOK.size.x - 28.0, 232.0)
	c.frame(paper, "note")
	c.fill(Rect2(paper.position.x + paper.size.x * 0.5 - 1.0, paper.position.y + 6.0, 1.0, paper.size.y - 12.0), 10)  # the gutter
	if tab == TAB_DEEDS:
		_draw_deeds(c, paper, defs)
	else:
		_draw_regulars(c, paper)
	var by: float = BOOK.end.y - 34.0
	if pages() > 1:
		c.button("ledger_prev", Rect2(BOOK.position.x + 14.0, by, 64.0, 20.0), "< PREV", page > 0)
		c.button("ledger_next", Rect2(BOOK.end.x - 78.0, by, 64.0, 20.0), "NEXT >", page < pages() - 1)
		c.text_c(cx + 100.0, by + 6.0, "PAGE %d OF %d" % [page + 1, pages()], 14, 1)
	var back := Rect2(cx - 44.0, by, 88.0, 20.0)
	c.button("ledger_back", back, "BACK [ESC]", true, true)
	if screen.focus_id != "":
		_flame_for(c, screen, back)


func _flame_for(c: TsCanvas, screen: TsScreen, back: Rect2) -> void:
	if screen.focus_id == "ledger_back":
		c.cursor_flame(Vector2(back.position.x - 14.0, back.position.y + 6.0))
	for w: Dictionary in c.widgets:
		if str(w["id"]) == screen.focus_id and screen.focus_id != "ledger_back":
			var r: Rect2 = w["rect"] as Rect2
			c.cursor_flame(Vector2(r.position.x - 14.0, r.position.y + 5.0))


func _tab_button(c: TsCanvas, _screen: TsScreen, id: String, rect: Rect2, label: String, on: bool) -> void:
	c.button(id, rect, label, true, on)


func _draw_deeds(c: TsCanvas, paper: Rect2, defs: Array[Dictionary]) -> void:
	var first: int = page * DEEDS_PER_PAGE
	for i: int in range(DEEDS_PER_PAGE):
		var n: int = first + i
		if n >= defs.size():
			break
		var u: float = UiMotion.ui_out((age - 0.05 * float(i)) / 0.25)
		if u <= 0.0:
			continue
		var def: Dictionary = defs[n]
		var row: Dictionary = deed_row(def, earned)
		var x: float = paper.position.x + 10.0 + float(i / 6) * COL_W
		var y: float = paper.position.y + 8.0 + float(i % 6) * DEED_ROW_H + floorf((1.0 - u) * 8.0)
		var state: String = str(row["state"])
		var seal := Rect2(x, y + 4.0, float(SEAL_PX), float(SEAL_PX))
		if state == "earned":
			var pop: float = UiMotion.ui_back((age - 0.05 * float(i) - 0.1) / 0.25)
			var grown: float = float(SEAL_PX) * clampf(pop, 0.0, 1.2)
			c.draw_texture_rect(seal_tex(str(def["id"])), Rect2(seal.get_center() - Vector2(grown, grown) * 0.5, Vector2(grown, grown)), false)
		else:
			c.draw_rect(seal.grow(-1.0), c.c(10), false, 1.0)  # an empty ring where the seal will go
			c.fill(Rect2(seal.position.x + 9.0, seal.position.y + 6.0, 2.0, 6.0), 10)
			c.fill(Rect2(seal.position.x + 9.0, seal.position.y + 14.0, 2.0, 2.0), 10)
		var ink: int = 0 if state == "earned" else (9 if state == "open" else 10)
		c.text(Vector2(x + 28.0, y + 5.0), str(row["name"]), 12 if state == "earned" else ink, 1, false)
		var lines: PackedStringArray = UiPixelFont.ui_wrap(str(row["text"]), int(COL_W) - 44)
		for k: int in range(mini(lines.size(), 2)):
			c.text(Vector2(x + 28.0, y + 16.0 + float(k * UiPixelFont.LINE_H)), lines[k], ink, 1, false)
		if i % 6 != 5:
			c.fill(Rect2(x, y + DEED_ROW_H - 3.0, COL_W - 20.0, 1.0), 10)


func _draw_regulars(c: TsCanvas, paper: Rect2) -> void:
	var defs: Array[Dictionary] = regular_defs()
	var first: int = page * REGULARS_PER_PAGE
	if defs.is_empty():
		c.text_c(paper.position.x + paper.size.x * 0.5, paper.position.y + 100.0, "NOBODY HAS COME BACK YET.", 9)
		return
	for i: int in range(REGULARS_PER_PAGE):
		var n: int = first + i
		if n >= defs.size():
			break
		var u: float = UiMotion.ui_out((age - 0.08 * float(i)) / 0.25)
		if u <= 0.0:
			continue
		var def: Dictionary = defs[n]
		var row: Dictionary = regular_row(def, int(progress.get(str(def["id"]), 0)))
		var x: float = paper.position.x + 10.0 + float(i / 3) * COL_W
		var y: float = paper.position.y + 6.0 + float(i % 3) * REG_ROW_H + floorf((1.0 - u) * 8.0)
		var met: bool = bool(row["met"])
		var pr := Rect2(x, y + 2.0, float(PORTRAIT_W), float(PORTRAIT_H))
		c.fill(pr.grow(2.0), 0)
		c.draw_texture_rect(portrait_tex(str(def["id"])), pr, false, Color.WHITE if met else c.c(2))
		if not met:
			c.fill(Rect2(pr.position.x + 12.0, pr.position.y + 12.0, 8.0, 2.0), 3)
		var nx: float = x + 42.0
		c.text(Vector2(nx, y + 3.0), str(row["name"]) if met else "A STRANGER", 12 if met else 10, 1, false)
		var total: int = int(row["total"])
		var tag: String = "CHAPTER %d OF %d" % [int(row["chapter"]), total] if met else "NOT MET YET"
		c.text(Vector2(nx, y + 13.0), tag, 8 if met else 10, 1, false)
		var seen: Array = row["lines"] as Array
		if met and not seen.is_empty():
			var last: String = str(seen[seen.size() - 1])
			var wrapped: PackedStringArray = UiPixelFont.ui_wrap(last, int(COL_W) - 62)
			for k: int in range(mini(wrapped.size(), 3)):
				var ln: String = wrapped[k]
				if k == 2 and wrapped.size() > 3:
					ln = ln.substr(0, maxi(ln.length() - 2, 1)) + ".."
				c.text(Vector2(nx, y + 25.0 + float(k * UiPixelFont.LINE_H)), ln, 0, 1, false)
			if int(row["chapter"]) < total:
				var dots: String = "..." if fmod(c.t, 1.6) < 1.1 else ".."
				c.text(Vector2(nx, y + 25.0 + float(mini(wrapped.size(), 3) * UiPixelFont.LINE_H)), "NEXT: " + dots, 9, 1, false)
			else:
				c.text(Vector2(nx, y + 58.0), "THE END.", 12, 1, false)
		elif met:
			c.text(Vector2(nx, y + 25.0), "...", 9, 1, false)
		if i % 3 != 2:
			c.fill(Rect2(x, y + REG_ROW_H - 4.0, COL_W - 20.0, 1.0), 10)
