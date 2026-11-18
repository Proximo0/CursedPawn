class_name CurioCollection
extends RefCounted
## Estate boxes and the curio collection book. Curios are cosmetic and never change a run (Washington law
## treats anything that extends play as a thing of value).
##
## Washington gambling = paying + chance + a thing of value. Each way to get a curio drops one of the three:
## - sealed box (paid, chance): the curio is LOCKED to the account; duplicates turn into locked shards.
## - appraised box (paid, no chance): the exact curio is shown before buying; tradeable.
## - free box (earned, chance): tradeable; duplicates stay as tradeable copies.
## - featured curio at a fixed price, run drops, grants: tradeable.
## - crafting from shards: tradeable only when paid for with free shards.
## Odds: rarity first (published odds, soft pity, hard pity), then a curio of that rarity: the featured curio
## with `featured_rate_up`, otherwise unowned curios before duplicates. Pure logic, seeded RNG.

const COMMON: String = "common"
const RARE: String = "rare"
const LEGENDARY: String = "legendary"
const RARITIES: PackedStringArray = ["common", "rare", "legendary"]
const CURIOS_PATH: String = "res://game/data/curios.json"

var curios: Array[Dictionary] = []  ## {id, name, rarity, set}
var owned: Dictionary = {}  ## id -> copies held
var tradeable: Dictionary = {}  ## id -> copies that may be traded (never more than owned)
var free_boxes: int = 0
var paid_boxes: int = 0
var shards_locked: int = 0
var shards_free: int = 0
var since_legendary: int = 0
var opened: int = 0
var featured_id: String = ""
var appraised: Dictionary = {}  ## the curio the current appraised box holds, shown before purchase
var claimed_sets: PackedStringArray = []
var tuning: Tuning
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func create(seed_value: int, tun: Tuning = null) -> CurioCollection:
	var c := CurioCollection.new()
	c.tuning = tun if tun != null else Tuning.shared()
	c.rng.seed = seed_value
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CURIOS_PATH))
	if parsed is Array:
		for d: Variant in parsed:
			if d is Dictionary:
				c.curios.append(d)
	return c


func curio(id: String) -> Dictionary:
	for c: Dictionary in curios:
		if c["id"] == id:
			return c
	return {}


## Unopened boxes of both kinds.
func boxes() -> int:
	return free_boxes + paid_boxes


## The odds for the NEXT box, as shown before buying: {rarity: chance}, summing to 1. Includes soft pity, and is
## {legendary: 1} when hard pity is due.
func odds() -> Dictionary:
	if since_legendary + 1 >= int(tuning.box_pity):
		return {COMMON: 0.0, RARE: 0.0, LEGENDARY: 1.0}
	var legendary: float = tuning.box_legendary_odds
	var past: int = since_legendary + 1 - int(tuning.box_soft_pity_start)
	if past > 0:
		legendary += tuning.box_soft_pity_step * past
	legendary = clampf(legendary, 0.0, 1.0)
	var rare: float = clampf(tuning.box_rare_odds, 0.0, 1.0 - legendary)
	return {COMMON: 1.0 - rare - legendary, RARE: rare, LEGENDARY: legendary}


## Boxes left until the guaranteed legendary.
func pity_left() -> int:
	return maxi(1, int(tuning.box_pity) - since_legendary)


func add_boxes(n: int, paid: bool = false) -> void:
	if paid:
		paid_boxes += maxi(0, n)
	else:
		free_boxes += maxi(0, n)


## Free boxes a finished run earns.
func reward_run(run: RunState) -> int:
	var n: int = int(tuning.box_per_won_run) if run.won else 0
	add_boxes(n)
	return n


## Sets the featured curio (rotated by the store every two weeks). "" for none.
func set_featured(id: String) -> bool:
	if id != "" and curio(id).is_empty():
		return false
	featured_id = id
	return true


## Opens one box, free boxes first. Returns {id, name, rarity, new, pity, tradeable, shards} or {} without a box.
func open_box() -> Dictionary:
	if boxes() <= 0 or curios.is_empty():
		return {}
	var from_paid: bool = free_boxes <= 0
	if from_paid:
		paid_boxes -= 1
	else:
		free_boxes -= 1
	opened += 1
	var pity: bool = since_legendary + 1 >= int(tuning.box_pity)
	var rarity: String = _curio_roll_rarity()
	var pick: Dictionary = _curio_pick(rarity)
	since_legendary = 0 if rarity == LEGENDARY else since_legendary + 1
	var is_new: bool = not owned.has(pick["id"])
	var shards: int = 0
	if from_paid and not is_new:
		shards = _curio_shards_for(rarity)
		shards_locked += shards
	else:
		_curio_add(pick["id"], not from_paid)
	return {"id": pick["id"], "name": pick["name"], "rarity": rarity, "new": is_new,
		"pity": pity and rarity == LEGENDARY, "tradeable": not from_paid, "shards": shards}


## The appraised box on offer: rolled once and shown before purchase, so buying it involves no chance.
func appraised_offer() -> Dictionary:
	if appraised.is_empty() and not curios.is_empty():
		var rarity: String = _curio_roll_rarity_plain()
		appraised = _curio_pick(rarity).duplicate()
	return appraised


## Delivers the appraised curio after payment (tradeable) and rolls the next offer.
func buy_appraised() -> Dictionary:
	var got: Dictionary = appraised_offer()
	if got.is_empty():
		return {}
	_curio_add(got["id"], true)
	appraised = {}
	appraised_offer()
	return got


## A curio bought at a fixed price, dropped in a run or granted: tradeable.
func grant(id: String) -> bool:
	if curio(id).is_empty():
		return false
	_curio_add(id, true)
	return true


