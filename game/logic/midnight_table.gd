class_name MidnightTable
extends RefCounted
## The house games of the Midnight Table, pure: 2d6 dice, a draw-to-13 card hand, the weighted wheel, the item
## stake and Tarot Pairs. Run cash and held run objects are the only stakes. Every game returns < 1 per coin
## staked; the `*_return()` functions compute that and Catalog.problems() checks it. RunState owns the rng.
## Data: game/data/table.json (+ the tarot deck for Pairs). Numbers: that file and Tuning.

const TABLE_PATH: String = "res://game/data/table.json"
const PAIRS_SIM_SEEDS: int = 400

var cfg: Dictionary = {}
var tuning: Tuning


static func load_default(tun: Tuning = null) -> MidnightTable:
	var t := MidnightTable.new()
	t.tuning = tun if tun != null else Tuning.shared()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if parsed is Dictionary:
		t.cfg = parsed
	return t


func wheel() -> Array:
	return cfg.get("wheel", [])


## Largest stake for `cash`.
func max_stake(cash: int) -> int:
	return int(cash * tuning.table_max_stake_frac)


# ---- dice: 2d6, a 7 loses; the called side wins on 8-12 (high) or 2-6 (low)

func dice_roll(rng: RandomNumberGenerator, call: String, stake: int) -> Dictionary:
	var d1: int = rng.randi_range(1, 6)
	var d2: int = rng.randi_range(1, 6)
	var win: bool = _dice_wins(d1 + d2, call)
	return {"d1": d1, "d2": d2, "call": call, "win": win, "stake": stake,
		"payout": int(round(stake * float(cfg["dice"]["mult"]))) if win else 0}


static func _dice_wins(total: int, call: String) -> bool:
	return (call == "high" and total > 7) or (call == "low" and total < 7)


func dice_return() -> float:
	var wins: int = 0
	for a: int in range(1, 7):
		for b: int in range(1, 7):
			if _dice_wins(a + b, "high"):
				wins += 1
	return float(wins) / 36.0 * float(cfg["dice"]["mult"])


# ---- hand: cards 1..card_max, draw toward `target` (over it busts), the house draws while under `house_stand`

func hand_card(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, int(cfg["hand"]["card_max"]))


## The house plays out from `cards` (it draws while its total is below house_stand). Returns the drawn cards.
func hand_house_draws(rng: RandomNumberGenerator, total: int) -> Array[int]:
	var out: Array[int] = []
	while total < int(cfg["hand"]["house_stand"]):
		var c: int = hand_card(rng)
		out.append(c)
		total += c
	return out


## {win, push, payout} for final totals.
func hand_result(you: int, house: int, stake: int) -> Dictionary:
	var target: int = int(cfg["hand"]["target"])
	if you > target:
		return {"win": false, "push": false, "payout": 0}
	if house > target or you > house:
		return {"win": true, "push": false, "payout": int(round(stake * float(cfg["hand"]["win_mult"])))}
	if you == house:
		return {"win": false, "push": true, "payout": int(round(stake * float(cfg["hand"]["push_mult"])))}
	return {"win": false, "push": false, "payout": 0}


## Expected return per coin with the best possible play (the house total is hidden until you stand).
func hand_return() -> float:
	var h: Dictionary = cfg["hand"]
	var target: int = int(h["target"])
	var cmax: int = int(h["card_max"])
	var stand_at: int = int(h["house_stand"])
	var house: Dictionary = {}  # final total (target + 1 = bust) -> probability
	var dist: Dictionary = {0: 1.0}
	for total: int in range(0, stand_at):
		if not dist.has(total):
			continue
		for c: int in range(1, cmax + 1):
			var nt: int = total + c
			dist[nt] = float(dist.get(nt, 0.0)) + float(dist[total]) / cmax
	for total: Variant in dist:
		if int(total) >= stand_at:
			var key: int = mini(int(total), target + 1)
			house[key] = float(house.get(key, 0.0)) + float(dist[total])
	var value: Dictionary = {}  # best expected return for a player total
	for p: int in range(target, 0, -1):
		var stand: float = 0.0
		for k: Variant in house:
			stand += float(house[k]) * _hand_pay(p, int(k), target, h)
		var draw: float = 0.0
		for c: int in range(1, cmax + 1):
			draw += float(value.get(p + c, 0.0)) / cmax if p + c <= target else 0.0
		value[p] = maxf(stand, draw)
	var deal: int = int(h.get("deal", 2))
	var start: Dictionary = {0: 1.0}
	for i: int in range(deal):
		var nxt: Dictionary = {}
		for t: Variant in start:
			for c: int in range(1, cmax + 1):
				nxt[int(t) + c] = float(nxt.get(int(t) + c, 0.0)) + float(start[t]) / cmax
		start = nxt
	var total_ret: float = 0.0
	for t: Variant in start:
		total_ret += float(start[t]) * (float(value.get(int(t), 0.0)) if int(t) <= target else 0.0)
	return total_ret


static func _hand_pay(you: int, house: int, target: int, h: Dictionary) -> float:
	if you > target:
		return 0.0
	if house > target or you > house:
		return float(h["win_mult"])
	return float(h["push_mult"]) if you == house else 0.0


# ---- wheel

