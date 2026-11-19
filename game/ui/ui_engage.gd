class_name UiEngage
extends RefCounted
## UI-side helpers for the engagement round (docs/engagement_brief.md): haunting and omen data, today's Daily Seance
## number and result, the badge text, request wording, and the guarded call that starts a run with options. Pure
## statics. The real date is read here (UI layer) and handed to logic; logic never reads the clock. Everything that
## touches logic written in parallel (Omens, Daily, run.opts, profile fields) is reached through guards, so the UI
## still works on logic that has not landed.

const HAUNTINGS_PATH: String = "res://game/data/hauntings.json"
const OMENS_PATH: String = "res://game/data/omens.json"
const OMENS_SCRIPT: String = "res://game/logic/omens.gd"
const DAILY_SCRIPT: String = "res://game/logic/daily.gd"
const MAX_HAUNTING: int = 10
const ACCENTS: Dictionary = {"é": "E", "É": "E", "è": "E", "ü": "U", "ö": "O", "ï": "I", "—": "-", "–": "-",
	"’": "'", "‘": "'", "“": "\"", "”": "\"", "…": "..."}

static var force_hauntings: Array = []  ## sheets and tests: replace the data file
static var force_omens: Array = []
static var force_run_opts: Dictionary = {}  ## sheets and tests: the badge shows these instead of run.opts
static var force_date: Dictionary = {}  ## sheets and tests: pretend it is this {year, month, day}


## Upper-case ASCII for the pixel font: accents folded, anything else outside printable ASCII dropped.
static func ascii_up(s: String) -> String:
	var out: String = ""
	for i: int in range(s.length()):
		var ch: String = s[i]
		if ACCENTS.has(ch):
			out += str(ACCENTS[ch])
		elif ch.unicode_at(0) >= 32 and ch.unicode_at(0) < 127:
			out += ch
	return out.to_upper()


static func _list(forced: Array, path: String) -> Array[Dictionary]:
	var raw: Variant = forced if not forced.is_empty() else UiOccult.read_json(path)
	var out: Array[Dictionary] = []
	if raw is Array:
		for e: Variant in raw:
			if e is Dictionary:
				out.append(e as Dictionary)
	return out


# ---------------------------------------------------------------- hauntings and omens

## Haunting definitions sorted by level (empty until game/data/hauntings.json exists).
static func hauntings() -> Array[Dictionary]:
	var list: Array[Dictionary] = _list(force_hauntings, HAUNTINGS_PATH)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("level", 0)) < int(b.get("level", 0)))
	return list


## The highest level the picker can offer: the unlocked level, capped by the data and MAX_HAUNTING.
static func picker_max(unlocked: int) -> int:
	var top: int = 0
	for h: Dictionary in hauntings():
		top = maxi(top, int(h.get("level", 0)))
	return clampi(mini(unlocked, top), 0, MAX_HAUNTING)


static func haunting_def(level: int) -> Dictionary:
	for h: Dictionary in hauntings():
		if int(h.get("level", 0)) == level:
			return h
	return {}


static func haunting_name(level: int) -> String:
	return "A QUIET SHOP" if level <= 0 else ascii_up(str(haunting_def(level).get("name", "HAUNTING %d" % level)))


