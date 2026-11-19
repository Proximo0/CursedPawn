class_name TsKeys
extends RefCounted
## The keyboard actions of the shop screen and the player's rebindings. Every action has a default key; the game turns a
## pressed key into the default key of the action it is bound to (`canonical`) and then runs its old key logic, so the
## rest of the code never learns about rebinding. A rebound action frees its old key (it does nothing any more).
## Bindings are {action: keycode} for the changed ones only, stored in TsSettings.

const ACTIONS: Array[Dictionary] = [
	{"id": "uv", "label": "UV LAMP", "key": KEY_1},
	{"id": "scale", "label": "SCALE", "key": KEY_2},
	{"id": "listen", "label": "LISTEN", "key": KEY_3},
	{"id": "touch", "label": "TOUCH", "key": KEY_4},
	{"id": "pendulum", "label": "PENDULUM", "key": KEY_Q},
	{"id": "offer", "label": "OFFER OR SELL", "key": KEY_ENTER},
	{"id": "buy", "label": "BUY", "key": KEY_B},
	{"id": "pass", "label": "PASS", "key": KEY_P},
	{"id": "counter", "label": "COUNTER", "key": KEY_C},
	{"id": "look", "label": "LOOK CLOSER", "key": KEY_I},
	{"id": "tarot", "label": "TAROT", "key": KEY_T},
	{"id": "replay", "label": "REPLAY WAKE", "key": KEY_R},
	{"id": "mute", "label": "MUTE", "key": KEY_M},
	{"id": "spell_scry", "label": "SPELL 1", "key": KEY_5},
	{"id": "spell_hex", "label": "SPELL 2", "key": KEY_6},
	{"id": "spell_glamour", "label": "SPELL 3", "key": KEY_7},
	{"id": "spell_banish", "label": "SPELL 4", "key": KEY_8},
	{"id": "spell_summon", "label": "SPELL 5", "key": KEY_9},
	{"id": "spell_seal", "label": "SPELL 6", "key": KEY_0},
]
const RESERVED: Array[int] = [KEY_ESCAPE, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10,
	KEY_F11, KEY_F12, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_BACKSPACE]

static var _bound: Dictionary = {}


static func set_bindings(d: Dictionary) -> void:
	_bound = clean(d)


static func default_of(action: String) -> int:
	for a: Dictionary in ACTIONS:
		if str(a["id"]) == action:
			return int(a["key"])
	return 0


static func key_of(action: String) -> int:
	return int(_bound.get(action, default_of(action)))


## What a key is called on a button: at most four capitals.
static func label_of(action: String) -> String:
	return name_of(key_of(action))


static func name_of(key: int) -> String:
	var s: String = OS.get_keycode_string(key).to_upper()
	return s.left(5) if s != "" else "?"


## The default key of the action `k` is bound to; 0 when `k` is the default of an action that has moved away.
static func canonical(k: int) -> int:
	for action: Variant in _bound.keys():
		if int(_bound[action]) == k:
			return default_of(str(action))
	for action: Variant in _bound.keys():
		if default_of(str(action)) == k:
			return 0
	return k


## A new bindings dictionary with `action` on `key`. Another action already on that key takes this action's old key.
## Reserved keys change nothing.
static func rebind(bindings: Dictionary, action: String, key: int) -> Dictionary:
	var out: Dictionary = bindings.duplicate()
	if RESERVED.has(key) or default_of(action) == 0:
		return out
	var old: int = int(out.get(action, default_of(action)))
	for a: Dictionary in ACTIONS:
		var other: String = str(a["id"])
		if other != action and int(out.get(other, int(a["key"]))) == key:
			out[other] = old
	out[action] = key
	for a: Dictionary in ACTIONS:
		var id: String = str(a["id"])
		if out.has(id) and int(out[id]) == int(a["key"]):
			out.erase(id)  # back on its default: nothing to store
	return out


## Only known actions with usable keys survive (saved files may hold anything).
static func clean(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not raw is Dictionary:
		return out
	for a: Dictionary in ACTIONS:
		var id: String = str(a["id"])
		if (raw as Dictionary).has(id):
			var k: int = int((raw as Dictionary)[id])
			if k > 0 and not RESERVED.has(k) and k != int(a["key"]):
				out[id] = k
	return out
