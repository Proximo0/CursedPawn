class_name RoomScenes
extends RefCounted
## Draw helpers for the shop room's extra scenes (docs/full_game_plan.md steps 32-33): the five wake types and the four
## night events. Everything is palette-locked, deterministic in the time it is given, and drawn on whatever CanvasItem
## the room hands over (the unlit glow layer for overlays, the window layer for rain and moon).
##
## Wake types (event key `wake_type`): drift, topple, lights_out, door_lock, possession; anything else is the classic wake.
## Night events (key `night_event`, also read as `event` / `id` / `kind`): blackout, storm, auction, full_moon.

const WAKE_TYPES: Array[String] = ["drift", "topple", "lights_out", "door_lock", "possession"]
const NIGHT_EVENTS: Array[String] = ["blackout", "storm", "auction", "full_moon"]
const PODIUM_POS := Vector2(530.0, 227.0)  ## base of the auction podium: on the counter, right of the object spot, clear of the customer
const MOON_C := Vector2(580.0, 112.0)  ## the full moon's centre in the window


static func wake_type_of(e: Dictionary) -> String:
	var t: String = str(e.get("wake_type", ""))
	return t if WAKE_TYPES.has(t) else ""


## The night event named by an event dictionary, "" when none. Accepts the key names Lane A might use.
static func event_of(e: Dictionary) -> String:
	for k: String in ["night_event", "event", "id", "kind", "name"]:
		var v: String = str(e.get(k, "")).to_lower().replace(" ", "_")
		if v == "moon" or v == "fullmoon":
			v = "full_moon"
		if NIGHT_EVENTS.has(v):
			return v
	return ""


## Strength 0..1 of the lightning in a storm at time t: a double flash every 9 s, one fork at 4 s of every 13.
static func lightning(t: float) -> float:
	var c: float = fposmod(t, 9.0)
	var f: float = 0.0
	if c < 0.12:
		f = 1.0
	elif c > 0.22 and c < 0.5:
		f = 0.75 * (1.0 - (c - 0.22) / 0.28)
	return f


# ---------------------------------------------------------------- night events

