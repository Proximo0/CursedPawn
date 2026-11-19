class_name UiEndings
extends RefCounted
## The four ways a run can be won, as the player sees them: a full-screen ending card (tableau, name, epilogue written in
## line by line) and the end panel's heading. The logic names the ending in `run_won.ending`; when it does not, `infer`
## reads it off the run. The tableau is the art worker's (`SpriteKit.ending_tableau(id)`, 640x360) when it exists, else a
## palette-locked stand-in drawn here.

const IDS: Array[String] = ["debt_free", "cursed_shop", "collector", "regulars"]
const CARD_SECS: float = 9.0
const LINE_AT: float = 1.6
const LINE_STEP: float = 1.25
const SKIES: Dictionary = {"debt_free": [2, 3, 9], "cursed_shop": [1, 12, 13],
	"collector": [1, 2, 3], "regulars": [1, 3, 8]}
const DATA: Dictionary = {
	"debt_free": {"title": "DEBT FREE", "sub": "THE LANDLORD HAS NOTHING LEFT TO SAY", "tone": 11,
		"epilogue": ["Five rents paid, and a coin to spare.", "The candle burns low and nothing in the shop moves.",
			"You lock up at dawn. The door sticks, as if it would rather you stayed."]},
	"cursed_shop": {"title": "BEYOND SAVING", "sub": "YOU WON. THE SHOP DID NOT.", "tone": 13,
		"epilogue": ["The rent is paid. Everything else is owed.", "Each shelf hums a note and they do not agree.",
			"You will open again tomorrow. It would be rude not to."]},
	"collector": {"title": "THE DRAWERS ARE FULL", "sub": "THE COLLECTOR IS SATISFIED", "tone": 14,
		"epilogue": ["He tips his hat and the dark tips with it.", "Something small and yours goes into a drawer. You do not ask what.",
			"His card stays on the counter. It is warm."]},
	"regulars": {"title": "THE REGULARS REMEMBER", "sub": "EVERY STORY HAS ITS LAST PAGE", "tone": 7,
		"epilogue": ["The widow's box is quiet. The colonel is thirty again.", "Somewhere a ghost has stopped being shy.",
			"They all leave a little something on the counter. A coin. A nod."]},
}


static func info(id: String) -> Dictionary:
	return (DATA[id] as Dictionary) if DATA.has(id) else (DATA["debt_free"] as Dictionary)


## The ending id of a won run: the event's, else the run's own, else read off the run.
static func ending_of(run: RunState, e: Dictionary = {}) -> String:
	var id: String = str(e.get("ending", ""))
	if id == "" and run != null:
		id = str(run.get("ending")) if "ending" in run else ""
		if id == "":
			id = str(run.opts.get("ending", ""))
	if id == "cursed":
		id = "cursed_shop"
	if IDS.has(id):
		return id
	return infer(run)


static func infer(run: RunState) -> String:
	if run == null:
		return "debt_free"
	if str(run.collector.get("result", "")) == "pleased":
		return "collector"
	var done: int = 0
	for id: Variant in run.regular_progress.keys():
		if Regulars.is_finished(str(id), run.regular_progress):
			done += 1
	if done > 0 and done >= Regulars.all().size():
		return "regulars"
	var cursed: int = 0
	for item: Dictionary in run.inventory:
		if str(item.get("curse", "")) != "":
			cursed += 1
	if cursed >= 3 or run.dread >= run.tuning.wake_threshold * 0.8:
		return "cursed_shop"
	return "debt_free"


## The card pushed on `run_won`.
## The logic's own name, title and epilogue text (on the event) win over the stand-ins here.
static func card_for(id: String, cash: int, e: Dictionary = {}) -> Dictionary:
	var d: Dictionary = info(id)
	var title: String = UiEngage.ascii_up(str(e.get("ending_name", ""))) if str(e.get("ending_name", "")) != "" else str(d["title"])
	var sub: String = UiEngage.ascii_up(str(e.get("ending_title", ""))) if str(e.get("ending_title", "")) != "" else str(d["sub"])
	var lines: Array = (d["epilogue"] as Array).duplicate()
	if str(e.get("epilogue", "")) != "":
		lines = Array(UiPixelFont.ui_wrap(str(e["epilogue"]), 540)).slice(0, 4)
	return {"title": title, "sub": sub, "tone": int(d["tone"]), "age": 0.0, "style": "ending", "ending": id,
		"secs": CARD_SECS + float(maxi(lines.size() - 3, 0)) * LINE_STEP, "epilogue": lines, "cash": cash}


static var _tab_cache: Dictionary = {}


