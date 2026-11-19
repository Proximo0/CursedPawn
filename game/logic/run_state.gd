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
## Engagement round. `opts` is what was applied ({haunting, omen, omen_name, daily}); `rules` are the omen and
## haunting rule flags read below; `requests` are the open customer requests (see Requests).
var opts: Dictionary = {}
var rules: Dictionary = {}
var requests: Array[Dictionary] = []
var request_seq: int = 0
var requests_done: int = 0
var requests_failed: int = 0
## The Collector (night-5 boss): {want: {category, curse, text}, rolled, arrived, done, result: "" | "pleased" | "refused"}.
## Empty until the roll. See Collector and docs/core_brief.md.
var collector: Dictionary = {}
## Round 6. Counters the Ledger of Deeds reads (all in snapshot/restore): spells cast, Midnight Table games won, Tarot
## Pairs games with every card matched, tools used, and the most cursed objects held at once.
var spells_cast: int = 0
var table_wins: int = 0
var pairs_perfect: int = 0
var tools_used: int = 0
var max_cursed_held: int = 0
## The regular who visits this run: {id, night, chapter (0-based), state: "" | "here" | "done" | "refused"}, or {} for
## none (see Regulars). `regular_progress` is {id: next chapter index} for chapters played this run, for the profile.
var regular: Dictionary = {}
var regular_progress: Dictionary = {}
## The guided first night: {idx: scripted customers shown, shown: [hint steps shown]}; {} outside the tutorial.
var tutorial: Dictionary = {}


## Starts a run. `gift` is an item passed on by a friend (its keys as in `inventory`); empty for none.
## `run_opts` is {haunting: 0..10, omen: id or "", daily: bool}; it is applied as overrides on a copy of `tun`.
func start(seed_value: int, cat: Catalog, tun: Tuning = null, gift: Dictionary = {}, run_opts: Dictionary = {}) -> Array[Dictionary]:
	catalog = cat
	var base: Tuning = tun if tun != null else Tuning.shared()
	var active: bool = _take_opts(run_opts)
	if active:
		tuning = Tuning.new()
		tuning.copy_from(base)
		_apply_opts()
	else:
		tuning = base
	seed_used = seed_value
	rng.seed = seed_value
	_setup_rules()
	found.clear()
	casts_left = int(tuning.spell_casts_per_night)
	sealed = false
	table = {}
	summon_category = ""
	night = 1
	cash = int(tuning.start_cash) + maxi(0, int(opts.get("carry_cash", 0)))
	tutorial = {"idx": 0, "shown": []} if bool(opts.get("tutorial", false)) else {}
	if not tutorial.is_empty():
		cash += int(tuning.tutorial_purse)
	spells_cast = 0
	table_wins = 0
	pairs_perfect = 0
	tools_used = 0
	max_cursed_held = 0
	regular_progress = {}
	regular = {}
	if opts.has("regulars") and tutorial.is_empty():
		regular = Regulars.plan(seed_value, opts["regulars"], tuning.regular_chance, int(tuning.nights))
		if not regular.is_empty():
			regular["state"] = ""
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
	requests.clear()
	request_seq = 0
	requests_done = 0
	requests_failed = 0
	collector = {}
	if str(rules["seller_type"]) == "one":
		var sellers: Array[Dictionary] = catalog.customer_types(SELLER)
		rules["seller_type"] = str(sellers[rng.randi_range(0, sellers.size() - 1)]["id"]) if not sellers.is_empty() else ""
	if not gift.is_empty():
		var item: Dictionary = gift.duplicate(true)
		item["uid"] = _take_uid()
		inventory.append(item)
	elif bool(rules["start_cursed"]):
		_start_cursed_item()
	for sp: String in rules["start_spells"]:
		if not spells_known.has(sp):
			spells_known.append(sp)
	if bool(rules["upgrade_spell"]):
		_grant_upgrade_spell()
	_track_cursed()
	clock = tuning.day_minutes
	var ev: Array[Dictionary] = [{"e": "night_start", "night": night, "rent": rent_for(night)}]
	_maybe_roll_collector(ev)
	if active:
		ev.push_front({"e": "run_opts", "haunting": opts["haunting"], "omen": opts["omen"], "omen_name": opts["omen_name"],
			"daily": opts["daily"]})
	_next_customer(ev)
	_tutorial_hints(ev)
	last_events = ev
	return ev


