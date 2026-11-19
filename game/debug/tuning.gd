class_name Tuning
extends RefCounted
## Template for live-tunable gameplay numbers (pattern from the skate project's PhysicsTuning).
## Game code reads `Tuning.shared().<field>` every tick instead of hard-coding numbers, so a tuning panel,
## replays, sims and presets can change the feel without touching code.
## Add a row to FIELDS and a matching `var` below; nothing else is needed.
## Presets are JSON dictionaries of {field: value}; unknown keys are ignored.

signal changed(field: String, value: float)

## [field, default, min, max, step, group, doc]. The order here is the order a tuning panel shows.
const FIELDS: Array = [
	["nights", 5.0, 1.0, 10.0, 1.0, "Run", "Nights in one run; survive them all to win."],
	["start_cash", 190.0, 0.0, 1000.0, 5.0, "Run", "Cash at the start of a run."],
	["rent_base", 38.0, 0.0, 500.0, 1.0, "Run", "Rent due at the end of night 1."],
	["rent_growth", 1.45, 1.0, 3.0, 0.05, "Run", "Rent multiplier per night (night n pays base * growth^(n-1))."],
	["day_minutes", 280.0, 60.0, 720.0, 10.0, "Clock", "Shop minutes per day on the day clock."],
	["customer_minutes", 25.0, 5.0, 120.0, 5.0, "Clock", "Day-clock minutes each customer takes before any tool or haggle."],
	["inspect_minutes", 10.0, 0.0, 60.0, 1.0, "Clock", "Day-clock minutes per tool use (UV lamp, scale, listen, touch)."],
	["haggle_minutes", 5.0, 0.0, 30.0, 1.0, "Clock", "Day-clock minutes per offer."],
	["seller_share", 0.5, 0.0, 1.0, 0.05, "Customers", "Chance a customer is selling (when you hold stock); otherwise buying."],
	["buyer_match_chance", 0.8, 0.0, 1.0, 0.05, "Customers", "Chance a buyer wants a category you hold."],
	["patience_base", 3.0, 1.0, 10.0, 1.0, "Customers", "Offers a seller takes before walking out (plus 0-1)."],
	["value_spread", 0.25, 0.0, 1.0, 0.05, "Customers", "Random spread of an object's true value around its catalog value."],
	["seller_reserve_frac", 0.55, 0.1, 1.5, 0.05, "Customers", "A seller's lowest price, as a fraction of true value."],
	["seller_ask_markup", 1.4, 1.0, 3.0, 0.05, "Customers", "A seller's opening ask over their lowest price."],
	["buyer_pay_frac", 1.5, 0.5, 3.0, 0.05, "Customers", "What a buyer pays, as a fraction of the item's true value."],
	["value_noise", 0.5, 0.0, 1.0, 0.05, "Inspect", "Error of the uninspected value estimate (fraction of value)."],
	["tell_chance", 0.6, 0.0, 1.0, 0.05, "Inspect", "Chance the right tool shows a cursed object's tell; below 1, careful players can miss curses."],
	["inspect_noise_cut", 0.6, 0.1, 1.0, 0.05, "Inspect", "Each tool used multiplies the estimate error by this."],
	["cursed_share", 0.35, 0.0, 1.0, 0.05, "Curses", "Chance a seller's object is cursed."],
	["cursed_value_mult", 1.8, 1.0, 5.0, 0.1, "Curses", "True-value multiplier for cursed objects (they pay best)."],
	["dread_on_buy", 1.5, 0.0, 5.0, 0.1, "Curses", "Dread gained when buying a cursed object, times the curse's dread."],
	["dread_per_night", 2.0, 0.0, 5.0, 0.1, "Curses", "Dread per held cursed object each night, times the curse's dread."],
	["wake_threshold", 1.5, 1.0, 20.0, 0.5, "Curses", "Dread at which something wakes."],
	["wake_dread_keep", 0.5, 0.0, 1.0, 0.05, "Curses", "Fraction of Dread left after a wake."],
	["wake_break_chance", 0.6, 0.0, 1.0, 0.05, "Curses", "Chance a wake breaks one held object."],
	["wake_close_chance", 0.6, 0.0, 1.0, 0.05, "Curses", "Chance a wake locks the door and ends the day early."],
	["box_rare_odds", 0.25, 0.0, 1.0, 0.01, "Estate boxes", "Chance an estate box holds a rare curio (shown to the player before buying)."],
	["box_legendary_odds", 0.05, 0.0, 1.0, 0.01, "Estate boxes", "Chance an estate box holds a legendary curio (shown before buying)."],
	["box_pity", 30, 1, 200, 1, "Estate boxes", "A legendary is guaranteed by this many boxes without one."],
	["box_soft_pity_start", 20, 1, 200, 1, "Estate boxes", "From this many boxes without a legendary, its odds rise each box (soft pity)."],
	["box_soft_pity_step", 0.06, 0.0, 1.0, 0.01, "Estate boxes", "Legendary odds added per box past the soft pity start."],
	["featured_rate_up", 0.5, 0.0, 1.0, 0.05, "Estate boxes", "Within the featured curio's rarity, the chance the pick is the featured curio."],
	["shards_common", 1, 0, 100, 1, "Estate boxes", "Shards from a duplicate common curio out of a sealed box."],
	["shards_rare", 5, 0, 200, 1, "Estate boxes", "Shards from a duplicate rare curio out of a sealed box."],
	["shards_legendary", 20, 0, 500, 1, "Estate boxes", "Shards from a duplicate legendary curio out of a sealed box."],
	["craft_common", 10, 1, 500, 1, "Estate boxes", "Shards to craft a chosen common curio."],
	["craft_rare", 40, 1, 1000, 1, "Estate boxes", "Shards to craft a chosen rare curio."],
	["craft_legendary", 150, 1, 5000, 1, "Estate boxes", "Shards to craft a chosen legendary curio."],
	["box_per_won_run", 1, 0, 10, 1, "Estate boxes", "Free estate boxes for surviving a run (every curio can be earned in play)."],
	["wager_minutes", 10, 0, 60, 1, "Tarot wager", "Day-clock minutes a tarot wager takes."],
	["wager_max_frac", 0.5, 0.0, 1.0, 0.05, "Tarot wager", "Largest stake, as a fraction of cash on hand."],
	["spell_casts_per_night", 3, 0, 10, 1, "Grimoire", "Spell casts per night."],
	["spell_backfire_base", 0.1, 0.0, 1.0, 0.01, "Grimoire", "Backfire chance of a cast at zero Dread."],
	["spell_backfire_per_dread", 0.06, 0.0, 0.5, 0.01, "Grimoire", "Backfire chance added per point of Dread."],
	["hex_mult", 0.65, 0.1, 1.0, 0.05, "Grimoire", "Hex multiplies the seller's lowest price and ask by this."],
	["glamour_mult", 1.3, 1.0, 3.0, 0.05, "Grimoire", "Glamour multiplies the next buyer's payment."],
	["banish_dread", 2.0, 0.0, 10.0, 0.1, "Grimoire", "Dread removed by banishing a cursed object."],
	["seal_debt_mult", 1.3, 1.0, 3.0, 0.05, "Grimoire", "Rent multiplier on a night the shop was sealed."],
	["backfire_dread", 1.0, 0.0, 10.0, 0.1, "Grimoire", "Dread added by a dread_spike backfire."],
	["backfire_cash_frac", 0.25, 0.0, 1.0, 0.05, "Grimoire", "Share of cash burned by a cash_burn backfire."],
	["hidden_find_chance", 0.12, 0.0, 1.0, 0.01, "Midnight Table", "Chance a seller's object hides a page or curio."],
	["hidden_page_share", 0.5, 0.0, 1.0, 0.05, "Midnight Table", "Share of hidden finds that are spell pages (the rest curios)."],
	["night_curio_chance", 0.0, 0.0, 1.0, 0.01, "Midnight Table", "Chance a survived night leaves a curio at the table door."],
	["table_games_per_night", 1, 0, 5, 1, "Midnight Table", "House games allowed per night at the Midnight Table."],
	["table_lots_per_night", 1, 0, 5, 1, "Midnight Table", "Sealed lots on offer per night."],
	["table_max_stake_frac", 0.5, 0.0, 1.0, 0.05, "Midnight Table", "Largest table stake, as a fraction of cash on hand."],
	["lot_price", 60, 0, 1000, 5, "Midnight Table", "Price of a sealed lot."],
	["pairs_tries", 3, 1, 5, 1, "Midnight Table", "Tries (two flips each) in Tarot Pairs."],
	["pairs_pay_scale", 0.4, 0.0, 2.0, 0.05, "Midnight Table", "Tarot Pairs: stake multiple added per matched card, times its tarot mult."],
	["secs_per_customer", 25.0, 1.0, 120.0, 1.0, "Pacing", "Estimated real seconds a player spends per customer (lab run length)."],
	["secs_per_inspect", 5.0, 0.0, 30.0, 0.5, "Pacing", "Estimated real seconds per tool use."],
	["secs_per_haggle", 4.0, 0.0, 30.0, 0.5, "Pacing", "Estimated real seconds per offer."],
	["secs_per_night", 30.0, 0.0, 300.0, 5.0, "Pacing", "Estimated real seconds of night-end and rent screens."],
]