## The window during a storm (rain streaks, a black sky, a lightning-bleached pane) or a full moon (one huge moon with
## craters and a halo). Drawn after the normal sky, so it covers the small moon.
static func draw_window_event(ci: CanvasItem, pal: PackedColorArray, w: Rect2, kind: String, t: float, flash: float) -> void:
	if kind == "storm":
		var sky: Color = pal[1]
		sky.a = 0.96
		ci.draw_rect(w, sky)
		for i: int in range(5):  # heavy cloud banks
			var cx: float = fposmod(t * (6.0 + float(i) * 2.0) + float(i) * 37.0, w.size.x + 60.0) - 30.0
			var cc: Color = pal[2] if i % 2 == 0 else pal[3]
			cc.a = 0.9
			ci.draw_rect(Rect2(w.position.x + cx, w.position.y + 4.0 + float(i) * 11.0, 46.0, 7.0), cc)
			ci.draw_rect(Rect2(w.position.x + cx + 8.0, w.position.y + float(i) * 11.0, 26.0, 6.0), cc)
		if flash > 0.01:  # the pane bleaches
			var fc: Color = pal[15]
			fc.a = 0.8 * flash
			ci.draw_rect(w, fc)
			var bolt: Color = pal[15]
			var bx: float = w.position.x + 30.0
			var by: float = w.position.y
			for s: int in range(9):
				var nx: float = bx + float((s * 7) % 11) - 5.0
				ci.draw_line(Vector2(bx, by), Vector2(nx, by + 14.0), bolt, 2.0 if s < 6 else 1.0)
				bx = nx
				by += 14.0
		for r: int in range(46):  # rain: diagonal streaks falling past the glass
			var sp: float = 150.0 + float((r * 31) % 70)
			var rx: float = w.position.x + float((r * 53) % int(w.size.x))
			var ry: float = fposmod(t * sp + float(r * 29), w.size.y)
			var rc: Color = pal[4] if r % 3 != 0 else pal[14]
			rc.a = 0.8
			ci.draw_line(Vector2(rx, w.position.y + ry), Vector2(rx - 2.0, w.position.y + ry + 5.0), rc, 1.0)
		for d: int in range(7):  # drops crawling down the inside of the glass
			var dx: float = w.position.x + 8.0 + float((d * 41) % int(w.size.x - 16.0))
			var dy: float = fposmod(t * (5.0 + float(d)) + float(d * 23), w.size.y - 6.0)
			ci.draw_rect(Rect2(dx, w.position.y + dy, 1.0, 2.0), pal[15])
	elif kind == "full_moon":
		var sky2: Color = pal[1]
		sky2.a = 0.95
		ci.draw_rect(w, sky2)
		for h: int in range(5):  # halo rings
			var hc: Color = pal[4] if h < 3 else pal[3]
			hc.a = 0.18 + 0.05 * float(5 - h)
			ci.draw_circle(MOON_C - Vector2(0.0, 6.0), 50.0 - float(h) * 6.0, hc)
		ci.draw_circle(MOON_C - Vector2(0.0, 6.0), 31.0, pal[14])
		ci.draw_circle(MOON_C - Vector2(2.0, 8.0), 29.0, pal[15])
		for c: Vector3 in [Vector3(-9.0, -4.0, 6.0), Vector3(8.0, 6.0, 5.0), Vector3(-2.0, 13.0, 3.0), Vector3(10.0, -12.0, 3.0), Vector3(-14.0, 9.0, 2.0)]:
			ci.draw_circle(MOON_C - Vector2(0.0, 6.0) + Vector2(c.x, c.y), c.z, pal[14])
			ci.draw_circle(MOON_C - Vector2(0.0, 6.0) + Vector2(c.x + 1.0, c.y + 1.0), c.z - 1.0, pal[4])
		var drift: float = fposmod(t * 2.0, w.size.x + 50.0) - 30.0  # one thin cloud crossing its face
		var cl: Color = pal[2]
		cl.a = 0.8
		ci.draw_rect(Rect2(w.position.x + drift, w.position.y + 64.0, 34.0, 3.0), cl)


## The auction podium: a lectern with a brass plate, a gavel and a small spot of light, standing in front of the
## counter. `bang` 0..1 lifts the gavel and flashes the plate (the room can raise it on a sale).
static func draw_podium(ci: CanvasItem, pal: PackedColorArray, t: float, bang: float) -> void:
	var b: Vector2 = PODIUM_POS
	var spot: Color = pal[11]
	spot.a = 0.07
	for i: int in range(4):
		ci.draw_rect(Rect2(b.x - 22.0 - float(i) * 3.0, b.y - 56.0 - float(i) * 4.0, 44.0 + float(i) * 6.0, 56.0 + float(i) * 4.0), spot)
	ci.draw_rect(Rect2(b.x - 13.0, b.y - 40.0, 26.0, 40.0), pal[0])  # body
	ci.draw_rect(Rect2(b.x - 12.0, b.y - 39.0, 24.0, 38.0), pal[8])
	ci.draw_rect(Rect2(b.x - 12.0, b.y - 39.0, 3.0, 38.0), pal[9])
	ci.draw_rect(Rect2(b.x + 9.0, b.y - 39.0, 3.0, 38.0), pal[0])
	ci.draw_rect(Rect2(b.x - 10.0, b.y - 30.0, 20.0, 18.0), pal[0])  # panel
	ci.draw_rect(Rect2(b.x - 9.0, b.y - 29.0, 18.0, 16.0), pal[8])
	var pl: Color = pal[10] if bang < 0.2 else pal[15]
	ci.draw_rect(Rect2(b.x - 5.0, b.y - 24.0, 10.0, 5.0), pl)  # brass plate with a lot number
	ci.draw_rect(Rect2(b.x - 3.0, b.y - 23.0, 1.0, 3.0), pal[8])
	ci.draw_rect(Rect2(b.x, b.y - 23.0, 1.0, 3.0), pal[8])
	ci.draw_rect(Rect2(b.x + 2.0, b.y - 23.0, 2.0, 3.0), pal[8])
	ci.draw_rect(Rect2(b.x - 15.0, b.y - 44.0, 30.0, 5.0), pal[0])  # slanted top
	ci.draw_rect(Rect2(b.x - 14.0, b.y - 43.0, 28.0, 3.0), pal[9])
	ci.draw_rect(Rect2(b.x - 14.0, b.y - 43.0, 28.0, 1.0), pal[10])
	var lift: float = -7.0 * bang
	ci.draw_rect(Rect2(b.x + 3.0, b.y - 49.0 + lift, 8.0, 4.0), pal[8])  # the gavel
	ci.draw_rect(Rect2(b.x + 3.0, b.y - 49.0 + lift, 8.0, 1.0), pal[9])
	ci.draw_rect(Rect2(b.x + 7.0, b.y - 45.0 + lift * 0.5, 1.0, 3.0), pal[9])