## The art lane's 640x360 tableau for an ending id (built once per id).
static func tableau(id: String) -> Texture2D:
	var key: String = EndingArt.id_for(id)
	if not _tab_cache.has(key):
		_tab_cache[key] = EndingArt.tableau(key)
	return _tab_cache[key] as Texture2D


## The full-screen card: tableau, the name inking in, the epilogue one line at a time.
static func draw_card(hud: UiHud, card: Dictionary) -> void:
	var age: float = float(card["age"])
	var id: String = str(card.get("ending", "debt_free"))
	var fade: float = clampf(age / 1.2, 0.0, 1.0)
	hud._rect(Rect2(Vector2.ZERO, ShopGame.VIEW), 0)
	var tex: Texture2D = tableau(id)
	if tex != null:
		hud.draw_texture_rect(tex, Rect2(Vector2.ZERO, ShopGame.VIEW), false, Color(1, 1, 1, fade))
	else:
		_draw_stand_in(hud, id, fade)
	hud.draw_texture_rect(TsCanvas.dim_texture(5), Rect2(Vector2(0.0, 200.0), Vector2(640.0, 160.0)), true)
	var title: String = str(card["title"])
	var tone: int = int(card["tone"])
	var dw: int = UiPixelFont.ui_display_width(title, 3, true)
	var t0: float = age - 0.4
	if t0 > 0.0:
		UiPixelFont.ui_display_draw(hud, Vector2(floorf(320.0 - float(dw) * 0.5), 34.0), title, 3,
			PackedInt32Array([tone, 15, 3, 0]), hud._t, 0.0, 0.2, true)
		var ramp: Array[int] = [3, 4, 14, 15]
		hud._text_c(320.0, 74.0, str(card["sub"]), ramp[int(clampf((t0 - 0.6) / 0.8, 0.0, 0.999) * 4.0)], 1)
	var lines: Array = card["epilogue"] as Array
	var y: float = 232.0 - float(maxi(lines.size() - 3, 0)) * 10.0
	for i: int in range(lines.size()):
		var u: float = age - LINE_AT - LINE_STEP * float(i)
		if u <= 0.0:
			continue
		var text: String = str(lines[i])
		var shown: int = int(u * 40.0)
		var w: float = float(UiPixelFont.ui_width(text))
		UiPixelFont.ui_draw_ink(hud, Vector2(floorf(320.0 - w * 0.5), y), text, hud._c(14), hud._c(15), shown,
			shown < text.length(), hud._c(tone), hud._t)
		y += 18.0
	if age > ShopGame.CARD_SKIP_AFTER + 1.0 and fmod(hud._t, 1.2) < 0.8:
		hud._text_c(320.0, 342.0, "CLICK TO CONTINUE", 3, 1, false)


## Stand-in scenes: a sky band, a floor, and the one thing each ending is about.
static func _draw_stand_in(hud: UiHud, id: String, fade: float) -> void:
	var sky: Array = SKIES[id]
	for i: int in range(3):
		hud._rect(Rect2(0.0, float(i) * 70.0, 640.0, 72.0), int(sky[i]) if fade > 0.3 else 0)
	hud._rect(Rect2(0.0, 214.0, 640.0, 146.0), 0)
	hud._rect(Rect2(0.0, 214.0, 640.0, 2.0), 8)
	var t: float = hud._t
	match id:
		"debt_free":
			UiFrames.ui_glow(hud, Vector2(320.0, 196.0), 90, 9, 10, 1.0)
			UiFrames.ui_candle(hud, 320.0, 214.0, 14, 40, t, 0, false, 5, 3)
		"cursed_shop":
			for i: int in range(5):
				var ex: float = 90.0 + float(i) * 110.0
				var open: bool = UiMotion.ui_hash(int(t * 2.0), i + 3) < 0.8
				if open:
					hud._rect(Rect2(ex, 150.0 + float(i % 2) * 20.0, 12.0, 5.0), 13)
					hud._rect(Rect2(ex + 26.0, 150.0 + float(i % 2) * 20.0, 12.0, 5.0), 13)
		"collector":
			hud._rect(Rect2(300.0, 70.0, 40.0, 144.0), 0)
			hud._rect(Rect2(292.0, 64.0, 56.0, 8.0), 0)
			for r: int in range(3):
				hud._rect(Rect2(360.0 + float(r) * 34.0, 150.0, 28.0, 64.0), 1)
				hud._rect(Rect2(364.0 + float(r) * 34.0, 170.0, 20.0, 3.0), 4)
		"regulars":
			for i: int in range(6):
				var cx: float = 140.0 + float(i) * 72.0
				UiFrames.ui_flame(hud, Vector2(cx, 160.0), t, 1, false, i + 1)
				hud._rect(Rect2(cx - 1.0, 170.0, 7.0, 44.0), 14)
