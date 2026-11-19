class_name PlayerProfile
extends RefCounted
## The saved player profile: the reliquary shop, its purchase log and the curio collection. One JSON file,
## written to a temp file and renamed so a crash mid-write never corrupts it. Callers skip saving on scripted
## runs (`Flags.is_scripted_run()`), so tests and captures never touch player data.

const PATH: String = "user://profile.json"
const VERSION: int = 3  ## 2 adds the grimoire, 3 the progress record (hauntings, best cash, daily); older files load with defaults
const DAILY_KEEP: int = 30


static func save(store: RelicStore, path: String = PATH) -> Error:
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": VERSION, "store": store.to_dict(), "grimoire": Array(store.grimoire),
		"progress": {"haunting_unlocked": store.haunting_unlocked, "best_cash": store.best_cash, "daily_last": store.daily_last,
			"daily_best": store.daily_best}}))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


## Loads a saved profile into `store`. Returns false (and leaves the store as it is) when there is no file or it
## is unreadable or from a newer version.
static func load_into(store: RelicStore, path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("version", 0)) > VERSION or not parsed.get("store") is Dictionary:
		return false
	store.from_dict(parsed["store"])
	store.grimoire = PackedStringArray(parsed.get("grimoire", Array(Grimoire.DEFAULT_KNOWN)))
	var pr: Dictionary = parsed.get("progress", {}) if parsed.get("progress") is Dictionary else {}
	store.haunting_unlocked = clampi(int(pr.get("haunting_unlocked", 0)), 0, Hauntings.MAX_LEVEL)
	store.best_cash = int(pr.get("best_cash", 0))
	store.daily_last = str(pr.get("daily_last", ""))
	store.daily_best = (pr.get("daily_best", {}) as Dictionary).duplicate(true) if pr.get("daily_best") is Dictionary else {}
	return true


## Banks what a finished run found: pages join the grimoire, curios are granted (tradeable, earned). Returns the
## ids newly added to the grimoire. Callers skip saving on scripted runs.
static func bank_finds(run: RunState, store: RelicStore) -> PackedStringArray:
	var added := PackedStringArray()
	for f: Dictionary in run.found:
		if f["kind"] == "page":
			if not store.grimoire.has(str(f["id"])):
				store.grimoire.append(str(f["id"]))
				added.append(str(f["id"]))
		elif f["kind"] == "curio":
			store.collection.grant(str(f["id"]))
	return added


## Records a finished run: unlocks the next haunting on a win at the highest unlocked one, keeps the best winning
## cash, and, for a daily run, the first attempt of the date (`opts.date`, else the system date). Returns
## {unlocked: new haunting level or 0, new_best: bool, daily_counted: bool}. Callers skip it on scripted runs and save after.
static func record_result(run: RunState, store: RelicStore) -> Dictionary:
	var out: Dictionary = {"unlocked": 0, "new_best": false, "daily_counted": false}
	var level: int = int(run.opts.get("haunting", 0))
	if run.won:
		if level >= store.haunting_unlocked and store.haunting_unlocked < Hauntings.MAX_LEVEL:
			store.haunting_unlocked += 1
			out["unlocked"] = store.haunting_unlocked
		if run.cash > store.best_cash:
			store.best_cash = run.cash
			out["new_best"] = true
	if bool(run.opts.get("daily", false)):
		var date: String = str(run.opts.get("date", Time.get_date_string_from_system()))
		if store.daily_last != date:
			store.daily_last = date
			store.daily_best[date] = {"number": int(run.opts.get("number", 0)), "night": run.night, "cash": run.cash,
				"won": run.won, "wakes": run.wake_nights.size()}
			var dates: Array = store.daily_best.keys()
			dates.sort()
			while dates.size() > DAILY_KEEP:
				store.daily_best.erase(dates.pop_front())
			out["daily_counted"] = true
	return out


## The run in progress, saved after every command so closing the game never loses a night. Binary Variant data
## (var_to_bytes): keeps ints and the 64-bit RNG state exact, and bytes_to_var never builds objects.
const RUN_PATH: String = "user://run.save"


## `rec` is the run's recording (RunRecording.to_dict()) so instant replay survives a restart.
static func save_run(run: RunState, rec: Dictionary = {}, path: String = RUN_PATH) -> Error:
	if run.phase == RunState.PHASE_OVER:
		return clear_run(path)
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(var_to_bytes({"version": VERSION, "run": run.snapshot(), "rec": rec}))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


## A saved run restored against `cat`: {run: RunState, rec: Dictionary}, or {} when there is none or it is
## unreadable.
static func load_run(cat: Catalog, path: String = RUN_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d: Variant = bytes_to_var(FileAccess.get_file_as_bytes(path))
	if not d is Dictionary or int(d.get("version", 0)) > VERSION or not d.get("run") is Dictionary:
		return {}
	var run := RunState.new()
	run.restore(d["run"], cat)
	return {"run": run, "rec": d.get("rec", {}) if d.get("rec") is Dictionary else {}}


static func clear_run(path: String = RUN_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
