class_name Collector
extends RefCounted
## The night-5 boss, from game/data/collector.json: {name, lines: {arrive, want, pleased, refused, curse},
## wants: [{curse or category, text}]}. He is the first customer of the final night. At night 3 start the run rolls
## one want (seeded, on its own RNG so the main stream is untouched) and announces it.

const PATH: String = "res://game/data/collector.json"
const SALT: int = 5003
const TID: String = "collector_boss"  ## the customer-type id his events carry (the regular "collector" buyer stays)


static func data() -> Dictionary:
	return DataFiles.read_dict(PATH)


static func line(key: String) -> String:
	return str((data().get("lines", {}) as Dictionary).get(key, ""))


## The want for a run seeded `seed_value`: {category, curse, text}.
static func roll_want(seed_value: int) -> Dictionary:
	var wants: Array = data().get("wants", [])
	if wants.is_empty():
		return {"category": "", "curse": "", "text": "anything at all"}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * SALT + 17
	var w: Dictionary = wants[rng.randi_range(0, wants.size() - 1)]
	return {"category": str(w.get("category", "")), "curse": str(w.get("curse", "")), "text": str(w.get("text", ""))}


## The announcement line for a rolled want.
static func omen_text(want: Dictionary, arrive_night: int) -> String:
	return line("want").replace("{want}", str(want["text"])).replace("{night}", str(arrive_night))


## Whether a held item (category, curse) satisfies the want.
static func matches(want: Dictionary, item: Dictionary) -> bool:
	if str(want.get("curse", "")) != "":
		return str(item["curse"]) == str(want["curse"])
	return str(item["category"]) == str(want.get("category", ""))


static func problems(cat: Catalog) -> PackedStringArray:
	var out := PackedStringArray()
	var d: Dictionary = data()
	for key: String in ["arrive", "want", "pleased", "refused", "curse"]:
		if line(key) == "":
			out.append("collector line %s missing" % key)
	var wants: Array = d.get("wants", [])
	if wants.is_empty():
		out.append("collector has no wants")
	var cats: PackedStringArray = cat.categories()
	for w: Variant in wants:
		var wd: Dictionary = w as Dictionary
		if str(wd.get("text", "")) == "":
			out.append("collector want without text")
		var curse: String = str(wd.get("curse", ""))
		var category: String = str(wd.get("category", ""))
		if (curse == "") == (category == ""):
			out.append("collector want %s needs exactly one of curse or category" % wd.get("text", "?"))
		elif curse != "" and cat.curse(curse).is_empty():
			out.append("collector want: unknown curse %s" % curse)
		elif category != "" and not cats.has(category):
			out.append("collector want: unknown category %s" % category)
	return out
