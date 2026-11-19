class_name Grimoire
extends RefCounted
## The spell rules, pure: which spells exist (game/data/spells.json), whether a cast is allowed, how likely it is to
## backfire and what the effects are. RunState applies the results and owns the rng, cash and Dread.

const SPELLS_PATH: String = "res://game/data/spells.json"
const DEFAULT_KNOWN: PackedStringArray = ["scry", "hex"]
const BACKFIRE_KINDS: PackedStringArray = ["dread_spike", "cash_burn", "customer_flees", "curse_jumps"]
const BACKFIRE_TEXT: Dictionary = {
	"dread_spike": "The shop shudders. Dread rises.",
	"cash_burn": "Coins curl up in your pocket and burn.",
	"customer_flees": "The customer takes one look at you and flees.",
	"curse_jumps": "Something slithers off the shelf and into another object.",
}

var spells: Array[Dictionary] = []  ## {id, name, dread, text, backfire}
var tuning: Tuning
var force_kind: String = ""  ## tests: always backfire this way


static func load_default(tun: Tuning = null) -> Grimoire:
	var g := Grimoire.new()
	g.tuning = tun if tun != null else Tuning.shared()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPELLS_PATH))
	if parsed is Array:
		for d: Variant in parsed:
			if d is Dictionary:
				g.spells.append(d)
	return g


func spell(id: String) -> Dictionary:
	for s: Dictionary in spells:
		if s["id"] == id:
			return s
	return {}


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for s: Dictionary in spells:
		out.append(str(s["id"]))
	return out


## Chance a cast backfires at the current Dread.
func backfire_chance(dread: float) -> float:
	return clampf(tuning.spell_backfire_base + tuning.spell_backfire_per_dread * dread, 0.0, 1.0)


## Why a cast is not allowed, or "" when it is. `customer` and `inventory` are RunState's; `uid` is banish's target.
func why_invalid(id: String, known: PackedStringArray, casts_left: int, customer: Dictionary,
		inventory: Array[Dictionary], uid: int, summon_pending: bool) -> String:
	if spell(id).is_empty() or not known.has(id):
		return "unknown spell %s" % id
	if casts_left <= 0:
		return "no casts left"
	var kind: String = str(customer.get("kind", ""))
	match id:
		"scry", "hex":
			if kind != RunState.SELLER:
				return "needs a seller"
		"glamour":
			if kind != RunState.BUYER:
				return "needs a buyer"
		"banish":
			for item: Dictionary in inventory:
				if int(item["uid"]) == uid and str(item["curse"]) != "":
					return ""
			return "no cursed object %d" % uid
		"summon":
			if inventory.is_empty() or summon_pending:
				return "nothing to summon for"
	return ""


## The tell scry shows for a seller: {tool, tell}. A cursed object gives its first unseen tell (tell_chance does not
## apply); a clean one gives {tool: first unused tool, tell: ""}.
func scry_pick(customer: Dictionary, cat: Catalog) -> Dictionary:
	var used: Array = customer["tools"]
	var cid: String = str(customer["item"]["curse"])
	if cid != "":
		var tells: Dictionary = cat.curse(cid).get("tells", {})
		var seen: Array = customer["tells"]
		var first: Dictionary = {}
		for tool: String in Catalog.TOOLS:
			if str(tells.get(tool, "")) == "":
				continue
			if not seen.has(tool):
				return {"tool": tool, "tell": str(tells[tool])}
			if first.is_empty():
				first = {"tool": tool, "tell": str(tells[tool])}
		if not first.is_empty():
			return first
	for tool: String in Catalog.TOOLS:
		if not used.has(tool):
			return {"tool": tool, "tell": ""}
	return {"tool": "", "tell": ""}


## Seller's reserve and ask after a hex.
func hexed(reserve: int, ask: int) -> Dictionary:
	var r: int = maxi(1, int(round(reserve * tuning.hex_mult)))
	return {"reserve": r, "ask": maxi(r, int(round(ask * tuning.hex_mult)))}


## The category a summoned buyer wants: the one held most (first in order on a tie).
func summon_category(inventory: Array[Dictionary]) -> String:
	var counts: Dictionary = {}
	var best: String = ""
	for item: Dictionary in inventory:
		var c: String = str(item["category"])
		counts[c] = int(counts.get(c, 0)) + 1
		if best == "" or int(counts[c]) > int(counts[best]):
			best = c
	return best


## A backfire kind. curse_jumps needs a clean object to land on; otherwise it is a dread_spike.
func backfire_kind(rng: RandomNumberGenerator, inventory: Array[Dictionary]) -> String:
	if force_kind != "":
		return force_kind
	var kind: String = BACKFIRE_KINDS[rng.randi_range(0, BACKFIRE_KINDS.size() - 1)]
	if kind == "curse_jumps":
		var clean: bool = false
		for item: Dictionary in inventory:
			if str(item["curse"]) == "":
				clean = true
		if not clean:
			return "dread_spike"
	return kind
