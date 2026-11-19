class_name RunRecording
extends RefCounted
## Flight recorder for a run: seed, tuning, gift and every command, plus the state hash after each command.
## A run is pure logic, so replaying the commands rebuilds any moment exactly. Drive a recorded run with
## `rec.drive(run, cmd)` instead of `run.apply(cmd)`.

var seed_value: int = 0
var tuning: Dictionary = {}
var gift: Dictionary = {}
var opts: Dictionary = {}  ## run options as passed to RunState.start ({haunting, omen, daily})
var spells: Array = []  ## spells known at the start (RunState.spells_known)
var commands: Array[Dictionary] = []
var hashes: Array[int] = []
var wake_at: Array[int] = []  ## command indexes whose events include a wake


## Starts `run` and records it from the first moment.
static func begin(run: RunState, seed_in: int, cat: Catalog, tun: Tuning, gift_in: Dictionary = {}, opts_in: Dictionary = {}) -> RunRecording:
	var rec := RunRecording.new()
	rec.seed_value = seed_in
	rec.tuning = tun.to_dict()
	rec.gift = gift_in.duplicate(true)
	rec.opts = opts_in.duplicate(true)
	rec.spells = Array(run.spells_known)
	run.start(seed_in, cat, tun, gift_in, opts_in)
	return rec


func drive(run: RunState, cmd: Dictionary) -> Array[Dictionary]:
	var ev: Array[Dictionary] = run.apply(cmd)
	commands.append(cmd.duplicate(true))
	hashes.append(run.state_hash())
	for e: Dictionary in ev:
		if e["e"] == "wake":
			wake_at.append(commands.size() - 1)
			break
	return ev


## Rebuilds the run after the first `upto` commands (all of them when upto < 0).
func replay(cat: Catalog, upto: int = -1) -> RunState:
	var tun := Tuning.new()
	tun.apply_dict(tuning)
	var run := RunState.new()
	run.spells_known = PackedStringArray(spells)
	run.start(seed_value, cat, tun, gift, opts)
	var n: int = commands.size() if upto < 0 else mini(upto, commands.size())
	for i: int in range(n):
		run.apply(commands[i])
	return run


## The first command index whose replayed hash differs from the recorded one, or -1 if the replay matches.
func first_divergence(cat: Catalog) -> int:
	var tun := Tuning.new()
	tun.apply_dict(tuning)
	var run := RunState.new()
	run.spells_known = PackedStringArray(spells)
	run.start(seed_value, cat, tun, gift, opts)
	for i: int in range(commands.size()):
		run.apply(commands[i])
		if run.state_hash() != hashes[i]:
			return i
	return -1


## A replay clip around a wake: [first command, end command) covering `before` commands up to the wake.
func wake_clip(wake_index: int, before: int) -> Vector2i:
	var at: int = wake_at[wake_index]
	return Vector2i(maxi(0, at - before), at + 1)


func to_dict() -> Dictionary:
	return {"seed": seed_value, "tuning": tuning, "gift": gift, "opts": opts, "spells": spells, "commands": commands, "hashes": hashes, "wake_at": wake_at}


static func from_dict(d: Dictionary) -> RunRecording:
	var rec := RunRecording.new()
	rec.seed_value = int(d.get("seed", 0))
	rec.tuning = d.get("tuning", {})
	rec.gift = d.get("gift", {})
	rec.opts = d.get("opts", {})
	rec.spells = d.get("spells", Array(Grimoire.DEFAULT_KNOWN))
	for c: Variant in d.get("commands", []):
		rec.commands.append(c)
	for h: Variant in d.get("hashes", []):
		rec.hashes.append(int(h))
	for w: Variant in d.get("wake_at", []):
		rec.wake_at.append(int(w))
	return rec


func save_json(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict()))
	return OK


static func load_json(path: String) -> RunRecording:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return RunRecording.from_dict(parsed if parsed is Dictionary else {})
