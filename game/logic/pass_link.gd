class_name PassLink
extends RefCounted
## Pass it on: at the end of a run the player's worst object goes to a friend as a link. The link carries only
## the object id, its curse and its history (who held it, how far they got, how often it woke the shop). The
## receiver re-derives name, category and value from their own catalog, so an edited link cannot gift a fortune:
## at worst it picks a different catalog object or curse. The code sits in the URL fragment (#gift=...), which
## browsers never send to the server.
##
## Code format: "1" + URL-safe base64 (no padding) of [u32 JSON size, u32 check, deflated JSON]: JSON {i: id, c: curse, h: [[handle, night, wakes,
## won], ...]}. History keeps the newest `MAX_HISTORY` holders.

const CODE_VERSION: String = "1"
const MAX_HISTORY: int = 6
const MAX_HANDLE: int = 16
const MAX_CODE: int = 2000
const FRAGMENT_KEY: String = "#gift="


## The object a run passes on: the cursed one with the most dread, else the least valuable. {} with nothing held.
static func pick_worst(run: RunState) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -INF
	for item: Dictionary in run.inventory:
		var score: float = -float(item["value"])
		if str(item["curse"]) != "":
			score = 1.0e6 * float(run.catalog.curse(item["curse"]).get("dread", 1.0)) - float(item["value"])
		if score > best_score:
			best_score = score
			best = item
	return best


## The pass-on code for `item` after `run` (empty when there is no item). `handle` is a name the player typed,
## trimmed to MAX_HANDLE printable characters; empty means anonymous.
static func encode(item: Dictionary, run: RunState, handle: String) -> String:
	if item.is_empty():
		return ""
	var hist: Array = (item.get("history", []) as Array).duplicate(true)
	hist.append([pass_clean_handle(handle), run.night, run.wake_nights.size(), run.won])
	while hist.size() > MAX_HISTORY:
		hist.remove_at(0)
	var raw: PackedByteArray = JSON.stringify({"i": item["id"], "c": item["curse"], "h": hist}).to_utf8_buffer()
	var packed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var head: PackedByteArray = _pass_u32(raw.size()) + _pass_u32(_pass_check(raw))
	var b64: String = Marshalls.raw_to_base64(head + packed)
	return CODE_VERSION + b64.replace("+", "-").replace("/", "_").replace("=", "")


## The share URL: `base` (the game page) with the code in the fragment.
static func url(base: String, code: String) -> String:
	return base + FRAGMENT_KEY + code


## The code inside a pasted URL or a bare code; "" when there is none.
static func code_from_text(text: String) -> String:
	var t: String = text.strip_edges()
	var at: int = t.find(FRAGMENT_KEY)
	return t.substr(at + FRAGMENT_KEY.length()) if at >= 0 else t


## Decodes a code into a gift item for RunState.start(): {id, name, category, value, curse, est, tells, history}.
## {} for anything unreadable, from a newer version, or naming an object or curse this catalog lacks.
static func decode(code: String, cat: Catalog, tun: Tuning) -> Dictionary:
	if code.length() < 2 or code.length() > MAX_CODE or not code.begins_with(CODE_VERSION):
		return {}
	var b64: String = code.substr(1).replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var bytes: PackedByteArray = Marshalls.base64_to_raw(b64)
	if bytes.size() < 9:
		return {}
	var size: int = bytes.decode_u32(0)
	if size <= 0 or size > MAX_CODE * 4:
		return {}
	var raw: PackedByteArray = bytes.slice(8).decompress(size, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != size or _pass_check(raw) != bytes.decode_u32(4):
		return {}
	var d: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not d is Dictionary:
		return {}
	var obj: Dictionary = {}
	for o: Dictionary in cat.objects:
		if o["id"] == str(d.get("i", "")):
			obj = o
	var cid: String = str(d.get("c", ""))
	if obj.is_empty() or (cid != "" and cat.curse(cid).is_empty()):
		return {}
	var value: float = float(obj["value"]) * (tun.cursed_value_mult if cid != "" else 1.0)
	return {"id": obj["id"], "name": obj["name"], "category": obj["category"], "value": int(round(value)),
		"curse": cid, "est": 0, "tells": 0, "history": _pass_clean_history(d.get("h", []))}


## Printable characters only, at most MAX_HANDLE.
static func pass_clean_handle(handle: String) -> String:
	var out: String = ""
	for ch: String in handle.strip_edges():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			out += ch
	return out.substr(0, MAX_HANDLE)


static func _pass_clean_history(src: Variant) -> Array:
	var out: Array = []
	if not src is Array:
		return out
	for e: Variant in src:
		if e is Array and (e as Array).size() == 4:
			out.append([pass_clean_handle(str(e[0])), clampi(int(e[1]), 1, 99), clampi(int(e[2]), 0, 99), bool(e[3])])
	while out.size() > MAX_HISTORY:
		out.remove_at(0)
	return out


## A 32-bit check of the JSON so a cut-off or mistyped link is refused instead of half-read.
static func _pass_check(raw: PackedByteArray) -> int:
	return raw.get_string_from_utf8().hash() & 0xFFFFFFFF


static func _pass_u32(n: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, n)
	return b
