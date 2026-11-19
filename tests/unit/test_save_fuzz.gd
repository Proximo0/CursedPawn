extends TestCase
## Fuzz-loads damaged, mistyped, truncated and older profile and run saves: nothing may crash, and a bad file is moved to a
## backup while the player starts from defaults. Helpers are prefixed sf_.

var SF_PROFILE: String = "user://test_fuzz_profile_%d.json" % OS.get_process_id()  # per process: other runs share user://
var SF_RUN: String = "user://test_fuzz_run_%d.save" % OS.get_process_id()
const SF_ODD: Array = [null, 5, -1, 1.0e30, "x", "", true, [], [1, 2], {}, {"a": 1}, [{"b": 2}]]


func sf_store() -> RelicStore:
	return RelicStore.create(CurioCollection.create(7, Tuning.new()))


func sf_clean() -> void:
	for p: String in [SF_PROFILE, SF_RUN]:
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p + suffix))


func sf_write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func sf_write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


## A well-used profile with something in every block.
func sf_good_profile() -> Dictionary:
	var s := sf_store()
	s.set_age(30, true)
	s.fulfill("sealed_10", "p1")
	s.collection.open_box()
	s.ecto = 40
	s.upgrades = {"keen_eye": 2}
	s.regulars = {"march": 2}
	s.deeds = PackedStringArray(["first_dawn"])
	s.haunting_unlocked = 3
	s.best_cash = 250
	s.daily_best = {"2026-11-19": {"number": 3, "night": 5, "cash": 90, "won": true, "wakes": 1}}
	PlayerProfile.save(s, SF_PROFILE)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SF_PROFILE))
	return parsed


## Loads `text` as the profile file and returns true when the load ended cleanly: either applied sensible values, or reset
## with a backup and an untouched store.
func sf_profile_survives(text: String, label: String) -> bool:
	sf_clean()
	sf_write_text(SF_PROFILE, text)
	var s := sf_store()
	var ok: bool = PlayerProfile.load_into(s, SF_PROFILE)
	var status: String = str(PlayerProfile.last_load["status"])
	if ok:
		assert_eq(status, "ok", label)
		assert_true(s.ecto >= 0 and s.carry_cash >= 0 and s.best_cash >= -1000000000000000, label + " sane numbers")
		assert_true(s.haunting_unlocked >= 0 and s.haunting_unlocked <= Hauntings.MAX_LEVEL, label + " haunting range")
		return true
	assert_true(status == "reset" or status == "missing", label + " status " + status)
	assert_eq(s.ecto, 0, label + " store untouched")
	assert_false(s.is_open(), label + " store untouched")
	if status == "reset":
		assert_true(FileAccess.file_exists(SF_PROFILE + ".bak"), label + " backup kept")
		assert_false(FileAccess.file_exists(SF_PROFILE), label + " bad file moved away")
	return false


func test_good_profile_loads_unchanged() -> void:
	var good: Dictionary = sf_good_profile()
	assert_true(sf_profile_survives(JSON.stringify(good), "good"))
	var s := sf_store()
	assert_true(PlayerProfile.load_into(s, SF_PROFILE))
	assert_eq(s.ecto, 40)
	assert_eq(s.upgrades, {"keen_eye": 2})
	sf_clean()


func test_truncated_profiles_reset_with_a_backup() -> void:
	var text: String = JSON.stringify(sf_good_profile())
	var resets: int = 0
	for cut: int in range(0, text.length() - 1, maxi(1, text.length() / 40)):
		if not sf_profile_survives(text.substr(0, cut), "cut %d" % cut):
			resets += 1
	assert_true(resets >= 35, "nearly every truncation is refused: %d" % resets)
	sf_clean()