## Normalises `run_opts` into `opts` and sets the rule flags. True when any option is on.
func _take_opts(run_opts: Dictionary) -> bool:
	var omen_id: String = str(run_opts.get("omen", ""))
	var omen: Dictionary = Omens.get_omen(omen_id) if omen_id != "" else {}
	opts = {"haunting": clampi(int(run_opts.get("haunting", 0)), 0, Hauntings.MAX_LEVEL),
		"omen": omen_id if not omen.is_empty() else "", "omen_name": str(omen.get("name", "")),
		"daily": bool(run_opts.get("daily", false))}
	for key: String in ["date", "number", "start_spell"]:
		if run_opts.has(key):
			opts[key] = run_opts[key]
	var ranks: Dictionary = Upgrades.clean(run_opts.get("upgrades", {}) if run_opts.get("upgrades") is Dictionary else {})
	if not ranks.is_empty():
		opts["upgrades"] = ranks
	if int(run_opts.get("carry_cash", 0)) > 0:
		opts["carry_cash"] = int(run_opts["carry_cash"])
	if bool(run_opts.get("tutorial", false)):
		opts["tutorial"] = true
	if run_opts.get("regulars") is Dictionary:
		opts["regulars"] = Regulars.clean(run_opts["regulars"])
	rules = {"all_cursed": false, "no_tool": "", "double_table": false, "seller_type": "", "start_cursed": false,
		"start_spells": [], "pendulum": false, "upgrade_spell": false}
	for h: Dictionary in Hauntings.upto(int(opts["haunting"])):
		for flag: Variant in (h.get("flags", {}) as Dictionary):
			rules[str(flag)] = h["flags"][flag]
	var flags: Dictionary = omen.get("flags", {})
	rules["all_cursed"] = bool(flags.get("all_cursed", false))
	rules["no_tool"] = str(flags.get("no_tool", ""))
	rules["double_table"] = bool(flags.get("double_table", false))
	rules["seller_type"] = "one" if bool(flags.get("one_customer_type", false)) else ""
	if flags.has("start_spell"):
		rules["start_spells"] = [str(flags["start_spell"])]
	var up_flags: Dictionary = Upgrades.flags_for(ranks)
	rules["pendulum"] = bool(up_flags.get("pendulum", false))
	rules["upgrade_spell"] = bool(up_flags.get("start_spell", false))
	return int(opts["haunting"]) > 0 or not omen.is_empty() or bool(opts["daily"]) or not ranks.is_empty()


func _apply_opts() -> void:
	for h: Dictionary in Hauntings.upto(int(opts["haunting"])):
		DataFiles.apply_rule(tuning, h)
	if str(opts["omen"]) != "":
		DataFiles.apply_rule(tuning, Omens.get_omen(str(opts["omen"])))
	if opts.has("upgrades"):
		Upgrades.apply(tuning, opts["upgrades"])


## The Borrowed Page upgrade: one more spell, the player's pick (opts.start_spell) or the first one not yet known.
func _grant_upgrade_spell() -> void:
	var pick: String = str(opts.get("start_spell", ""))
	if pick != "" and not catalog.spell(pick).is_empty() and not spells_known.has(pick):
		spells_known.append(pick)
		return
	for sp: Dictionary in catalog.spells:
		if not spells_known.has(str(sp["id"])):
			spells_known.append(str(sp["id"]))
			return


