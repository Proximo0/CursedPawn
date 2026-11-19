class_name UiNightEvent
extends RefCounted
## Night events as the player sees them: the dusk card (a glyph, the name, the rule spelled out in plain numbers) and the
## small tag that stays under the top bar all night. Rules are written from the event's `mods`, so a new event in
## night_events.json explains itself. Glyphs are 24x24 pixel pictures drawn with rectangles.

const KNOWN: PackedStringArray = ["blackout", "storm", "auction", "full_moon"]
const TONES: Dictionary = {"blackout": 3, "storm": 4, "auction": 11, "full_moon": 15}
const TAG_RIGHT: float = 586.0
const TAG_Y: float = 20.0


## The event's data row ({id, name, text, mods}) from the logic, or a stand-in when the id is not in the file.
static func data(id: String) -> Dictionary:
	var d: Dictionary = NightEvents.get_event(id)
	if d.is_empty():
		d = {"id": id, "name": id.replace("_", " ").capitalize(), "text": "", "mods": {}}
	return d


## One plain sentence per modifier: "TOOLS TAKE TWICE AS LONG." and so on.
static func rule_lines(mods: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in mods.keys():
		var v: float = float(mods[k])
		match str(k):
			"tool_cost_mult":
				out.append("TOOLS TAKE %s AS LONG." % _times(v))
			"customer_minutes_mult":
				out.append("CUSTOMERS COME %d%% %s OFTEN." % [int(round(absf(1.0 - 1.0 / maxf(v, 0.01)) * 100.0)), "LESS" if v > 1.0 else "MORE"])
			"price_mult":
				out.append("PRICES %s %d%%." % ["UP" if v >= 1.0 else "DOWN", int(round(absf(v - 1.0) * 100.0))])
			"auction_value_mult":
				out.append("THE AUCTION LOT IS WORTH %s." % _times(v))
			"auction_cursed_odds":
				out.append("THE LOT IS CURSED %d TIMES IN 100." % int(round(v * 100.0)))
			"cursed_share_mult":
				out.append("%s AS MANY CURSED OBJECTS COME IN." % _times(v))
			"curse_dread_mult":
				out.append("EACH CURSE WEIGHS %s AS MUCH." % _times(v))
			"cursed_pay_mult":
				out.append("BUYERS PAY %d%% MORE FOR CURSES." % int(round((v - 1.0) * 100.0)))
	return out


static func _times(v: float) -> String:
	if is_equal_approx(v, 2.0):
		return "TWICE"
	if is_equal_approx(v, 3.0):
		return "THREE TIMES"
	return "%sX" % str(snappedf(v, 0.1))


## The tag text and tooltip lines for the run's active event ({} when none).
static func tag_info(r: RunState) -> Dictionary:
	if r == null or r.night_event.is_empty():
		return {}
	var id: String = str(r.night_event.get("id", ""))
	var d: Dictionary = data(id)
	var tip: Array[String] = []
	tip.append_array(rule_lines(r.night_event.get("mods", {}) as Dictionary))
	return {"id": id, "text": UiEngage.ascii_up(str(d.get("name", id))), "tip": tip}


## The glyph for an event id at `at` (top-left), t seconds of animation, `big` for the card's 2x.
static func draw_glyph(ci: CanvasItem, id: String, at: Vector2, t: float, px: int = 1) -> void:
	var pal: PackedColorArray = RoomPalette.colors()
	var p: float = float(px)
	match id:
		"blackout":  # a snuffed candle with a thread of smoke
			ci.draw_rect(Rect2(at.x + 9.0 * p, at.y + 10.0 * p, 6.0 * p, 13.0 * p), pal[14])
			ci.draw_rect(Rect2(at.x + 9.0 * p, at.y + 10.0 * p, 2.0 * p, 13.0 * p), pal[15])
			ci.draw_rect(Rect2(at.x + 11.0 * p, at.y + 8.0 * p, 2.0 * p, 2.0 * p), pal[0])
			for i: int in range(7):
				ci.draw_rect(Rect2(at.x + (11.0 + sin(t * 2.0 + float(i) * 0.9) * 1.5) * p, at.y + (7.0 - float(i)) * p, p, p), pal[4])
		"storm":  # a cloud and a bolt
			ci.draw_rect(Rect2(at.x + 3.0 * p, at.y + 6.0 * p, 18.0 * p, 7.0 * p), pal[3])
			ci.draw_rect(Rect2(at.x + 6.0 * p, at.y + 3.0 * p, 8.0 * p, 4.0 * p), pal[4])
			var bolt: bool = fmod(t, 1.4) < 0.25
			for i: int in range(6):
				ci.draw_rect(Rect2(at.x + (12.0 - float(i % 3) * 2.0) * p, at.y + (13.0 + float(i) * 2.0) * p, 3.0 * p, 2.0 * p), pal[15 if bolt else 11])
			for i: int in range(4):
				ci.draw_rect(Rect2(at.x + (4.0 + float(i) * 5.0) * p, at.y + (16.0 + fmod(t * 14.0 + float(i) * 3.0, 6.0)) * p, p, 2.0 * p), pal[4])
		"auction":  # a gavel
			ci.draw_rect(Rect2(at.x + 4.0 * p, at.y + 4.0 * p, 12.0 * p, 7.0 * p), pal[9])
			ci.draw_rect(Rect2(at.x + 4.0 * p, at.y + 4.0 * p, 12.0 * p, 2.0 * p), pal[10])
			ci.draw_rect(Rect2(at.x + 9.0 * p, at.y + 11.0 * p, 2.0 * p, 10.0 * p), pal[8])
			ci.draw_rect(Rect2(at.x + 3.0 * p, at.y + 21.0 * p, 18.0 * p, 2.0 * p), pal[9])
		"full_moon":  # a big pale disc with maria
			for y: int in range(-10, 11):
				var w: int = int(sqrt(float(100 - y * y)))
				ci.draw_rect(Rect2(at.x + (12.0 - float(w)) * p, at.y + (12.0 + float(y)) * p, float(w * 2) * p, p), pal[15])
			ci.draw_rect(Rect2(at.x + 8.0 * p, at.y + 8.0 * p, 4.0 * p, 3.0 * p), pal[14])
			ci.draw_rect(Rect2(at.x + 14.0 * p, at.y + 13.0 * p, 5.0 * p, 4.0 * p), pal[14])
		_:  # an unknown event: a plain candle flame
			UiFrames.ui_flame(ci, at + Vector2(8.0, 6.0) * p, t, 0, false, 3, px)


## The dusk card band content: glyph, name, flavour and rule lines, drawn over the card's band.
static func draw_card(hud: UiHud, card: Dictionary, band: Rect2, t0: float) -> void:
	var id: String = str(card.get("event_id", ""))
	var title: String = str(card["title"])
	var tone: int = int(TONES.get(id, 14))
	var u: float = clampf(t0 / 0.7, 0.0, 1.0)
	var dw: int = UiPixelFont.ui_display_width(title, 3, true)
	var x: float = floorf(320.0 - float(dw) * 0.5) + 14.0
	draw_glyph(hud, id, Vector2(x - 44.0, band.position.y + 17.0), hud._t, 2)
	UiPixelFont.ui_display_draw(hud, Vector2(x, band.position.y + 28.0), title, 3,
		PackedInt32Array([tone, 15, 3, 0]), hud._t, 0.0, 0.0, true)
	var ramp: Array[int] = [3, 4, 14, 15]
	var shade: int = ramp[int(clampf((t0 - 0.5) / 0.6, 0.0, 0.999) * 4.0)]
	var y: float = band.position.y + 66.0
	for ln: String in UiPixelFont.ui_wrap(str(card["sub"]), 420):
		hud._text_c(320.0, y, ln, shade, 1)
		y += float(UiPixelFont.LINE_H)
	var rules: Array = card.get("rules", []) as Array
	var rc: int = ramp[int(clampf((t0 - 1.0) / 0.6, 0.0, 0.999) * 4.0)]
	for r: Variant in rules:
		hud._text_c(320.0, y + 3.0, str(r), 11 if rc >= 14 else rc, 1)
		y += float(UiPixelFont.LINE_H)
	if u >= 1.0 and float(card["age"]) > ShopGame.CARD_SKIP_AFTER + 0.5 and fmod(hud._t, 1.2) < 0.8:
		hud._text_c(320.0, band.end.y - 14.0, "CLICK TO SKIP", 3, 1, false)


## The tag under the top bar: glyph at 1x, the name, and the rules when hovered.
static func draw_tag(hud: UiHud, r: RunState, hovered: bool) -> void:
	var info: Dictionary = tag_info(r)
	if info.is_empty():
		return
	var label: String = "TONIGHT: " + str(info["text"])
	var w: float = float(UiPixelFont.ui_width(label)) + 18.0
	var rc := Rect2(TAG_RIGHT - w, TAG_Y, w, 13.0)
	hud._add("night_event_tag", rc, true)
	hud._rect(rc, 0)
	hud._rect(Rect2(rc.position.x, rc.end.y - 1.0, rc.size.x, 1.0), 8)
	draw_glyph(hud, str(info["id"]), rc.position + Vector2(-3.0, -5.0), hud._t, 1)
	hud._text(Vector2(rc.position.x + 14.0, rc.position.y + 3.0), label, int(TONES.get(str(info["id"]), 14)) if not hovered else 15, 1, false)
	if hovered:
		var tip: Array = info["tip"] as Array
		var h: float = 8.0 + float(UiPixelFont.LINE_H * tip.size())
		var tr := Rect2(rc.end.x - 250.0, rc.end.y + 2.0, 250.0, h)
		hud._frame(tr, "note")
		for i: int in range(tip.size()):
			hud._text(tr.position + Vector2(6.0, 4.0 + float(UiPixelFont.LINE_H * i)), str(tip[i]), 0, 1, false)
