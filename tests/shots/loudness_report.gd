extends SceneTree
## Offline loudness report: every one-shot's active level against its class target. Prints one line per sound and a summary;
## exit 1 when a sound is more than 2 dB from its target. Usage: tools/loudness_report.sh. Writes nothing.

const TOLERANCE_DB: float = 2.0


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var bad: int = 0
	var worst: float = 0.0
	for name: String in SfxSynth.NAMES:
		if SfxSynth.LOOPS.has(name):
			continue
		var buf: PackedFloat32Array = SfxSynth.au_decode(SfxSynth.build(name, 1))
		var secs: float = float(buf.size()) / float(SfxSynth.SR)
		var target: float = SfxSynth.au_target_db(name, secs)
		var level: float = SfxSynth.au_active_db(buf)
		var off: float = level - target
		worst = maxf(worst, absf(off))
		var flag: String = ""
		if absf(off) > TOLERANCE_DB:
			bad += 1
			flag = " OUT"
		print("%-18s target %6.1f level %6.1f off %+4.1f peak %5.1f dBFS%s" % [name, target, level, off,
				20.0 * log(maxf(SfxSynth.au_peak(buf), 0.00001)) / log(10.0), flag])
	for track: String in MusicSynth.TRACKS:
		for s: int in range(MusicSynth.mu_stem_count(track)):
			var mb: PackedFloat32Array = SfxSynth.au_decode(MusicSynth.build_stem(track, s, 1))
			print("music %-10s stem %d active %6.1f dBFS" % [track, s, SfxSynth.au_active_db(mb)])
	print("LOUDNESS out_of_tolerance=%d worst_off=%.1f dB tolerance=%.1f" % [bad, worst, TOLERANCE_DB])
	quit(1 if bad > 0 else 0)
