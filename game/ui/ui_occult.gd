class_name UiOccult
extends RefCounted
## Pure helpers for the occult round's UI: spell definitions (game/data/spells.json, with a built-in fallback so the UI
## runs before the logic worker's data lands), the spell bar's key map and odds hint, the wheel's spin maths, the
## Tarot Pairs grid maths and the curio set groups. No nodes, no clock, no global random. Calls into logic that may not
## exist yet go through `has_prop` / `static_has` so the game still runs on older logic.

const PHASE_TABLE: String = "table"
const SPELLS_PATH: String = "res://game/data/spells.json"
const TABLE_PATH: String = "res://game/data/table.json"
const CURIOS_PATH: String = "res://game/data/curios.json"
const SPELL_IDS: PackedStringArray = ["scry", "hex", "glamour", "banish", "summon", "seal"]
const SPELL_KEYS: Array[int] = [KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
const SET_IDS: PackedStringArray = ["parlor", "attic", "cellar", "chapel"]
const PAIRS_COLS: int = 5
const PAIRS_ROWS: int = 2
const FALLBACK_SPELLS: Array = [
	{"id": "scry", "name": "Scry", "dread": 0.5, "text": "An eye opens and shows a tell the tools have not found.", "backfire": "The eye looks back."},
	{"id": "hex", "name": "Hex", "dread": 0.8, "text": "Chains settle on the seller. Their reserve drops.", "backfire": "The chains find your wrist."},
	{"id": "glamour", "name": "Glamour", "dread": 0.6, "text": "The object shines. A buyer will pay more.", "backfire": "It shines, then it stares."},
	{"id": "banish", "name": "Banish", "dread": 1.0, "text": "Send one held object away. Its curse goes too.", "backfire": "It goes. Something else arrives."},
	{"id": "summon", "name": "Summon", "dread": 0.9, "text": "The next customer wants what you choose.", "backfire": "Someone else answers the call."},
	{"id": "seal", "name": "Seal", "dread": 1.2, "text": "A circle holds the rent debt at bay for the night.", "backfire": "The circle holds you in."},
]
const FALLBACK_WHEEL: Array = [
	{"id": "ash", "name": "Ash", "weight": 30, "mult": 0.0, "dread": 0.0, "prize": ""},
	{"id": "coin", "name": "Coin", "weight": 25, "mult": 1.5, "dread": 0.0, "prize": ""},
	{"id": "bone", "name": "Bone", "weight": 20, "mult": 0.5, "dread": 0.0, "prize": ""},
	{"id": "eye", "name": "Eye", "weight": 12, "mult": 2.0, "dread": 0.3, "prize": ""},
	{"id": "page", "name": "Page", "weight": 8, "mult": 0.0, "dread": 0.2, "prize": "page"},
	{"id": "curio", "name": "Curio", "weight": 5, "mult": 0.0, "dread": 0.4, "prize": "curio"},
]
const SET_NAMES: Dictionary = {"parlor": "PARLOR", "attic": "ATTIC", "cellar": "CELLAR", "chapel": "CHAPEL"}
const RARITY_COL: Dictionary = {"common": 14, "rare": 4, "legendary": 11}
static var _uo_cache: Dictionary = {}
static var force_found: Array = []  ## sheets and tests: pretend the run found these
static var force_known: PackedStringArray = PackedStringArray()  ## sheets and tests: pretend the run knows these spells


# ---------------------------------------------------------------- guarded access to logic that may not exist yet

static func has_prop(obj: Object, prop: String) -> bool:
	return obj != null and prop in obj


static func static_has(script: GDScript, method: String) -> bool:
	for m: Dictionary in script.get_script_method_list():
		if str(m["name"]) == method:
			return true
	return false


static func read_json(path: String) -> Variant:
	if _uo_cache.has(path):
		return _uo_cache[path]
	var out: Variant = null
	if FileAccess.file_exists(path):
		out = JSON.parse_string(FileAccess.get_file_as_string(path))
	_uo_cache[path] = out
	return out


# ---------------------------------------------------------------- spells

static func spell_defs() -> Array[Dictionary]:
	var src: Variant = read_json(SPELLS_PATH)
	var raw: Array = src as Array if src is Array else FALLBACK_SPELLS
	var out: Array[Dictionary] = []
	for id: String in SPELL_IDS:
		var found: Dictionary = {}
		for d: Variant in raw:
			if d is Dictionary and str((d as Dictionary).get("id", "")) == id:
				found = d as Dictionary
		if found.is_empty():
			for d: Dictionary in FALLBACK_SPELLS:
				if str(d["id"]) == id:
					found = d
		out.append(found)
	return out


static func spell_def(id: String) -> Dictionary:
	for d: Dictionary in spell_defs():
		if str(d["id"]) == id:
			return d
	return {}


## The spell ids a run knows, in bar order. Reads run.spells_known; before the logic lands, the two starters.
static func known_spells(r: RunState) -> PackedStringArray:
	var src: PackedStringArray = PackedStringArray(["scry", "hex"])
	if not force_known.is_empty():
		src = force_known
	elif has_prop(r, "spells_known"):
		src = PackedStringArray(r.get("spells_known"))
	var out := PackedStringArray()
	for id: String in SPELL_IDS:
		if src.has(id):
			out.append(id)
	return out


## The spell a key press means (KEY_5..KEY_0), "" for none. Only known spells answer.
static func spell_for_key(key: int, known: PackedStringArray) -> String:
	var at: int = SPELL_KEYS.find(key)
	if at < 0 or not known.has(SPELL_IDS[at]):
		return ""
	return SPELL_IDS[at]


static func key_label(id: String) -> String:
	var at: int = SPELL_IDS.find(id)
	return "" if at < 0 else str((at + 5) % 10)


static func cast_command(id: String, uid: int = -1) -> Dictionary:
	var cmd: Dictionary = {"t": "cast", "spell": id}
	if uid >= 0:
		cmd["uid"] = uid
	return cmd


static func needs_item(id: String) -> bool:
	return id == "banish"


static func casts_left(r: RunState) -> int:
	return int(r.get("casts_left")) if has_prop(r, "casts_left") else 2


static func dread_cost(id: String) -> float:
	return float(spell_def(id).get("dread", 0.0))


## Spells answer only in the customer phase, with a customer at the counter and casts left tonight.
static func spells_enabled(r: RunState) -> bool:
	return r.phase == RunState.PHASE_CUSTOMER and not r.customer.is_empty() and casts_left(r) > 0


## Backfire odds shown on the bar, 0..95 percent: base plus a share per Dread point (Tuning fields when present).
static func backfire_pct(r: RunState, id: String) -> int:
	var base: float = float(r.tuning.get("spell_backfire_base")) if has_prop(r.tuning, "spell_backfire_base") else 0.06
	var per: float = float(r.tuning.get("spell_backfire_per_dread")) if has_prop(r.tuning, "spell_backfire_per_dread") else 0.05
	return clampi(int(round((base + per * r.dread) * 100.0)), 0, 95)


static func dread_text(v: float) -> String:
	return "+%d" % int(round(v)) if absf(v - round(v)) < 0.05 else "+%.1f" % v


# ---------------------------------------------------------------- table

static func in_table(r: RunState) -> bool:
	return r.phase == PHASE_TABLE


static func wheel_segments() -> Array[Dictionary]:
	var src: Variant = read_json(TABLE_PATH)
	var raw: Array = FALLBACK_WHEEL
	if src is Dictionary and (src as Dictionary).get("wheel") is Array and not ((src as Dictionary)["wheel"] as Array).is_empty():
		raw = (src as Dictionary)["wheel"] as Array
	var out: Array[Dictionary] = []
	for d: Variant in raw:
		out.append(d as Dictionary)
	return out


## Start angle (radians, clockwise from 12 o'clock) of each wheel segment, plus the end as the last element.
static func wheel_edges(segs: Array[Dictionary]) -> PackedFloat32Array:
	var total: float = 0.0
	for s: Dictionary in segs:
		total += maxf(float(s.get("weight", 1.0)), 0.01)
	var out := PackedFloat32Array([0.0])
	var acc: float = 0.0
	for s: Dictionary in segs:
		acc += maxf(float(s.get("weight", 1.0)), 0.01)
		out.append(TAU * acc / total)
	return out


## Which segment an event names: by id, then name, then index. -1 when unknown.
static func wheel_index(segs: Array[Dictionary], ev: Dictionary) -> int:
	var seg: Variant = ev.get("segment", -1)
	for i: int in range(segs.size()):
		if seg is String and (str(segs[i].get("id", "")) == seg or str(segs[i].get("name", "")) == seg):
			return i
	if (seg is int or seg is float) and int(seg) >= 0 and int(seg) < segs.size():
		return int(seg)
	for i: int in range(segs.size()):
		if str(segs[i].get("name", "")) == str(ev.get("name", "\u0001")):
			return i
	return -1


## The wheel's rotation (radians) u seconds-fraction into a spin that ends with segment `target` centred under the
## pointer: several fast turns that slow to a crawl (ease out quartic).
static func wheel_angle(u: float, edges: PackedFloat32Array, target: int, turns: int = 4, from: float = 0.0) -> float:
	var mid: float = (edges[target] + edges[target + 1]) * 0.5
	var span: float = TAU * float(turns) + fposmod((TAU - mid) - from, TAU)
	var k: float = 1.0 - clampf(u, 0.0, 1.0)
	return from + span * (1.0 - k * k * k * k)


## Index of the segment under the pointer (12 o'clock) for a wheel rotated by angle.
static func wheel_under(edges: PackedFloat32Array, angle: float) -> int:
	var a: float = fposmod(TAU - fposmod(angle, TAU), TAU)
	for i: int in range(edges.size() - 1):
		if a >= edges[i] and a < edges[i + 1]:
			return i
	return 0


# ---------------------------------------------------------------- Tarot Pairs

## A card flip: the card's width factor 0..1..0 across u 0..1 and whether the face shows (second half).
static func flip_width(u: float) -> float:
	return absf(cos(clampf(u, 0.0, 1.0) * PI))


static func flip_face_up(u: float) -> bool:
	return u >= 0.5


## Top-left of grid cell i (row-major, PAIRS_COLS wide) inside a grid whose top-left is origin.
static func pairs_cell(origin: Vector2, i: int, cell: Vector2) -> Vector2:
	return origin + Vector2(float(i % PAIRS_COLS) * cell.x, float(i / PAIRS_COLS) * cell.y)


static func pairs_index_at(origin: Vector2, p: Vector2, cell: Vector2, count: int) -> int:
	var q: Vector2 = p - origin
	if q.x < 0.0 or q.y < 0.0:
		return -1
	var cx: int = int(q.x / cell.x)
	var cy: int = int(q.y / cell.y)
	var i: int = cy * PAIRS_COLS + cx
	return i if cx < PAIRS_COLS and cy < PAIRS_ROWS and i < count else -1


## A horizontal shudder offset for a missed card, dying away over u 0..1.
static func shudder(u: float) -> float:
	return roundf(sin(u * 38.0) * 3.0 * (1.0 - clampf(u, 0.0, 1.0)))


# ---------------------------------------------------------------- curios

static func curio_defs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var src: Variant = read_json(CURIOS_PATH)
	if src is Array:
		for d: Variant in src:
			out.append(d as Dictionary)
	return out


static func curio_def(id: String) -> Dictionary:
	for d: Dictionary in curio_defs():
		if str(d.get("id", "")) == id:
			return d
	return {}


## {set: {"have": n, "total": n, "ids": [...]}} for the four sets, in SET_IDS order, from owned (id -> copies).
static func set_groups(curios: Array[Dictionary], owned: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for s: String in SET_IDS:
		out[s] = {"have": 0, "total": 0, "ids": []}
	for c: Dictionary in curios:
		var s: String = str(c.get("set", ""))
		if not out.has(s):
			out[s] = {"have": 0, "total": 0, "ids": []}
		var g: Dictionary = out[s] as Dictionary
		g["total"] = int(g["total"]) + 1
		(g["ids"] as Array).append(str(c["id"]))
		if int(owned.get(str(c["id"]), 0)) > 0:
			g["have"] = int(g["have"]) + 1
	return out


static func set_header(set_name: String, have: int, total: int) -> String:
	return "%s SET  %d/%d%s" % [str(SET_NAMES.get(set_name, set_name.to_upper())), have, total, "  COMPLETE" if total > 0 and have >= total else ""]


## The run's finds ({kind, id} dictionaries): run.found, or force_found in sheets.
static func run_finds(r: RunState) -> Array:
	if not force_found.is_empty():
		return force_found
	return r.get("found") as Array if has_prop(r, "found") else []


## What a run found, as display rows {kind, id, name, text, col} (names from the events or the data files).
static func find_rows(found: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Variant in found:
		var d: Dictionary = f as Dictionary
		var kind: String = str(d.get("kind", ""))
		var id: String = str(d.get("id", ""))
		var def: Dictionary = spell_def(id) if kind == "page" else curio_def(id)
		var nm: String = str(d.get("name", def.get("name", id)))
		var col: int = 11 if kind == "page" else int(RARITY_COL.get(str(def.get("rarity", "common")), 14))
		out.append({"kind": kind, "id": id, "name": nm, "text": str(def.get("text", "")), "col": col})
	return out


static func found_line(rows: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for r: Dictionary in rows:
		parts.append(("PAGE: " if str(r["kind"]) == "page" else "") + str(r["name"]).to_upper())
	return ", ".join(parts)


static func whisper_text(kind: String) -> String:
	return "A PAGE RUSTLES INSIDE IT..." if kind == "page" else "SOMETHING GLINTS INSIDE IT..."


# ---------------------------------------------------------------- log lines for the occult events

const OCCULT_EVENTS: PackedStringArray = ["cast", "scry_reveal", "hexed", "glamoured", "banished", "summoned", "sealed", "backfire",
	"found_hint", "found", "table_open", "dice", "hand_card", "hand_end", "pairs_deal", "pairs_flip", "pairs_match", "pairs_miss",
	"pairs_end", "wheel", "item_staked", "lot", "table_leave"]


## The ledger line for an occult event, "" when it has none (animations carry it). Only for events in OCCULT_EVENTS.
static func event_text(e: Dictionary) -> String:
	match str(e.get("e", "")):
		"cast":
			if not bool(e.get("ok", true)):
				return ""
			return "%s%s" % [str(e.get("text", "")) if str(e.get("text", "")) != "" else "You cast %s." % str(e.get("spell", "?")),
				"  (Dread +%.1f)" % float(e["dread"]) if float(e.get("dread", 0.0)) > 0.0 else ""]
		"backfire":
			return "BACKFIRE: %s" % str(e.get("text", str(e.get("kind", "?"))))
		"scry_reveal":
			return "The eye shows: %s" % str(e.get("tell", "nothing"))
		"hexed":
			return "Hexed. Their price drops to %d." % int(e.get("ask", 0))
		"glamoured":
			return "The next sale shines x%.1f." % float(e.get("mult", 1.0))
		"banished":
			return "%s is gone, and the room is lighter." % str(e.get("name", "It"))
		"summoned":
			return "Someone who wants %s is on the way." % str(e.get("category", "something"))
		"sealed":
			return "A circle of salt holds the rent at bay."
		"found_hint":
			return UiOccult.whisper_text(str(e.get("kind", ""))).capitalize()
		"found":
			return "FOUND: %s." % str(e.get("name", "something"))
		"table_open":
			return "The Midnight Table opens. %d games, %d lots." % [int(e.get("games_left", 0)), int(e.get("lots_left", 0))]
		"dice":
			return "Dice: %d and %d. %s" % [int(e.get("d1", 0)), int(e.get("d2", 0)), "You win." if bool(e.get("win", false)) else "The house wins."]
		"hand_end":
			return "Hand: you %d, house %d. %s" % [int(e.get("you", 0)), int(e.get("house", 0)), "You win." if bool(e.get("win", false)) else "The house wins."]
		"pairs_end":
			return "Pairs: %d found, payout %d." % [int(e.get("matches", 0)), int(e.get("payout", 0))]
		"wheel":
			return "The wheel stops on %s. Payout %d." % [str(e.get("name", "?")), int(e.get("payout", 0))]
		"item_staked":
			return "%s %s." % [str(e.get("name", "Item")), "pays double" if bool(e.get("win", false)) else "stays with the house"]
		"lot":
			return "Sealed lot: %s for %d." % [str(e.get("name", "?")), int(e.get("price", 0))]
	return ""
