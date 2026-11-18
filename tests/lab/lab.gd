extends Node
## Feel-target lab: plays many seeded runs with the greedy and cautious bots and measures the targets agreed in
## docs/handoff.md. Prints "LAB <metric> PASS|WARN|FAIL <detail>" and a summary line.
## FAIL only for broken invariants (stuck runs, replay or restore divergence, cursed objects without a tell).
## Balance targets print WARN when missed: check them against the design before tuning them away.
## Run: godot --headless --path . res://tests/lab/lab.tscn [-- --runs=300 --json=/tmp/lab.json --set=field:value,...]
## --set overrides Tuning fields for a sweep; --preset=path loads a tuning preset first.

var fails: int = 0
var warns: int = 0
var report: Dictionary = {}


func _ready() -> void:
	var runs: int = int(_lab_arg("runs", "300"))
	if _lab_arg("preset", "") != "":
		Tuning.shared().load_json(_lab_arg("preset", ""))
	for pair: String in _lab_arg("set", "").split(",", false):
		var kv: PackedStringArray = pair.split(":")
		if kv.size() != 2 or not Tuning.shared().set_value(kv[0], float(kv[1])):
			_lab_line("set_%s" % pair, false, true, "unknown tuning field or bad value")
	var cat := Catalog.load_default()
	var problems: PackedStringArray = cat.problems()
	_lab_line("catalog", problems.is_empty(), true, "problems=%d %s" % [problems.size(), "; ".join(problems)])
	var stats: Dictionary = {}
	for style: String in ShopBot.STYLES:
		stats[style] = _lab_play(style, runs, cat)
	var g: Dictionary = stats[ShopBot.GREEDY]
	var c: Dictionary = stats[ShopBot.CAUTIOUS]
	for style: String in ShopBot.STYLES:
		var s: Dictionary = stats[style]
		_lab_line("%s_stuck" % style, s["stuck"] == 0, true, "stuck=%d of %d" % [s["stuck"], runs])
		_lab_line("%s_replay" % style, s["diverged"] == 0, true, "diverged=%d of %d" % [s["diverged"], s["checked"]])
	_lab_line("restore", _lab_restore_ok(cat), true, "snapshot/restore mid-run continues identically")
	_lab_target("run_minutes_median", _lab_median(g["minutes"] + c["minutes"]), 15.0, 25.0, "min")
	_lab_target("wake_by_night3", _lab_rate(g["woke3"] + c["woke3"], 2 * runs), 0.8, 1.0, "share")
	_lab_target("greedy_survival", _lab_rate(g["won"], runs), 0.25, 0.40, "share")
	_lab_target("cautious_survival", _lab_rate(c["won"], runs), 0.50, 0.65, "share")
	var ratio: float = _lab_mean(g["won_cash"]) / maxf(1.0, _lab_mean(c["won_cash"]))
	_lab_target("greedy_cash_ratio", ratio, 1.5, 1000.0, "x cautious (survivors' final cash)")
	for style: String in ShopBot.STYLES:
		var s: Dictionary = stats[style]
		print("LAB %s_info INFO won=%d/%d cash_mean=%.0f wakes_mean=%.2f lost_by_night=%s" % [
			style, s["won"], runs, _lab_mean(s["won_cash"]), _lab_mean(s["wakes"]), s["lost_night"]])
	print("LAB done runs=%d warn=%d fail=%d" % [runs, warns, fails])
	var json_path: String = _lab_arg("json", "")
	if json_path != "":
		var f := FileAccess.open(json_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "\t"))
	get_tree().quit(1 if fails > 0 else 0)


func _lab_arg(key: String, default: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.split("=", true, 1)[1]
	return default


func _lab_play(style: String, runs: int, cat: Catalog) -> Dictionary:
	var s: Dictionary = {"won": 0, "won_cash": [], "minutes": [], "woke3": 0, "wakes": [], "stuck": 0,
		"diverged": 0, "checked": 0, "lost_night": {}}
	var bot := ShopBot.new(style)
	for i: int in range(runs):
		var tun := Tuning.new()
		tun.copy_from(Tuning.shared())
		var run := RunState.new()
		var check: bool = i < 20
		var rec: RunRecording = RunRecording.begin(run, 1000 + i, cat, tun) if check else null
		if not check:
			run.start(1000 + i, cat, tun)
		if not bot.play(run, rec):
			s["stuck"] += 1
			continue
		if check:
			s["checked"] += 1
			if rec.first_divergence(cat) != -1:
				s["diverged"] += 1
		(s["minutes"] as Array).append(run.play_secs / 60.0)
		(s["wakes"] as Array).append(float(run.wake_nights.size()))
		if not run.wake_nights.is_empty() and run.wake_nights[0] <= 3:
			s["woke3"] += 1
		if run.won:
			s["won"] += 1
			(s["won_cash"] as Array).append(float(run.cash))
		else:
			var key: String = str(run.night)
			s["lost_night"][key] = int(s["lost_night"].get(key, 0)) + 1
	return s


func _lab_restore_ok(cat: Catalog) -> bool:
	var bot := ShopBot.new(ShopBot.GREEDY)
	for seed_value: int in [1, 2, 3]:
		var a := RunState.new()
		a.start(seed_value, cat, Tuning.new())
		for i: int in range(25):
			if not a.is_over():
				a.apply(bot.decide(a))
		var b := RunState.new()
		b.restore(a.snapshot(), cat)
		bot.play(a)
		bot.play(b)
		if a.state_hash() != b.state_hash():
			return false
	return true


func _lab_line(metric: String, ok: bool, hard: bool, detail: String) -> void:
	var verdict: String = "PASS"
	if not ok:
		verdict = "FAIL" if hard else "WARN"
		if hard:
			fails += 1
		else:
			warns += 1
	report[metric] = {"verdict": verdict, "detail": detail}
	print("LAB %s %s %s" % [metric, verdict, detail])


func _lab_target(metric: String, value: float, lo: float, hi: float, unit: String) -> void:
	var ok: bool = value >= lo and value <= hi
	var target: String = ">= %.2f" % lo if hi >= 1000.0 else "%.2f..%.2f" % [lo, hi]
	_lab_line(metric, ok, false, "value=%.2f target=%s %s" % [value, target, unit])
	report[metric]["value"] = value


func _lab_median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var v: Array = values.duplicate()
	v.sort()
	return float(v[v.size() / 2])


func _lab_mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var t: float = 0.0
	for x: Variant in values:
		t += float(x)
	return t / values.size()


func _lab_rate(n: int, total: int) -> float:
	return float(n) / maxf(1.0, float(total))
