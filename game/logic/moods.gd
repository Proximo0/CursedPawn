class_name Moods
extends RefCounted
## Seller moods from game/data/moods.json: calm, nervous, greedy. A mood sets how a seller haggles and is readable
## from lines the player sees: `lines` when the customer arrives, `tells` on a counter-offer (a greedy seller's
## `bluff_tell` fires 70% of the time on a bluff and `slip_tell` 15% on an honest counter, so it is a hint, not a proof).
## move = fraction of the gap to your offer a counter closes (0.5 splits the difference); bluff = chance a greedy seller
## holds the ask unchanged; buyer_open = the share of their limit a buyer of this mood opens at (a buyer's counters use
## move and bluff the same way, raising their offer instead of lowering an ask); flee_below = a lowball under this fraction of their lowest price sends them out the door.

const PATH: String = "res://game/data/moods.json"
const IDS: PackedStringArray = ["calm", "nervous", "greedy"]

static var _mood_cache: Array[Dictionary] = []


static func all() -> Array[Dictionary]:
	if _mood_cache.is_empty():
		_mood_cache = DataFiles.read_array(PATH)
	return _mood_cache


static func get_mood(id: String) -> Dictionary:
	for m: Dictionary in all():
		if str(m["id"]) == id:
			return m
	return {"id": "calm", "name": "Calm", "weight": 1.0, "move": 0.5, "bluff": 0.0, "patience_add": 0, "reserve_mult": 1.0,
		"flee_below": 0.0, "buyer_open": 0.85, "lines": [], "tells": []}


## A mood id for a seller type: moods by weight, times the type's `mood_bias` {mood: factor}.
static func pick(rng: RandomNumberGenerator, type_def: Dictionary) -> String:
	var bias: Dictionary = type_def.get("mood_bias", {})
	var total: float = 0.0
	for m: Dictionary in all():
		total += float(m["weight"]) * float(bias.get(str(m["id"]), 1.0))
	var r: float = rng.randf() * total
	for m: Dictionary in all():
		r -= float(m["weight"]) * float(bias.get(str(m["id"]), 1.0))
		if r < 0.0:
			return str(m["id"])
	return "calm"


static func line_for(rng: RandomNumberGenerator, id: String) -> String:
	var lines: Array = get_mood(id).get("lines", [])
	return str(lines[rng.randi_range(0, lines.size() - 1)]) if not lines.is_empty() else ""


static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in IDS:
		var m: Dictionary = get_mood(id)
		if str(m["id"]) != id or (id != "calm" and (m["lines"] as Array).is_empty()):
			out.append("mood %s is missing or has no lines" % id)
		if float(m["move"]) <= 0.0 or float(m["move"]) > 1.0:
			out.append("mood %s: move must be in (0, 1]" % id)
		for s: Variant in (m["lines"] as Array) + (m["tells"] as Array):
			if str(s).length() > 80:
				out.append("mood %s: line too long: %s" % [id, s])
	return out
