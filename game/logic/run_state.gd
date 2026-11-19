class_name RunState
extends RefCounted
## One run of the shop: nights, customers, inspecting, haggling, rent, curses and Dread.
## Pure logic: seeded, no clock, driven only by apply(cmd). Every change comes back as a list of events.
## Commands and events are listed in docs/core_brief.md. Numbers come from `tuning` (a Tuning).

const PHASE_CUSTOMER: String = "customer"
const PHASE_TABLE: String = "table"  ## between nights: the Midnight Table
const PHASE_OVER: String = "over"
const SELLER: String = "seller"
const BUYER: String = "buyer"
const MAX_COMMANDS: int = 5000  ## a run that needs more is stuck

var tuning: Tuning
var catalog: Catalog
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_used: int = 0

var night: int = 1
var cash: int = 0
var clock: float = 0.0  ## day-clock minutes left today
var dread: float = 0.0
## Held items: {uid, id, name, category, value, curse, est, tells}. value and curse are hidden from the player;
## est (estimate when bought) and tells (tells seen) are what the player knows.
var inventory: Array[Dictionary] = []
## Current customer. Seller: {kind, item, reserve, ask, patience, noise_u, tools, tells, imposter}.
## Buyer: {kind, category, pay_mult, imposter}.
var customer: Dictionary = {}
var customers_seen: int = 0
var phase: String = PHASE_CUSTOMER
var won: bool = false
var wake_nights: Array[int] = []
var play_secs: float = 0.0  ## estimated real seconds a player would have spent
var commands: int = 0
var next_uid: int = 1
var last_events: Array[Dictionary] = []
## Occult round. spells_known is set by the caller before start(); found is {kind: "page"|"curio", id} for the
## caller to grant at run end; table is the Midnight Table state ({} outside PHASE_TABLE).
var spells_known: PackedStringArray = Grimoire.DEFAULT_KNOWN.duplicate()
var found: Array[Dictionary] = []
var casts_left: int = 0
var sealed: bool = false
var table: Dictionary = {}
var summon_category: String = ""  ## set by a summon: the next customer is a buyer of this category
var grimoire: Grimoire
var house: MidnightTable


## Starts a run. `gift` is an item passed on by a friend (its keys as in `inventory`); empty for none.
func start(seed_value: int, cat: Catalog, tun: Tuning = null, gift: Dictionary = {}) -> Array[Dictionary]:
	catalog = cat
	tuning = tun if tun != null else Tuning.shared()
	seed_used = seed_value
	rng.seed = seed_value
	_setup_rules()
	found.clear()
	casts_left = int(tuning.spell_casts_per_night)
	sealed = false
	table = {}
	summon_category = ""
	night = 1
	cash = int(tuning.start_cash)
	dread = 0.0
	inventory.clear()
	customer = {}
	customers_seen = 0
	phase = PHASE_CUSTOMER
	won = false
	wake_nights.clear()
	play_secs = 0.0
	commands = 0
	next_uid = 1
	if not gift.is_empty():
		var item: Dictionary = gift.duplicate(true)
		item["uid"] = _take_uid()
		inventory.append(item)
	clock = tuning.day_minutes
	var ev: Array[Dictionary] = [{"e": "night_start", "night": night, "rent": rent_for(night)}]
	_next_customer(ev)
	last_events = ev
	return ev


func _setup_rules() -> void:
	grimoire = Grimoire.new()
	grimoire.spells = catalog.spells
	grimoire.tuning = tuning
	house = MidnightTable.new()
	house.cfg = catalog.table
	house.tuning = tuning


func rent_for(n: int) -> int:
	return int(round(tuning.rent_base * pow(tuning.rent_growth, n - 1)))


func is_over() -> bool:
	return phase == PHASE_OVER


## What the player sees of the current seller's object: {mid, spread}. spread is a fraction of mid.
func estimate() -> Dictionary:
	if customer.get("kind", "") != SELLER:
		return {}
	var noise: float = tuning.value_noise * pow(tuning.inspect_noise_cut, (customer["tools"] as Array).size())
	var value: float = float(customer["item"]["value"])
	return {"mid": int(round(value * (1.0 + noise * float(customer["noise_u"])))), "spread": noise}


## Held items a buyer would take (matching category).
func sellable() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if customer.get("kind", "") != BUYER:
		return out
	for item: Dictionary in inventory:
		if item["category"] == customer["category"]:
			out.append(item)
	return out


