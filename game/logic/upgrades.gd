class_name Upgrades
extends RefCounted
## Altar upgrades from game/data/upgrades.json: {id, name, text, cost, max_rank, set, mul, add, flags}. Earned with
## ectoplasm only, never sold. Ranks are {id: rank}. Per rank: `add` adds, `mul` compounds, `set` sets (any rank > 0).
## Flags RunState reads: start_spell, pendulum (bool), loss_cash_frac (kept on a loss, per rank, read by PlayerProfile).
## Ranks travel in run_opts.upgrades, so the same overrides replay from RunRecording.opts.

const PATH: String = "res://game/data/upgrades.json"
const FLAGS: PackedStringArray = ["start_spell", "pendulum", "loss_cash_frac"]
const ECTO_HAUNTING_BONUS: float = 0.1


static func all() -> Array[Dictionary]:
	return DataFiles.read_array(PATH)


static func get_upgrade(id: String) -> Dictionary:
	for u: Dictionary in all():
		if str(u["id"]) == id:
			return u
	return {}


## Ranks cleaned to known ids and 0 < rank <= max_rank.
static func clean(ranks: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in ranks:
		var u: Dictionary = get_upgrade(str(key))
		var r: int = clampi(int(ranks[key]), 0, int(u.get("max_rank", 0)))
		if r > 0:
			out[str(key)] = r
	return out


## Applies the ranks to `tun` and returns {overrides: {field: value}, flags: {flag: value}}.
static func apply(tun: Tuning, ranks: Dictionary) -> Dictionary:
	var overrides: Dictionary = {}
	var flags: Dictionary = {}
	var clean_ranks: Dictionary = clean(ranks)
	for u: Dictionary in all():
		var r: int = int(clean_ranks.get(str(u["id"]), 0))
		if r == 0:
			continue
		for field: Variant in (u.get("set", {}) as Dictionary):
			tun.set_value(str(field), float(u["set"][field]))
			overrides[str(field)] = float(tun.get(str(field)))
		for field: Variant in (u.get("mul", {}) as Dictionary):
			tun.set_value(str(field), float(tun.get(str(field))) * pow(float(u["mul"][field]), r))
			overrides[str(field)] = float(tun.get(str(field)))
		for field: Variant in (u.get("add", {}) as Dictionary):
			tun.set_value(str(field), float(tun.get(str(field))) + float(u["add"][field]) * r)
			overrides[str(field)] = float(tun.get(str(field)))
		for flag: Variant in (u.get("flags", {}) as Dictionary):
			var v: Variant = u["flags"][flag]
			flags[str(flag)] = float(v) * r if v is float or v is int else v
	return {"overrides": overrides, "flags": flags}


## The flags alone (no tuning needed).
static func flags_for(ranks: Dictionary) -> Dictionary:
	return apply(Tuning.new(), ranks)["flags"]


## Cost of the next rank of `id` at `rank`: the listed cost times the rank being bought.
static func cost_of(id: String, rank: int) -> int:
	return int(get_upgrade(id).get("cost", 0)) * (rank + 1)


## Ectoplasm to buy every rank of every upgrade (the lab's "runs to max everything").
static func total_cost() -> int:
	var t: int = 0
	for u: Dictionary in all():
		for r: int in range(int(u["max_rank"])):
			t += cost_of(str(u["id"]), r)
	return t


## Buys one rank of `id` with the profile's ectoplasm. `profile` is the RelicStore (ecto, upgrades).
## Returns {ok, why, rank, cost}; why is "" on success.
static func buy(id: String, profile: RelicStore) -> Dictionary:
	var u: Dictionary = get_upgrade(id)
	if u.is_empty():
		return {"ok": false, "why": "unknown upgrade", "rank": 0, "cost": 0}
	var rank: int = int(profile.upgrades.get(id, 0))
	var cost: int = cost_of(id, rank)
	if rank >= int(u["max_rank"]):
		return {"ok": false, "why": "already at max rank", "rank": rank, "cost": cost}
	if profile.ecto < cost:
		return {"ok": false, "why": "not enough ectoplasm", "rank": rank, "cost": cost}
	profile.ecto -= cost
	profile.upgrades[id] = rank + 1
	return {"ok": true, "why": "", "rank": rank + 1, "cost": cost}


## Ectoplasm a finished run earns: per night survived plus the win bonus, times (1 + 0.1 * haunting).
static func ecto_for(run: RunState) -> int:
	var survived: int = int(run.tuning.nights) if run.won else maxi(0, run.night - 1)
	var base: float = float(survived) * run.tuning.ecto_per_night + (run.tuning.ecto_win_bonus if run.won else 0.0)
	return int(round(base * (1.0 + ECTO_HAUNTING_BONUS * float(int(run.opts.get("haunting", 0))))))


static func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var ids: Dictionary = {}
	for u: Dictionary in all():
		var id: String = str(u.get("id", ""))
		if ids.has(id):
			out.append("upgrade %s duplicated" % id)
		ids[id] = true
		for line: String in DataFiles.rule_problems("upgrade %s" % id, u, FLAGS):
			out.append(line)
		for field: Variant in (u.get("add", {}) as Dictionary):
			if Tuning.field_info(str(field)).is_empty():
				out.append("upgrade %s: unknown tuning field %s" % [id, field])
		if int(u.get("cost", 0)) <= 0 or int(u.get("max_rank", 0)) <= 0:
			out.append("upgrade %s needs a cost and max_rank" % id)
	if ids.size() < 8:
		out.append("fewer than 8 upgrades")
	return out
