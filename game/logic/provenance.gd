class_name Provenance
extends RefCounted
## A short provenance line for every object you buy: a story seeded from the object's tags (category, cursed or not)
## from game/data/provenance.json, with the pass-it-on history merged in. Never reveals the curse, only hints at it:
## cursed objects draw the "ominous" pool about half the time, clean ones about one time in five.
## It uses its own seeded RNG (seed, uid, id), so it never changes a run's random stream.

const PATH: String = "res://game/data/provenance.json"
const MAX_LEN: int = 140

static var _prov_cache: Dictionary = {}


static func data() -> Dictionary:
	if _prov_cache.is_empty():
		_prov_cache = DataFiles.read_dict(PATH)
	return _prov_cache


## The line for `item` ({id, category, curse, uid, history?}) in a run seeded `seed_value`.
static func make(item: Dictionary, seed_value: int) -> String:
	var d: Dictionary = data()
	if d.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%s:%s" % [seed_value, str(item.get("uid", 0)), str(item.get("id", ""))]).hash()
	var origins: Array = (d.get("origin", {}) as Dictionary).get(str(item.get("category", "")), [])
	var first: String = str(origins[rng.randi_range(0, origins.size() - 1)]) if not origins.is_empty() else ""
	var cursed: bool = str(item.get("curse", "")) != ""
	var second_pool: Array = d.get("ominous", []) if rng.randf() < (0.5 if cursed else 0.2) else d.get("owner", [])
	var second: String = str(second_pool[rng.randi_range(0, second_pool.size() - 1)]) if not second_pool.is_empty() else ""
	var line: String = (first + " " + second).strip_edges()
	var past: String = history_text(item.get("history", []))
	return (line + " " + past).strip_edges()


## The pass-it-on history as sentences: the last holder, how far they got, and whether they paid every rent.
static func history_text(history: Variant) -> String:
	if not history is Array or (history as Array).is_empty():
		return ""
	var h: Dictionary = (data().get("history", {}) as Dictionary)
	var last: Array = (history as Array)[-1]
	var who: String = str(last[0]) if str(last[0]) != "" else str(h.get("anonymous", "a stranger"))
	var out: String = str(h.get("intro", "%s")) % who
	out += " " + str(h.get("reached", "%d %d")) % [int(last[1]), int(last[2])]
	if bool(last[3]):
		out += " " + str(h.get("won", ""))
	return out + (" (%d holders.)" % (history as Array).size() if (history as Array).size() > 1 else "")


static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var d: Dictionary = data()
	for key: String in ["origin", "owner", "ominous", "history"]:
		if not d.has(key):
			out.append("provenance.json missing %s" % key)
	if not out.is_empty():
		return out
	for cat: Variant in d["origin"]:
		if (d["origin"][cat] as Array).size() < 3:
			out.append("provenance: category %s needs at least 3 origins" % cat)
		for s: Variant in d["origin"][cat]:
			if str(s).length() > 55:
				out.append("provenance: too long: %s" % s)
	for pool: String in ["owner", "ominous"]:
		for s: Variant in d[pool]:
			if str(s).length() > 55:
				out.append("provenance: too long: %s" % s)
	return out
