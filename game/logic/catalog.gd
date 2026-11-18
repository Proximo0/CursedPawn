class_name Catalog
extends RefCounted
## Object and curse definitions. Placeholder content until the content rounds; data in game/data/*.json.
## objects: {id, name, category, value}. curses: {id, name, dread, sale_mult, imposter_every, tells: {tool: text}}.

const TOOLS: PackedStringArray = ["uv", "scale", "listen", "touch"]
const OBJECTS_PATH: String = "res://game/data/objects.json"
const CURSES_PATH: String = "res://game/data/curses.json"
const TAROT_PATH: String = "res://game/data/tarot.json"
const CUSTOMERS_PATH: String = "res://game/data/customers.json"

var objects: Array[Dictionary] = []
var curses: Array[Dictionary] = []
var tarot: Array[Dictionary] = []  ## {id, name, weight, mult, dread, text}: the tarot wager deck
## Customer types: {id, name, kind (seller|buyer), weight, line}; sellers add patience and reserve_mult, buyers
## pay_mult and optional cursed_mult (applied to cursed items only).
var customers: Array[Dictionary] = []


static func load_default() -> Catalog:
	var c := Catalog.new()
	c.objects = _catalog_read(OBJECTS_PATH)
	c.curses = _catalog_read(CURSES_PATH)
	c.tarot = _catalog_read(TAROT_PATH)
	c.customers = _catalog_read(CUSTOMERS_PATH)
	return c


static func _catalog_read(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		for d: Variant in parsed:
			if d is Dictionary:
				out.append(d)
	return out


func curse(id: String) -> Dictionary:
	for c: Dictionary in curses:
		if c["id"] == id:
			return c
	return {}


## Customer types of one kind ("seller" or "buyer").
func customer_types(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in customers:
		if str(t.get("kind", "")) == kind:
			out.append(t)
	return out


func categories() -> PackedStringArray:
	var out := PackedStringArray()
	for o: Dictionary in objects:
		if not out.has(str(o["category"])):
			out.append(str(o["category"]))
	return out


## Expected payout per coin staked on a tarot wager (below 1 = the house wins on average).
func tarot_return() -> float:
	var total: float = 0.0
	var paid: float = 0.0
	for card: Dictionary in tarot:
		total += float(card["weight"])
		paid += float(card["weight"]) * float(card["mult"])
	return paid / total if total > 0.0 else 0.0


## Data problems, one line each. Empty when the catalog is usable. Every curse needs at least one tell.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if objects.is_empty():
		out.append("no objects")
	if curses.is_empty():
		out.append("no curses")
	var ids: Dictionary = {}
	for o: Dictionary in objects:
		for key: String in ["id", "name", "category", "value"]:
			if not o.has(key):
				out.append("object %s missing %s" % [o.get("id", "?"), key])
		if float(o.get("value", 0.0)) <= 0.0:
			out.append("object %s has no value" % o.get("id", "?"))
		if ids.has(o.get("id", "")):
			out.append("duplicate id %s" % o.get("id", ""))
		ids[o.get("id", "")] = true
	for c: Dictionary in curses:
		var tells: Dictionary = c.get("tells", {})
		var n: int = 0
		for tool: String in TOOLS:
			if str(tells.get(tool, "")) != "":
				n += 1
		for tool: Variant in tells:
			if not TOOLS.has(str(tool)):
				out.append("curse %s has a tell for unknown tool %s" % [c.get("id", "?"), tool])
		if n == 0:
			out.append("curse %s has no tell" % c.get("id", "?"))
		if ids.has(c.get("id", "")):
			out.append("duplicate id %s" % c.get("id", ""))
		ids[c.get("id", "")] = true
	for kind: String in ["seller", "buyer"]:
		if customer_types(kind).is_empty():
			out.append("no %s customer types" % kind)
	if tarot.is_empty():
		out.append("no tarot deck")
	elif tarot_return() >= 1.0:
		out.append("tarot deck pays %.2f per coin staked; it must stay below 1" % tarot_return())
	return out
