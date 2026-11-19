class_name Hauntings
extends RefCounted
## Difficulty tiers from game/data/hauntings.json: [{level 1..10, name, text, set, mul, flags}]. Levels stack:
## Haunting N applies levels 1..N in order, as Tuning overrides (set, then mul) plus rule flags.

const PATH: String = "res://game/data/hauntings.json"
const MAX_LEVEL: int = 10
const FLAGS: PackedStringArray = ["start_cursed"]


static func all() -> Array[Dictionary]:
	return DataFiles.read_array(PATH)


## The entries for levels 1..level, in order.
static func upto(level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h: Dictionary in all():
		if int(h["level"]) <= level:
			out.append(h)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) < int(b["level"]))
	return out


static func entry(level: int) -> Dictionary:
	for h: Dictionary in all():
		if int(h["level"]) == level:
			return h
	return {}


## Data problems, one line each.
static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary = {}
	for h: Dictionary in all():
		seen[int(h.get("level", 0))] = true
		for line: String in DataFiles.rule_problems("haunting %s" % h.get("level", "?"), h, FLAGS):
			out.append(line)
	for lv: int in range(1, MAX_LEVEL + 1):
		if not seen.has(lv):
			out.append("haunting %d missing" % lv)
	return out