## The price the current buyer offers for a held item. An imposter offers it too but never pays (see _sell).
func sale_price(item: Dictionary) -> int:
	if customer.get("kind", "") != BUYER:
		return 0
	var cursed: float = float(customer.get("cursed_mult", 1.0)) if str(item["curse"]) != "" else 1.0
	return int(round(float(item["value"]) * tuning.buyer_pay_frac * float(customer["pay_mult"]) * sale_mult() * cursed))


## Product of the sale multipliers of distinct curses held.
func sale_mult() -> float:
	var m: float = 1.0
	var seen: Dictionary = {}
	for item: Dictionary in inventory:
		var cid: String = item["curse"]
		if cid != "" and not seen.has(cid):
			seen[cid] = true
			m *= float(catalog.curse(cid).get("sale_mult", 1.0))
	return m


## Commands: {t: "inspect", tool}, {t: "offer", amount}, {t: "buy"}, {t: "pass"}, {t: "sell", uid},
## {t: "wager", amount} (a tarot draw for run cash; the customer waits).
func apply(cmd: Dictionary) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if phase == PHASE_OVER:
		ev.append({"e": "invalid", "why": "over"})
		last_events = ev
		return ev
	commands += 1
	var t: String = str(cmd.get("t", ""))
	var kind: String = customer.get("kind", "")
	if phase == PHASE_TABLE:
		if t.begins_with("table_") or t.begins_with("hand_") or t.begins_with("pairs_"):
			_table_cmd(t, cmd, ev)
		else:
			ev.append({"e": "invalid", "why": "cannot %s at the table" % t})
	elif t.begins_with("table_") or t.begins_with("hand_") or t.begins_with("pairs_"):
		ev.append({"e": "invalid", "why": "the table is closed"})
	elif t == "cast":
		_cast(cmd, ev)
	elif t == "pass":
		ev.append({"e": "passed", "kind": kind})
		_next_customer(ev)
	elif t == "inspect" and kind == SELLER:
		_inspect(str(cmd.get("tool", "")), ev)
	elif t == "offer" and kind == SELLER:
		_offer(int(cmd.get("amount", 0)), ev)
	elif t == "buy" and kind == SELLER:
		_buy_at(int(customer["ask"]), ev)
	elif t == "sell" and kind == BUYER:
		_sell(int(cmd.get("uid", -1)), ev)
	elif t == "wager" and kind != "":
		_wager(int(cmd.get("amount", 0)), ev)
	else:
		ev.append({"e": "invalid", "why": "cannot %s now" % t})
	last_events = ev
	return ev


func _take_uid() -> int:
	next_uid += 1
	return next_uid - 1


func _inspect(tool: String, ev: Array[Dictionary]) -> void:
	var tools: Array = customer["tools"]
	if not Catalog.TOOLS.has(tool) or tools.has(tool):
		ev.append({"e": "invalid", "why": "tool %s" % tool})
		return
	tools.append(tool)
	clock -= tuning.inspect_minutes
	play_secs += tuning.secs_per_inspect
	var tell: String = ""
	var cid: String = customer["item"]["curse"]
	if cid != "" and rng.randf() < tuning.tell_chance:
		tell = str(catalog.curse(cid).get("tells", {}).get(tool, ""))
	if tell != "":
		(customer["tells"] as Array).append(tool)
	ev.append({"e": "inspected", "tool": tool, "tell": tell, "estimate": estimate()})
	var hidden: Dictionary = customer["item"].get("hidden", {})
	if tool == "touch" and not hidden.is_empty():
		ev.append({"e": "found_hint", "kind": hidden["kind"]})


func _offer(amount: int, ev: Array[Dictionary]) -> void:
	if amount > cash or amount <= 0:
		ev.append({"e": "invalid", "why": "offer %d" % amount})
		return
	clock -= tuning.haggle_minutes
	play_secs += tuning.secs_per_haggle
	if amount >= int(customer["reserve"]):
		_buy_at(amount, ev)
		return
	customer["patience"] = int(customer["patience"]) - 1
	if int(customer["patience"]) <= 0:
		ev.append({"e": "left", "offer": amount})
		_next_customer(ev)
		return
	customer["ask"] = maxi(int(customer["reserve"]), int(round((int(customer["ask"]) + amount) / 2.0)))
	ev.append({"e": "counter", "offer": amount, "ask": customer["ask"], "patience": customer["patience"]})