func craft_cost(id: String) -> int:
	match str(curio(id).get("rarity", "")):
		COMMON:
			return int(tuning.craft_common)
		RARE:
			return int(tuning.craft_rare)
		LEGENDARY:
			return int(tuning.craft_legendary)
	return -1


## Crafts a chosen curio. Enough free shards pay for it alone and make it tradeable; otherwise locked shards are
## spent first and the curio is locked. Returns {id, tradeable} or {} when there are not enough shards.
func craft(id: String) -> Dictionary:
	var cost: int = craft_cost(id)
	if cost < 0 or shards_free + shards_locked < cost:
		return {}
	var free_only: bool = shards_free >= cost
	if free_only:
		shards_free -= cost
	else:
		var from_locked: int = mini(shards_locked, cost)
		shards_locked -= from_locked
		shards_free -= cost - from_locked
	_curio_add(id, free_only)
	return {"id": id, "tradeable": free_only}


## Removes one tradeable copy when it is traded or sold on the market. False if no copy may be traded.
func take_tradeable(id: String) -> bool:
	if int(tradeable.get(id, 0)) <= 0:
		return false
	tradeable[id] = int(tradeable[id]) - 1
	owned[id] = int(owned[id]) - 1
	if int(owned[id]) <= 0:
		owned.erase(id)
	if int(tradeable[id]) <= 0:
		tradeable.erase(id)
	return true


## A traded-in copy arriving from another player: tradeable.
func receive_trade(id: String) -> bool:
	return grant(id)


func complete_count() -> int:
	return owned.size()


## {set name: [curio ids]}.
func sets() -> Dictionary:
	var out: Dictionary = {}
	for c: Dictionary in curios:
		var s: String = str(c.get("set", ""))
		if s == "":
			continue
		if not out.has(s):
			out[s] = []
		(out[s] as Array).append(c["id"])
	return out


## Sets newly completed since the last call (each reward, a shop theme, is claimed once).
func claim_completed_sets() -> PackedStringArray:
	var out := PackedStringArray()
	var all: Dictionary = sets()
	for s: String in all:
		if claimed_sets.has(s):
			continue
		var done: bool = true
		for id: Variant in all[s]:
			if not owned.has(id):
				done = false
				break
		if done:
			claimed_sets.append(s)
			out.append(s)
	return out


func _curio_add(id: String, can_trade: bool) -> void:
	owned[id] = int(owned.get(id, 0)) + 1
	if can_trade:
		tradeable[id] = int(tradeable.get(id, 0)) + 1


func _curio_shards_for(rarity: String) -> int:
	match rarity:
		RARE:
			return int(tuning.shards_rare)
		LEGENDARY:
			return int(tuning.shards_legendary)
	return int(tuning.shards_common)


func _curio_roll_rarity() -> String:
	var o: Dictionary = odds()
	var r: float = rng.randf()
	var rarity: String = COMMON
	if r < float(o[LEGENDARY]):
		rarity = LEGENDARY
	elif r < float(o[LEGENDARY]) + float(o[RARE]):
		rarity = RARE
	return rarity if not _curio_pool_raw(rarity).is_empty() else COMMON


## Base odds without pity (appraised boxes do not touch the pity counter).
func _curio_roll_rarity_plain() -> String:
	var r: float = rng.randf()
	var rarity: String = COMMON
	if r < tuning.box_legendary_odds:
		rarity = LEGENDARY
	elif r < tuning.box_legendary_odds + tuning.box_rare_odds:
		rarity = RARE
	return rarity if not _curio_pool_raw(rarity).is_empty() else COMMON


func _curio_pick(rarity: String) -> Dictionary:
	if featured_id != "" and str(curio(featured_id).get("rarity", "")) == rarity:
		if rng.randf() < tuning.featured_rate_up:
			return curio(featured_id)
	var pool: Array[Dictionary] = _curio_pool(rarity)
	return pool[rng.randi_range(0, pool.size() - 1)]


func _curio_pool_raw(rarity: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in curios:
		if c["rarity"] == rarity:
			out.append(c)
	return out


## Curios of a rarity, unowned ones only while any are left.
func _curio_pool(rarity: String) -> Array[Dictionary]:
	var all: Array[Dictionary] = _curio_pool_raw(rarity)
	var fresh: Array[Dictionary] = []
	for c: Dictionary in all:
		if not owned.has(c["id"]):
			fresh.append(c)
	return fresh if not fresh.is_empty() else all


func to_dict() -> Dictionary:
	return {"owned": owned.duplicate(), "tradeable": tradeable.duplicate(), "free_boxes": free_boxes,
		"paid_boxes": paid_boxes, "shards_locked": shards_locked, "shards_free": shards_free,
		"since_legendary": since_legendary, "opened": opened, "featured_id": featured_id,
		"appraised": appraised.duplicate(), "claimed_sets": Array(claimed_sets), "rng_state": rng.state}


func from_dict(d: Dictionary) -> void:
	owned = (d.get("owned", {}) as Dictionary).duplicate()
	tradeable = (d.get("tradeable", {}) as Dictionary).duplicate()
	free_boxes = int(d.get("free_boxes", 0))
	paid_boxes = int(d.get("paid_boxes", 0))
	shards_locked = int(d.get("shards_locked", 0))
	shards_free = int(d.get("shards_free", 0))
	since_legendary = int(d.get("since_legendary", 0))
	opened = int(d.get("opened", 0))
	featured_id = str(d.get("featured_id", ""))
	appraised = (d.get("appraised", {}) as Dictionary).duplicate()
	claimed_sets = PackedStringArray(d.get("claimed_sets", []))
	rng.state = int(d.get("rng_state", rng.state))
