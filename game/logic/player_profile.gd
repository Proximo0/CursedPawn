class_name PlayerProfile
extends RefCounted
## The saved player profile: the reliquary shop, its purchase log and the curio collection. One JSON file,
## written to a temp file and renamed so a crash mid-write never corrupts it. Callers skip saving on scripted
## runs (`Flags.is_scripted_run()`), so tests and captures never touch player data.

const PATH: String = "user://profile.json"
const VERSION: int = 1


static func save(store: RelicStore, path: String = PATH) -> Error:
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": VERSION, "store": store.to_dict()}))
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
	return true


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