func test_every_field_with_every_wrong_type() -> void:
	var good: Dictionary = sf_good_profile()
	var tried: int = 0
	var refused: int = 0
	var paths: Array = []
	for k1: Variant in good:
		paths.append([k1])
		if good[k1] is Dictionary:
			for k2: Variant in good[k1]:
				paths.append([k1, k2])
				if good[k1][k2] is Dictionary:
					for k3: Variant in good[k1][k2]:
						paths.append([k1, k2, k3])
	for path: Array in paths:
		for odd: Variant in SF_ODD:
			var d: Dictionary = good.duplicate(true)
			var node: Dictionary = d
			for i: int in range(path.size() - 1):
				node = node[path[i]]
			if typeof(node[path[-1]]) == typeof(odd) and not (odd is Dictionary or odd is Array):
				continue
			node[path[-1]] = odd
			tried += 1
			if not sf_profile_survives(JSON.stringify(d), "%s=%s" % [str(path), str(odd)]):
				refused += 1
	assert_true(tried > 200, "fuzz volume %d" % tried)
	assert_true(refused > 0, "some wrong types are refused")
	sf_clean()


func test_garbage_and_empty_files() -> void:
	for text: String in ["", "{", "[]", "null", "42", "\"profile\"", "{\"version\": \"two\"}", "{\"store\": 5}", "\u0001\u0002", "{}"]:
		sf_profile_survives(text, "garbage '%s'" % text.c_escape())
	sf_clean()


func test_older_versions_load_with_defaults() -> void:
	var good: Dictionary = sf_good_profile()
	for version: int in [1, 2, 3, 4]:
		var old: Dictionary = {"version": version, "store": (good["store"] as Dictionary).duplicate(true)}
		if version >= 2:
			old["grimoire"] = good["grimoire"]
		if version >= 3:
			old["progress"] = good["progress"]
		if version >= 4:
			old["altar"] = good["altar"]
		assert_true(sf_profile_survives(JSON.stringify(old), "version %d" % version))
		var s := sf_store()
		PlayerProfile.load_into(s, SF_PROFILE)
		assert_true(s.tutorial_done, "an older file counts the tutorial as done")
		assert_eq(s.deeds.size(), 0)
	var newer: Dictionary = good.duplicate(true)
	newer["version"] = PlayerProfile.VERSION + 3
	assert_false(sf_profile_survives(JSON.stringify(newer), "newer"))
	assert_eq(PlayerProfile.last_load["why"], "saved by a newer version")
	sf_clean()


func test_random_byte_flips_in_a_profile() -> void:
	var text: PackedByteArray = JSON.stringify(sf_good_profile()).to_utf8_buffer()
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i: int in range(150):
		var b: PackedByteArray = text.duplicate()
		for n: int in range(rng.randi_range(1, 4)):
			b[rng.randi_range(0, b.size() - 1)] = rng.randi_range(32, 126)  # printable: invalid UTF-8 only makes engine noise
		sf_profile_survives(b.get_string_from_utf8(), "flip %d" % i)
	sf_clean()


# ---- the saved run

func sf_good_run() -> Dictionary:
	var run := RunState.new()
	run.start(33, Catalog.load_default(), Tuning.new())
	var bot := ShopBot.new(ShopBot.CAUTIOUS)
	for i: int in range(30):
		if not run.is_over():
			run.apply(bot.decide(run))
	return {"version": PlayerProfile.VERSION, "run": run.snapshot(), "rec": {"seed": 33}}


func sf_run_survives(d: Variant, label: String) -> bool:
	sf_clean()
	sf_write_bytes(SF_RUN, var_to_bytes(d))
	var out: Dictionary = PlayerProfile.load_run(Catalog.load_default(), SF_RUN)
	var status: String = str(PlayerProfile.last_load["status"])
	if not out.is_empty():
		assert_eq(status, "ok", label)
		var run: RunState = out["run"]
		var bot := ShopBot.new(ShopBot.GREEDY)
		var steps: int = 0
		while not run.is_over() and steps < 400:  # a loaded run must keep playing without errors
			run.apply(bot.decide(run))
			steps += 1
		assert_true(run.is_over() or steps >= 400, label + " plays on")
		return true
	assert_eq(status, "reset", label)
	assert_true(FileAccess.file_exists(SF_RUN + ".bak"), label + " backup kept")
	assert_false(FileAccess.file_exists(SF_RUN), label + " bad file moved away")
	return false