# ---------------------------------------------------------------- wake types

## Overlay for one wake type on the unlit layer. t is wall time (looks), k is seconds into the wake (after the beat),
## scare 0 gentle / 1 full. `at` is where the possessed object floats (ignored by the other types).
static func draw_wake(ci: CanvasItem, pal: PackedColorArray, vs: Vector2, wtype: String, t: float, k: float, _scare: int, at: Vector2) -> void:
	match wtype:
		"drift":
			var wash: Color = pal[6]
			wash.a = 0.26
			ci.draw_rect(Rect2(Vector2.ZERO, vs), wash)
			for i: int in range(34):  # motes and wisps rising instead of falling
				var x: float = float((i * 79) % int(vs.x))
				var y: float = vs.y - fposmod(t * (8.0 + float(i % 7) * 3.0) + float(i * 41), vs.y + 20.0)
				var c: Color = pal[7] if i % 3 == 0 else (pal[6] if i % 3 == 1 else pal[14])
				c.a = 0.55
				ci.draw_rect(Rect2(x + sin(t * 0.8 + float(i)) * 6.0, y, 2.0, 2.0 if i % 5 == 0 else 1.0), c)
		"topple":
			for i: int in range(18):  # a rolling cloud of plaster dust along the floor
				var x2: float = fposmod(float(i) * 41.0 + k * 38.0, vs.x + 40.0) - 20.0
				var d: Color = pal[14] if i % 2 == 0 else pal[4]
				d.a = clampf(0.28 - absf(sin(float(i) + t)) * 0.12, 0.05, 0.3)
				ci.draw_circle(Vector2(x2, 296.0 - float(i % 4) * 6.0), 12.0 + float(i % 5) * 3.0, d)
		"lights_out":
			var black: Color = pal[0]
			black.a = 0.78
			ci.draw_rect(Rect2(Vector2.ZERO, vs), black)
			for i: int in range(9):  # eyes open one pair after another, all turned toward the counter
				var open: float = clampf((k - 0.15 * float(i)) * 3.0, 0.0, 1.0)
				var blink: float = 0.0 if fposmod(t * 0.9 + float(i) * 1.7, 5.0) < 0.2 else 1.0
				if open * blink <= 0.0:
					continue
				var ex: float = 40.0 + float((i * 137) % 540)
				var ey: float = 70.0 + float((i * 71) % 190)
				var c2: Color = pal[10] if i % 2 == 0 else pal[13]
				c2.a = open
				for dx: float in [0.0, 7.0 + float(i % 3)]:
					ci.draw_rect(Rect2(ex + dx, ey, 3.0, 2.0), c2)
					ci.draw_rect(Rect2(ex + dx + 1.0, ey, 1.0, 2.0), pal[0])
		"door_lock":
			var dr: Rect2 = Rect2(4.0, 206.0, 40.0, 94.0)
			var pulse: float = 0.6 + 0.4 * sin(t * 9.0)
			var glow: Color = pal[13]
			glow.a = 0.25 * pulse
			ci.draw_rect(dr.grow(5.0), glow)
			for i: int in range(3):  # iron bars and chains laid across the door
				var y3: float = dr.position.y + 18.0 + float(i) * 30.0
				ci.draw_rect(Rect2(dr.position.x - 2.0, y3, dr.size.x + 4.0, 5.0), pal[0])
				ci.draw_rect(Rect2(dr.position.x - 2.0, y3 + 1.0, dr.size.x + 4.0, 2.0), pal[2])
				ci.draw_rect(Rect2(dr.position.x - 2.0, y3 + 1.0, dr.size.x + 4.0, 1.0), pal[3])
			for i: int in range(9):
				var ly: float = dr.position.y + 4.0 + float(i) * 10.0
				var off: float = 1.0 if i % 2 == 0 else -1.0
				ci.draw_rect(Rect2(dr.position.x + 18.0 + off, ly, 3.0, 8.0), pal[4])
				ci.draw_rect(Rect2(dr.position.x + 19.0 + off, ly + 1.0, 1.0, 6.0), pal[1])
			var lc: Vector2 = dr.position + Vector2(20.0, 48.0)  # padlock with a red sigil
			ci.draw_rect(Rect2(lc.x - 7.0, lc.y - 4.0, 14.0, 12.0), pal[0])
			ci.draw_rect(Rect2(lc.x - 6.0, lc.y - 3.0, 12.0, 10.0), pal[10])
			ci.draw_rect(Rect2(lc.x - 6.0, lc.y - 3.0, 12.0, 2.0), pal[11])
			ci.draw_rect(Rect2(lc.x - 4.0, lc.y - 9.0, 2.0, 6.0), pal[14])
			ci.draw_rect(Rect2(lc.x + 2.0, lc.y - 9.0, 2.0, 6.0), pal[14])
			ci.draw_rect(Rect2(lc.x - 4.0, lc.y - 10.0, 8.0, 2.0), pal[14])
			var sg: Color = pal[13] if pulse > 0.5 else pal[12]
			ci.draw_rect(Rect2(lc.x - 1.0, lc.y, 2.0, 5.0), sg)
			ci.draw_rect(Rect2(lc.x - 3.0, lc.y + 1.0, 6.0, 1.0), sg)
			var sp: int = int(t * 12.0) % 6  # sparks off the bolt
			for i: int in range(4):
				var sc: Color = pal[11] if (i + sp) % 2 == 0 else pal[15]
				ci.draw_rect(Rect2(lc.x + float((i * 5 + sp * 3) % 15) - 7.0, lc.y + float((i * 7 + sp * 2) % 13) - 9.0, 1.0, 1.0), sc)
		"possession":
			var aura: Color = pal[13]
			aura.a = 0.18 + 0.08 * sin(t * 8.0)
			for r: int in range(4):
				ci.draw_circle(at, 26.0 - float(r) * 5.0, aura)
			for i: int in range(6):  # red threads hanging from above, the object's strings
				var ang: float = float(i) * 1.047 + t * 0.9
				var tip: Vector2 = at + Vector2(cos(ang) * 14.0, sin(ang) * 9.0)
				var tc: Color = pal[13] if i % 2 == 0 else pal[12]
				ci.draw_line(Vector2(at.x + float(i - 3) * 9.0, -4.0), tip, tc, 1.0)
			var e1: Color = pal[15]
			ci.draw_rect(Rect2(at.x - 6.0, at.y - 3.0, 3.0, 2.0), e1)  # two eyes open in the object
			ci.draw_rect(Rect2(at.x + 3.0, at.y - 3.0, 3.0, 2.0), e1)
			ci.draw_rect(Rect2(at.x - 5.0, at.y - 3.0, 1.0, 2.0), pal[0])
			ci.draw_rect(Rect2(at.x + 4.0, at.y - 3.0, 1.0, 2.0), pal[0])


