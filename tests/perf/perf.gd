extends SceneTree
## Frame-time profile of the real game screen: the play-bot drives ShopGame (one command a frame), the first frames are
## skipped as warm-up, then N real frames are timed. Also prints the boot phases (ms from process start) and the first-call
## cost of every SpriteKit texture family. One quiet summary line: PERF frames=.. p50=.. p95=.. p99=.. max=.. (ms).
## xvfb-run -a godot --path . --disable-vsync --resolution 1280x720 -s res://tests/perf/perf.gd -- --scripted --seed=7 [--frames=600]
## (tools/perf.sh wraps it.) Never writes player data.

const WARMUP: int = 120
const SLOW_MS: float = 30.0

var _g: Variant
var _bot: ShopBot
var _t_start: int = 0


func _initialize() -> void:
	_t_start = Time.get_ticks_msec()
	_go.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.trim_prefix("--%s=" % name)
	return fallback


func _go() -> void:
	var frames: int = int(_arg("frames", "600"))
	var boot_ms: float = float(Time.get_ticks_msec())  ## since process start: engine init, autoloads, script load
	var t0: int = Time.get_ticks_usec()
	var packed: PackedScene = load("res://game/ui/shop_game.tscn") as PackedScene
	_g = packed.instantiate()
	root.add_child(_g)
	await process_frame
	var scene_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	_bot = ShopBot.new("greedy")
	var first_customer_ms: float = -1.0
	var dts: PackedFloat64Array = PackedFloat64Array()
	var draws: int = 0
	var script_ms: float = 0.0
	var slow: int = 0
	var slow_audio: int = 0
	var last_build: float = 0.0
	var worst_draws: int = 0
	var last: int = Time.get_ticks_usec()
	var guard: int = 0
	var started: bool = false
	while dts.size() < frames and guard < frames * 20:
		guard += 1
		var run: RunState = _g.run
		if run != null and not run.is_over():
			if _g.has_method("act") and (started or run.phase != "" ):
				started = true
				var ev: Variant = _g.act(_bot.decide(run))
				if first_customer_ms < 0.0 and run.customer != null and not run.customer.is_empty():
					first_customer_ms = float(Time.get_ticks_msec())
		await process_frame
		var now: int = Time.get_ticks_usec()
		if guard > WARMUP:
			dts.append(float(now - last) / 1000.0)
			var dc: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			draws += dc
			script_ms += float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
			worst_draws = maxi(worst_draws, dc)
		if guard > WARMUP:
			var b: float = float(_g.sfx.build_ms) + float(_g.sfx.music.build_ms)
			if dts[dts.size() - 1] > SLOW_MS:
				slow += 1
				if b - last_build > 5.0:
					slow_audio += 1
			last_build = b
		last = now
	dts.sort()
	var n: int = maxi(dts.size(), 1)
	print("PERF boot_to_script=%.0f ms scene_build=%.0f ms first_customer_at=%.0f ms" % [boot_ms, scene_ms, first_customer_ms])
	print("PERF frames=%d p50=%.1f p95=%.1f p99=%.1f max=%.1f ms script_ms_avg=%.1f draw_calls_avg=%d max=%d" % [dts.size(), _pct(dts, 0.5),
			_pct(dts, 0.95), _pct(dts, 0.99), dts[n - 1] if dts.size() > 0 else 0.0, script_ms / float(n), draws / n, worst_draws])
	print("PERF slow_frames(>%.0f ms)=%d of which with an audio build in the frame=%d" % [SLOW_MS, slow, slow_audio])
	_sprite_kit_cost()
	quit(0)


func _pct(sorted: PackedFloat64Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[mini(int(float(sorted.size()) * q), sorted.size() - 1)]


## First-call cost of each SpriteKit family, in ms: object over every catalog object, customer over every type, tiles, tools.
func _sprite_kit_cost() -> void:
	var sk: GDScript = load("res://game/room2d/sprite_kit.gd") as GDScript
	var objs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/objects.json")) as Array
	var worst: float = 0.0
	var total: float = 0.0
	for o: Dictionary in objs:
		var t: int = Time.get_ticks_usec()
		sk.call("object_texture", str(o["id"]), str(o["category"]))
		var ms: float = float(Time.get_ticks_usec() - t) / 1000.0
		worst = maxf(worst, ms)
		total += ms
	print("PERF sprite_kit object_texture n=%d avg=%.1f worst=%.1f ms total=%.0f ms" % [objs.size(), total / float(maxi(objs.size(), 1)), worst, total])
	var t2: int = Time.get_ticks_usec()
	for kind: String in ["wall", "floor", "shelf", "counter", "door"]:
		var t: int = Time.get_ticks_usec()
		sk.call("tile_texture", kind)
		worst = float(Time.get_ticks_usec() - t) / 1000.0
		print("PERF sprite_kit tile_texture %s %.1f ms" % [kind, worst])
	var types: Array = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/customers.json")) as Array
	var cw: float = 0.0
	var ct: float = 0.0
	for c: Dictionary in types:
		var t: int = Time.get_ticks_usec()
		var look: Dictionary = (load("res://game/room2d/art_content.gd") as GDScript).call("customer_look", str(c.get("id", ""))) if false else {}
		sk.call("customer_texture", look)
		var ms: float = float(Time.get_ticks_usec() - t) / 1000.0
		cw = maxf(cw, ms)
		ct += ms
	print("PERF sprite_kit customer_texture (default look) n=%d worst=%.1f ms total=%.0f ms" % [types.size(), cw, ct])
	var tt: int = Time.get_ticks_usec()
	for tool: String in ["uv", "scale", "listen", "touch", "pendulum"]:
		sk.call("tool_texture", tool)
	print("PERF sprite_kit tool_texture x5 %.1f ms; all tile+tool %.1f ms" % [float(Time.get_ticks_usec() - tt) / 1000.0, float(Time.get_ticks_usec() - t2) / 1000.0])
	# the strict music budget lives here, where nothing else competes for the CPU (unit tests run sharded across all cores)
	for track: String in MusicSynth.TRACKS:
		var tm: int = Time.get_ticks_usec()
		for st: int in range(MusicSynth.mu_stem_count(track)):
			MusicSynth.build_stem(track, st, 1)
		var mms: float = float(Time.get_ticks_usec() - tm) / 1000.0
		print("PERF music %s build=%.0f ms budget=%.0f ms %s" % [track, mms, MusicSynth.BUDGET_SECS * 1000.0,
			"PASS" if mms <= MusicSynth.BUDGET_SECS * 1000.0 else "FAIL"])
