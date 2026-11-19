class_name Requests
extends RefCounted
## Customer requests: a named customer asks for something, due on a night 1-2 ahead, and pays well for a matching
## held item. Request: {id, who, tid, want: {category, cursed}, due, pay_mult, reward: {kind, id}, called}.
## `called` is true once the requester has come in as the buyer. Data in game/data/requests.json.

const PATH: String = "res://game/data/requests.json"


## A new request made on `night` of a run of `nights`. Draws from `rng`. {} when no night is left to be due on.
static func make(rng: RandomNumberGenerator, cat: Catalog, tun: Tuning, night: int, nights: int, seq: int,
		tid: String, reward: Dictionary) -> Dictionary:
	if night >= nights:
		return {}
	var data: Dictionary = DataFiles.read_dict(PATH)
	var who_list: Array = data.get("who", ["A customer"])
	var due: int = mini(night + rng.randi_range(1, 2), nights)
	var cursed: bool = rng.randf() < 0.4
	var category: String = ""
	if not cursed or rng.randf() < 0.3:
		var cats: PackedStringArray = cat.categories()
		category = cats[rng.randi_range(0, cats.size() - 1)]
	return {"id": "r%d" % seq, "who": str(who_list[rng.randi_range(0, who_list.size() - 1)]), "tid": tid,
		"want": {"category": category, "cursed": cursed}, "due": due,
		"pay_mult": snappedf(tun.request_pay_mult * rng.randf_range(0.9, 1.1), 0.01), "reward": reward, "called": false}


## "a cursed jewelry piece", "any cursed object", "a book".
static func want_text(want: Dictionary) -> String:
	var category: String = str(want.get("category", ""))
	var cursed: bool = bool(want.get("cursed", false))
	if category == "":
		return "any cursed object"
	return "a cursed %s" % category if cursed else "a %s" % category


## The requester's spoken line.
static func line(rng: RandomNumberGenerator, req: Dictionary) -> String:
	var lines: Array = DataFiles.read_dict(PATH).get("lines", ["I want {want} by night {due}."])
	var text: String = str(lines[rng.randi_range(0, lines.size() - 1)])
	return text.replace("{want}", want_text(req["want"])).replace("{due}", str(req["due"]))


## Whether a held item (a dictionary with category and curse) satisfies `want`.
static func matches(want: Dictionary, item: Dictionary) -> bool:
	var category: String = str(want.get("category", ""))
	if category != "" and str(item["category"]) != category:
		return false
	return not bool(want.get("cursed", false)) or str(item["curse"]) != ""
