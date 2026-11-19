class_name DailyThemes
extends RefCounted
## Weekly themes for the Daily Seance, from game/data/daily_themes.json: {id, name, text, set, mul, flags}. A theme runs for a
## whole week and then the next one starts (they cycle in file order). Weeks count from the launch day, so everybody who plays
## on a date gets the same theme. A theme is an extra rule set on top of the day's omen: it rides in the run options as
## `theme: id` and RunState applies its `set`/`mul` to the tuning copy and its flags (all_cursed, double_table,
## one_customer_type, start_cursed) to the rules.

const PATH: String = "res://game/data/daily_themes.json"
const FLAGS: PackedStringArray = ["all_cursed", "double_table", "one_customer_type", "start_cursed"]
const DAYS_PER_THEME: int = 7


static func all() -> Array[Dictionary]:
	return DataFiles.read_array(PATH)


static func get_theme(id: String) -> Dictionary:
	for t: Dictionary in all():
		if str(t["id"]) == id:
			return t
	return {}


## The theme for the week that contains the date (before the launch day, the same cycle runs backwards).
static func theme_for(y: int, m: int, d: int) -> Dictionary:
	var themes: Array[Dictionary] = all()
	if themes.is_empty():
		return {}
	var week: int = int(floor(float(Daily.number(y, m, d) - 1) / float(DAYS_PER_THEME)))
	return themes[posmod(week, themes.size())]


## Days left in the date's theme week, counting the date itself (1 on the last day).
static func days_left(y: int, m: int, d: int) -> int:
	return DAYS_PER_THEME - posmod(Daily.number(y, m, d) - 1, DAYS_PER_THEME)


static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var ids: Dictionary = {}
	for t: Dictionary in all():
		var id: String = str(t.get("id", ""))
		if id == "" or ids.has(id):
			out.append("daily theme %s: missing or duplicate id" % id)
		ids[id] = true
		for line: String in DataFiles.rule_problems("daily theme %s" % id, t, FLAGS):
			out.append(line)
	if ids.size() < 4:
		out.append("fewer than 4 daily themes")
	return out
