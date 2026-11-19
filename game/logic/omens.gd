class_name Omens
extends RefCounted
## Omens from game/data/omens.json: {id, name, text, set, mul, flags}. Pick one of three at run start. Each has an
## upside and a downside. Flags RunState reads: all_cursed (bool), no_tool (tool id), start_spell (spell id),
## double_table (bool), one_customer_type (bool). Cursed buyer pay and similar go through `mul`.

const PATH: String = "res://game/data/omens.json"
const FLAGS: PackedStringArray = ["all_cursed", "no_tool", "start_spell", "double_table", "one_customer_type"]
const OFFER_COUNT: int = 3
const SALT: int = 7919


static func all() -> Array[Dictionary]:
	return DataFiles.read_array(PATH)


## The omen with `id`, or {}.
static func get_omen(id: String) -> Dictionary:
	for o: Dictionary in all():
		if str(o["id"]) == id:
			return o
	return {}


## Three distinct omen ids for `seed_value`, always the same for the same seed.
static func offer(seed_value: int) -> Array[String]:
	var ids: Array[String] = []
	for o: Dictionary in all():
		ids.append(str(o["id"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * SALT + 13
	var out: Array[String] = []
	while out.size() < OFFER_COUNT and not ids.is_empty():
		out.append(ids.pop_at(rng.randi_range(0, ids.size() - 1)))
	return out


static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var ids: Dictionary = {}
	for o: Dictionary in all():
		var id: String = str(o.get("id", ""))
		if ids.has(id):
			out.append("omen %s duplicated" % id)
		ids[id] = true
		for line: String in DataFiles.rule_problems("omen %s" % id, o, FLAGS):
			out.append(line)
		var flags: Dictionary = o.get("flags", {})
		if flags.has("no_tool") and not Catalog.TOOLS.has(str(flags["no_tool"])):
			out.append("omen %s: no_tool %s is not a tool" % [id, flags["no_tool"]])
	if ids.size() < OFFER_COUNT:
		out.append("fewer than %d omens" % OFFER_COUNT)
	return out
