extends SceneTree
## Writes every SfxSynth sound to /tmp/sfx/<name>.wav and prints one line per sound: duration, peak, build time.
## Usage: tools/render_sfx.sh   (or: godot --headless --path . -s res://tests/shots/sfx_dump.gd [-- --seed=3])
## Writes nothing to player data.

const OUT_DIR: String = "/tmp/sfx"


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var seed_value: int = 1
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.trim_prefix("--seed="))
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var total_ms: float = 0.0
	for name: String in SfxSynth.NAMES:
		var t0: int = Time.get_ticks_usec()
		var w: AudioStreamWAV = SfxSynth.build(name, seed_value)
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		total_ms += ms
		var peak: int = 0
		var acc: float = 0.0
		var n: int = w.data.size() / 2
		for i: int in range(n):
			var v: int = w.data.decode_s16(i * 2)
			peak = maxi(peak, absi(v))
			acc += float(v) * float(v)
		var secs: float = float(n) / float(SfxSynth.SR)
		var rms: float = sqrt(acc / float(maxi(n, 1))) / 32767.0
		var err: Error = w.save_to_wav("%s/%s.wav" % [OUT_DIR, name])
		print("%-15s %5.2fs peak %6.1f dBFS rms %6.1f dBFS build %6.1f ms%s%s" % [name, secs,
				20.0 * log(maxf(float(peak), 1.0) / 32767.0) / log(10.0), 20.0 * log(maxf(rms, 0.00001)) / log(10.0),
				ms, " loop" if SfxSynth.LOOPS.has(name) else "", " SAVE FAILED" if err != OK else ""])
	print("SFX sounds=%d total_build=%.0f ms dir=%s" % [SfxSynth.NAMES.size(), total_ms, OUT_DIR])
	quit(0)
