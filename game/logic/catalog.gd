class_name Catalog
extends RefCounted
## Object and curse definitions. Placeholder content until the content rounds; data in game/data/*.json.
## objects: {id, name, category, value}. curses: {id, name, dread, sale_mult, imposter_every, tells: {tool: text}}.

const TOOLS: PackedStringArray = ["uv", "scale", "listen", "touch"]
const OBJECTS_PATH: String = "res://game/data/objects.json"
const CURSES_PATH: String = "res://game/data/curses.json"

var objects: Array[Dictionary] = []
var curses: Array[Dictionary] = []


static func load_default() -> Catalog:
	var c := Catalog.new()
	c.objects = _catalog_read(OBJECTS_PATH)
	c.curses = _catalog_read(CURSES_PATH)
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


func categories() -> PackedStringArray:
	var out := PackedStringArray()
	for o: Dictionary in objects:
		if not out.has(str(o["category"])):
			out.append(str(o["category"]))
	return out


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
	return out
