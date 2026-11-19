class_name Daily
extends RefCounted
## The Daily Seance: one seed and one omen for everybody on a date. Pure: the caller passes the date.

const LAUNCH: Vector3i = Vector3i(2026, 12, 18)
const STRIP_SURVIVED: String = "🕯"
const STRIP_WOKE: String = "🔥"
const STRIP_LOST: String = "💀"
const STRIP_UNREACHED: String = "▫"


## Days since 1970-01-01 for a civil date (proleptic Gregorian).
@warning_ignore("integer_division")
static func day_index(y: int, m: int, d: int) -> int:
	var yy: int = y - (1 if m <= 2 else 0)
	var era: int = (yy if yy >= 0 else yy - 399) / 400
	var yoe: int = yy - era * 400
	var doy: int = (153 * (m + (-3 if m > 2 else 9)) + 2) / 5 + d - 1
	var doe: int = yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


## 1 on launch day (2026-12-18); zero or negative before it.
static func number(y: int, m: int, d: int) -> int:
	return day_index(y, m, d) - day_index(LAUNCH.x, LAUNCH.y, LAUNCH.z) + 1


## Everyone playing on a date gets the same seed (a mixed 31-bit number, stable across engine versions).
static func seed_for(y: int, m: int, d: int) -> int:
	var h: int = (y * 10000 + m * 100 + d) * 2654435761 + 40503
	h = (h ^ (h >> 15)) * 2246822519
	return (h ^ (h >> 13)) & 0x7fffffff


## The run options of the daily run: haunting 0, the first omen offered for the seed, daily set.
static func opts_for(seed_value: int) -> Dictionary:
	var offered: Array[String] = Omens.offer(seed_value)
	return {"haunting": 0, "omen": offered[0] if not offered.is_empty() else "", "daily": true}


## A spoiler-free summary to paste: title, result line, a strip with one symbol per night, and the omen.
static func result_text(run: RunState, num: int) -> String:
	var nights: int = int(run.tuning.nights)
	var reached: int = mini(run.night, nights)
	var strip: String = ""
	for n: int in range(1, nights + 1):
		if n > reached:
			strip += STRIP_UNREACHED
		elif run.wake_nights.has(n):
			strip += STRIP_WOKE
		elif n == reached and not run.won:
			strip += STRIP_LOST
		else:
			strip += STRIP_SURVIVED
	var verdict: String = "survived" if run.won else "lost"
	var omen_name: String = str(run.opts.get("omen_name", ""))
	return "Cursed Pawn Séance #%d\nNight %d/%d %s | %d coins | woke %dx\n%s\nOmen: %s" % [
		num, reached, nights, verdict, run.cash, run.wake_nights.size(), strip, omen_name if omen_name != "" else "none"]
