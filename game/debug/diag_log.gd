class_name DiagLog
extends RefCounted
## Local diagnostics: a ring buffer of the last log lines and engine errors, and a text report the player can copy from the
## settings screen and paste into a bug report. Nothing is sent anywhere. Messages have the home folder and the user-data path
## replaced, so a report holds no user name. Scripted runs (tests, captures) never write the optional file.
##   DiagLog.install()   at boot (SfxPlayer does it, so every game screen has it): starts catching engine errors. Counted:
##                       each install() needs one uninstall(); the engine hook is removed when the count reaches zero.
##   DiagLog.note(msg)   an application line; DiagLog.warn(msg) / DiagLog.error(msg) for the louder ones.
##   DiagLog.report()    the report text; DiagLog.copy_report() puts it on the clipboard and returns it.
##   DiagLog.context     optional Callable -> String, appended to the report (the game screen sets it to the run summary).

const CAPACITY: int = 200
const LEVEL_NOTE: int = 0
const LEVEL_WARN: int = 1
const LEVEL_ERROR: int = 2
const LEVEL_NAMES: PackedStringArray = ["note", "warn", "ERROR"]
const MAX_LINE: int = 300
const REPORT_LINES: int = 60  ## the newest lines the report carries
const FILE_PATH: String = "user://diagnostics.txt"
const FILE_GAP_SECS: float = 2.0  ## an error rewrites the file at most this often

static var context: Callable = Callable()
static var _lines: Array[Dictionary] = []  ## {t (secs since start), level, msg}, oldest first
static var _counts: PackedInt32Array = PackedInt32Array([0, 0, 0])
static var _total: int = 0  ## every line ever logged, including those that fell out of the ring
static var _mutex: Mutex = Mutex.new()
static var _logger: Logger = null
static var _last_write: float = -100.0
static var _installs: int = 0


## Starts catching engine errors and warnings. Returns false where the engine has no Logger hook.
static func install() -> bool:
	if _logger == null:
		if not ClassDB.class_exists("Logger"):
			return false
		_logger = _EngineLogger.new()
		OS.add_logger(_logger)
	_installs += 1
	return true


## Pairs with install(); the hook is taken out of the engine before the logger can be freed at exit.
static func uninstall() -> void:
	_installs = maxi(_installs - 1, 0)
	if _installs == 0 and _logger != null:
		OS.remove_logger(_logger)
		_logger = null


static func note(msg: String) -> void:
	add(LEVEL_NOTE, msg)


static func warn(msg: String) -> void:
	add(LEVEL_WARN, msg)


static func error(msg: String) -> void:
	add(LEVEL_ERROR, msg)


## Adds one line to the ring (the oldest drops when it is full). Thread-safe: engine errors can arrive from any thread.
static func add(level: int, msg: String) -> void:
	var lv: int = clampi(level, LEVEL_NOTE, LEVEL_ERROR)
	var line: String = clean(msg)
	_mutex.lock()
	_lines.append({"t": float(Time.get_ticks_msec()) / 1000.0, "level": lv, "msg": line})
	if _lines.size() > CAPACITY:
		_lines.remove_at(0)
	_counts[lv] += 1
	_total += 1
	_mutex.unlock()
	if lv == LEVEL_ERROR:
		_write_file()


## A copy of the ring, oldest first.
static func lines() -> Array[Dictionary]:
	_mutex.lock()
	var out: Array[Dictionary] = _lines.duplicate()
	_mutex.unlock()
	return out


static func count(level: int) -> int:
	return _counts[clampi(level, LEVEL_NOTE, LEVEL_ERROR)]


static func total() -> int:
	return _total


static func clear() -> void:
	_mutex.lock()
	_lines.clear()
	_counts = PackedInt32Array([0, 0, 0])
	_total = 0
	_mutex.unlock()


## Strips the home folder and the user-data path (they hold the user name) and caps the length.
static func clean(msg: String) -> String:
	var s: String = msg.replace("\r", " ").replace("\n", " | ")
	for secret: String in [OS.get_environment("HOME"), OS.get_environment("USERPROFILE"), OS.get_user_data_dir(),
			OS.get_environment("USERNAME")]:
		if secret.length() >= 3:
			s = s.replace(secret, "~")
	if s.length() > MAX_LINE:
		s = s.substr(0, MAX_LINE) + "..."
	return s


## The report text: build and machine facts, counts, the optional game context, and the newest lines.
static func report() -> String:
	var out: PackedStringArray = PackedStringArray()
	out.append("Cursed Pawn diagnostics")
	out.append("version: %s" % str(ProjectSettings.get_setting("application/config/version", "dev")))
	out.append("engine: %s" % Engine.get_version_info().get("string", "?"))
	out.append("os: %s %s, %s, %s" % [OS.get_name(), OS.get_version(), OS.get_model_name(), OS.get_locale()])
	out.append("renderer: %s / %s" % [str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")),
		RenderingServer.get_video_adapter_name() if DisplayServer.get_name() != "headless" else "headless"])
	out.append("window: %s, web: %s, debug build: %s" % [str(DisplayServer.window_get_size()), OS.has_feature("web"),
		OS.is_debug_build()])
	out.append("uptime: %.0f s, lines logged: %d (warn %d, error %d)" % [float(Time.get_ticks_msec()) / 1000.0, _total,
		_counts[LEVEL_WARN], _counts[LEVEL_ERROR]])
	if context.is_valid():
		out.append("game: " + clean(str(context.call())))
	out.append("--- newest %d lines (seconds since start) ---" % REPORT_LINES)
	var all: Array[Dictionary] = lines()
	for i: int in range(maxi(0, all.size() - REPORT_LINES), all.size()):
		var e: Dictionary = all[i]
		out.append("%8.2f %-5s %s" % [float(e["t"]), LEVEL_NAMES[int(e["level"])], str(e["msg"])])
	return "\n".join(out)


## Puts the report on the clipboard (the settings screen's "copy diagnostics" button) and returns it.
static func copy_report() -> String:
	var text: String = report()
	DisplayServer.clipboard_set(text)
	return text


static func _write_file() -> void:
	if Flags.is_scripted_run():
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _last_write < FILE_GAP_SECS:
		return
	_last_write = now
	var f: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(report())


## The engine hook: script and engine errors and warnings go into the ring. Called from any thread.
class _EngineLogger extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var level: int = DiagLog.LEVEL_WARN if error_type == Logger.ERROR_TYPE_WARNING else DiagLog.LEVEL_ERROR
		var what: String = rationale if rationale != "" else code
		DiagLog.add(level, "%s (%s:%d in %s)" % [what, file.get_file(), line, function])
