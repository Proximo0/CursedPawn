class_name UiJournalLog
extends RefCounted
## What the journal remembers that the profile does not: the customer types the player has met, the curses they have
## identified, and the last 20 runs. Kept in its own small file (user://journal_ui.json, written atomically). Scripted
## runs and tests never read or write the file: they get an empty log in memory.

const PATH: String = "user://journal_ui.json"
const VERSION: int = 1
const MAX_RUNS: int = 20

static var _shared: UiJournalLog = null

var customers: Array[String] = []
var curses: Array[String] = []
var runs: Array[Dictionary] = []  ## newest first: {n, seed, omen, omen_name, haunting, nights, cash, won, ending, daily}
var counter: int = 0  ## runs ever recorded, for the numbering


static func shared() -> UiJournalLog:
	if _shared == null:
		_shared = UiJournalLog.new()
		if not Flags.is_scripted_run():
			_shared.load_from(PATH)
	return _shared


static func forget_shared() -> void:
	_shared = null


func note_customer(tid: String) -> bool:
	if tid == "" or customers.has(tid):
		return false
	customers.append(tid)
	return true


func note_curse(id: String) -> bool:
	if id == "" or curses.has(id):
		return false
	curses.append(id)
	return true


## Adds a finished run at the front; only the last MAX_RUNS stay.
func record_run(run: RunState, ending: String, daily: bool = false) -> Dictionary:
	counter += 1
	var o: Dictionary = run.opts
	var entry: Dictionary = {"n": counter, "seed": run.seed_used, "omen": str(o.get("omen", "")), "omen_name": str(o.get("omen_name", "")),
		"haunting": int(o.get("haunting", 0)), "nights": run.night, "cash": run.cash, "won": run.won, "ending": ending if run.won else "",
		"daily": daily}
	runs.push_front(entry)
	while runs.size() > MAX_RUNS:
		runs.pop_back()
	return entry


## The options a "replay seed" start uses for an entry: the same haunting and omen.
static func replay_opts(entry: Dictionary) -> Dictionary:
	return UiEngage.make_opts(int(entry.get("haunting", 0)), str(entry.get("omen", "")), false)


func to_dict() -> Dictionary:
	return {"version": VERSION, "customers": customers.duplicate(), "curses": curses.duplicate(), "runs": runs.duplicate(true), "counter": counter}


## Tolerant of anything a file may hold: wrong types are dropped, lists are clamped.
func from_dict(d: Dictionary) -> void:
	customers.clear()
	curses.clear()
	runs.clear()
	for key: String in ["customers", "curses"]:
		var raw: Variant = d.get(key, [])
		if raw is Array:
			for v: Variant in raw as Array:
				if v is String and str(v) != "" and not (customers if key == "customers" else curses).has(str(v)):
					(customers if key == "customers" else curses).append(str(v))
	var rr: Variant = d.get("runs", [])
	if rr is Array:
		for v: Variant in rr as Array:
			if v is Dictionary and runs.size() < MAX_RUNS:
				var e: Dictionary = v as Dictionary
				runs.append({"n": int(e.get("n", 0)), "seed": int(e.get("seed", 0)), "omen": str(e.get("omen", "")),
					"omen_name": str(e.get("omen_name", "")), "haunting": clampi(int(e.get("haunting", 0)), 0, 10),
					"nights": maxi(int(e.get("nights", 0)), 0), "cash": int(e.get("cash", 0)), "won": bool(e.get("won", false)),
					"ending": str(e.get("ending", "")), "daily": bool(e.get("daily", false))})
	counter = maxi(int(d.get("counter", runs.size())), runs.size())


func save(path: String = PATH) -> Error:
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


func save_player() -> void:
	if not Flags.is_scripted_run():
		save()


func load_from(path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int((parsed as Dictionary).get("version", 0)) > VERSION:
		return false
	from_dict(parsed as Dictionary)
	return true
