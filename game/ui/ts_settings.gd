class_name TsSettings
extends RefCounted
## Player settings and the set of tutorial hints already seen, in user://settings.json. Written to a temp file and
## renamed (like PlayerProfile) so a crash mid-write never corrupts it. Scripted runs never write (save_player).

const PATH: String = "user://settings.json"
const VERSION: int = 2
const TEXT_SPEEDS: Array[String] = ["SLOW", "NORMAL", "FAST", "INSTANT"]
const TEXT_CPS: Array[float] = [35.0, 70.0, 140.0, 4000.0]  ## ledger ink speed, characters per second
const WINDOW_SCALES: Array[String] = ["AUTO", "1X", "2X", "3X"]
const SHAKE_STEP: int = 25
const VOLUME_STEP: float = 0.1

static var _ts_shared: TsSettings = null

var master: float = 1.0  ## linear 0..1, in steps of VOLUME_STEP
var muted: bool = false
var dither: bool = true
var fullscreen: bool = false
var scares_full: bool = true  ## false = gentle: no sudden flashes, loud stingers or screen-filling faces
var sfx_volume: float = 1.0  ## linear 0..1, steps of VOLUME_STEP
var music_volume: float = 1.0
var shake: int = 100  ## screen shake, 0..100 percent
var flash_reduce: bool = false  ## fewer and dimmer flashes (lightning, wake)
var text_speed: int = 1  ## index into TEXT_SPEEDS
var text_scale: int = 1  ## 1 or 2: the size of menu and log text
var colorblind: bool = false  ## shapes and words beside colour-only signals
var window_scale: int = 0  ## 0 auto, else 1..3: the window opens at 640x360 times this
var keys: Dictionary = {}  ## action -> keycode for rebound actions (TsKeys)
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


## Back to every default, keeping the tutorial hints already seen.
func reset_defaults() -> void:
	var keep: Array[String] = seen.duplicate()
	from_dict({})
	seen = keep


func text_cps() -> float:
	return TEXT_CPS[text_speed]


## One step of a setting row (dir -1 or 1; toggles flip). True when `id` is a setting row.
func adjust(id: String, dir: int) -> bool:
	match id:
		"volume":
			step_volume(dir)
		"sfx":
			sfx_volume = clampf(snappedf(sfx_volume + float(dir) * VOLUME_STEP, VOLUME_STEP), 0.0, 1.0)
		"music":
			music_volume = clampf(snappedf(music_volume + float(dir) * VOLUME_STEP, VOLUME_STEP), 0.0, 1.0)
		"mute":
			muted = not muted
		"shake":
			shake = clampi(shake + dir * SHAKE_STEP, 0, 100)
		"flash":
			flash_reduce = not flash_reduce
		"dither":
			dither = not dither
		"fullscreen":
			fullscreen = not fullscreen
		"window":
			window_scale = posmod(window_scale + dir, WINDOW_SCALES.size())
		"scares":
			scares_full = not scares_full
		"text_speed":
			text_speed = posmod(text_speed + dir, TEXT_SPEEDS.size())
		"text_size":
			text_scale = 2 if text_scale == 1 else 1
		"colorblind":
			colorblind = not colorblind
		_:
			return false
	return true


## The text a setting row shows as its value.
func value_text(id: String) -> String:
	match id:
		"volume":
			return "%d%%" % volume_percent()
		"sfx":
			return "%d%%" % int(round(sfx_volume * 100.0))
		"music":
			return "%d%%" % int(round(music_volume * 100.0))
		"mute":
			return "MUTED" if muted else "ON"
		"shake":
			return "%d%%" % shake
		"flash":
			return "REDUCED" if flash_reduce else "NORMAL"
		"dither":
			return "ON" if dither else "OFF"
		"fullscreen":
			return "ON" if fullscreen else "OFF"
		"window":
			return WINDOW_SCALES[window_scale]
		"scares":
			return "FULL" if scares_full else "GENTLE"
		"text_speed":
			return TEXT_SPEEDS[text_speed]
		"text_size":
			return "%dX" % text_scale
		"colorblind":
			return "ON" if colorblind else "OFF"
	return ""


func has_seen(id: String) -> bool:
	return seen.has(id)


func mark_seen(id: String) -> void:
	if not seen.has(id):
		seen.append(id)


func reset_hints() -> void:
	seen.clear()


func to_dict() -> Dictionary:
	return {"version": VERSION, "master": master, "muted": muted, "dither": dither, "fullscreen": fullscreen,
		"scares": "full" if scares_full else "gentle", "seen": seen.duplicate(),
		"sfx": sfx_volume, "music": music_volume, "shake": shake, "flash_reduce": flash_reduce, "text_speed": text_speed,
		"text_scale": text_scale, "colorblind": colorblind, "window_scale": window_scale, "keys": keys.duplicate()}


func from_dict(d: Dictionary) -> void:
	master = clampf(float(d.get("master", 1.0)), 0.0, 1.0)
	muted = bool(d.get("muted", false))
	dither = bool(d.get("dither", true))
	fullscreen = bool(d.get("fullscreen", false))
	scares_full = str(d.get("scares", "full")) != "gentle"
	sfx_volume = clampf(float(d.get("sfx", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(d.get("music", 1.0)), 0.0, 1.0)
	shake = clampi(int(d.get("shake", 100)), 0, 100)
	flash_reduce = bool(d.get("flash_reduce", false))
	text_speed = clampi(int(d.get("text_speed", 1)), 0, TEXT_SPEEDS.size() - 1)
	text_scale = 2 if int(d.get("text_scale", 1)) >= 2 else 1
	colorblind = bool(d.get("colorblind", false))
	window_scale = clampi(int(d.get("window_scale", 0)), 0, WINDOW_SCALES.size() - 1)
	keys = TsKeys.clean(d.get("keys", {}))
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
	TsKeys.set_bindings(keys)
	if sfx != null:
		sfx.set_music_volume(music_volume)
		sfx.set_master_volume(master)
		if sfx.has_method("set_sfx_volume"):  # the audio worker's property, when it lands
			sfx.call("set_sfx_volume", sfx_volume)
	if room != null:
		room.dither_enabled = dither
		if "shake_scale" in room:
			room.set("shake_scale", float(shake) / 100.0)
		if "flash_reduce" in room:
			room.set("flash_reduce", flash_reduce)
		if "scare_level" in room:  # the room worker's property; 0 gentle, 1 full
			room.set("scare_level", 1 if scares_full else 0)
	if not Flags.is_scripted_run() and ts_is_desktop():
		if window_scale > 0 and not fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			var want := Vector2i(640 * window_scale, 360 * window_scale)
			if DisplayServer.window_get_size() != want:
				DisplayServer.window_set_size(want)
		var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


static func ts_is_desktop() -> bool:
	return not (OS.has_feature("web") or OS.has_feature("mobile"))