## Haunting 10: the shop remembers. A cursed object is already on the shelf.
func _start_cursed_item() -> void:
	var obj: Dictionary = catalog.objects[rng.randi_range(0, catalog.objects.size() - 1)]
	var cid: String = str(catalog.curses[rng.randi_range(0, catalog.curses.size() - 1)]["id"])
	inventory.append({"id": obj["id"], "name": obj["name"], "category": obj["category"],
		"value": int(round(float(obj["value"]) * tuning.cursed_value_mult)), "curse": cid, "uid": _take_uid(),
		"est": int(obj["value"]), "tells": 0})


## Whether a tool can be used this run (an omen can break one).
func tool_ok(tool: String) -> bool:
	if tool == "pendulum":
		return bool(rules.get("pendulum", false))
	return Catalog.TOOLS.has(tool) and str(rules.get("no_tool", "")) != tool


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
	var used: int = (customer["tools"] as Array).size() - (1 if (customer["tools"] as Array).has("pendulum") else 0)
	var noise: float = tuning.value_noise * pow(tuning.inspect_noise_cut, used)
	var value: float = float(customer["item"]["value"])
	return {"mid": int(round(value * (1.0 + noise * float(customer["noise_u"])))), "spread": noise}


## Held items a buyer would take (matching category).
func sellable() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if customer.get("kind", "") != BUYER:
		return out
	for item: Dictionary in inventory:
		if _wants(item):
			out.append(item)
	return out


## Whether the current buyer takes `item`.
func _wants(item: Dictionary) -> bool:
	if str(customer.get("regular", "")) != "":
		return Regulars.matches(customer["want"], item)
	if customer.get("collector", false):
		return Collector.matches(customer["want"], item)
	if customer.get("request", false):
		return Requests.matches(customer["want"], item)
	return item["category"] == customer["category"]


## The price the current buyer offers for a held item. An imposter offers it too but never pays (see _sell).
func sale_price(item: Dictionary) -> int:
	if customer.get("kind", "") != BUYER:
		return 0
	if str(customer.get("regular", "")) != "":
		return int(round(float(item["value"]) * tuning.regular_pay_mult))
	if customer.get("collector", false):
		return int(round(float(item["value"]) * tuning.collector_pay_mult * float(customer["pay_mult"])))
	if customer.get("request", false):
		return int(round(float(item["value"]) * float(customer["pay_mult"])))
	var cursed: float = float(customer.get("cursed_mult", 1.0)) * tuning.cursed_buyer_mult if str(item["curse"]) != "" else 1.0
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
	_tutorial_hints(ev)
	last_events = ev
	return ev


func _take_uid() -> int:
	next_uid += 1
	return next_uid - 1


func _inspect(tool: String, ev: Array[Dictionary]) -> void:
	var tools: Array = customer["tools"]
	if not tool_ok(tool) or tools.has(tool):
		ev.append({"e": "invalid", "why": "tool %s" % tool})
		return
	tools.append(tool)
	tools_used += 1
	clock -= tuning.pendulum_minutes if tool == "pendulum" else tuning.inspect_minutes
	play_secs += tuning.secs_per_inspect
	var tell: String = ""
	var cid: String = customer["item"]["curse"]
	if tool == "pendulum":
		tell = "cursed" if cid != "" else "clean"  # certain, and never says which curse
	elif cid != "" and tool == str(customer.get("sure_tell", "")):
		tell = str(catalog.curse(cid).get("tells", {}).get(tool, ""))  # the tutorial's obvious tell: no dice
	elif cid != "" and rng.randf() < tuning.tell_chance:
		tell = str(catalog.curse(cid).get("tells", {}).get(tool, ""))
	if tell != "" and (tool != "pendulum" or cid != ""):
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
	if str(customer.get("regular", "")) != "":
		_regular_done(price, ev)
	if not hidden.is_empty():
		_add_find(hidden, ev)
	if item["curse"] != "":
		dread += tuning.dread_on_buy * float(catalog.curse(item["curse"]).get("dread", 1.0))
		_check_wake(ev)
	_track_cursed()
	_next_customer(ev)