static var _shared: Tuning = null

var nights: float
var start_cash: float
var rent_base: float
var rent_growth: float
var day_minutes: float
var customer_minutes: float
var inspect_minutes: float
var haggle_minutes: float
var seller_share: float
var buyer_match_chance: float
var patience_base: float
var value_spread: float
var seller_reserve_frac: float
var seller_ask_markup: float
var buyer_pay_frac: float
var value_noise: float
var inspect_noise_cut: float
var tell_chance: float
var cursed_share: float
var cursed_value_mult: float
var dread_on_buy: float
var dread_per_night: float
var wake_threshold: float
var wake_dread_keep: float
var wake_close_chance: float
var wake_break_chance: float
var box_rare_odds: float
var box_legendary_odds: float
var box_pity: float
var box_soft_pity_start: float
var box_soft_pity_step: float
var featured_rate_up: float
var shards_common: float
var shards_rare: float
var shards_legendary: float
var craft_common: float
var craft_rare: float
var craft_legendary: float
var box_per_won_run: float
var wager_minutes: float
var wager_max_frac: float
var spell_casts_per_night: float
var spell_backfire_base: float
var spell_backfire_per_dread: float
var hex_mult: float
var glamour_mult: float
var banish_dread: float
var seal_debt_mult: float
var backfire_dread: float
var backfire_cash_frac: float
var hidden_find_chance: float
var hidden_page_share: float
var night_curio_chance: float
var table_games_per_night: float
var table_lots_per_night: float
var table_max_stake_frac: float
var lot_price: float
var pairs_tries: float
var pairs_pay_scale: float
var secs_per_customer: float
var secs_per_inspect: float
var secs_per_haggle: float
var secs_per_night: float


