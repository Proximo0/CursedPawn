class_name Deeds
extends RefCounted
## The Ledger of Deeds (achievements, later mirrored to Steam), from game/data/deeds.json:
## {id, name, text, secret, check}. `check` is a rule object; every key in it must hold (AND). Kinds:
## won, haunting_at_least n, wakes_at_least n, cash_at_least n, spells_cast n, table_wins n, pairs_perfect,
## collector "pleased", requests_done n, curios_owned n, set_complete id, regular_finished id, omen id, daily,
## no_tools, all_cursed_held n (most cursed objects held at once). Run counters come from RunState; curios, sets,
## regulars and earned deeds come from the profile (a RelicStore), plus anything the run just found or advanced.

const PATH: String = "res://game/data/deeds.json"
const KINDS: PackedStringArray = ["won", "haunting_at_least", "wakes_at_least", "cash_at_least", "spells_cast",
	"table_wins", "pairs_perfect", "collector", "requests_done", "curios_owned", "set_complete", "regular_finished",
	"omen", "daily", "no_tools", "all_cursed_held"]


static func all() -> Array[Dictionary]:
	return DataFiles.read_array(PATH)


static func get_deed(id: String) -> Dictionary:
	for d: Dictionary in all():
		if str(d["id"]) == id:
			return d
	return {}


## The ids newly earned: every deed not yet in `profile.deeds` whose rule holds for `run` and `profile`.
## Pure: nothing is written (PlayerProfile.record_result stores them). Safe to call mid-run for a toast.
static func check(run: RunState, profile: RelicStore) -> PackedStringArray:
	var out := PackedStringArray()
	var curios: Dictionary = _curios_held(run, profile)
	for d: Dictionary in all():
		var id: String = str(d["id"])
		if profile.deeds.has(id):
			continue
		if holds(d.get("check", {}), run, profile, curios):
			out.append(id)
	return out


## Whether one rule object holds.
static func holds(rule: Dictionary, run: RunState, profile: RelicStore, curios: Dictionary = {}) -> bool:
	if rule.is_empty():
		return false
	if curios.is_empty():
		curios = _curios_held(run, profile)
	for key: Variant in rule:
		var v: Variant = rule[key]
		var ok: bool = false
		match str(key):
			"won":
				ok = run.won == bool(v)
			"haunting_at_least":
				ok = int(run.opts.get("haunting", 0)) >= int(v)
			"wakes_at_least":
				ok = run.wake_nights.size() >= int(v)
			"cash_at_least":
				ok = run.cash >= int(v)
			"spells_cast":
				ok = run.spells_cast >= int(v)
			"table_wins":
				ok = run.table_wins >= int(v)
			"pairs_perfect":
				ok = (run.pairs_perfect > 0) == bool(v)
			"collector":
				ok = str(run.collector.get("result", "")) == str(v)
			"requests_done":
				ok = run.requests_done >= int(v)
			"curios_owned":
				ok = curios.size() >= int(v)
			"set_complete":
				ok = _set_complete(str(v), curios, run.catalog)
			"regular_finished":
				var progress: int = maxi(int(profile.regulars.get(str(v), 0)), int(run.regular_progress.get(str(v), 0)))
				ok = progress >= Regulars.chapter_count(str(v))
			"omen":
				ok = str(run.opts.get("omen", "")) == str(v)
			"daily":
				ok = bool(run.opts.get("daily", false)) == bool(v)
			"no_tools":
				ok = (run.tools_used == 0) == bool(v)
			"all_cursed_held":
				ok = run.max_cursed_held >= int(v)
		if not ok:
			return false
	return true


## Curio ids the player owns or has just found this run: {id: true}.
static func _curios_held(run: RunState, profile: RelicStore) -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in profile.collection.owned:
		out[str(id)] = true
	for f: Dictionary in run.found:
		if f["kind"] == "curio":
			out[str(f["id"])] = true
	return out


static func _set_complete(set_id: String, curios: Dictionary, cat: Catalog) -> bool:
	var found_any: bool = false
	if cat == null:
		return false
	for c: Dictionary in cat.curios:
		if str(c.get("set", "")) == set_id:
			found_any = true
			if not curios.has(str(c["id"])):
				return false
	return found_any


static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var ids: Dictionary = {}
	var list: Array[Dictionary] = all()
	if list.size() < 28:
		out.append("fewer than 28 deeds")
	for d: Dictionary in list:
		var id: String = str(d.get("id", ""))
		if id == "" or ids.has(id):
			out.append("deed %s: missing or duplicate id" % id)
		ids[id] = true
		for key: String in ["name", "text"]:
			if str(d.get(key, "")) == "" or str(d[key]).length() > 80:
				out.append("deed %s: %s must be 1-80 characters" % [id, key])
		if not d.get("secret") is bool:
			out.append("deed %s: secret must be true or false" % id)
		var rule: Dictionary = d.get("check", {}) if d.get("check") is Dictionary else {}
		if rule.is_empty():
			out.append("deed %s: empty check" % id)
		for key: Variant in rule:
			if not KINDS.has(str(key)):
				out.append("deed %s: unknown rule kind %s" % [id, key])
		if rule.has("regular_finished") and Regulars.get_regular(str(rule["regular_finished"])).is_empty():
			out.append("deed %s: unknown regular" % id)
		if rule.has("omen") and Omens.get_omen(str(rule["omen"])).is_empty():
			out.append("deed %s: unknown omen" % id)
	return out
