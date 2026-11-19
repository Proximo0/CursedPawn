class_name UiJournalPages
extends RefCounted
## The journal's pages beyond the deeds and regulars: GRIMOIRE (spells known), CURIOS (the four sets), BESTIARY (curses
## identified, customers met) and RUNS (the last 20 runs, each with a replay-seed button). Pure row builders (tested) and
## draw methods that paint onto a TsCanvas inside the journal's paper rectangle.

const SPELLS_PER_PAGE: int = 6
const CURIOS_PER_PAGE: int = 2
const BEAST_PER_PAGE: int = 12
const RUNS_PER_PAGE: int = 5
const RUN_ROW_H: float = 42.0


## Spell rows: {id, name, text, dread, known}.
static func spell_rows(known: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in UiOccult.spell_defs():
		var id: String = str(d.get("id", ""))
		out.append({"id": id, "name": str(d.get("name", id)).to_upper(), "text": str(d.get("text", "")), "dread": float(d.get("dread", 0.0)),
			"known": known.has(id)})
	return out


## Curio set rows: {set, header, have, total, items: [{id, name, owned}]}.
static func curio_rows(owned: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var curios: Array[Dictionary] = UiOccult.curio_defs()
	var groups: Dictionary = UiOccult.set_groups(curios, owned)
	for s: Variant in groups.keys():
		var g: Dictionary = groups[s] as Dictionary
		var items: Array[Dictionary] = []
		for id: Variant in g["ids"] as Array:
			items.append({"id": str(id), "name": str(UiOccult.curio_def(str(id)).get("name", id)).to_upper(), "owned": int(owned.get(str(id), 0)) > 0})
		out.append({"set": str(s), "header": UiOccult.set_header(str(s), int(g["have"]), int(g["total"])), "have": int(g["have"]),
			"total": int(g["total"]), "items": items})
	return out


## Bestiary rows: curses then customers: {kind, id, name, text, known}. Unknown ones carry no name or text.
static func beast_rows(cat: Catalog, log: UiJournalLog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in cat.curses:
		var id: String = str(c["id"])
		var known: bool = log.curses.has(id)
		var tells: Array = (c.get("tells", {}) as Dictionary).values()
		out.append({"kind": "curse", "id": id, "name": str(c["name"]).to_upper() if known else "? ? ? ?",
			"text": ("DREAD %s. %s" % [str(c.get("dread", 1.0)), str(tells[0]) if not tells.is_empty() else ""]).to_upper() if known else "NOT YET IDENTIFIED.",
			"known": known})
	for t: Dictionary in cat.customers:
		var id: String = str(t["id"])
		var met: bool = log.customers.has(id)
		out.append({"kind": "customer", "id": id, "name": str(t.get("name", id)).to_upper() if met else "? ? ? ?",
			"text": str(t.get("line", "")).to_upper() if met else "NOT YET MET.", "known": met})
	return out


## "#3  SEED 17  H2  THE MOTH" and "NIGHT 5. 120 COINS. DEBT FREE" for a run entry.
static func run_lines(e: Dictionary) -> PackedStringArray:
	var head: String = "#%d  SEED %d  HAUNTING %d" % [int(e.get("n", 0)), int(e.get("seed", 0)), int(e.get("haunting", 0))]
	if str(e.get("omen_name", "")) != "":
		head += "  " + UiEngage.ascii_up(str(e["omen_name"]))
	if bool(e.get("daily", false)):
		head += "  DAILY"
	var tail: String = "NIGHT %d, %d COINS. " % [int(e.get("nights", 0)), int(e.get("cash", 0))]
	if bool(e.get("won", false)):
		tail += str(UiEndings.info(str(e.get("ending", "debt_free")))["title"]) if UiEndings.IDS.has(str(e.get("ending", ""))) else "SURVIVED"
	else:
		tail += "THE SHOP WAS LOST"
	return PackedStringArray([head, tail])


static func pages_for(tab: String, n: int) -> int:
	var per: int = {"grimoire": SPELLS_PER_PAGE, "curios": CURIOS_PER_PAGE, "bestiary": BEAST_PER_PAGE, "runs": RUNS_PER_PAGE}.get(tab, 1)
	return UiLedger.page_count(n, per)


# ---------------------------------------------------------------- drawing

static func draw_grimoire(c: TsCanvas, paper: Rect2, known: PackedStringArray, age: float, page: int) -> void:
	var rows: Array[Dictionary] = spell_rows(known)
	for i: int in range(SPELLS_PER_PAGE):
		var n: int = page * SPELLS_PER_PAGE + i
		if n >= rows.size():
			break
		var r: Dictionary = rows[n]
		var u: float = UiMotion.ui_out((age - 0.06 * float(i)) / 0.25)
		if u <= 0.0:
			continue
		var x: float = paper.position.x + 10.0 + float(i / 3) * UiLedger.COL_W
		var y: float = paper.position.y + 8.0 + float(i % 3) * 72.0 + floorf((1.0 - u) * 8.0)
		var kn: bool = bool(r["known"])
		var icon: ImageTexture = SpriteKit.spell_icon(str(r["id"]))
		c.draw_texture_rect(icon, Rect2(x, y + 2.0, 32.0, 32.0), false, Color.WHITE if kn else c.c(2))
		c.text(Vector2(x + 40.0, y + 3.0), str(r["name"]) if kn else "? ? ? ?", 12 if kn else 10, 1, false)
		c.text(Vector2(x + 40.0, y + 13.0), "DREAD +%s" % str(snappedf(float(r["dread"]), 0.1)) if kn else "A TORN PAGE HOLDS IT", 8 if kn else 10, 1, false)
		var lines: PackedStringArray = UiPixelFont.ui_wrap(str(r["text"]).to_upper() if kn else "FIND ITS PAGE ON A RUN.", int(UiLedger.COL_W) - 62)
		for k: int in range(mini(lines.size(), 4)):
			c.text(Vector2(x + 40.0, y + 25.0 + float(k * UiPixelFont.LINE_H)), lines[k], 0 if kn else 10, 1, false)


static func draw_curios(c: TsCanvas, paper: Rect2, owned: Dictionary, age: float, page: int) -> void:
	var rows: Array[Dictionary] = curio_rows(owned)
	if rows.is_empty():
		c.text_c(paper.position.x + paper.size.x * 0.5, paper.position.y + 100.0, "NO CURIOS YET.", 9)
		return
	for i: int in range(CURIOS_PER_PAGE):
		var n: int = page * CURIOS_PER_PAGE + i
		if n >= rows.size():
			break
		var r: Dictionary = rows[n]
		var x: float = paper.position.x + 10.0 + float(i) * UiLedger.COL_W
		var y: float = paper.position.y + 8.0
		c.text(Vector2(x, y), str(r["header"]), 12 if int(r["have"]) >= int(r["total"]) and int(r["total"]) > 0 else 0, 1, false)
		c.fill(Rect2(x, y + 11.0, UiLedger.COL_W - 24.0, 1.0), 10)
		var items: Array = r["items"] as Array
		for k: int in range(mini(items.size(), 14)):
			var it: Dictionary = items[k] as Dictionary
			var yy: float = y + 16.0 + float(k) * 14.5
			c.fill(Rect2(x, yy + 1.0, 5.0, 5.0), 11 if bool(it["owned"]) else 3)
			c.text(Vector2(x + 10.0, yy), str(it["name"]) if bool(it["owned"]) else "? ? ? ?", 0 if bool(it["owned"]) else 10, 1, false)


static func draw_bestiary(c: TsCanvas, paper: Rect2, rows: Array[Dictionary], age: float, page: int) -> void:
	var first: int = page * BEAST_PER_PAGE
	for i: int in range(BEAST_PER_PAGE):
		var n: int = first + i
		if n >= rows.size():
			break
		var r: Dictionary = rows[n]
		var x: float = paper.position.x + 10.0 + float(i / 6) * UiLedger.COL_W
		var y: float = paper.position.y + 8.0 + float(i % 6) * 36.0
		var kn: bool = bool(r["known"])
		var cursed: bool = str(r["kind"]) == "curse"
		c.fill(Rect2(x, y + 2.0, 5.0, 5.0), (13 if cursed else 7) if kn else 3)
		c.text(Vector2(x + 10.0, y), str(r["name"]), 12 if kn else 10, 1, false)
		var lines: PackedStringArray = UiPixelFont.ui_wrap(str(r["text"]), int(UiLedger.COL_W) - 40)
		for k: int in range(mini(lines.size(), 2)):
			c.text(Vector2(x + 10.0, y + 11.0 + float(k * UiPixelFont.LINE_H)), lines[k], 0 if kn else 10, 1, false)


## Run rows with their replay buttons; ids "run_replay:<index into runs>".
static func draw_runs(c: TsCanvas, paper: Rect2, runs: Array[Dictionary], age: float, page: int) -> void:
	if runs.is_empty():
		c.text_c(paper.position.x + paper.size.x * 0.5, paper.position.y + 100.0, "NO RUNS YET. THE SHOP IS WAITING.", 9)
		return
	for i: int in range(RUNS_PER_PAGE):
		var n: int = page * RUNS_PER_PAGE + i
		if n >= runs.size():
			break
		var e: Dictionary = runs[n]
		var y: float = paper.position.y + 6.0 + float(i) * RUN_ROW_H
		var lines: PackedStringArray = run_lines(e)
		c.fill(Rect2(paper.position.x + 12.0, y + 4.0, 6.0, 6.0), 7 if bool(e.get("won", false)) else 13)
		c.text(Vector2(paper.position.x + 24.0, y + 3.0), lines[0], 0, 1, false)
		c.text(Vector2(paper.position.x + 24.0, y + 15.0), lines[1], 9, 1, false)
		c.button("run_replay:%d" % n, Rect2(paper.end.x - 112.0, y + 5.0, 100.0, 17.0), "REPLAY SEED", true)
		c.fill(Rect2(paper.position.x + 12.0, y + RUN_ROW_H - 5.0, paper.size.x - 24.0, 1.0), 10)