func test_good_run_loads_and_plays_on() -> void:
	assert_true(sf_run_survives(sf_good_run(), "good run"))
	sf_clean()


func test_run_fields_with_wrong_types() -> void:
	var good: Dictionary = sf_good_run()
	var tried: int = 0
	var refused: int = 0
	for key: Variant in good["run"]:
		for odd: Variant in SF_ODD:
			var d: Dictionary = good.duplicate(true)
			if typeof(d["run"][key]) == typeof(odd) and not (odd is Dictionary or odd is Array):
				continue
			d["run"][key] = odd
			tried += 1
			if not sf_run_survives(d, "run.%s=%s" % [key, str(odd)]):
				refused += 1
	assert_true(tried > 300, "fuzz volume %d" % tried)
	assert_true(refused > 100, "most wrong types are refused: %d" % refused)
	sf_clean()


func test_run_inventory_and_customer_entries_with_wrong_types() -> void:
	var good: Dictionary = sf_good_run()
	for where: String in ["inventory", "customer"]:
		var base: Variant = good["run"][where]
		var targets: Array = []
		if where == "inventory" and (base as Array).size() > 0:
			targets = [(base as Array)[0]]
		elif where == "customer":
			targets = [base]
		for t: Variant in targets:
			for key: Variant in (t as Dictionary):
				for odd: Variant in SF_ODD:
					var d: Dictionary = good.duplicate(true)
					var node: Dictionary = d["run"][where][0] if where == "inventory" else d["run"][where]
					node[key] = odd
					sf_run_survives(d, "%s.%s=%s" % [where, key, str(odd)])
	sf_clean()


func test_missing_run_keys_and_older_version() -> void:
	var good: Dictionary = sf_good_run()
	for key: Variant in good["run"]:
		var d: Dictionary = good.duplicate(true)
		(d["run"] as Dictionary).erase(key)
		sf_run_survives(d, "missing run.%s" % key)
	var old: Dictionary = good.duplicate(true)
	old["version"] = 3
	for key: String in ["twin", "night_event", "ending", "curses_held", "wake_types", "events_seen", "whispered", "copies", "haggle_wins",
			"twin_sales", "unseen_cash", "regular", "tutorial", "collector"]:
		(old["run"] as Dictionary).erase(key)
	assert_true(sf_run_survives(old, "an older run save"), "an older save without the new keys still loads")
	var newer: Dictionary = good.duplicate(true)
	newer["version"] = PlayerProfile.VERSION + 1
	assert_false(sf_run_survives(newer, "newer"))
	sf_clean()


func test_truncated_and_garbage_run_files() -> void:
	var bytes: PackedByteArray = var_to_bytes(sf_good_run())
	for cut: int in range(0, bytes.size() - 1, maxi(1, bytes.size() / 40)):
		sf_clean()
		sf_write_bytes(SF_RUN, bytes.slice(0, cut))
		var out: Dictionary = PlayerProfile.load_run(Catalog.load_default(), SF_RUN)
		assert_true(out.is_empty(), "cut %d is refused" % cut)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i: int in range(60):
		var b: PackedByteArray = bytes.duplicate()
		for n: int in range(rng.randi_range(1, 5)):
			b[rng.randi_range(0, b.size() - 1)] = rng.randi_range(0, 255)
		sf_clean()
		sf_write_bytes(SF_RUN, b)
		var res: Dictionary = PlayerProfile.load_run(Catalog.load_default(), SF_RUN)
		if not res.is_empty():
			var run: RunState = res["run"]
			var bot := ShopBot.new()
			var steps: int = 0
			while not run.is_over() and steps < 400:
				run.apply(bot.decide(run))
				steps += 1
	sf_clean()
