extends SceneTree
## Writes every music track to /tmp/music/<track>_<stem or mix>.wav and prints build time per track.
## Usage: tools/render_music.sh. Writes nothing to player data.

const OUT_DIR: String = "/tmp/music"


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for track: String in MusicSynth.TRACKS:
		var t0: int = Time.get_ticks_usec()
		var stems: Array[AudioStreamWAV] = []
		for s: int in range(MusicSynth.mu_stem_count(track)):
			var t1: int = Time.get_ticks_usec()
			stems.append(MusicSynth.build_stem(track, s, 1))
			print("  %s stem %d: %.0f ms" % [track, s, float(Time.get_ticks_usec() - t1) / 1000.0])
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		print("MUSIC %-10s loop %.1fs stems=%d build %.0f ms" % [track, MusicSynth.mu_loop_secs(track), stems.size(), ms])
		# Mixes: layers 1..n summed, resampled to 22050 mono, the loop played twice.
		for upto: int in range(1, stems.size() + 1):
			var secs: float = MusicSynth.mu_loop_secs(track)
			var n: int = int(secs * 22050.0)
			var mix: PackedFloat32Array = PackedFloat32Array()
			mix.resize(n * 2)
			for s: int in range(upto):
				var w: AudioStreamWAV = stems[s]
				var cnt: int = w.data.size() / 2
				var sr: float = float(w.mix_rate)
				for i: int in range(n * 2):
					var pos: float = float(i % n) / 22050.0 * sr
					var a: int = int(pos) % cnt
					mix[i] += float(w.data.decode_s16(a * 2)) / 32767.0
			var name: String = "%s_layers%d" % [track, upto]
			SfxSynth.au_to_wav(mix).save_to_wav("%s/%s.wav" % [OUT_DIR, name])
	quit(0)