func _sell(uid: int, ev: Array[Dictionary]) -> void:
	for i: int in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if int(item["uid"]) != uid:
			continue
		if not _wants(item):
			break
		var price: int = 0 if customer["imposter"] else sale_price(item)
		cash += price
		inventory.remove_at(i)
		ev.append({"e": "sold", "uid": uid, "name": item["name"], "price": price, "imposter": customer["imposter"]})
		if customer.get("request", false):
			_complete_request(str(customer["request_id"]), price, ev)
		if customer.get("collector", false):
			_collector_pleased(price, ev)
		if str(customer.get("regular", "")) != "":
			_regular_done(price, ev)
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
	var prev: Dictionary = customer
	customer = {}
	if phase == PHASE_OVER:
		return
	if prev.get("collector", false) and str(collector.get("result", "")) == "":
		_collector_refuse(ev)  # passed on, or fled
	if str(prev.get("regular", "")) != "" and str(regular.get("state", "")) == "here":
		_regular_refuse(ev)  # passed on, or fled
	if prev.get("request", false) and not _find_request(str(prev["request_id"])).is_empty():
		_fail_request(_find_request(str(prev["request_id"])), ev)  # passed on, or fled
	if not tutorial.is_empty() and night == 1:
		_tutorial_customer(ev)
		return
	if clock < tuning.customer_minutes:
		_end_night(ev)
		return
	if _collector_due():
		_collector_arrive(ev)
		return
	if _regular_due():
		_regular_arrive(ev)
		return
	if _call_requester(ev):
		return
	_roll_customer(ev)
	if not customer.is_empty():
		_maybe_new_request(ev)