func _buy_at(price: int, ev: Array[Dictionary]) -> void:
	if price > cash:
		ev.append({"e": "invalid", "why": "cannot afford %d" % price})
		return
	cash -= price
	var item: Dictionary = (customer["item"] as Dictionary).duplicate(true)
	item["uid"] = _take_uid()
	item["est"] = estimate()["mid"]
	item["tells"] = (customer["tells"] as Array).size()
	var hidden: Dictionary = item.get("hidden", {})
	item.erase("hidden")
	inventory.append(item)
	ev.append({"e": "bought", "uid": item["uid"], "name": item["name"], "price": price})
	if not hidden.is_empty():
		_add_find(hidden, ev)
	if item["curse"] != "":
		dread += tuning.dread_on_buy * float(catalog.curse(item["curse"]).get("dread", 1.0))
		_check_wake(ev)
	_next_customer(ev)


func _sell(uid: int, ev: Array[Dictionary]) -> void:
	for i: int in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if int(item["uid"]) != uid:
			continue
		if item["category"] != customer["category"]:
			break
		var price: int = 0 if customer["imposter"] else sale_price(item)
		cash += price
		inventory.remove_at(i)
		ev.append({"e": "sold", "uid": uid, "name": item["name"], "price": price, "imposter": customer["imposter"]})
		_next_customer(ev)
		return
	ev.append({"e": "invalid", "why": "cannot sell %d" % uid})


## Largest stake allowed now.
func max_wager() -> int:
	return int(cash * tuning.wager_max_frac)


## Tarot wager: stake run cash on one card from the deck. Run cash is never bought with real money and is worth
## nothing outside the run, which keeps this legal. The card's mult sets the payout; some cards add Dread.
func _wager(amount: int, ev: Array[Dictionary]) -> void:
	if amount <= 0 or amount > max_wager() or catalog.tarot.is_empty():
		ev.append({"e": "invalid", "why": "wager %d" % amount})
		return
	clock -= tuning.wager_minutes
	play_secs += tuning.secs_per_haggle
	var total: float = 0.0
	for card: Dictionary in catalog.tarot:
		total += float(card["weight"])
	var r: float = rng.randf() * total
	var pick: Dictionary = catalog.tarot[catalog.tarot.size() - 1]
	for card: Dictionary in catalog.tarot:
		r -= float(card["weight"])
		if r < 0.0:
			pick = card
			break
	var payout: int = int(round(amount * float(pick["mult"])))
	cash += payout - amount
	dread += float(pick.get("dread", 0.0))
	ev.append({"e": "wager", "card": pick["name"], "text": pick.get("text", ""), "stake": amount, "payout": payout,
		"dread": float(pick.get("dread", 0.0))})
	_check_wake(ev)


## Every nth customer is an imposter while a curse with imposter_every = n is held (0 = none).
func _imposter_every() -> int:
	var n: int = 0
	for item: Dictionary in inventory:
		if item["curse"] != "":
			var k: int = int(catalog.curse(item["curse"]).get("imposter_every", 0))
			if k > 0 and (n == 0 or k < n):
				n = k
	return n


