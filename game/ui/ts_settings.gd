class_name TsSettings
extends RefCounted
## Player settings and the set of tutorial hints already seen, in user://settings.json. Written to a temp file and
## renamed (like PlayerProfile) so a crash mid-write never corrupts it. Scripted runs never write (save_player).

const PATH: String = "user://settings.json"
const VERSION: int = 1
const VOLUME_STEP: float = 0.1

static var _ts_shared: TsSettings = null

var master: float = 1.0  ## linear 0..1, in steps of VOLUME_STEP
var muted: bool = false
var dither: bool = true
var fullscreen: bool = false
var seen: Array[String] = []  ## tutorial hint ids that have been shown


## The one settings object the title, pause menu and hints share. Scripted runs get defaults, never the file.
static func shared() -> TsSettings:
	if _ts_shared == null:
		_ts_shared = TsSettings.new()
		if not Flags.is_scripted_run():
			_ts_shared.load_from(PATH)
	return _ts_shared


## Drops the shared instance (tests, and the title when it should re-read the file).
static func ts_forget_shared() -> void:
	_ts_shared = null


func volume_percent() -> int:
	return int(round(master * 100.0))


## Moves the master volume one step (dir -1 or 1), snapped to the step grid and clamped to 0..1.
func step_volume(dir: int) -> void:
	var steps: int = int(round(master / VOLUME_STEP)) + dir
	master = clampf(float(steps) * VOLUME_STEP, 0.0, 1.0)


func has_seen(id: String) -> bool:
	return seen.has(id)


func mark_seen(id: String) -> void:
	if not seen.has(id):
		seen.append(id)


func reset_hints() -> void:
	seen.clear()


func to_dict() -> Dictionary:
	return {"version": VERSION, "master": master, "muted": muted, "dither": dither, "fullscreen": fullscreen,
		"seen": seen.duplicate()}


func from_dict(d: Dictionary) -> void:
	master = clampf(float(d.get("master", 1.0)), 0.0, 1.0)
	muted = bool(d.get("muted", false))
	dither = bool(d.get("dither", true))
	fullscreen = bool(d.get("fullscreen", false))
	seen.clear()
	var raw: Variant = d.get("seen", [])
	if raw is Array:
		for v: Variant in raw as Array:
			mark_seen(str(v))


func save(path: String = PATH) -> Error:
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


## Saves unless this is a scripted run (tests, captures and gates never write player data).
func save_player() -> void:
	if not Flags.is_scripted_run():
		save()


## Loads the file into this object. False (settings unchanged) when it is missing, unreadable or from a newer version.
func load_from(path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int((parsed as Dictionary).get("version", 0)) > VERSION:
		return false
	from_dict(parsed as Dictionary)
	return true


## Pushes the settings onto the live game. Either argument may be null. Fullscreen only on desktop, never scripted.
func apply(sfx: SfxPlayer, room: ShopRoom2D) -> void:
	if sfx != null:
		sfx.set_master_volume(master)
		sfx.set_muted(muted)
	if room != null:
		room.dither_enabled = dither
	if not Flags.is_scripted_run() and ts_is_desktop():
		var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


static func ts_is_desktop() -> bool:
	return not (OS.has_feature("web") or OS.has_feature("mobile"))