# ---------------------------------------------------------------- title scene (step 35)

const TITLE_LAMP := Vector2(344.0, 30.0)  ## the hanging lamp the title's moth circles
const TITLE_SHADOW_PERIOD: float = 17.0
const TITLE_SHADOW_SECS: float = 7.0


## Slow automatic camera drift for the title, in the same -1..1 units as the mouse parallax. No input needed.
static func title_pan(t: float) -> Vector2:
	return Vector2(sin(t * 0.11) * 0.9, cos(t * 0.083) * 0.45)


## 0..1 progress of the customer shadow crossing the window, or -1 while it is away. One walk every 17 s, 7 s long.
static func title_shadow_k(t: float) -> float:
	var c: float = fposmod(t - 4.0, TITLE_SHADOW_PERIOD)
	return c / TITLE_SHADOW_SECS if c < TITLE_SHADOW_SECS else -1.0


## Where the moth is at time t: a lazy loop around the lamp that swells and shrinks, with a stutter every few seconds
## as it bumps the glass. Whole pixels only.
static func title_moth_pos(t: float) -> Vector2:
	var r: float = 14.0 + 6.0 * sin(t * 0.7)
	var a: float = t * 2.1 + sin(t * 0.9) * 1.2
	var p: Vector2 = TITLE_LAMP + Vector2(cos(a) * r, sin(a) * r * 0.55) + Vector2(sin(t * 7.3) * 1.5, sin(t * 9.1) * 1.0)
	return Vector2(roundf(p.x), roundf(p.y))