func _next_customer(ev: Array[Dictionary]) -> void:
	customer = {}
	if phase == PHASE_OVER:
		return
	if clock < tuning.customer_minutes:
		_end_night(ev)
		return
	clock -= tuning.customer_minutes
	play_secs += tuning.secs_per_customer
	customers_seen += 1
	var every: int = _imposter_every()
	var imposter: bool = every > 0 and customers_seen % every == 0
	if summon_category != "":
		var sb: Dictionary = _pick_type(BUYER)
		customer = {"kind": BUYER, "category": summon_category, "imposter": imposter, "type": sb.get("id", ""),
			"pay_mult": rng.randf_range(0.8, 1.2) * float(sb.get("pay_mult", 1.0)),
			"cursed_mult": float(sb.get("cursed_mult", 1.0))}
		summon_category = ""
		ev.append({"e": "customer", "kind": BUYER, "category": customer["category"], "type": sb.get("name", ""),
			"tid": sb.get("id", ""), "line": sb.get("line", "")})
		return
	if not inventory.is_empty() and rng.randf() >= tuning.seller_share:
		var cats: PackedStringArray = catalog.categories()
		var category: String = cats[rng.randi_range(0, cats.size() - 1)]
		if rng.randf() < tuning.buyer_match_chance:
			category = inventory[rng.randi_range(0, inventory.size() - 1)]["category"]
		var bt: Dictionary = _pick_type(BUYER)
		customer = {"kind": BUYER, "category": category, "imposter": imposter, "type": bt.get("id", ""),
			"pay_mult": rng.randf_range(0.8, 1.2) * float(bt.get("pay_mult", 1.0)),
			"cursed_mult": float(bt.get("cursed_mult", 1.0))}
		ev.append({"e": "customer", "kind": BUYER, "category": category, "type": bt.get("name", ""), "tid": bt.get("id", ""),
			"line": bt.get("line", "")})
		return
	var st: Dictionary = _pick_type(SELLER)
	var obj: Dictionary = catalog.objects[rng.randi_range(0, catalog.objects.size() - 1)]
	var value: float = float(obj["value"]) * rng.randf_range(1.0 - tuning.value_spread, 1.0 + tuning.value_spread)
	var cid: String = ""
	if imposter or rng.randf() < tuning.cursed_share:
		cid = catalog.curses[rng.randi_range(0, catalog.curses.size() - 1)]["id"]
		value *= tuning.cursed_value_mult
	var reserve: int = maxi(1, int(round(value * tuning.seller_reserve_frac * rng.randf_range(0.85, 1.15)
		* float(st.get("reserve_mult", 1.0)))))
	customer = {
		"kind": SELLER,
		"item": {"id": obj["id"], "name": obj["name"], "category": obj["category"], "value": int(round(value)), "curse": cid},
		"reserve": reserve,
		"ask": int(round(reserve * tuning.seller_ask_markup)),
		"patience": maxi(1, int(tuning.patience_base) + rng.randi_range(0, 1) + int(st.get("patience", 0))),
		"type": st.get("id", ""),
		"noise_u": rng.randf_range(-1.0, 1.0),
		"tools": [],
		"tells": [],
		"imposter": imposter,
	}
	customer["item"]["hidden"] = _roll_hidden()
	ev.append({"e": "customer", "kind": SELLER, "name": obj["name"], "ask": customer["ask"],
		"type": st.get("name", ""), "tid": st.get("id", ""), "line": st.get("line", "")})


## A customer type of `kind`, weighted; {} when the catalog has none.
func _pick_type(kind: String) -> Dictionary:
	var types: Array[Dictionary] = catalog.customer_types(kind)
	var total: float = 0.0
	for t: Dictionary in types:
		total += float(t.get("weight", 1.0))
	var r: float = rng.randf() * total
	for t: Dictionary in types:
		r -= float(t.get("weight", 1.0))
		if r < 0.0:
			return t
	return types[-1] if not types.is_empty() else {}


func _check_wake(ev: Array[Dictionary]) -> void:
	if sealed or dread < tuning.wake_threshold:
		return
	var w: Dictionary = {"e": "wake", "night": night, "dread": dread, "broke": "", "closed": false}
	if not inventory.is_empty() and rng.randf() < tuning.wake_break_chance:
		var i: int = rng.randi_range(0, inventory.size() - 1)
		w["broke"] = inventory[i]["name"]
		inventory.remove_at(i)
	dread *= tuning.wake_dread_keep
	if rng.randf() < tuning.wake_close_chance:
		clock = 0.0
		w["closed"] = true
	wake_nights.append(night)
	ev.append(w)


func _end_night(ev: Array[Dictionary]) -> void:
	var curse_cash: int = 0
	for item: Dictionary in inventory:
		if item["curse"] != "":
			var c: Dictionary = catalog.curse(item["curse"])
			dread += tuning.dread_per_night * float(c.get("dread", 1.0))
			curse_cash += int(c.get("night_cash", 0))
	cash = maxi(0, cash + curse_cash)
	var rent: int = rent_for(night)
	if sealed:
		rent = int(round(rent * tuning.seal_debt_mult))
	ev.append({"e": "night_end", "night": night, "rent": rent, "cash": cash, "curse_cash": curse_cash})
	if cash < rent:
		phase = PHASE_OVER
		ev.append({"e": "run_lost", "night": night, "cash": cash, "rent": rent})
		return
	cash -= rent
	_check_wake(ev)
	sealed = false
	if night >= int(tuning.nights):
		phase = PHASE_OVER
		won = true
		ev.append({"e": "run_won", "cash": cash})
		return
	phase = PHASE_TABLE
	table = {"games_left": int(tuning.table_games_per_night), "lots_left": int(tuning.table_lots_per_night),
		"hand": {}, "pairs": {}}
	if tuning.night_curio_chance > 0.0 and rng.randf() < tuning.night_curio_chance:
		var nc: Dictionary = _pick_find(false)
		if not nc.is_empty():
			_add_find(nc, ev)
	ev.append({"e": "table_open", "night": night, "games_left": table["games_left"], "lots_left": table["lots_left"]})


