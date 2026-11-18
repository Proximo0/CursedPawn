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
