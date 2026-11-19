extends TestCase
## DiagLog: the ring keeps the newest lines, counts levels, scrubs the home folder, builds a report; nothing is sent.


func _reset() -> void:
	DiagLog.clear()
	DiagLog.context = Callable()


func test_ring_keeps_the_newest_capacity_lines() -> void:
	_reset()
	for i: int in range(DiagLog.CAPACITY + 25):
		DiagLog.note("line %d" % i)
	var all: Array[Dictionary] = DiagLog.lines()
	assert_eq(all.size(), DiagLog.CAPACITY)
	assert_eq(str(all[0]["msg"]), "line 25")
	assert_eq(str(all[all.size() - 1]["msg"]), "line %d" % (DiagLog.CAPACITY + 24))
	assert_eq(DiagLog.total(), DiagLog.CAPACITY + 25)


func test_levels_are_counted() -> void:
	_reset()
	DiagLog.note("a")
	DiagLog.warn("b")
	DiagLog.warn("c")
	DiagLog.error("d")
	assert_eq(DiagLog.count(DiagLog.LEVEL_NOTE), 1)
	assert_eq(DiagLog.count(DiagLog.LEVEL_WARN), 2)
	assert_eq(DiagLog.count(DiagLog.LEVEL_ERROR), 1)
	DiagLog.clear()
	assert_eq(DiagLog.total(), 0)


func test_clean_scrubs_paths_newlines_and_length() -> void:
	_reset()
	var home: String = OS.get_environment("HOME")
	if home.length() >= 3:
		assert_false(DiagLog.clean("failed at " + home + "/secret/file").contains(home), "home folder removed")
	assert_eq(DiagLog.clean("a\nb"), "a | b")
	assert_true(DiagLog.clean("x".repeat(1000)).length() <= DiagLog.MAX_LINE + 3)


func test_report_has_facts_context_and_newest_lines() -> void:
	_reset()
	for i: int in range(DiagLog.REPORT_LINES + 10):
		DiagLog.note("event %d" % i)
	DiagLog.context = func() -> String: return "night 3 cash 120"
	var text: String = DiagLog.report()
	assert_true(text.contains("Cursed Pawn diagnostics"))
	assert_true(text.contains("engine: "))
	assert_true(text.contains("game: night 3 cash 120"))
	assert_true(text.contains("event %d" % (DiagLog.REPORT_LINES + 9)), "newest line present")
	assert_false(text.contains("event 0\n") or text.contains(" event 0 "), "oldest lines are left out")


func test_engine_logger_feeds_the_ring() -> void:
	_reset()
	var lg: Object = DiagLog._EngineLogger.new()
	lg._log_error("fn", "res://game/x.gd", 12, "code", "it broke", false, Logger.ERROR_TYPE_SCRIPT, [] as Array[ScriptBacktrace])
	lg._log_error("fn", "res://game/x.gd", 13, "code", "", false, Logger.ERROR_TYPE_WARNING, [] as Array[ScriptBacktrace])
	assert_eq(DiagLog.count(DiagLog.LEVEL_ERROR), 1)
	assert_eq(DiagLog.count(DiagLog.LEVEL_WARN), 1)
	assert_true(str(DiagLog.lines()[0]["msg"]).contains("it broke (x.gd:12 in fn)"))


func test_install_is_idempotent_and_scripted_runs_write_no_file() -> void:
	_reset()
	assert_true(DiagLog.install())
	assert_true(DiagLog.install())
	DiagLog.error("boom")
	DiagLog.uninstall()
	DiagLog.uninstall()
	assert_true(DiagLog._logger == null, "hook removed when the count reaches zero")
	if Flags.is_scripted_run():
		assert_false(FileAccess.file_exists(DiagLog.FILE_PATH) and FileAccess.get_modified_time(DiagLog.FILE_PATH) > Time.get_unix_time_from_system() - 5, "no file written")
