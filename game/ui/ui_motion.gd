class_name UiMotion
extends RefCounted
## Easing and small deterministic helpers shared by the pixel UI. Pure: no nodes, no clock, no global random.


## Ease out (cubic): fast start, soft landing. t is clamped to 0..1.
static func ui_out(t: float) -> float:
	var u: float = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u * u


## Ease in (quadratic): slow start, fast finish.
static func ui_in(t: float) -> float:
	var u: float = clampf(t, 0.0, 1.0)
	return u * u


## Smooth in and out.
static func ui_in_out(t: float) -> float:
	var u: float = clampf(t, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Ease out with a small overshoot (a pinned note settling).
static func ui_back(t: float) -> float:
	var u: float = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * u * u * u + 1.70158 * u * u


## Frame-rate independent approach of cur towards target (rate in 1/s).
static func ui_approach(cur: float, target: float, delta: float, rate: float) -> float:
	return lerpf(cur, target, 1.0 - exp(-rate * delta))


## A repeatable noise value in 0..1 from three integers.
static func ui_hash(a: int, b: int, c: int = 0) -> float:
	var h: int = a * 374761393 + b * 668265263 + c * 1274126177 + 1013904223
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0