## One spin: {segment, name, mult, stake, payout, prize, dread}.
func wheel_spin(rng: RandomNumberGenerator, stake: int) -> Dictionary:
	var total: float = 0.0
	for seg: Dictionary in wheel():
		total += float(seg["weight"])
	var r: float = rng.randf() * total
	var pick: Dictionary = wheel()[wheel().size() - 1]
	for seg: Dictionary in wheel():
		r -= float(seg["weight"])
		if r < 0.0:
			pick = seg
			break
	return {"segment": pick["id"], "name": pick["name"], "mult": float(pick["mult"]), "stake": stake,
		"payout": int(round(stake * float(pick["mult"]))), "prize": str(pick.get("prize", "")),
		"dread": float(pick.get("dread", 0.0))}


func wheel_return() -> float:
	var total: float = 0.0
	var paid: float = 0.0
	for seg: Dictionary in wheel():
		total += float(seg["weight"])
		paid += float(seg["weight"]) * float(seg["mult"])
	return paid / total if total > 0.0 else 0.0


# ---- item stake: a coin flip at house odds; a win doubles the item's value, a loss forfeits it

func stake_item_flip(rng: RandomNumberGenerator, value: int) -> Dictionary:
	var win: bool = rng.randf() < float(cfg["stake_item"]["win_chance"])
	return {"win": win, "value": int(round(value * float(cfg["stake_item"]["win_mult"]))) if win else value}


func item_return() -> float:
	return float(cfg["stake_item"]["win_chance"]) * float(cfg["stake_item"]["win_mult"])


# ---- Tarot Pairs: two copies of each tarot card face down; pairs_tries tries of two flips

## A shuffled board of tarot indexes, two of each.
func pairs_deal(rng: RandomNumberGenerator, tarot: Array[Dictionary]) -> Array[int]:
	var board: Array[int] = []
	for i: int in range(tarot.size()):
		board.append(i)
		board.append(i)
	for i: int in range(board.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = board[i]
		board[i] = board[j]
		board[j] = tmp
	return board


## Payout multiple (of the stake) after matching `card`, given the multiple so far. A void card zeroes it.
func pairs_add(so_far: float, card: Dictionary) -> float:
	if str(card["id"]) == str(cfg.get("pairs", {}).get("void", "")):
		return 0.0
	return so_far + float(card["mult"]) * tuning.pairs_pay_scale


## Expected payout multiple with perfect memory, averaged over PAIRS_SIM_SEEDS fixed seeds.
func pairs_return(tarot: Array[Dictionary]) -> float:
	if tarot.is_empty():
		return 0.0
	var total: float = 0.0
	for s: int in range(PAIRS_SIM_SEEDS):
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + s
		total += _pairs_perfect_game(rng, tarot)
	return total / PAIRS_SIM_SEEDS


func _pairs_perfect_game(rng: RandomNumberGenerator, tarot: Array[Dictionary]) -> float:
	var board: Array[int] = pairs_deal(rng, tarot)
	var seen: Dictionary = {}  # board index -> true
	var done: Dictionary = {}
	var acc: float = 0.0
	for _try: int in range(int(tuning.pairs_tries)):
		var pair: Array[int] = _pairs_known_pair(board, seen, done, tarot)
		if pair.is_empty():
			var a: int = _pairs_unseen(board, seen, done, -1, rng)
			if a < 0:
				break
			seen[a] = true
			var known_mate: int = -1
			for i: int in seen:
				if i != a and not done.has(i) and board[i] == board[a]:
					known_mate = i
			var b: int = known_mate if known_mate >= 0 else _pairs_unseen(board, seen, done, a, rng)
			if b < 0:
				break
			seen[b] = true
			pair = [a, b]
		if board[pair[0]] == board[pair[1]]:
			acc = pairs_add(acc, tarot[board[pair[0]]])
			done[pair[0]] = true
			done[pair[1]] = true
	return acc


## A fully seen, unmatched pair, preferring the highest mult and skipping the void card; [] when none.
func _pairs_known_pair(board: Array[int], seen: Dictionary, done: Dictionary, tarot: Array[Dictionary]) -> Array[int]:
	var best: Array[int] = []
	var best_mult: float = -1.0
	for i: int in seen:
		if done.has(i):
			continue
		for j: int in seen:
			if j > i and not done.has(j) and board[i] == board[j]:
				var card: Dictionary = tarot[board[i]]
				if pairs_add(1.0, card) <= 0.0:
					continue  # never cash in the void card on purpose
				var m: float = float(card["mult"])
				if m > best_mult:
					best_mult = m
					best = [i, j]
	return best


## A random face-down board index not yet seen (and not `skip`); -1 if none.
func _pairs_unseen(board: Array[int], seen: Dictionary, done: Dictionary, skip: int, rng: RandomNumberGenerator) -> int:
	var open: Array[int] = []
	for i: int in range(board.size()):
		if not seen.has(i) and not done.has(i) and i != skip:
			open.append(i)
	return open[rng.randi_range(0, open.size() - 1)] if not open.is_empty() else -1


# ---- sealed lots

## A curio rarity for a lot or night find, weighted by table.json.
func curio_rarity(rng: RandomNumberGenerator) -> String:
	var w: Dictionary = cfg["lot"]["curio_weights"]
	var total: float = 0.0
	for k: Variant in w:
		total += float(w[k])
	var r: float = rng.randf() * total
	for k: Variant in w:
		r -= float(w[k])
		if r < 0.0:
			return str(k)
	return "common"
