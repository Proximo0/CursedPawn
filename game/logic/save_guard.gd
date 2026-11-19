class_name SaveGuard
extends RefCounted
## Validates a loaded profile or run save before anything reads it, so a truncated, hand-edited, mistyped or damaged file can
## never crash the game. A file that fails is moved to `<path>.bak` (the player keeps it) and the game starts from defaults.
## Missing keys are fine (older versions load with defaults); a key that is present must have the right type.

const LIMIT: float = 1.0e15


static func _num(v: Variant) -> bool:
	return (v is int) or ((v is float) and is_finite(v) and absf(v) < LIMIT)


static func _kind_ok(v: Variant, kind: String) -> bool:
	match kind:
		"num":
			return _num(v)
		"str":
			return v is String
		"bool":
			return v is bool
		"dict":
			return v is Dictionary
		"arr":
			return v is Array
		"numstr":
			return _num(v) or v is String
	return false


## "" when every key of `schema` ({key: kind}) that `d` has is of its kind, else a short reason.
static func _shape(d: Variant, schema: Dictionary, where: String) -> String:
	if not d is Dictionary:
		return "%s is not an object" % where
	for key: Variant in schema:
		if d.has(key) and not _kind_ok(d[key], str(schema[key])):
			return "%s.%s is not a %s" % [where, key, schema[key]]
	return ""


static func _all_kind(items: Variant, kind: String, where: String) -> String:
	var values: Array = (items as Dictionary).values() if items is Dictionary else (items as Array)
	for v: Variant in values:
		if not _kind_ok(v, kind):
			return "%s holds a bad entry" % where
	return ""


## Why a parsed profile (the JSON root) cannot be used, or "".
static func profile_problem(parsed: Variant, max_version: int) -> String:
	var why: String = _shape(parsed, {"version": "num", "store": "dict", "grimoire": "arr", "progress": "dict", "altar": "dict",
		"journal": "dict"}, "profile")
	if why != "":
		return why
	var root: Dictionary = parsed
	if not root.get("store") is Dictionary:
		return "no store"
	if int(root.get("version", 0)) > max_version:
		return "saved by a newer version"
	if int(root.get("version", 0)) < 0:
		return "bad version"
	var store: Dictionary = root["store"]
	why = _shape(store, {"age_checked": "bool", "age_ok": "bool", "terms_accepted": "str", "log": "arr", "collection": "dict"}, "store")
	if why != "":
		return why
	for entry: Variant in store.get("log", []):
		why = _shape(entry, {"n": "num", "id": "str", "price_cents": "num", "payment_ref": "str", "delivered": "arr", "refunded": "bool"}, "log entry")
		if why != "":
			return why
		for key: String in ["n", "id", "price_cents", "refunded"]:
			if not (entry as Dictionary).has(key):
				return "log entry lacks %s" % key
	why = _shape(store.get("collection", {}), {"owned": "dict", "tradeable": "dict", "free_boxes": "num", "paid_boxes": "num",
		"shards_locked": "num", "shards_free": "num", "since_legendary": "num", "opened": "num", "featured_id": "str",
		"appraised": "dict", "claimed_sets": "arr", "rng_state": "numstr"}, "collection")
	if why != "":
		return why
	var coll: Dictionary = store.get("collection", {})
	for key: String in ["owned", "tradeable"]:
		why = _all_kind(coll.get(key, {}), "num", "collection." + key)
		if why != "":
			return why
	why = _all_kind(coll.get("claimed_sets", []), "str", "collection.claimed_sets")
	if why != "":
		return why
	why = _all_kind(root.get("grimoire", []), "str", "grimoire")
	if why != "":
		return why
	why = _shape(root.get("progress", {}), {"haunting_unlocked": "num", "best_cash": "num", "daily_last": "str", "daily_best": "dict"}, "progress")
	if why != "":
		return why
	why = _all_kind((root.get("progress", {}) as Dictionary).get("daily_best", {}), "dict", "progress.daily_best")
	if why != "":
		return why
	why = _shape(root.get("altar", {}), {"ecto": "num", "upgrades": "dict", "carry_cash": "num"}, "altar")
	if why != "":
		return why
	why = _all_kind((root.get("altar", {}) as Dictionary).get("upgrades", {}), "num", "altar.upgrades")
	if why != "":
		return why
	why = _shape(root.get("journal", {}), {"regulars": "dict", "deeds": "arr", "tutorial_done": "bool"}, "journal")
	if why != "":
		return why
	why = _all_kind((root.get("journal", {}) as Dictionary).get("regulars", {}), "num", "journal.regulars")
	if why != "":
		return why
	return _all_kind((root.get("journal", {}) as Dictionary).get("deeds", []), "str", "journal.deeds")


