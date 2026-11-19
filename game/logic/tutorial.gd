class_name Tutorial
extends RefCounted
## The guided first night. The first run ever (profile `tutorial_done` false) uses SEED and RunState opts
## `tutorial: true`: night 1 is a fixed sequence of three customers (no random draws, so it is identical for every
## seed), safe (no wake; Dread stays below the threshold) and its rent is covered by `tutorial_purse`. After the three
## customers the night ends and the run goes on normally. `customers()` is the sequence, `script()` the hints.
## Hints arrive as `tutorial_step {step, text, focus}` events; the customer that introduces a step carries
## `tutorial: step` on its `customer` event. Focus is a UI id: tools, offer, buy, pass, shelf, dread, spells, table.

const SEED: int = 6006
const FOCUS: PackedStringArray = ["tools", "offer", "buy", "pass", "shelf", "dread", "spells", "table"]


static func opts() -> Dictionary:
	return {"tutorial": true}


## The scripted customers of night 1, in order: {kind, tid, item_id, curse, category, pay_mult, sure_tell, step}.
## `step` is the hint the customer arrives with. The cursed seller's UV tell is certain.
static func customers() -> Array[Dictionary]:
	return [
		{"kind": "seller", "tid": "estate_clearer", "item_id": "hand_bell", "curse": "", "step": 1},
		{"kind": "seller", "tid": "nervous_heir", "item_id": "oil_portrait", "curse": "sleepwalker", "sure_tell": "uv", "step": 3},
		{"kind": "buyer", "tid": "decorator", "category": "instrument", "pay_mult": 1.2, "step": 5},
	]


## The hints. `trigger` is the event that shows it: "customer" (the nth scripted customer arrives), "inspected" (a tool
## was used on the nth customer; `tell` true waits for a tell), "table_open" or "night_start" (night `at`).
static func script() -> Array[Dictionary]:
	return [
		{"step": 1, "trigger": "customer", "at": 1, "focus": "tools", "text": "A seller. Use a tool to look the object over before you pay."},
		{"step": 2, "trigger": "inspected", "at": 1, "focus": "offer", "text": "Now haggle. Offer less than the ask, or take it as it stands."},
		{"step": 3, "trigger": "customer", "at": 2, "focus": "tools", "text": "This one feels wrong. Try the UV lamp."},
		{"step": 4, "trigger": "inspected", "at": 2, "tell": true, "focus": "dread", "text": "A curse! It pays best but feeds the Dread. Buy it, or pass."},
		{"step": 5, "trigger": "customer", "at": 3, "focus": "shelf", "text": "A buyer. Pick something from your shelf to sell them."},
		{"step": 6, "trigger": "table_open", "at": 1, "focus": "table", "text": "The Midnight Table: games of chance, for shop cash only."},
		{"step": 7, "trigger": "night_start", "at": 2, "focus": "spells", "text": "Spells cost Dread. Cast one on a customer when it counts."},
	]


static func step(n: int) -> Dictionary:
	for s: Dictionary in script():
		if int(s["step"]) == n:
			return s
	return {}


## The hints an event list triggers. `tut` is the run's tutorial state ({idx: scripted customers shown, shown: [steps]}).
## Returns tutorial_step events and records them in `tut["shown"]`.
static func hints_for(events: Array[Dictionary], tut: Dictionary, night: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var shown: Array = tut["shown"]
	for e: Dictionary in events:
		for s: Dictionary in script():
			if shown.has(int(s["step"])) or not _fires(s, e, tut, night):
				continue
			shown.append(int(s["step"]))
			out.append({"e": "tutorial_step", "step": s["step"], "text": s["text"], "focus": s["focus"]})
	return out


static func _fires(s: Dictionary, e: Dictionary, tut: Dictionary, night: int) -> bool:
	var kind: String = str(e["e"])
	var idx: int = int(tut["idx"])
	match str(s["trigger"]):
		"customer":
			return kind == "customer" and int(e.get("tutorial", 0)) == int(s["step"])
		"inspected":
			return kind == "inspected" and idx == int(s["at"]) and (not bool(s.get("tell", false)) or str(e.get("tell", "")) != "")
		"table_open":
			return kind == "table_open" and night == int(s["at"])
		"night_start":
			return kind == "night_start" and int(e.get("night", 0)) == int(s["at"])
	return false


static func problems(cat: Catalog) -> PackedStringArray:
	var out := PackedStringArray()
	for c: Dictionary in customers():
		var known: bool = false
		for t: Dictionary in cat.customer_types(str(c["kind"])):
			known = known or str(t["id"]) == str(c["tid"])
		if not known:
			out.append("tutorial customer: unknown type %s" % c["tid"])
		if c["kind"] == "seller":
			var found: bool = false
			for o: Dictionary in cat.objects:
				found = found or str(o["id"]) == str(c["item_id"])
			if not found:
				out.append("tutorial customer: unknown item %s" % c["item_id"])
			if str(c["curse"]) != "":
				var tells: Dictionary = cat.curse(str(c["curse"])).get("tells", {})
				if not tells.has(str(c.get("sure_tell", ""))):
					out.append("tutorial curse %s has no %s tell" % [c["curse"], c.get("sure_tell", "")])
	for s: Dictionary in script():
		if not FOCUS.has(str(s["focus"])) or str(s["text"]).length() > 80:
			out.append("tutorial step %s: bad focus or text over 80 characters" % s["step"])
	return out