## A tall hatted customer seen as a shadow behind the window glass: a slow walk, a pause at the middle, a turned head.
static func draw_title_shadow(ci: CanvasItem, pal: PackedColorArray, w: Rect2, k: float) -> void:
	if k < 0.0:
		return
	var e: float = k * k * (3.0 - 2.0 * k)
	var walk: float = e + 0.04 * sin(k * 30.0) * 0.0
	var x: float = lerpf(w.position.x - 16.0, w.end.x + 16.0, walk)
	var sh: Color = pal[0]
	sh.a = 0.92
	var base: float = w.end.y - 2.0
	var bob: float = absf(sin(k * 40.0)) * 1.5
	ci.draw_rect(Rect2(x - 7.0, base - 70.0 - bob, 14.0, 4.0), sh)  # hat brim
	ci.draw_rect(Rect2(x - 4.0, base - 82.0 - bob, 8.0, 12.0), sh)  # crown
	ci.draw_circle(Vector2(x, base - 60.0 - bob), 5.0, sh)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 5.0, base - 56.0 - bob), Vector2(x + 5.0, base - 56.0 - bob),
		Vector2(x + 11.0, base), Vector2(x - 11.0, base)]), sh)
	if k > 0.42 and k < 0.58:  # it stops and looks in
		var g: Color = pal[11]
		g.a = 0.9
		ci.draw_rect(Rect2(x - 2.0, base - 61.0 - bob, 1.0, 1.0), g)
		ci.draw_rect(Rect2(x + 1.0, base - 61.0 - bob, 1.0, 1.0), g)


# ---------------------------------------------------------------- lighting pass 2 (step 37)