const ITEM_KEYS: Dictionary = {"uid": "num", "id": "str", "name": "str", "category": "str", "value": "num", "curse": "str"}


## Why a saved run (the decoded root: {version, run, rec}) cannot be used, or "".
static func run_problem(d: Variant, max_version: int) -> String:
	var why: String = _shape(d, {"version": "num", "run": "dict", "rec": "dict"}, "save")
	if why != "":
		return why
	if not (d as Dictionary).get("run") is Dictionary:
		return "no run"
	if int((d as Dictionary).get("version", 0)) > max_version:
		return "saved by a newer version"
	var r: Dictionary = d["run"]
	for key: String in ["seed", "rng_state", "tuning", "night", "cash", "clock", "dread", "inventory", "customer", "customers_seen",
			"phase", "won", "wake_nights", "play_secs", "commands", "next_uid"]:  # restore() reads these without a default
		if not r.has(key):
			return "run lacks %s" % key
	why = _shape(r, _run_schema(), "run")
	if why != "":
		return why
	for key: String in ["wake_nights"]:
		why = _all_kind(r.get(key, []), "num", "run." + key)
		if why != "":
			return why
	for key: String in ["spells_known", "curses_held", "wake_types", "events_seen"]:
		why = _all_kind(r.get(key, []), "str", "run." + key)
		if why != "":
			return why
	if int(r["night"]) < 1 or int(r["night"]) > 99 or not ["customer", "table", "over"].has(str(r["phase"])):
		return "run has a bad night or phase"
	for k: Variant in r["tuning"]:
		if not _num((r["tuning"] as Dictionary)[k]):
			return "tuning.%s is not a number" % k
	for item: Variant in r["inventory"]:
		why = _shape(item, ITEM_KEYS, "inventory item")
		if why != "":
			return why
		for key: Variant in ITEM_KEYS:
			if not (item as Dictionary).has(key):
				return "inventory item lacks %s" % key
	for f: Variant in r.get("found", []):
		if not f is Dictionary or not (f as Dictionary).has("kind") or not (f as Dictionary).has("id"):
			return "found entry is bad"
	for e: Variant in r.get("requests", []):
		if not e is Dictionary:
			return "request is bad"
	var c: Dictionary = r["customer"]
	if not c.is_empty():
		if str(c.get("kind", "")) == "seller":
			why = _shape(c, {"item": "dict", "reserve": "num", "ask": "num", "patience": "num", "noise_u": "num", "tools": "arr",
				"tells": "arr", "imposter": "bool"}, "customer")
			if why != "":
				return why
			for key: String in ["item", "reserve", "ask", "patience", "noise_u", "tools", "tells", "imposter"]:
				if not c.has(key):
					return "seller lacks %s" % key
			why = _shape(c["item"], ITEM_KEYS, "customer item")
			if why != "":
				return why
			for key: Variant in ITEM_KEYS:
				if key != "uid" and not (c["item"] as Dictionary).has(key):
					return "customer item lacks %s" % key
		elif str(c.get("kind", "")) == "buyer":
			why = _shape(c, {"category": "str", "pay_mult": "num", "imposter": "bool", "offer": "dict", "limit": "num"}, "customer")
			if why != "":
				return why
			for key: String in ["category", "pay_mult", "imposter"]:
				if not c.has(key):
					return "buyer lacks %s" % key
		else:
			return "customer has no kind"
	return ""


## Whether `bytes` start like an encoded Dictionary (Variant type 27), so bytes_to_var is not fed obvious garbage.
static func looks_like_variant_dict(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 8 and bytes[0] == TYPE_DICTIONARY


static var _schema_cache: Dictionary = {}


## {key: kind} for every top-level key of a run snapshot, read off a fresh run so new counters are covered automatically.
static func _run_schema() -> Dictionary:
	if _schema_cache.is_empty():
		var run := RunState.new()
		run.start(1, Catalog.load_default(), Tuning.new())
		var snap: Dictionary = run.snapshot()
		for key: Variant in snap:
			var v: Variant = snap[key]
			var kind: String = "num"
			if v is String:
				kind = "str"
			elif v is bool:
				kind = "bool"
			elif v is Dictionary:
				kind = "dict"
			elif v is Array:
				kind = "arr"
			_schema_cache[key] = kind
	return _schema_cache


## Moves the damaged file at `path` to `<path>.bak` (replacing an older backup) and returns the backup path, "" on failure.
static func quarantine(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var bak: String = path + ".bak"
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bak))
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(bak)) != OK:
		return ""
	return bak
