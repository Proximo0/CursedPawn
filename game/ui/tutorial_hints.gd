class_name TutorialHints
extends RefCounted
## Which one-line hint to show now, given the run and the hint ids already seen. Pure: no nodes, no files.
## Each hint is shown once ever; the caller records it (TsHintTracker does). Order is the teaching order.

const IDS: PackedStringArray = ["seller", "tell", "buyer", "dread_half", "wake", "rent"]
const TEXTS: Dictionary = {
	"seller": "Inspect with 1-4 before you buy. Cursed things pay best... and wake.",
	"tell": "A tell! Something here is cursed. It pays well, but it feeds the Dread.",
	"buyer": "Buyers want one kind of thing. Click a glowing item, then click again to sell.",
	"dread_half": "Dread is over half. When the bar fills, something wakes.",
	"wake": "It woke. Dread eases, but it never leaves. Press R to watch it again.",
	"rent": "Night done, rent paid. It rises every night, so keep a cushion.",
}
const HALF: float = 0.5


## The first unseen hint whose moment has come: {id, text}, or {} for none.
static func next(run: RunState, seen: Array) -> Dictionary:
	if run == null or run.is_over():
		return {}
	for id: String in IDS:
		if not seen.has(id) and applies(id, run):
			return {"id": id, "text": str(TEXTS[id])}
	return {}


## True when the moment for hint `id` has come in `run`.
static func applies(id: String, run: RunState) -> bool:
	var kind: String = str(run.customer.get("kind", ""))
	match id:
		"seller":
			return kind == RunState.SELLER
		"tell":
			return kind == RunState.SELLER and not (run.customer.get("tells", []) as Array).is_empty()
		"buyer":
			return kind == RunState.BUYER
		"dread_half":
			return run.tuning != null and run.dread >= run.tuning.wake_threshold * HALF
		"wake":
			return not run.wake_nights.is_empty()
		"rent":
			return run.night >= 2
	return false
