class_name RoomFx
extends RefCounted
## Tiny pixel particle pool for the 2D shop: coin sparkles, ink smoke, tarot spark trails, landing dust and ash.
## Palette-locked (RoomPalette indices), seeded, capped, drawn by whatever CanvasItem calls draw().

const MAX_PARTICLES: int = 220
## kind -> {life: [min, max], speed: [min, max], gravity, size, colours (palette indices)}
const KINDS: Dictionary = {
	"sparkle": {"life": [0.5, 0.9], "speed": [40.0, 120.0], "gravity": 240.0, "size": 2, "cols": [11, 15, 10, 11]},
	"smoke": {"life": [0.9, 1.5], "speed": [4.0, 14.0], "gravity": -14.0, "size": 5, "cols": [3, 2, 3]},
	"trail": {"life": [0.25, 0.45], "speed": [6.0, 26.0], "gravity": 30.0, "size": 1, "cols": [4, 15, 11]},
	"dust": {"life": [0.3, 0.55], "speed": [14.0, 50.0], "gravity": 40.0, "size": 2, "cols": [14, 4, 14]},
	"ash": {"life": [0.6, 1.1], "speed": [6.0, 18.0], "gravity": -16.0, "size": 1, "cols": [14, 4, 1, 14]},
	"gold": {"life": [0.7, 1.2], "speed": [4.0, 16.0], "gravity": -6.0, "size": 2, "cols": [11, 10, 15, 11]},
	"inksmoke": {"life": [1.1, 1.8], "speed": [8.0, 22.0], "gravity": -10.0, "size": 5, "cols": [0, 0, 1, 0]},
	"glimmer": {"life": [0.6, 1.0], "speed": [1.0, 5.0], "gravity": -3.0, "size": 1, "cols": [15, 11, 15]},
}

var _rng := RandomNumberGenerator.new()
var _p: Array[Dictionary] = []


func _init() -> void:
	_rng.seed = 424242


func count() -> int:
	return _p.size()


func clear() -> void:
	_p.clear()


## Emits `n` particles of `kind` at `pos` (world pixels). Unknown kinds are ignored; the pool is capped.
func emit(kind: String, pos: Vector2, n: int) -> void:
	if not KINDS.has(kind):
		return
	var k: Dictionary = KINDS[kind]
	var life: Array = k["life"] as Array
	var speed: Array = k["speed"] as Array
	var cols: Array = k["cols"] as Array
	for i: int in range(n):
		if _p.size() >= MAX_PARTICLES:
			return
		var a: float = _rng.randf_range(0.0, TAU)
		if kind == "sparkle" or kind == "gold":
			a = _rng.randf_range(-PI * 0.95, -PI * 0.05)
		var sp: float = _rng.randf_range(float(speed[0]), float(speed[1]))
		var lf: float = _rng.randf_range(float(life[0]), float(life[1]))
		var jitter := Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0))
		var v := Vector2(cos(a), sin(a)) * sp
		if kind == "smoke" or kind == "inksmoke":
			v = Vector2(_rng.randf_range(-8.0, 8.0), -sp)
		elif kind == "dust":
			v = Vector2(cos(a) * sp, -absf(sin(a)) * sp * 0.6)
		_p.append({"x": pos.x + jitter.x, "y": pos.y + jitter.y, "vx": v.x, "vy": v.y, "g": float(k["gravity"]),
			"life": lf, "max": lf, "s": int(k["size"]) if kind != "sparkle" and kind != "gold" else _rng.randi_range(1, 2),
			"c": int(cols[_rng.randi_range(0, cols.size() - 1)]), "kind": kind})


func update(delta: float) -> void:
	for i: int in range(_p.size() - 1, -1, -1):
		var q: Dictionary = _p[i]
		q["life"] = float(q["life"]) - delta
		if float(q["life"]) <= 0.0:
			_p.remove_at(i)
			continue
		q["vy"] = float(q["vy"]) + float(q["g"]) * delta
		q["x"] = float(q["x"]) + float(q["vx"]) * delta
		q["y"] = float(q["y"]) + float(q["vy"]) * delta


func draw(ci: CanvasItem, pal: PackedColorArray) -> void:
	for q: Dictionary in _p:
		var f: float = float(q["life"]) / float(q["max"])
		var col: Color = pal[int(q["c"])]
		var x: float = roundf(float(q["x"]))
		var y: float = roundf(float(q["y"]))
		var sz: float = float(q["s"])
		match str(q["kind"]):
			"smoke", "inksmoke":
				sz = 3.0 + (1.0 - f) * 4.0
				col.a = clampf(f * 1.4, 0.0, 0.75 if str(q["kind"]) == "smoke" else 0.92)
				if str(q["kind"]) == "inksmoke":  # black puff with a violet rim so it reads against dark shelves
					var rim: Color = pal[3]
					rim.a = col.a * 0.8
					ci.draw_rect(Rect2(x - sz * 0.5 - 1.0, y - sz * 0.5 - 1.0, sz + 2.0, sz + 2.0), rim)
				ci.draw_rect(Rect2(x - sz * 0.5, y - sz * 0.5, sz, sz), col)
			"sparkle", "gold":
				col.a = clampf(f * 3.0, 0.0, 1.0)
				if sz >= 2.0 and f < 0.45:  # twinkle: a tiny plus
					ci.draw_rect(Rect2(x - 1.0, y, 3.0, 1.0), col)
					ci.draw_rect(Rect2(x, y - 1.0, 1.0, 3.0), col)
				else:
					ci.draw_rect(Rect2(x, y, sz, sz), col)
			_:
				col.a = clampf(f * 2.5, 0.0, 1.0)
				if str(q["kind"]) == "dust" and f < 0.5:
					sz = 1.0
				ci.draw_rect(Rect2(x, y, sz, sz), col)