func _start_next_night(ev: Array[Dictionary]) -> void:
	phase = PHASE_CUSTOMER
	table = {}
	night += 1
	clock = tuning.day_minutes
	casts_left = int(tuning.spell_casts_per_night)
	play_secs += tuning.secs_per_night
	ev.append({"e": "night_start", "night": night, "rent": rent_for(night)})
	_next_customer(ev)


## Full state, enough to restore() and continue identically (the catalog is assumed unchanged).
func snapshot() -> Dictionary:
	return {
		"seed": seed_used, "rng_state": rng.state, "tuning": tuning.to_dict(),
		"night": night, "cash": cash, "clock": clock, "dread": dread,
		"inventory": inventory.duplicate(true), "customer": customer.duplicate(true),
		"customers_seen": customers_seen, "phase": phase, "won": won, "wake_nights": wake_nights.duplicate(),
		"play_secs": play_secs, "commands": commands, "next_uid": next_uid,
		"spells_known": Array(spells_known), "found": found.duplicate(true), "casts_left": casts_left,
		"sealed": sealed, "table": table.duplicate(true), "summon_category": summon_category,
	}


func restore(d: Dictionary, cat: Catalog) -> void:
	catalog = cat
	tuning = Tuning.new()
	tuning.apply_dict(d["tuning"])
	seed_used = int(d["seed"])
	rng.seed = seed_used
	rng.state = int(d["rng_state"])
	night = int(d["night"])
	cash = int(d["cash"])
	clock = float(d["clock"])
	dread = float(d["dread"])
	inventory.assign((d["inventory"] as Array).duplicate(true))
	customer = (d["customer"] as Dictionary).duplicate(true)
	customers_seen = int(d["customers_seen"])
	phase = str(d["phase"])
	won = bool(d["won"])
	wake_nights.assign(d["wake_nights"])
	play_secs = float(d["play_secs"])
	commands = int(d["commands"])
	next_uid = int(d["next_uid"])
	_setup_rules()
	spells_known = PackedStringArray(d.get("spells_known", Array(Grimoire.DEFAULT_KNOWN)))
	found.assign((d.get("found", []) as Array).duplicate(true))
	casts_left = int(d.get("casts_left", 0))
	sealed = bool(d.get("sealed", false))
	table = (d.get("table", {}) as Dictionary).duplicate(true)
	summon_category = str(d.get("summon_category", ""))


func state_hash() -> int:
	return hash(var_to_str(snapshot()))


## The per-command debug frame for the overlay and logs.
func debug_frame() -> Dictionary:
	return {
		"night": night, "clock": clock, "cash": cash, "rent": rent_for(night), "dread": dread,
		"held": inventory.size(), "kind": customer.get("kind", ""), "phase": phase, "wakes": wake_nights.size(),
		"casts_left": casts_left, "found": found.size(), "play_min": play_secs / 60.0, "commands": commands, "events": last_events,
	}


# ---- the occult round: finds, spells, the Midnight Table

func _find_name(f: Dictionary) -> String:
	var d: Dictionary = catalog.spell(str(f["id"])) if f["kind"] == "page" else catalog.curio(str(f["id"]))
	return str(d.get("name", f["id"]))


func _add_find(f: Dictionary, ev: Array[Dictionary]) -> void:
	found.append(f)
	ev.append({"e": "found", "kind": f["kind"], "id": f["id"], "name": _find_name(f)})


