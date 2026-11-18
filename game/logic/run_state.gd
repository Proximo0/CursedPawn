class_name RunState
extends RefCounted
## One run of the shop: nights, customers, inspecting, haggling, rent, curses and Dread.
## Pure logic: seeded, no clock, driven only by apply(cmd). Every change comes back as a list of events.
## Commands and events are listed in docs/core_brief.md. Numbers come from `tuning` (a Tuning).

const PHASE_CUSTOMER: String = "customer"
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


## Starts a run. `gift` is an item passed on by a friend (its keys as in `inventory`); empty for none.
func start(seed_value: int, cat: Catalog, tun: Tuning = null, gift: Dictionary = {}) -> Array[Dictionary]:
	catalog = cat
	tuning = tun if tun != null else Tuning.shared()
	seed_used = seed_value
	rng.seed = seed_value
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
	return int(round(float(item["value"]) * tuning.buyer_pay_frac * float(customer["pay_mult"]) * sale_mult()))


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
	if t == "pass":
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
	inventory.append(item)
	ev.append({"e": "bought", "uid": item["uid"], "name": item["name"], "price": price})
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
	if not inventory.is_empty() and rng.randf() >= tuning.seller_share:
		var cats: PackedStringArray = catalog.categories()
		var category: String = cats[rng.randi_range(0, cats.size() - 1)]
		if rng.randf() < tuning.buyer_match_chance:
			category = inventory[rng.randi_range(0, inventory.size() - 1)]["category"]
		customer = {"kind": BUYER, "category": category, "pay_mult": rng.randf_range(0.8, 1.2), "imposter": imposter}
		ev.append({"e": "customer", "kind": BUYER, "category": category})
		return
	var obj: Dictionary = catalog.objects[rng.randi_range(0, catalog.objects.size() - 1)]
	var value: float = float(obj["value"]) * rng.randf_range(1.0 - tuning.value_spread, 1.0 + tuning.value_spread)
	var cid: String = ""
	if imposter or rng.randf() < tuning.cursed_share:
		cid = catalog.curses[rng.randi_range(0, catalog.curses.size() - 1)]["id"]
		value *= tuning.cursed_value_mult
	var reserve: int = maxi(1, int(round(value * tuning.seller_reserve_frac * rng.randf_range(0.85, 1.15))))
	customer = {
		"kind": SELLER,
		"item": {"id": obj["id"], "name": obj["name"], "category": obj["category"], "value": int(round(value)), "curse": cid},
		"reserve": reserve,
		"ask": int(round(reserve * tuning.seller_ask_markup)),
		"patience": int(tuning.patience_base) + rng.randi_range(0, 1),
		"noise_u": rng.randf_range(-1.0, 1.0),
		"tools": [],
		"tells": [],
		"imposter": imposter,
	}
	ev.append({"e": "customer", "kind": SELLER, "name": obj["name"], "ask": customer["ask"]})


func _check_wake(ev: Array[Dictionary]) -> void:
	if dread < tuning.wake_threshold:
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
	for item: Dictionary in inventory:
		if item["curse"] != "":
			dread += tuning.dread_per_night * float(catalog.curse(item["curse"]).get("dread", 1.0))
	var rent: int = rent_for(night)
	ev.append({"e": "night_end", "night": night, "rent": rent, "cash": cash})
	if cash < rent:
		phase = PHASE_OVER
		ev.append({"e": "run_lost", "night": night, "cash": cash, "rent": rent})
		return
	cash -= rent
	_check_wake(ev)
	if night >= int(tuning.nights):
		phase = PHASE_OVER
		won = true
		ev.append({"e": "run_won", "cash": cash})
		return
	night += 1
	clock = tuning.day_minutes
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


func state_hash() -> int:
	return hash(var_to_str(snapshot()))


## The per-command debug frame for the overlay and logs.
func debug_frame() -> Dictionary:
	return {
		"night": night, "clock": clock, "cash": cash, "rent": rent_for(night), "dread": dread,
		"held": inventory.size(), "kind": customer.get("kind", ""), "phase": phase, "wakes": wake_nights.size(),
		"play_min": play_secs / 60.0, "commands": commands, "events": last_events,
	}