static func noise_hash(seed_v: int, i: int) -> float:
	var h: int = (i * 374761393 + seed_v * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


## Smooth seeded value noise 0..1: the same seed and x always give the same value, so a torch's flicker is a fixed curve.
static func noise(seed_v: int, x: float) -> float:
	var i: int = floori(x)
	var f: float = x - float(i)
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(noise_hash(seed_v, i), noise_hash(seed_v, i + 1), f)


## One torch's brightness multiplier at time t: a slow wander plus fast crackle, both seeded noise, stronger with Dread n.
## Around 1.0, never below 0.35. Different seeds give different curves, so no two torches flicker together.
static func torch_flicker(seed_v: int, t: float, n: float) -> float:
	var slow: float = noise(seed_v, t * 2.2) - 0.5
	var fast: float = noise(seed_v + 101, t * 17.0) - 0.5
	var spike: float = maxf(noise(seed_v + 313, t * 5.0) - 0.88, 0.0) * 4.0  # a sudden gust, a dip
	return maxf(1.0 + slow * (0.3 + 0.35 * n) + fast * (0.22 + 0.4 * n) - spike * (0.4 + 0.5 * n), 0.35)


## Flame colour tinted by Dread n (0..1.2): warm amber when calm, a sickly yellow-green by 0.5, a bruised red by 1.
static func dread_tint(base: Color, n: float) -> Color:
	var c: Color = base
	var k: float = clampf(n, 0.0, 1.2)
	if k < 0.55:
		c = base.lerp(Color(0.86, 0.78, 0.34), k / 0.55 * 0.6)
	else:
		c = Color(0.86, 0.78, 0.34).lerp(Color(0.95, 0.26, 0.26), clampf((k - 0.55) / 0.5, 0.0, 1.0))
		c = base.lerp(c, 0.85)
	return c


## The window light for how far through the night it is (p 0 first customer .. 1 last customer): dusk, then night,
## then the pre-dawn grey. {light: Color, energy, tint: palette index of the sky wash, alpha, moon (0..1 how visible)}.
static func window_phase(p: float) -> Dictionary:
	var dusk: Dictionary = {"light": Color(1.0, 0.55, 0.36), "energy": 0.85, "tint": 12, "alpha": 0.5, "moon": 0.15}
	var night: Dictionary = {"light": Color(0.55, 0.66, 1.0), "energy": 1.0, "tint": 1, "alpha": 0.0, "moon": 1.0}
	var dawn: Dictionary = {"light": Color(0.78, 0.80, 0.88), "energy": 1.1, "tint": 14, "alpha": 0.42, "moon": 0.3}
	var q: float = clampf(p, 0.0, 1.0)
	var a: Dictionary = dusk
	var b: Dictionary = night
	var f: float = 0.0
	if q < 0.28:
		f = q / 0.28
	elif q < 0.72:
		a = night
		b = night
	else:
		a = night
		b = dawn
		f = (q - 0.72) / 0.28
	f = f * f * (3.0 - 2.0 * f)
	var out: Dictionary = {}
	out["light"] = (a["light"] as Color).lerp(b["light"] as Color, f)
	out["energy"] = lerpf(float(a["energy"]), float(b["energy"]), f)
	out["alpha"] = lerpf(float(a["alpha"]), float(b["alpha"]), f)
	out["moon"] = lerpf(float(a["moon"]), float(b["moon"]), f)
	out["tint"] = int(a["tint"]) if f < 0.5 else int(b["tint"])
	return out


## The sky wash over the window glass for a phase: two stacked bands so dusk reads as a horizon glow.
static func draw_sky_wash(ci: CanvasItem, pal: PackedColorArray, w: Rect2, ph: Dictionary) -> void:
	var alpha: float = float(ph["alpha"])
	if alpha <= 0.01:
		return
	var c: Color = pal[int(ph["tint"])]
	c.a = alpha * 0.8
	ci.draw_rect(w, c)
	if int(ph["tint"]) == 12:  # dusk: an amber band at the horizon
		var h: Color = pal[10]
		h.a = alpha * 0.6
		ci.draw_rect(Rect2(w.position.x, w.end.y - 44.0, w.size.x, 44.0), h)
		var h2: Color = pal[11]
		h2.a = alpha * 0.5
		ci.draw_rect(Rect2(w.position.x, w.end.y - 18.0, w.size.x, 18.0), h2)