func _init() -> void:
	reset()


## The tuning the game uses unless it is given its own. A tuning panel edits this one.
static func shared() -> Tuning:
	if _shared == null:
		_shared = Tuning.new()
	return _shared


static func field_names() -> PackedStringArray:
	var out := PackedStringArray()
	for f: Array in FIELDS:
		out.append(f[0])
	return out


static func field_info(field: String) -> Dictionary:
	for f: Array in FIELDS:
		if f[0] == field:
			return {"name": f[0], "default": f[1], "min": f[2], "max": f[3], "step": f[4], "group": f[5], "doc": f[6]}
	return {}


func reset() -> void:
	for f: Array in FIELDS:
		set(f[0], float(f[1]))


## Sets one field, clamped to its range. Returns false for an unknown field.
func set_value(field: String, value: float) -> bool:
	var info: Dictionary = field_info(field)
	if info.is_empty():
		return false
	var v: float = clampf(value, float(info["min"]), float(info["max"]))
	set(field, v)
	changed.emit(field, v)
	return true


func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for f: Array in FIELDS:
		d[f[0]] = get(f[0])
	return d


## Applies known keys from `d` (others are ignored). Returns the number of fields applied.
func apply_dict(d: Dictionary) -> int:
	var n: int = 0
	for key: Variant in d:
		if set_value(str(key), float(d[key])):
			n += 1
	return n


## Only the fields that differ from the defaults: what a preset needs to store.
func diff_from_defaults() -> Dictionary:
	var d: Dictionary = {}
	for f: Array in FIELDS:
		if not is_equal_approx(float(get(f[0])), float(f[1])):
			d[f[0]] = get(f[0])
	return d


func copy_from(other: Tuning) -> void:
	apply_dict(other.to_dict())


func save_json(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t", false))
	return OK


## Loads a preset file over the current values. Returns false if the file is missing or not a JSON object.
func load_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	apply_dict(parsed)
	return true