## The stacked rules of Haunting N: one {level, text} row per level 1..N, in order.
static func rule_rows(level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h: Dictionary in hauntings():
		var lv: int = int(h.get("level", 0))
		if lv >= 1 and lv <= level:
			out.append({"level": lv, "text": ascii_up(str(h.get("text", h.get("name", ""))))})
	return out


static func omen_def(id: String) -> Dictionary:
	for o: Dictionary in _list(force_omens, OMENS_PATH):
		if str(o.get("id", "")) == id:
			return o
	return {}


static func omen_name(id: String) -> String:
	return "" if id == "" else ascii_up(str(omen_def(id).get("name", id)))


static func omen_text(id: String) -> String:
	return ascii_up(str(omen_def(id).get("text", "")))


static func _logic(path: String) -> GDScript:
	return load(path) as GDScript if ResourceLoader.exists(path) else null


## Three omen ids for a seed (Omens.offer). Empty when the logic is absent or the data has no omens.
static func omen_offer(seed_in: int) -> Array[String]:
	var out: Array[String] = []
	var s: GDScript = _logic(OMENS_SCRIPT)
	if s != null and UiOccult.static_has(s, "offer"):
		for id: Variant in (s.call("offer", seed_in) as Array):
			out.append(str(id))
	elif not _list(force_omens, OMENS_PATH).is_empty():
		var all: Array[Dictionary] = _list(force_omens, OMENS_PATH)
		for i: int in range(mini(3, all.size())):
			out.append(str(all[posmod(seed_in + i * 5, all.size())].get("id", "")))
	return out


# ---------------------------------------------------------------- opts, the guarded start

## The run options in the shape RunState.start takes.
static func make_opts(haunting: int, omen: String, daily: bool) -> Dictionary:
	return {"haunting": haunting, "omen": omen, "daily": daily}


## True when an opts dictionary changes nothing (so today's start path is used unchanged).
static func opts_empty(opts: Dictionary) -> bool:
	return int(opts.get("haunting", 0)) == 0 and str(opts.get("omen", "")) == "" and not bool(opts.get("daily", false))


## RunRecording.begin with run options when the logic accepts them (its sixth parameter), else without them.
static func begin(run: RunState, seed_in: int, cat: Catalog, tun: Tuning, gift: Dictionary, opts: Dictionary) -> RunRecording:
	var s: GDScript = RunRecording as GDScript
	if not opts_empty(opts):
		for m: Dictionary in s.get_script_method_list():
			if str(m["name"]) == "begin" and (m["args"] as Array).size() >= 6:
				return s.call("begin", run, seed_in, cat, tun, gift, opts) as RunRecording
	return RunRecording.begin(run, seed_in, cat, tun, gift)


## The options a run applied (run.opts) or {} when the logic has none.
static func run_opts(run: RunState) -> Dictionary:
	if not force_run_opts.is_empty():
		return force_run_opts
	if run != null and "opts" in run and run.get("opts") is Dictionary:
		return run.get("opts") as Dictionary
	return {}


# ---------------------------------------------------------------- the badge

## What the badge by the night label shows: {text, tip: Array[String]}; empty text when the run has neither.
static func badge_info(run: RunState) -> Dictionary:
	var o: Dictionary = run_opts(run)
	var lv: int = int(o.get("haunting", 0))
	var omen: String = str(o.get("omen", ""))
	var parts: PackedStringArray = PackedStringArray()
	var tip: Array[String] = []
	if bool(o.get("daily", false)):
		parts.append("DAILY")
	if lv > 0:
		parts.append("HAUNTING %d" % lv)
		tip.append("HAUNTING %d: %s" % [lv, haunting_name(lv)])
		for row: Dictionary in rule_rows(lv):
			tip.append("%d. %s" % [int(row["level"]), str(row["text"])])
	if omen != "":
		parts.append(omen_name(omen))
		tip.append("OMEN: %s" % omen_name(omen))
		tip.append(omen_text(omen))
	return {"text": " + ".join(parts) if parts.size() <= 2 else "%s + %s" % [parts[0], parts[1]], "tip": tip}


# ---------------------------------------------------------------- Daily Seance

static func today() -> Dictionary:
	if not force_date.is_empty():
		return force_date
	var d: Dictionary = Time.get_date_dict_from_system()
	return {"year": int(d["year"]), "month": int(d["month"]), "day": int(d["day"])}


static func date_key(d: Dictionary) -> String:
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


static func daily_available() -> bool:
	var s: GDScript = _logic(DAILY_SCRIPT)
	return s != null and UiOccult.static_has(s, "seed_for") and UiOccult.static_has(s, "number")


static func daily_seed(d: Dictionary) -> int:
	return int(_logic(DAILY_SCRIPT).call("seed_for", int(d["year"]), int(d["month"]), int(d["day"])))


static func daily_number(d: Dictionary) -> int:
	if not daily_available():
		return 0
	return int(_logic(DAILY_SCRIPT).call("number", int(d["year"]), int(d["month"]), int(d["day"])))


## The paste-able result (Daily.result_text), "" when the logic is absent.
static func daily_result(run: RunState, number: int) -> String:
	var s: GDScript = _logic(DAILY_SCRIPT)
	if s == null or not UiOccult.static_has(s, "result_text"):
		return ""
	return str(s.call("result_text", run, number))


## The daily options: haunting 0, the first omen of the day's offer, daily set, plus the real date and number so the
## run (and the profile) never read the clock themselves.
static func daily_opts(seed_in: int, d: Dictionary) -> Dictionary:
	var offer: Array[String] = omen_offer(seed_in)
	var o: Dictionary = make_opts(0, offer[0] if not offer.is_empty() else "", true)
	o["date"] = date_key(d)
	o["number"] = daily_number(d)
	return o


## "" when today's daily has not been played; else a short line for the title ("NIGHT 5, 412 COINS" or the saved text).
static func played_line(store: Object, d: Dictionary) -> String:
	if store == null or not ("daily_last" in store) or str(store.get("daily_last")) != date_key(d):
		return ""
	var best: Variant = store.get("daily_best") if "daily_best" in store else null
	if best is Dictionary and (best as Dictionary).has(date_key(d)):
		var b: Variant = (best as Dictionary)[date_key(d)]
		if b is Dictionary:
			var bd: Dictionary = b as Dictionary
			return "NIGHT %d, %d COINS" % [int(bd.get("night", bd.get("nights", 0))), int(bd.get("cash", bd.get("coins", 0)))]
		return ascii_up(str(b))
	return "ALREADY PLAYED"


# ---------------------------------------------------------------- requests

## "CURSED DOLL" style wording of a request's want: {category, cursed}.
static func want_text(want: Dictionary) -> String:
	var cat: String = ascii_up(str(want.get("category", "")))
	var cursed: bool = bool(want.get("cursed", false))
	if cat == "":
		return "ANY CURSED THING" if cursed else "ANYTHING"
	return "CURSED " + cat if cursed else cat


## One board line from an open request (run.requests entry) or a request_new event.
static func request_line(req: Dictionary) -> String:
	var who: String = ascii_up(str(req.get("who", "SOMEONE")))
	var want: String = ascii_up(str(req["want_text"])) if req.has("want_text") else want_text(req.get("want", {}) as Dictionary)
	return "%s WANTS %s" % [who, want]
