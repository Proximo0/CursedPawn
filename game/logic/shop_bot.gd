class_name ShopBot
extends RefCounted
## Play-bot policies for the lab. A bot sees only what a player sees: the ask, the estimate, tells it found,
## its own cash, rent and what it paid. Greedy buys whatever looks cheap and ignores tells; cautious inspects,
## walks away from anything with a tell and keeps cash back for rent.

const GREEDY: String = "greedy"
const CAUTIOUS: String = "cautious"
const STYLES: PackedStringArray = ["greedy", "cautious"]

var style: String = GREEDY
var _cast_key: String = ""  ## the customer the bot last cast hex or glamour on (casts are not repeated)


func _init(style_in: String = GREEDY) -> void:
	style = style_in


func decide(run: RunState) -> Dictionary:
	if run.phase == RunState.PHASE_TABLE:
		return _bot_table(run)
	var spell: Dictionary = _bot_cast(run)
	if not spell.is_empty():
		return spell
	if run.customer.get("kind", "") == RunState.BUYER:
		return _bot_sell(run)
	if run.customer.get("kind", "") == RunState.SELLER:
		return _bot_greedy_buy(run) if style == GREEDY else _bot_cautious_buy(run)
	return {"t": "pass"}


## The bots never gamble at the Midnight Table: every house game loses on average, so a bot that plays only measures
## the house edge, and the lab's feel targets are about shop strategy. The games are covered by unit tests.
func _bot_table(_run: RunState) -> Dictionary:
	return {"t": "table_leave"}


## A sensible spell, or {} for none. Scry before any tool on a fresh seller (cautious only), hex a seller before
## haggling, glamour a buyer, banish a held object that showed a tell when Dread is near a wake.
func _bot_cast(run: RunState) -> Dictionary:
	if run.casts_left <= 0:
		return {}
	var known: PackedStringArray = run.spells_known
	var key: String = "%d:%d" % [run.get_instance_id(), run.customers_seen]
	var kind: String = str(run.customer.get("kind", ""))
	if known.has("banish") and run.dread >= run.tuning.wake_threshold * 0.8:
		for item: Dictionary in run.inventory:
			if int(item.get("tells", 0)) > 0:
				return {"t": "cast", "spell": "banish", "uid": item["uid"]}
	if run.dread > run.tuning.wake_threshold * 0.6:
		return {}
	if kind == RunState.SELLER:
		if not (run.customer["tells"] as Array).is_empty():
			return {}  # walking away from it
		if style == CAUTIOUS and known.has("scry") and (run.customer["tools"] as Array).is_empty():
			return {"t": "cast", "spell": "scry"}
		if known.has("hex") and _cast_key != key and run.casts_left > 1:
			_cast_key = key
			return {"t": "cast", "spell": "hex"}
	elif kind == RunState.BUYER and known.has("glamour") and _cast_key != key and not run.sellable().is_empty():
		_cast_key = key
		return {"t": "cast", "spell": "glamour"}
	return {}


func _bot_sell(run: RunState) -> Dictionary:
	var best: Dictionary = {}
	var keep: int = _bot_collector_keep(run)
	for item: Dictionary in run.sellable():
		if int(item["uid"]) == keep:
			continue
		var score: float = float(item.get("est", 0)) + (1000.0 if int(item.get("tells", 0)) > 0 else 0.0)
		if best.is_empty() or score > float(best["score"]):
			best = {"uid": item["uid"], "score": score}
	if best.is_empty():
		return {"t": "pass"}
	return {"t": "sell", "uid": best["uid"]}


## The uid of the one held item kept back for the Collector while he is still to come (-1 for none).
func _bot_collector_keep(run: RunState) -> int:
	if run.collector.is_empty() or bool(run.collector["arrived"]) or run.night < int(run.tuning.nights) - 1:
		return -1  # only the last evening: earlier, cash from a sale is worth more than waiting
	for held: Dictionary in run.inventory:
		if Collector.matches(run.collector["want"], held):
			return int(held["uid"])
	return -1


func _bot_greedy_buy(run: RunState) -> Dictionary:
	var c: Dictionary = run.customer
	var mid: int = int(run.estimate()["mid"])
	var ask: int = int(c["ask"])
	var spendable: int = run.cash - _bot_reserve(run, 0.0)
	if str(c.get("regular", "")) != "" and ask <= spendable:
		return {"t": "buy"}  # the story is worth a fair price
	if ask <= mid and ask <= spendable:
		return {"t": "buy"}
	var offer: int = mini(spendable, int(mid * 0.6))
	if int(c["patience"]) > 1 and offer > 0 and offer < ask:
		return {"t": "offer", "amount": offer}
	return {"t": "pass"}


func _bot_cautious_buy(run: RunState) -> Dictionary:
	var c: Dictionary = run.customer
	if not (c["tells"] as Array).is_empty():
		return {"t": "pass"}
	if run.tool_ok("pendulum") and not (c["tools"] as Array).has("pendulum") and run.clock >= run.tuning.pendulum_minutes:
		return {"t": "inspect", "tool": "pendulum"}  # the altar's sixth tool: a certain yes or no on a curse
	var picked: int = 0
	for tool: String in ["uv", "listen", "touch", "scale"]:  # the first two it can use (an omen can break one)
		if not run.tool_ok(tool):
			continue
		picked += 1
		if not (c["tools"] as Array).has(tool) and run.clock >= run.tuning.inspect_minutes:
			return {"t": "inspect", "tool": tool}
		if picked >= 2:
			break
	var mid: int = int(run.estimate()["mid"])
	var ask: int = int(c["ask"])
	var spendable: int = run.cash - _bot_reserve(run, 1.0)
	if str(c.get("regular", "")) != "" and ask <= spendable:
		return {"t": "buy"}  # no tell after its two tools: the story is worth a fair price
	if ask <= int(mid * 0.8) and ask <= spendable:
		return {"t": "buy"}
	var offer: int = mini(spendable, int(mid * 0.55))
	if int(c["patience"]) > 1 and offer > 0 and offer < ask:
		return {"t": "offer", "amount": offer}
	return {"t": "pass"}


## Cash kept back for tonight's rent: `share` of it all day, and all of it once the day is nearly over.
func _bot_reserve(run: RunState, share: float) -> int:
	var rent: int = run.rent_for(run.night)
	if run.clock < run.tuning.customer_minutes * 3.0:
		return rent
	return int(rent * share)


## Plays a whole run. Returns false if it hit RunState.MAX_COMMANDS (stuck).
func play(run: RunState, rec: RunRecording = null) -> bool:
	while not run.is_over():
		if run.commands >= RunState.MAX_COMMANDS:
			return false
		var cmd: Dictionary = decide(run)
		if rec != null:
			rec.drive(run, cmd)
		else:
			run.apply(cmd)
	return true
