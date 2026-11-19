class_name PlayerProfile
extends RefCounted
## The saved player profile: the reliquary shop, its purchase log and the curio collection. One JSON file,
## written to a temp file and renamed so a crash mid-write never corrupts it. Callers skip saving on scripted
## runs (`Flags.is_scripted_run()`), so tests and captures never touch player data.

const PATH: String = "user://profile.json"
const VERSION: int = 5  ## 5 adds the regulars, deeds and the tutorial flag (older files count the tutorial as done), 2 adds the grimoire, 3 the progress record (hauntings, best cash, daily), 4 the altar (ecto, upgrades, carry cash); older files load with defaults
const DAILY_KEEP: int = 30


static func save(store: RelicStore, path: String = PATH) -> Error:
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": VERSION, "store": store.to_dict(), "grimoire": Array(store.grimoire),
		"progress": {"haunting_unlocked": store.haunting_unlocked, "best_cash": store.best_cash, "daily_last": store.daily_last,
			"daily_best": store.daily_best},
		"altar": {"ecto": store.ecto, "upgrades": store.upgrades, "carry_cash": store.carry_cash},
		"journal": {"regulars": store.regulars, "deeds": Array(store.deeds), "tutorial_done": store.tutorial_done}}))
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


## What the last load found: {status: "" | "ok" | "missing" | "reset", why, backup}. "reset" means the file was damaged, wrong
## or from a newer version: it was moved to `backup` (`<path>.bak`) and the player starts from defaults. The UI can tell them.
static var last_load: Dictionary = {"status": "", "why": "", "backup": ""}


static func _load_result(status: String, why: String = "", backup: String = "") -> void:
	last_load = {"status": status, "why": why, "backup": backup}


## Loads a saved profile into `store`. Returns false (and leaves the store as it is) when there is no file or it
## is unreadable, damaged or from a newer version; a damaged file is moved to `<path>.bak` (see `last_load`).
static func load_into(store: RelicStore, path: String = PATH) -> bool:
	if not FileAccess.file_exists(path):
		_load_result("missing")
		return false
	var json := JSON.new()  # parse() reports an error code quietly; parse_string prints an engine error on bad input
	var parsed: Variant = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	var why: String = "not valid JSON" if parsed == null else SaveGuard.profile_problem(parsed, VERSION)
	if why != "":
		_load_result("reset", why, SaveGuard.quarantine(path))
		return false
	_load_result("ok")
	store.from_dict(parsed["store"])
	store.grimoire = PackedStringArray(parsed.get("grimoire", Array(Grimoire.DEFAULT_KNOWN)))
	var pr: Dictionary = parsed.get("progress", {}) if parsed.get("progress") is Dictionary else {}
	store.haunting_unlocked = clampi(int(pr.get("haunting_unlocked", 0)), 0, Hauntings.MAX_LEVEL)
	store.best_cash = int(pr.get("best_cash", 0))
	store.daily_last = str(pr.get("daily_last", ""))
	store.daily_best = (pr.get("daily_best", {}) as Dictionary).duplicate(true) if pr.get("daily_best") is Dictionary else {}
	var al: Dictionary = parsed.get("altar", {}) if parsed.get("altar") is Dictionary else {}
	store.ecto = maxi(0, int(al.get("ecto", 0)))
	store.upgrades = Upgrades.clean(al.get("upgrades", {}) if al.get("upgrades") is Dictionary else {})
	store.carry_cash = maxi(0, int(al.get("carry_cash", 0)))
	var jr: Dictionary = parsed.get("journal", {}) if parsed.get("journal") is Dictionary else {}
	store.regulars = Regulars.clean(jr.get("regulars", {}) if jr.get("regulars") is Dictionary else {})
	store.deeds = PackedStringArray()
	for id: Variant in (jr.get("deeds", []) as Array if jr.get("deeds") is Array else []):
		if not Deeds.get_deed(str(id)).is_empty() and not store.deeds.has(str(id)):
			store.deeds.append(str(id))
	store.tutorial_done = bool(jr.get("tutorial_done", int(parsed.get("version", 0)) < 5))
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


## The run options the altar adds for the next run: {upgrades: ranks, carry_cash}. Merge into the opts passed to
## RunState.start (empty when the player has neither).
static func altar_opts(store: RelicStore) -> Dictionary:
	var out: Dictionary = {}
	if not store.upgrades.is_empty():
		out["upgrades"] = store.upgrades.duplicate()
	if store.carry_cash > 0:
		out["carry_cash"] = store.carry_cash
	out["regulars"] = store.regulars.duplicate()  # the key switches the regulars' visits on
	return out


## Whether the next run is the guided first night (the profile's tutorial is not done). Merge `Tutorial.opts()` and
## use `Tutorial.SEED` for it.
static func needs_tutorial(store: RelicStore) -> bool:
	return not store.tutorial_done


## Records a finished run: unlocks the next haunting on a win at the highest unlocked one, keeps the best winning
## cash, and, for a daily run, the first attempt of the date (`opts.date`, else the system date). Returns
## {unlocked: new haunting level or 0, new_best: bool, daily_counted: bool, ecto: earned, carried: cash kept on a loss,
## deeds_new: ids newly inked in the Ledger}. It also advances `store.regulars` from `run.regular_progress`, marks a
## tutorial run done and appends the new deeds to `store.deeds`. Call after bank_finds so found curios count for the
## deeds. Callers skip it on scripted runs and save after.
static func record_result(run: RunState, store: RelicStore) -> Dictionary:
	var out: Dictionary = {"unlocked": 0, "new_best": false, "daily_counted": false, "ecto": 0, "carried": 0, "deeds_new": PackedStringArray()}
	var level: int = int(run.opts.get("haunting", 0))
	if run.won:
		if level >= store.haunting_unlocked and store.haunting_unlocked < Hauntings.MAX_LEVEL:
			store.haunting_unlocked += 1
			out["unlocked"] = store.haunting_unlocked
		if run.cash > store.best_cash:
			store.best_cash = run.cash
			out["new_best"] = true
	out["ecto"] = Upgrades.ecto_for(run)
	store.ecto += int(out["ecto"])
	store.carry_cash = 0
	if not run.won:
		var frac: float = float(Upgrades.flags_for(store.upgrades).get("loss_cash_frac", 0.0))
		store.carry_cash = int(run.cash * frac)
		out["carried"] = store.carry_cash
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
	for id: Variant in run.regular_progress:
		store.regulars[str(id)] = maxi(int(store.regulars.get(str(id), 0)), int(run.regular_progress[id]))
	if bool(run.opts.get("tutorial", false)):
		store.tutorial_done = true
	var earned: PackedStringArray = Deeds.check(run, store)
	store.deeds.append_array(earned)
	out["deeds_new"] = earned
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
## unreadable, damaged or from a newer version (a damaged file moves to `<path>.bak`; see `last_load`).
static func load_run(cat: Catalog, path: String = RUN_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		_load_result("missing")
		return {}
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var d: Variant = bytes_to_var(bytes) if SaveGuard.looks_like_variant_dict(bytes) else null
	var why: String = "unreadable" if d == null else SaveGuard.run_problem(d, VERSION)
	if why != "":
		_load_result("reset", why, SaveGuard.quarantine(path))
		return {}
	var run := RunState.new()
	run.restore(d["run"], cat)
	_load_result("ok")
	return {"run": run, "rec": d.get("rec", {}) if d.get("rec") is Dictionary else {}}


static func clear_run(path: String = RUN_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