## A page (a spell not yet known or found) or a curio (rarity weighted); a curio when no page is left. {} if none.
func _pick_find(want_page: bool) -> Dictionary:
	if want_page:
		var unknown: Array[String] = []
		for sp: Dictionary in catalog.spells:
			var id: String = str(sp["id"])
			if spells_known.has(id):
				continue
			var got: bool = false
			for f: Dictionary in found:
				if f["kind"] == "page" and f["id"] == id:
					got = true
			if not got:
				unknown.append(id)
		if not unknown.is_empty():
			return {"kind": "page", "id": unknown[rng.randi_range(0, unknown.size() - 1)]}
	if catalog.curios.is_empty() or house.cfg.is_empty():
		return {}
	var rarity: String = house.curio_rarity(rng)
	var pool: Array[Dictionary] = []
	for cu: Dictionary in catalog.curios:
		if cu["rarity"] == rarity:
			pool.append(cu)
	if pool.is_empty():
		pool = catalog.curios
	return {"kind": "curio", "id": str(pool[rng.randi_range(0, pool.size() - 1)]["id"])}


func _roll_hidden() -> Dictionary:
	if tuning.hidden_find_chance <= 0.0 or rng.randf() >= tuning.hidden_find_chance:
		return {}
	return _pick_find(rng.randf() < tuning.hidden_page_share)


func _cast(cmd: Dictionary, ev: Array[Dictionary]) -> void:
	var id: String = str(cmd.get("spell", ""))
	var uid: int = int(cmd.get("uid", -1))
	var why: String = grimoire.why_invalid(id, spells_known, casts_left, customer, inventory, uid, summon_category != "")
	if why != "":
		ev.append({"e": "cast", "spell": id, "ok": false, "backfire": false, "text": why, "dread": 0.0})
		ev.append({"e": "invalid", "why": why})
		return
	var sp: Dictionary = grimoire.spell(id)
	casts_left -= 1
	var backfired: bool = rng.randf() < grimoire.backfire_chance(dread)
	var cost: float = float(sp["dread"])
	dread += cost
	ev.append({"e": "cast", "spell": id, "ok": true, "backfire": backfired,
		"text": str(sp["backfire"]) if backfired else str(sp["text"]), "dread": cost})
	if backfired:
		_backfire(id, ev)
	else:
		_spell_effect(id, uid, ev)
	_check_wake(ev)


func _spell_effect(id: String, uid: int, ev: Array[Dictionary]) -> void:
	match id:
		"scry":
			var pick: Dictionary = grimoire.scry_pick(customer, catalog)
			var tools: Array = customer["tools"]
			if pick["tool"] != "" and not tools.has(pick["tool"]):
				tools.append(pick["tool"])
			if pick["tell"] != "" and not (customer["tells"] as Array).has(pick["tool"]):
				(customer["tells"] as Array).append(pick["tool"])
			ev.append({"e": "scry_reveal", "tool": pick["tool"], "tell": pick["tell"]})
		"hex":
			var h: Dictionary = grimoire.hexed(int(customer["reserve"]), int(customer["ask"]))
			customer["reserve"] = h["reserve"]
			customer["ask"] = h["ask"]
			ev.append({"e": "hexed", "reserve": h["reserve"], "ask": h["ask"]})
		"glamour":
			customer["pay_mult"] = float(customer["pay_mult"]) * tuning.glamour_mult
			ev.append({"e": "glamoured", "mult": tuning.glamour_mult})
		"banish":
			for i: int in range(inventory.size()):
				if int(inventory[i]["uid"]) == uid:
					ev.append({"e": "banished", "uid": uid, "name": inventory[i]["name"]})
					inventory.remove_at(i)
					break
			dread = maxf(0.0, dread - tuning.banish_dread)
		"summon":
			summon_category = grimoire.summon_category(inventory)
			ev.append({"e": "summoned", "category": summon_category})
		"seal":
			sealed = true
			ev.append({"e": "sealed"})


func _backfire(id: String, ev: Array[Dictionary]) -> void:
	var kind: String = grimoire.backfire_kind(rng, inventory)
	ev.append({"e": "backfire", "spell": id, "kind": kind, "text": str(Grimoire.BACKFIRE_TEXT[kind])})
	match kind:
		"dread_spike":
			dread += tuning.backfire_dread
		"cash_burn":
			cash -= int(cash * tuning.backfire_cash_frac)
		"customer_flees":
			if not customer.is_empty():
				ev.append({"e": "left", "offer": 0})
				_next_customer(ev)
		"curse_jumps":
			var clean: Array[int] = []
			for i: int in range(inventory.size()):
				if str(inventory[i]["curse"]) == "":
					clean.append(i)
			var pick: int = clean[rng.randi_range(0, clean.size() - 1)]
			inventory[pick]["curse"] = str(catalog.curses[rng.randi_range(0, catalog.curses.size() - 1)]["id"])


