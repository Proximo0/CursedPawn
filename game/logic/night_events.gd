class_name NightEvents
extends RefCounted
## Dusk events from game/data/night_events.json: {id, name, weight, text, mods}. `mods` keys RunState reads through
## `event_mod`: tool_cost_mult (blackout), customer_minutes_mult and price_mult (storm), auction_value_mult and
## auction_cursed_odds (auction), cursed_share_mult, curse_dread_mult and cursed_pay_mult (full moon).
## The roll has its own RNG (seed, night), so events never change the run's main random stream.

const PATH: String = "res://game/data/night_events.json"
const SALT: int = 104729
const KNOWN_MODS: PackedStringArray = ["tool_cost_mult", "customer_minutes_mult", "price_mult", "auction_value_mult",
	"auction_cursed_odds", "cursed_share_mult", "curse_dread_mult", "cursed_pay_mult"]


static func all() -> Array[Dictionary]:
	return DataFiles.read_array(PATH)


static func get_event(id: String) -> Dictionary:
	for e: Dictionary in all():
		if str(e["id"]) == id:
			return e
	return {}


## The event for `night` of a run with `seed_value`, or {} for none. Night 1 never has one.
static func roll(seed_value: int, night: int, chance: float) -> Dictionary:
	if night < 2 or chance <= 0.0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * SALT + night * 31 + 7
	if rng.randf() >= chance:
		return {}
	var events: Array[Dictionary] = all()
	var total: float = 0.0
	for e: Dictionary in events:
		total += float(e.get("weight", 1.0))
	var r: float = rng.randf() * total
	for e: Dictionary in events:
		r -= float(e.get("weight", 1.0))
		if r < 0.0:
			return e
	return events[-1] if not events.is_empty() else {}


static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var ids: Dictionary = {}
	for e: Dictionary in all():
		var id: String = str(e.get("id", ""))
		if id == "" or ids.has(id):
			out.append("night event %s: missing or duplicate id" % id)
		ids[id] = true
		var text: String = str(e.get("text", ""))
		if str(e.get("name", "")) == "" or text == "" or text.length() > 110:
			out.append("night event %s: needs a name and a text of at most 110 characters" % id)
		for key: Variant in (e.get("mods", {}) as Dictionary):
			if not KNOWN_MODS.has(str(key)):
				out.append("night event %s: unknown mod %s" % [id, key])
	for needed: String in ["blackout", "storm", "auction", "full_moon"]:
		if not ids.has(needed):
			out.append("night event %s is missing" % needed)
	return out