func _roll_customer(ev: Array[Dictionary]) -> void:
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
	if str(rules["seller_type"]) != "":
		for t: Dictionary in catalog.customer_types(SELLER):
			if str(t["id"]) == str(rules["seller_type"]):
				st = t
	var obj: Dictionary = catalog.objects[rng.randi_range(0, catalog.objects.size() - 1)]
	var value: float = float(obj["value"]) * rng.randf_range(1.0 - tuning.value_spread, 1.0 + tuning.value_spread)
	var cid: String = ""
	if imposter or bool(rules["all_cursed"]) or rng.randf() < tuning.cursed_share:
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
	if not tutorial.is_empty() and night == 1:
		dread = minf(dread, tuning.wake_threshold * 0.9)  # the guided night is safe
		return
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
	if cash < rent and not tutorial.is_empty() and night == 1:
		cash = rent  # the purse covers the first rent
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
	table = {"games_left": int(tuning.table_games_per_night) * (2 if bool(rules["double_table"]) else 1), "lots_left": int(tuning.table_lots_per_night),
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
	var relief: float = minf(dread, tuning.night_dread_relief)
	dread -= relief
	var ns: Dictionary = {"e": "night_start", "night": night, "rent": rent_for(night)}
	if relief > 0.0:
		ns["dread_relief"] = relief
	ev.append(ns)
	_maybe_roll_collector(ev)
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
		"opts": opts.duplicate(true), "rules": rules.duplicate(true), "requests": requests.duplicate(true),
		"request_seq": request_seq, "requests_done": requests_done, "requests_failed": requests_failed,
		"collector": collector.duplicate(true), "spells_cast": spells_cast, "table_wins": table_wins,
		"pairs_perfect": pairs_perfect, "tools_used": tools_used, "max_cursed_held": max_cursed_held,
		"regular": regular.duplicate(true), "regular_progress": regular_progress.duplicate(true),
		"tutorial": tutorial.duplicate(true),
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
	opts = (d.get("opts", {}) as Dictionary).duplicate(true)
	rules = {"all_cursed": false, "no_tool": "", "double_table": false, "seller_type": "", "start_cursed": false,
		"start_spells": [], "pendulum": false, "upgrade_spell": false}
	rules.merge((d.get("rules", {}) as Dictionary).duplicate(true), true)
	requests.assign((d.get("requests", []) as Array).duplicate(true))
	request_seq = int(d.get("request_seq", 0))
	requests_done = int(d.get("requests_done", 0))
	requests_failed = int(d.get("requests_failed", 0))
	collector = (d.get("collector", {}) as Dictionary).duplicate(true)
	spells_cast = int(d.get("spells_cast", 0))
	table_wins = int(d.get("table_wins", 0))
	pairs_perfect = int(d.get("pairs_perfect", 0))
	tools_used = int(d.get("tools_used", 0))
	max_cursed_held = int(d.get("max_cursed_held", 0))
	regular = (d.get("regular", {}) as Dictionary).duplicate(true)
	regular_progress = (d.get("regular_progress", {}) as Dictionary).duplicate(true)
	tutorial = (d.get("tutorial", {}) as Dictionary).duplicate(true)


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
	spells_cast += 1
	var backfired: bool = rng.randf() < grimoire.backfire_chance(dread)
	var cost: float = float(sp["dread"]) * tuning.spell_dread_mult
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
			_track_cursed()


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
			table_wins += 1 if int(r["payout"]) > int(r["stake"]) else 0
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
			table_wins += 1 if int(w["payout"]) > int(w["stake"]) else 0
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
				table_wins += 1
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
	table_wins += 1 if bool(r["win"]) else 0
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
	table_wins += 1 if payout > int(p["stake"]) else 0
	pairs_perfect += 1 if up.size() >= board.size() else 0
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
	_track_cursed()
	ev.append({"e": "lot", "name": item["name"], "price": int(tuning.lot_price), "item_uid": item["uid"],
		"hidden": not hidden.is_empty()})
	if not hidden.is_empty():
		_add_find(hidden, ev)
	if cid != "":
		dread += tuning.dread_on_buy * float(catalog.curse(cid).get("dread", 1.0))
		_check_wake(ev)


# ---- customer requests

func _find_request(id: String) -> Dictionary:
	for r: Dictionary in requests:
		if str(r["id"]) == id:
			return r
	return {}


func _holds_match(want: Dictionary) -> bool:
	for item: Dictionary in inventory:
		if Requests.matches(want, item):
			return true
	return false


## Maybe a customer slot also brings a request: the requester speaks up and the slot goes on as usual.
func _maybe_new_request(ev: Array[Dictionary]) -> void:
	if requests.size() >= int(tuning.requests_max) or night >= int(tuning.nights) or tuning.request_chance <= 0.0 or rng.randf() >= tuning.request_chance:
		return
	var bt: Dictionary = _pick_type(BUYER)
	var reward: Dictionary = _pick_find(false)
	request_seq += 1
	var req: Dictionary = Requests.make(rng, catalog, tuning, night, int(tuning.nights), request_seq, str(bt.get("id", "")), reward)
	if req.is_empty():
		return
	requests.append(req)
	ev.append({"e": "request_new", "id": req["id"], "who": req["who"], "line": Requests.line(rng, req),
		"want_text": Requests.want_text(req["want"]), "due": req["due"]})


## On a request's due night the requester is the first customer, a buyer. A requester with nothing to take fails
## at once and the next customer comes instead. True when the requester is now the customer.
func _call_requester(ev: Array[Dictionary]) -> bool:
	while true:
		var req: Dictionary = {}
		for r: Dictionary in requests:
			if int(r["due"]) <= night and not bool(r["called"]):
				req = r
				break
		if req.is_empty():
			return false
		req["called"] = true
		ev.append({"e": "request_due", "id": req["id"], "who": req["who"]})
		if not _holds_match(req["want"]):
			_fail_request(req, ev)
			continue
		var bt: Dictionary = {}
		for t: Dictionary in catalog.customer_types(BUYER):
			if str(t["id"]) == str(req["tid"]):
				bt = t
		clock -= tuning.customer_minutes
		play_secs += tuning.secs_per_customer
		customers_seen += 1
		customer = {"kind": BUYER, "category": str(req["want"]["category"]), "imposter": false, "type": req["tid"],
			"pay_mult": float(req["pay_mult"]), "cursed_mult": 1.0, "request": true, "request_id": req["id"],
			"want": (req["want"] as Dictionary).duplicate(), "who": req["who"]}
		ev.append({"e": "customer", "kind": BUYER, "category": customer["category"], "type": bt.get("name", ""),
			"tid": req["tid"], "line": bt.get("line", ""), "request": true, "who": req["who"],
			"want_text": Requests.want_text(req["want"])})
		return true
	return false


func _fail_request(req: Dictionary, ev: Array[Dictionary]) -> void:
	requests.erase(req)
	requests_failed += 1
	ev.append({"e": "request_failed", "id": req["id"]})


func _complete_request(id: String, pay: int, ev: Array[Dictionary]) -> void:
	var req: Dictionary = _find_request(id)
	if req.is_empty():
		return
	requests.erase(req)
	requests_done += 1
	var reward: Dictionary = req["reward"]
	ev.append({"e": "request_done", "id": id, "pay": pay, "reward": reward})
	if not reward.is_empty():
		_add_find(reward, ev)


# ---- the Collector (night-5 boss)

## The night the want is announced: two nights before the last (night 3 of 5).
func _collector_roll_night() -> int:
	return maxi(1, int(tuning.nights) - 2)


func _maybe_roll_collector(ev: Array[Dictionary]) -> void:
	if not collector.is_empty() or night != _collector_roll_night():
		return
	var want: Dictionary = Collector.roll_want(seed_used)
	collector = {"want": want, "rolled": true, "arrived": false, "done": false, "result": ""}
	ev.append({"e": "collector_omen", "text": Collector.omen_text(want, int(tuning.nights)), "night": night,
		"arrive_night": int(tuning.nights), "want_text": want["text"]})


## On the last night he is the first customer, once.
func _collector_due() -> bool:
	return night >= int(tuning.nights) and not collector.is_empty() and not bool(collector["arrived"])


func _collector_arrive(ev: Array[Dictionary]) -> void:
	clock -= tuning.customer_minutes
	play_secs += tuning.secs_per_customer
	customers_seen += 1
	collector["arrived"] = true
	var want: Dictionary = collector["want"]
	customer = {"kind": BUYER, "category": str(want["category"]), "imposter": false, "type": Collector.TID, "pay_mult": 1.0,
		"cursed_mult": 1.0, "boss": true, "collector": true, "want": want.duplicate(), "who": str(Collector.data().get("name", ""))}
	ev.append({"e": "customer", "kind": BUYER, "category": customer["category"], "type": customer["who"],
		"tid": Collector.TID, "line": Collector.line("arrive"), "boss": true, "who": customer["who"],
		"want_text": want["text"]})
	ev.append({"e": "collector_arrives", "want_text": want["text"], "line": Collector.line("arrive")})


func _collector_pleased(price: int, ev: Array[Dictionary]) -> void:
	collector["done"] = true
	collector["result"] = "pleased"
	var gift: Dictionary = {}
	if not catalog.curios.is_empty():
		var rarity: String = "legendary" if rng.randf() < tuning.collector_legendary_odds else "rare"
		var pool: Array[Dictionary] = []
		for cu: Dictionary in catalog.curios:
			if cu["rarity"] == rarity:
				pool.append(cu)
		if pool.is_empty():
			pool = catalog.curios
		gift = {"kind": "curio", "id": str(pool[rng.randi_range(0, pool.size() - 1)]["id"])}
		_add_find(gift, ev)
	ev.append({"e": "collector_pleased", "price": price, "line": Collector.line("pleased"), "reward": gift})


func _collector_refuse(ev: Array[Dictionary]) -> void:
	collector["done"] = true
	collector["result"] = "refused"
	var toll: int = int(cash * tuning.collector_toll_frac)
	cash -= toll
	dread += tuning.collector_curse_dread
	ev.append({"e": "collector_refused", "toll": toll, "dread": tuning.collector_curse_dread,
		"line": Collector.line("refused"), "curse_line": Collector.line("curse")})
	_check_wake(ev)


## The most cursed objects held at once (a Ledger of Deeds counter).
func _track_cursed() -> void:
	var n: int = 0
	for item: Dictionary in inventory:
		if str(item["curse"]) != "":
			n += 1
	max_cursed_held = maxi(max_cursed_held, n)


# ---- regulars (stories across runs)

## The regular's next customer slot: on or after their night (through night 4), a seller chapter at once, a buyer
## chapter as soon as a held object matches.
func _regular_due() -> bool:
	if regular.is_empty() or str(regular["state"]) != "" or night < int(regular["night"]) or night > mini(Regulars.LAST_NIGHT, int(tuning.nights) - 1):
		return false
	var chap: Dictionary = Regulars.chapter(str(regular["id"]), int(regular["chapter"]))
	if chap.is_empty():
		return false
	if str(chap["kind"]) == SELLER:
		return true
	for item: Dictionary in inventory:
		if Regulars.matches(chap, item):
			return true
	return false


func _object(id: String) -> Dictionary:
	for o: Dictionary in catalog.objects:
		if str(o["id"]) == id:
			return o
	return {}


func _regular_arrive(ev: Array[Dictionary]) -> void:
	var id: String = str(regular["id"])
	var def: Dictionary = Regulars.get_regular(id)
	var chap: Dictionary = Regulars.chapter(id, int(regular["chapter"]))
	regular["state"] = "here"
	clock -= tuning.customer_minutes
	play_secs += tuning.secs_per_customer
	customers_seen += 1
	var obj: Dictionary = _object(str(chap.get("item_id", "")))
	var who: String = str(def["name"])
	if str(chap["kind"]) == SELLER:
		var cid: String = str(chap.get("curse", ""))
		var value: float = float(obj["value"]) * (tuning.cursed_value_mult if cid != "" else 1.0)
		var reserve: int = maxi(1, int(round(value * tuning.seller_reserve_frac)))
		customer = {"kind": SELLER,
			"item": {"id": obj["id"], "name": obj["name"], "category": obj["category"], "value": int(round(value)), "curse": cid, "hidden": {}},
			"reserve": reserve, "ask": int(round(reserve * tuning.seller_ask_markup)), "patience": maxi(1, int(tuning.patience_base)),
			"type": str(def["tid"]), "noise_u": rng.randf_range(-1.0, 1.0), "tools": [], "tells": [], "imposter": false,
			"regular": id, "who": who}
		ev.append({"e": "customer", "kind": SELLER, "name": obj["name"], "ask": customer["ask"], "type": who,
			"tid": str(def["tid"]), "line": str(chap["line"]), "regular": id})
	else:
		var category: String = str(chap.get("category", obj.get("category", "")))
		customer = {"kind": BUYER, "category": category, "imposter": false, "type": str(def["tid"]), "pay_mult": 1.0,
			"cursed_mult": 1.0, "regular": id, "who": who, "want": {"item_id": str(chap.get("item_id", "")),
			"category": str(chap.get("category", "")), "curse": str(chap.get("curse", ""))}}
		ev.append({"e": "customer", "kind": BUYER, "category": category, "type": who, "tid": str(def["tid"]),
			"line": str(chap["line"]), "regular": id})
	ev.append({"e": "regular", "id": id, "name": who, "chapter": int(regular["chapter"]) + 1,
		"chapters": Regulars.chapter_count(id), "line": str(chap["line"])})


func _regular_done(price: int, ev: Array[Dictionary]) -> void:
	var chap: Dictionary = Regulars.chapter(str(regular["id"]), int(regular["chapter"]))
	regular["state"] = "done"
	regular_progress[str(regular["id"])] = int(regular["chapter"]) + 1
	var reward: Dictionary = (chap.get("reward", {}) as Dictionary).duplicate()
	ev.append({"e": "regular_done", "id": regular["id"], "chapter": int(regular["chapter"]) + 1,
		"line": str((chap["outcome_lines"] as Dictionary)["done"]), "reward": reward, "price": price})
	if not reward.is_empty():
		_add_find(reward, ev)


func _regular_refuse(ev: Array[Dictionary]) -> void:
	var chap: Dictionary = Regulars.chapter(str(regular["id"]), int(regular["chapter"]))
	regular["state"] = "refused"
	regular_progress[str(regular["id"])] = int(regular["chapter"]) + 1
	ev.append({"e": "regular_refused", "id": regular["id"], "chapter": int(regular["chapter"]) + 1,
		"line": str((chap["outcome_lines"] as Dictionary)["refused"])})


# ---- the guided first night

## The next scripted customer of the tutorial night, or the end of the night after the last.
func _tutorial_customer(ev: Array[Dictionary]) -> void:
	var script: Array[Dictionary] = Tutorial.customers()
	if int(tutorial["idx"]) >= script.size():
		_end_night(ev)
		return
	var c: Dictionary = script[int(tutorial["idx"])]
	tutorial["idx"] = int(tutorial["idx"]) + 1
	clock -= tuning.customer_minutes
	play_secs += tuning.secs_per_customer
	customers_seen += 1
	var kind: String = str(c["kind"])
	var t: Dictionary = {}
	for ct: Dictionary in catalog.customer_types(kind):
		if str(ct["id"]) == str(c["tid"]):
			t = ct
	if kind == SELLER:
		var obj: Dictionary = _object(str(c["item_id"]))
		var cid: String = str(c["curse"])
		var value: float = float(obj["value"]) * (tuning.cursed_value_mult if cid != "" else 1.0)
		var reserve: int = maxi(1, int(round(value * tuning.seller_reserve_frac * float(t.get("reserve_mult", 1.0)))))
		customer = {"kind": SELLER,
			"item": {"id": obj["id"], "name": obj["name"], "category": obj["category"], "value": int(round(value)), "curse": cid, "hidden": {}},
			"reserve": reserve, "ask": int(round(reserve * tuning.seller_ask_markup)),
			"patience": maxi(1, int(tuning.patience_base) + 1 + int(t.get("patience", 0))), "type": str(c["tid"]),
			"noise_u": 0.3, "tools": [], "tells": [], "imposter": false, "sure_tell": str(c.get("sure_tell", ""))}
		ev.append({"e": "customer", "kind": SELLER, "name": obj["name"], "ask": customer["ask"], "type": t.get("name", ""),
			"tid": str(c["tid"]), "line": t.get("line", ""), "tutorial": int(c["step"])})
	else:
		customer = {"kind": BUYER, "category": str(c["category"]), "imposter": false, "type": str(c["tid"]),
			"pay_mult": float(c["pay_mult"]), "cursed_mult": 1.0}
		ev.append({"e": "customer", "kind": BUYER, "category": customer["category"], "type": t.get("name", ""),
			"tid": str(c["tid"]), "line": t.get("line", ""), "tutorial": int(c["step"])})


## Appends the tutorial_step events that the events so far trigger (see Tutorial.script).
func _tutorial_hints(ev: Array[Dictionary]) -> void:
	if tutorial.is_empty():
		return
	ev.append_array(Tutorial.hints_for(ev.duplicate(), tutorial, night))