func _stake_ok(cmd: Dictionary) -> bool:
	var stake: int = int(cmd.get("stake", 0))
	return stake > 0 and stake <= house.max_stake(cash)


func _table_cmd(t: String, cmd: Dictionary, ev: Array[Dictionary]) -> void:
	var hand: Dictionary = table["hand"]
	var pairs: Dictionary = table["pairs"]
	if t == "table_leave":
		if not hand.is_empty() or not pairs.is_empty():
			ev.append({"e": "invalid", "why": "a game is in progress"})
			return
		ev.append({"e": "table_leave"})
		_start_next_night(ev)
		return
	if t == "hand_draw" or t == "hand_stand":
		if hand.is_empty():
			ev.append({"e": "invalid", "why": "no hand"})
		else:
			_hand_step(t == "hand_draw", ev)
		return
	if t == "pairs_flip":
		if pairs.is_empty():
			ev.append({"e": "invalid", "why": "no pairs game"})
		else:
			_pairs_flip(int(cmd.get("i", -1)), ev)
		return
	if not hand.is_empty() or not pairs.is_empty():
		ev.append({"e": "invalid", "why": "a game is in progress"})
		return
	var is_lot: bool = t == "table_lot"
	if int(table["lots_left" if is_lot else "games_left"]) <= 0:
		ev.append({"e": "invalid", "why": "nothing left at the table"})
		return
	match t:
		"table_dice":
			var call: String = str(cmd.get("call", ""))
			if not _stake_ok(cmd) or (call != "high" and call != "low"):
				ev.append({"e": "invalid", "why": "dice %s" % str(cmd.get("stake", 0))})
				return
			var r: Dictionary = house.dice_roll(rng, call, int(cmd["stake"]))
			cash += int(r["payout"]) - int(r["stake"])
			r["e"] = "dice"
			ev.append(r)
		"table_hand":
			if not _stake_ok(cmd):
				ev.append({"e": "invalid", "why": "hand stake"})
				return
			cash -= int(cmd["stake"])
			table["hand"] = {"stake": int(cmd["stake"]), "total": 0}
			for i: int in range(int(house.cfg["hand"]["deal"])):
				var c: int = house.hand_card(rng)
				table["hand"]["total"] = int(table["hand"]["total"]) + c
				ev.append({"e": "hand_card", "who": "you", "card": c, "total": table["hand"]["total"]})
		"table_wheel":
			if not _stake_ok(cmd):
				ev.append({"e": "invalid", "why": "wheel stake"})
				return
			var w: Dictionary = house.wheel_spin(rng, int(cmd["stake"]))
			cash += int(w["payout"]) - int(w["stake"])
			var find: Dictionary = {}
			if w["prize"] != "":
				find = _pick_find(w["prize"] == "page")
				w["prize"] = str(find.get("kind", ""))
			dread += float(w["dread"])
			w["e"] = "wheel"
			ev.append(w)
			if not find.is_empty():
				_add_find(find, ev)
			_check_wake(ev)
		"table_stake_item":
			var item: Dictionary = {}
			for it: Dictionary in inventory:
				if int(it["uid"]) == int(cmd.get("uid", -1)):
					item = it
			if item.is_empty():
				ev.append({"e": "invalid", "why": "stake item %s" % str(cmd.get("uid", -1))})
				return
			var f: Dictionary = house.stake_item_flip(rng, int(item["value"]))
			ev.append({"e": "item_staked", "uid": item["uid"], "name": item["name"], "win": f["win"], "value": f["value"]})
			if f["win"]:
				item["value"] = f["value"]
			else:
				inventory.erase(item)
		"table_pairs":
			if not _stake_ok(cmd) or catalog.tarot.is_empty():
				ev.append({"e": "invalid", "why": "pairs stake"})
				return
			cash -= int(cmd["stake"])
			var board: Array[int] = house.pairs_deal(rng, catalog.tarot)
			table["pairs"] = {"stake": int(cmd["stake"]), "board": board, "up": [], "first": -1,
				"tries_left": int(tuning.pairs_tries), "acc": 0.0, "matches": 0, "dread": 0.0}
			ev.append({"e": "pairs_deal", "count": board.size(), "tries": int(tuning.pairs_tries)})
		"table_lot":
			if cash < int(tuning.lot_price):
				ev.append({"e": "invalid", "why": "cannot afford the lot"})
				return
			_buy_lot(ev)
			table["lots_left"] = int(table["lots_left"]) - 1
			play_secs += tuning.secs_per_haggle
			return
		_:
			ev.append({"e": "invalid", "why": "cannot %s" % t})
			return
	table["games_left"] = int(table["games_left"]) - 1
	play_secs += tuning.secs_per_haggle


