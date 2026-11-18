class_name ShopBot
extends RefCounted
## Play-bot policies for the lab. A bot sees only what a player sees: the ask, the estimate, tells it found,
## its own cash, rent and what it paid. Greedy buys whatever looks cheap and ignores tells; cautious inspects,
## walks away from anything with a tell and keeps cash back for rent.

const GREEDY: String = "greedy"
const CAUTIOUS: String = "cautious"
const STYLES: PackedStringArray = ["greedy", "cautious"]

var style: String = GREEDY


func _init(style_in: String = GREEDY) -> void:
	style = style_in


func decide(run: RunState) -> Dictionary:
	if run.customer.get("kind", "") == RunState.BUYER:
		return _bot_sell(run)
	if run.customer.get("kind", "") == RunState.SELLER:
		return _bot_greedy_buy(run) if style == GREEDY else _bot_cautious_buy(run)
	return {"t": "pass"}


func _bot_sell(run: RunState) -> Dictionary:
	var best: Dictionary = {}
	for item: Dictionary in run.sellable():
		var score: float = float(item.get("est", 0)) + (1000.0 if int(item.get("tells", 0)) > 0 else 0.0)
		if best.is_empty() or score > float(best["score"]):
			best = {"uid": item["uid"], "score": score}
	if best.is_empty():
		return {"t": "pass"}
	return {"t": "sell", "uid": best["uid"]}


func _bot_greedy_buy(run: RunState) -> Dictionary:
	var c: Dictionary = run.customer
	var mid: int = int(run.estimate()["mid"])
	var ask: int = int(c["ask"])
	var spendable: int = run.cash - _bot_reserve(run, 0.0)
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
	for tool: String in ["uv", "listen"]:
		if not (c["tools"] as Array).has(tool) and run.clock >= run.tuning.inspect_minutes:
			return {"t": "inspect", "tool": tool}
	var mid: int = int(run.estimate()["mid"])
	var ask: int = int(c["ask"])
	var spendable: int = run.cash - _bot_reserve(run, 1.0)
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
