class_name CurioCollection
extends RefCounted
## Estate boxes and the curio collection book (cosmetic only, never tradeable or sellable).
## A box rolls a rarity with the published odds, then a curio of that rarity, preferring ones not yet owned.
## Pity: a legendary is guaranteed once `tuning.box_pity` boxes in a row had none.
## Paid and earned boxes open the same way; `boxes` counts unopened ones. Pure logic, seeded RNG.

const COMMON: String = "common"
const RARE: String = "rare"
const LEGENDARY: String = "legendary"
const CURIOS_PATH: String = "res://game/data/curios.json"

var curios: Array[Dictionary] = []  ## {id, name, rarity}
var owned: Dictionary = {}  ## id -> count
var boxes: int = 0
var since_legendary: int = 0
var opened: int = 0
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


## The odds a player is shown before buying: {rarity: chance}. Always sums to 1.
func odds() -> Dictionary:
	var legendary: float = clampf(tuning.box_legendary_odds, 0.0, 1.0)
	var rare: float = clampf(tuning.box_rare_odds, 0.0, 1.0 - legendary)
	return {COMMON: 1.0 - rare - legendary, RARE: rare, LEGENDARY: legendary}


## Boxes left until the pity guarantee.
func pity_left() -> int:
	return maxi(1, int(tuning.box_pity) - since_legendary)


func add_boxes(n: int) -> void:
	boxes += maxi(0, n)


## Boxes a finished run earns.
func reward_run(run: RunState) -> int:
	var n: int = int(tuning.box_per_won_run) if run.won else 0
	add_boxes(n)
	return n


## Opens one box. Returns {id, name, rarity, new, pity} or {} when there is no box to open.
func open_box() -> Dictionary:
	if boxes <= 0 or curios.is_empty():
		return {}
	boxes -= 1
	opened += 1
	var rarity: String = _curio_roll_rarity()
	var pool: Array[Dictionary] = _curio_pool(rarity)
	var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var is_new: bool = not owned.has(pick["id"])
	owned[pick["id"]] = int(owned.get(pick["id"], 0)) + 1
	var pity: bool = rarity == LEGENDARY and since_legendary + 1 >= int(tuning.box_pity)
	since_legendary = 0 if rarity == LEGENDARY else since_legendary + 1
	return {"id": pick["id"], "name": pick["name"], "rarity": rarity, "new": is_new, "pity": pity}


func complete_count() -> int:
	return owned.size()


func _curio_roll_rarity() -> String:
	if since_legendary + 1 >= int(tuning.box_pity) and not _curio_pool_raw(LEGENDARY).is_empty():
		return LEGENDARY
	var o: Dictionary = odds()
	var r: float = rng.randf()
	var rarity: String = COMMON
	if r < float(o[LEGENDARY]):
		rarity = LEGENDARY
	elif r < float(o[LEGENDARY]) + float(o[RARE]):
		rarity = RARE
	if _curio_pool_raw(rarity).is_empty():
		rarity = COMMON
	return rarity


func _curio_pool_raw(rarity: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in curios:
		if c["rarity"] == rarity:
			out.append(c)
	return out


## Curios of a rarity, unowned ones only while any are left (so duplicates come after the set is done).
func _curio_pool(rarity: String) -> Array[Dictionary]:
	var all: Array[Dictionary] = _curio_pool_raw(rarity)
	var fresh: Array[Dictionary] = []
	for c: Dictionary in all:
		if not owned.has(c["id"]):
			fresh.append(c)
	return fresh if not fresh.is_empty() else all


func to_dict() -> Dictionary:
	return {"owned": owned.duplicate(), "boxes": boxes, "since_legendary": since_legendary, "opened": opened,
		"rng_state": rng.state}


func from_dict(d: Dictionary) -> void:
	owned = (d.get("owned", {}) as Dictionary).duplicate()
	boxes = int(d.get("boxes", 0))
	since_legendary = int(d.get("since_legendary", 0))
	opened = int(d.get("opened", 0))
	rng.state = int(d.get("rng_state", rng.state))