func _hand_step(draw: bool, ev: Array[Dictionary]) -> void:
	var hand: Dictionary = table["hand"]
	var target: int = int(house.cfg["hand"]["target"])
	var you: int = int(hand["total"])
	var stake: int = int(hand["stake"])
	if draw:
		var c: int = house.hand_card(rng)
		you += c
		hand["total"] = you
		ev.append({"e": "hand_card", "who": "you", "card": c, "total": you})
		if you <= target:
			return
		ev.append({"e": "hand_end", "you": you, "house": 0, "win": false, "stake": stake, "payout": 0})
		table["hand"] = {}
		return
	var total: int = 0
	for c: int in house.hand_house_draws(rng, 0):
		total += c
		ev.append({"e": "hand_card", "who": "house", "card": c, "total": total})
	var r: Dictionary = house.hand_result(you, total, stake)
	cash += int(r["payout"])
	ev.append({"e": "hand_end", "you": you, "house": total, "win": r["win"], "stake": stake, "payout": r["payout"]})
	table["hand"] = {}


func _pairs_flip(i: int, ev: Array[Dictionary]) -> void:
	var p: Dictionary = table["pairs"]
	var board: Array = p["board"]
	var up: Array = p["up"]
	if i < 0 or i >= board.size() or up.has(i) or int(p["first"]) == i:
		ev.append({"e": "invalid", "why": "flip %d" % i})
		return
	var card: Dictionary = catalog.tarot[int(board[i])]
	ev.append({"e": "pairs_flip", "i": i, "card": card["id"], "name": card["name"]})
	if int(p["first"]) < 0:
		p["first"] = i
		return
	var a: int = int(p["first"])
	p["first"] = -1
	p["tries_left"] = int(p["tries_left"]) - 1
	if board[a] == board[i]:
		up.append(a)
		up.append(i)
		p["matches"] = int(p["matches"]) + 1
		p["acc"] = house.pairs_add(float(p["acc"]), card)
		var d: float = float(card.get("dread", 0.0))
		p["dread"] = float(p["dread"]) + d
		dread += d
		ev.append({"e": "pairs_match", "card": card["id"], "name": card["name"], "mult": float(card["mult"]), "dread": d})
	else:
		ev.append({"e": "pairs_miss", "a": a, "b": i})
	if int(p["tries_left"]) > 0 and up.size() < board.size():
		return
	var payout: int = int(round(int(p["stake"]) * float(p["acc"])))
	cash += payout
	ev.append({"e": "pairs_end", "matches": p["matches"], "stake": p["stake"], "payout": payout, "dread": p["dread"]})
	table["pairs"] = {}
	_check_wake(ev)


func _buy_lot(ev: Array[Dictionary]) -> void:
	var obj: Dictionary = catalog.objects[rng.randi_range(0, catalog.objects.size() - 1)]
	var value: float = float(obj["value"]) * rng.randf_range(1.0 - tuning.value_spread, 1.0 + tuning.value_spread)
	var cid: String = ""
	if rng.randf() < tuning.cursed_share:
		cid = str(catalog.curses[rng.randi_range(0, catalog.curses.size() - 1)]["id"])
		value *= tuning.cursed_value_mult
	var hidden: Dictionary = _roll_hidden()
	var item: Dictionary = {"id": obj["id"], "name": obj["name"], "category": obj["category"],
		"value": int(round(value)), "curse": cid, "uid": _take_uid(), "est": int(obj["value"]), "tells": 0}
	cash -= int(tuning.lot_price)
	inventory.append(item)
	ev.append({"e": "lot", "name": item["name"], "price": int(tuning.lot_price), "item_uid": item["uid"],
		"hidden": not hidden.is_empty()})
	if not hidden.is_empty():
		_add_find(hidden, ev)
	if cid != "":
		dread += tuning.dread_on_buy * float(catalog.curse(cid).get("dread", 1.0))
		_check_wake(ev)
