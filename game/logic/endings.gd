class_name Endings
extends RefCounted
## How a won run ends (game/data/endings.json), by priority: `collector` (the Collector was pleased), `regulars` (a regular's
## arc reached its final chapter this run), `cursed_shop` (you won holding at least `ending_cursed_count` cursed objects),
## `debt_free` (anything else). `run_won` carries `ending`, `ending_name`, `ending_title` and `epilogue`.

const PATH: String = "res://game/data/endings.json"
const IDS: PackedStringArray = ["collector", "regulars", "cursed_shop", "debt_free"]


static func all() -> Array[Dictionary]:
	return DataFiles.read_array(PATH)


static func get_ending(id: String) -> Dictionary:
	for e: Dictionary in all():
		if str(e["id"]) == id:
			return e
	return {}


## The ending id for a run that has just been won.
static func pick(run: RunState) -> String:
	if str(run.collector.get("result", "")) == "pleased":
		return "collector"
	if not run.regular.is_empty() and str(run.regular.get("state", "")) == "done" \
			and int(run.regular["chapter"]) + 1 >= Regulars.chapter_count(str(run.regular["id"])):
		return "regulars"
	var cursed: int = 0
	for item: Dictionary in run.inventory:
		cursed += 1 if str(item["curse"]) != "" else 0
	if cursed >= int(run.tuning.ending_cursed_count):
		return "cursed_shop"
	return "debt_free"


static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in IDS:
		var e: Dictionary = get_ending(id)
		if e.is_empty():
			out.append("ending %s is missing" % id)
		elif str(e.get("name", "")) == "" or str(e.get("title", "")) == "" or str(e.get("text", "")).length() < 20 or str(e["text"]).length() > 200:
			out.append("ending %s needs a name, a title and text of 20-200 characters" % id)
	return out
