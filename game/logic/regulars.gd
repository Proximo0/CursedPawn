class_name Regulars
extends RefCounted
## Regulars: six customers whose small stories continue across runs, from game/data/regulars.json:
## {id, name, tid (a customers.json type to look like), chapters: [{line, kind: seller|buyer, item_id or category,
## curse, outcome_lines: {done, refused}, reward: {kind, id} or {}}]}. The profile keeps `regulars: {id: next chapter
## index}` (0 = not met). A visit plays the next chapter; doing what it asks (buy the item, or sell a match) says
## `done`, refusing says `refused`, and either way the arc moves on. Buyer chapters only start once the player holds a
## match, so a story is never lost to an empty shelf. The seeded plan lives in RunState.

const PATH: String = "res://game/data/regulars.json"
const SALT: int = 6007
const MAX_LINE: int = 80
const FIRST_NIGHT: int = 2
const LAST_NIGHT: int = 4


static func all() -> Array[Dictionary]:
	return DataFiles.read_array(PATH)


static func get_regular(id: String) -> Dictionary:
	for r: Dictionary in all():
		if str(r["id"]) == id:
			return r
	return {}


static func chapter_count(id: String) -> int:
	return (get_regular(id).get("chapters", []) as Array).size()


## Chapter `index` (0-based) of regular `id`, or {} past the end.
static func chapter(id: String, index: int) -> Dictionary:
	var chapters: Array = get_regular(id).get("chapters", [])
	return chapters[index] if index >= 0 and index < chapters.size() else {}


static func is_finished(id: String, progress: Dictionary) -> bool:
	return int(progress.get(id, 0)) >= chapter_count(id)


## Ids of regulars whose arc is not finished, in file order.
static func unfinished(progress: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for r: Dictionary in all():
		if not is_finished(str(r["id"]), progress):
			out.append(str(r["id"]))
	return out


## Progress cleaned to known ids and 0 <= index <= chapter count.
static func clean(progress: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in progress:
		var n: int = clampi(int(progress[key]), 0, chapter_count(str(key)))
		if n > 0:
			out[str(key)] = n
	return out


## Whether a held item satisfies a buyer chapter (its item_id, else its category, and its curse when it names one).
static func matches(chap: Dictionary, item: Dictionary) -> bool:
	var want_id: String = str(chap.get("item_id", ""))
	if want_id != "":
		if str(item["id"]) != want_id:
			return false
	elif str(item["category"]) != str(chap.get("category", "")):
		return false
	var curse: String = str(chap.get("curse", ""))
	return curse == "" or str(item["curse"]) == curse


## The seeded plan for a run: {id, night, chapter} or {} for no visit. Own RNG, so the main stream is untouched.
static func plan(seed_value: int, progress: Dictionary, chance: float, nights: int) -> Dictionary:
	var open: PackedStringArray = unfinished(progress)
	var last: int = mini(LAST_NIGHT, nights - 1)
	if open.is_empty() or last < FIRST_NIGHT:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * SALT + 31
	var roll: float = rng.randf()
	var id: String = open[rng.randi_range(0, open.size() - 1)]
	var night: int = rng.randi_range(FIRST_NIGHT, last)
	if roll >= chance:
		return {}
	return {"id": id, "night": night, "chapter": int(progress.get(id, 0))}


static func problems(cat: Catalog) -> PackedStringArray:
	var out := PackedStringArray()
	var list: Array[Dictionary] = all()
	if list.size() != 6:
		out.append("regulars: expected 6, found %d" % list.size())
	var cats: PackedStringArray = cat.categories()
	var ids: Dictionary = {}
	for r: Dictionary in list:
		var id: String = str(r.get("id", ""))
		var chapters: Array = r.get("chapters", [])
		if id == "" or ids.has(id):
			out.append("regular %s: missing or duplicate id" % id)
		ids[id] = true
		if str(r.get("name", "")) == "":
			out.append("regular %s: no name" % id)
		var known_tid: bool = false
		for t: Dictionary in cat.customers:
			known_tid = known_tid or str(t["id"]) == str(r.get("tid", ""))
		if not known_tid:
			out.append("regular %s: unknown tid %s" % [id, r.get("tid", "")])
		if chapters.size() < 3 or chapters.size() > 4:
			out.append("regular %s: needs 3-4 chapters" % id)
		for i: int in range(chapters.size()):
			out.append_array(_chapter_problems("regular %s ch%d" % [id, i + 1], chapters[i] as Dictionary, cat, cats, i == chapters.size() - 1))
	return out


static func _chapter_problems(label: String, c: Dictionary, cat: Catalog, cats: PackedStringArray, last: bool) -> PackedStringArray:
	var out := PackedStringArray()
	var texts: Array = [c.get("line", ""), (c.get("outcome_lines", {}) as Dictionary).get("done", ""),
		(c.get("outcome_lines", {}) as Dictionary).get("refused", "")]
	for s: Variant in texts:
		if str(s) == "" or str(s).length() > MAX_LINE:
			out.append("%s: lines must be 1-%d characters (%d)" % [label, MAX_LINE, str(s).length()])
	var kind: String = str(c.get("kind", ""))
	if kind != "seller" and kind != "buyer":
		out.append("%s: kind must be seller or buyer" % label)
	var item_id: String = str(c.get("item_id", ""))
	var category: String = str(c.get("category", ""))
	if kind == "seller" and not _object_known(cat, item_id):
		out.append("%s: a seller needs a known item_id (%s)" % [label, item_id])
	if kind == "buyer" and (item_id == "") == (category == ""):
		out.append("%s: a buyer needs exactly one of item_id or category" % label)
	if kind == "buyer" and item_id != "" and not _object_known(cat, item_id):
		out.append("%s: unknown item_id %s" % [label, item_id])
	if category != "" and not cats.has(category):
		out.append("%s: unknown category %s" % [label, category])
	var curse: String = str(c.get("curse", ""))
	if curse != "" and cat.curse(curse).is_empty():
		out.append("%s: unknown curse %s" % [label, curse])
	var reward: Dictionary = c.get("reward", {})
	if last and reward.is_empty():
		out.append("%s: the last chapter needs a reward (the payoff)" % label)
	if not reward.is_empty():
		var rid: String = str(reward.get("id", ""))
		var ok: bool = not cat.curio(rid).is_empty() if reward.get("kind") == "curio" else (not cat.spell(rid).is_empty() if reward.get("kind") == "page" else false)
		if not ok:
			out.append("%s: unknown reward %s" % [label, reward])
	return out


static func _object_known(cat: Catalog, id: String) -> bool:
	for o: Dictionary in cat.objects:
		if str(o["id"]) == id:
			return true
	return false
