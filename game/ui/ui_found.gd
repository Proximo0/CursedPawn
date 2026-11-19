class_name UiFound
extends RefCounted
## The found reveal popup and the whisper. A `found` event flutters a torn spell page in (it sways and settles) or
## glints a curio in (scale-in with a light sweep and sparkles), with its name and text. A `found_hint` event shows a
## small whisper strip under the top bar. Popups queue; a click or Enter closes the front one after a short beat.

const POP_SECS: float = 4.0
const SKIP_AFTER: float = 0.5
const WHISPER_SECS: float = 2.6
const BOX_W: float = 190.0
const BOX_H: float = 128.0

var popups: Array[Dictionary] = []  ## {kind, id, name, text, col, age}
var whisper: Dictionary = {}  ## {text, age}
var sfx: SfxPlayer
var _icon_tex: Dictionary = {}


func feed(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		match str(e.get("e", "")):
			"found":
				var rows: Array[Dictionary] = UiOccult.find_rows([e])
				var row: Dictionary = rows[0]
				row["age"] = 0.0
				popups.append(row)
				whisper = {}
				if sfx != null:
					sfx.ui("click")
			"found_hint":
				whisper = {"text": UiOccult.whisper_text(str(e.get("kind", ""))), "age": 0.0}


func active() -> bool:
	return not popups.is_empty()


func tick(delta: float) -> void:
	if not popups.is_empty():
		popups[0]["age"] = float(popups[0]["age"]) + delta
		if float(popups[0]["age"]) >= POP_SECS:
			popups.pop_front()
	if not whisper.is_empty():
		whisper["age"] = float(whisper["age"]) + delta
		if float(whisper["age"]) >= WHISPER_SECS:
			whisper = {}


## Closes the front popup when it has been up long enough. True when it did.
func dismiss() -> bool:
	if popups.is_empty() or float(popups[0]["age"]) < SKIP_AFTER:
		return false
	popups.pop_front()
	return true


## A 24x24 curio icon: SpriteKit.curio_icon(id) if the art worker shipped it, else a faceted gem in the rarity colour.
func curio_icon(id: String, col: int) -> ImageTexture:
	var key: String = "%s:%d" % [id, col]
	if _icon_tex.has(key):
		return _icon_tex[key] as ImageTexture
	var tex: ImageTexture = null
	var sk: GDScript = load("res://game/room2d/sprite_kit.gd") as GDScript
	if sk != null and UiOccult.static_has(sk, "curio_icon"):
		tex = sk.call("curio_icon", id) as ImageTexture
	if tex == null:
		tex = gem_icon(col)
	_icon_tex[key] = tex
	return tex


static func gem_icon(col: int) -> ImageTexture:
	var pal: PackedColorArray = RoomPalette.colors()
	var img: Image = Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	for y: int in range(24):
		for x: int in range(24):
			var d: float = absf(float(x) - 11.5) + absf(float(y) - 11.5) * 1.15
			if d < 11.0:
				var tone: Color = pal[col]
				if d > 8.5:
					tone = pal[0]
				elif x + y < 22 and d > 3.0:
					tone = pal[15]
				elif x > y:
					tone = pal[col].darkened(0.25)
				img.set_pixel(x, y, tone)
	return ImageTexture.create_from_image(img)


func draw(hud: UiHud) -> void:
	if not whisper.is_empty():
		_draw_whisper(hud)
	if popups.is_empty():
		return
	var p: Dictionary = popups[0]
	var age: float = float(p["age"])
	var fade_in: float = clampf(age / 0.25, 0.0, 1.0)
	hud.draw_texture_rect(TsCanvas.dim_texture(int(round(9.0 * fade_in))), Rect2(Vector2.ZERO, ShopGame.VIEW), true)
	var is_page: bool = str(p["kind"]) == "page"
	var settle: float = UiMotion.ui_out(age / 1.1)
	var center := Vector2(320.0, 150.0)
	if is_page:
		var fall: float = (1.0 - settle) * -170.0
		var sway: float = sin(age * 6.5) * 34.0 * (1.0 - settle)
		var ang: float = sin(age * 6.5 + 1.0) * 0.32 * (1.0 - settle)
		hud.draw_set_transform(center + Vector2(sway, fall), ang, Vector2.ONE)
		_page_body(hud, Rect2(-BOX_W * 0.5, -BOX_H * 0.5, BOX_W, BOX_H))
		hud.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_page_text(hud, p, center, age)
	else:
		var s: float = UiMotion.ui_back(age / 0.5)
		var box := Rect2(center - Vector2(BOX_W, BOX_H) * 0.5 * s, Vector2(BOX_W, BOX_H) * s)
		_curio_body(hud, box, p, age)
		if s >= 0.98:
			_curio_text(hud, p, center, age)
	if age > SKIP_AFTER + 0.5 and fmod(age, 1.2) < 0.8:
		hud._text_c(320.0, center.y + BOX_H * 0.5 + 8.0, "CLICK TO CLOSE", 3, 1, false)


func _page_body(hud: UiHud, rc: Rect2) -> void:
	hud._frame(rc, "note")
	# the torn edge: ragged dark notches along the bottom and a curl in one corner
	var x: float = rc.position.x
	while x < rc.end.x - 2.0:
		var h: float = 1.0 + floorf(UiMotion.ui_hash(int(x), 3, 9) * 4.0)
		hud.draw_rect(Rect2(x, rc.end.y - h, 3.0, h), hud._c(1))
		x += 3.0
	hud.draw_rect(Rect2(rc.end.x - 12.0, rc.position.y, 12.0, 1.0), hud._c(10))


func _page_text(hud: UiHud, p: Dictionary, center: Vector2, age: float) -> void:
	var u: float = clampf((age - 0.7) / 0.5, 0.0, 1.0)
	if u <= 0.0:
		return
	var top: float = center.y - BOX_H * 0.5
	hud._text_c(center.x, top + 10.0, "A TORN SPELL PAGE", 8, 1, false)
	var nm: String = str(p["name"]).to_upper()
	var tw: int = UiPixelFont.ui_head_width(nm, 2)
	UiPixelFont.ui_draw_reveal(hud, Vector2(center.x - float(tw) * 0.5, top + 26.0), nm, hud._c(12), hud._c(13), UiPixelFont.HEAD, 2, u, 6)
	var tex: ImageTexture = _spell_icon(str(p["id"]))
	hud.draw_texture_rect(tex, Rect2(center.x - 16.0, top + 48.0, 32.0, 32.0), false)
	var lines: PackedStringArray = UiPixelFont.ui_wrap(str(p["text"]), int(BOX_W) - 28)
	for i: int in range(mini(lines.size(), 4)):
		hud._text_c(center.x, top + 86.0 + float(i * UiPixelFont.LINE_H), lines[i], 0, 1, false)


func _spell_icon(id: String) -> ImageTexture:
	if not _icon_tex.has("spell:" + id):
		var sk: GDScript = load("res://game/room2d/sprite_kit.gd") as GDScript
		var tex: ImageTexture = null
		if sk != null and UiOccult.static_has(sk, "spell_icon"):
			tex = sk.call("spell_icon", id) as ImageTexture
		_icon_tex["spell:" + id] = tex if tex != null else UiSpellBar.placeholder_icon(id)
	return _icon_tex["spell:" + id] as ImageTexture


func _curio_body(hud: UiHud, box: Rect2, p: Dictionary, age: float) -> void:
	var col: int = int(p["col"])
	hud._frame(box, "panel")
	hud.draw_rect(box.grow(-4.0), hud._c(col), false, 1.0)
	if age > 0.5:
		for k: int in range(9):
			var ph: float = fmod(age * 1.3 + UiMotion.ui_hash(k, 1, 4), 1.0)
			var sx: float = box.position.x + 8.0 + UiMotion.ui_hash(k, 2, 4) * (box.size.x - 16.0)
			var sy: float = box.position.y + 8.0 + UiMotion.ui_hash(k, 3, 4) * (box.size.y - 16.0)
			if ph < 0.35:
				hud._rect(Rect2(floorf(sx), floorf(sy) - 1.0, 1.0, 3.0), 15)
				hud._rect(Rect2(floorf(sx) - 1.0, floorf(sy), 3.0, 1.0), 15)


func _curio_text(hud: UiHud, p: Dictionary, center: Vector2, age: float) -> void:
	var top: float = center.y - BOX_H * 0.5
	var col: int = int(p["col"])
	hud._text_c(center.x, top + 10.0, "A CURIO, FOUND", 4, 1, false)
	var ic := Vector2(center.x - 12.0, top + 22.0)
	hud.draw_texture(curio_icon(str(p["id"]), col), ic + Vector2(0.0, floorf(sin(age * 2.0) * 1.0)))
	var sweep: float = fmod(age * 1.2, 1.8) / 0.6
	if sweep < 1.0:
		var gx: float = ic.x - 6.0 + sweep * 36.0
		for k: int in range(24):
			var x: float = gx + float(k) * 0.5
			if x >= ic.x and x < ic.x + 24.0:
				hud._rect(Rect2(floorf(x), ic.y + float(k), 2.0, 1.0), 15)
	var nm: String = str(p["name"]).to_upper()
	var tw: int = UiPixelFont.ui_head_width(nm, 1)
	UiPixelFont.ui_head_draw(hud, Vector2(center.x - float(tw) * 0.5, top + 52.0), nm, hud._c(col if col != 14 else 15), 1, true, hud._c(0))
	var lines: PackedStringArray = UiPixelFont.ui_wrap(str(p["text"]), int(BOX_W) - 28)
	for i: int in range(mini(lines.size(), 5)):
		hud._text_c(center.x, top + 70.0 + float(i * UiPixelFont.LINE_H), lines[i], 14, 1, true)


func _draw_whisper(hud: UiHud) -> void:
	var age: float = float(whisper["age"])
	var a: float = UiMotion.ui_out(age / 0.3) * (1.0 - UiMotion.ui_in(clampf((age - (WHISPER_SECS - 0.5)) / 0.5, 0.0, 1.0)))
	if a <= 0.02:
		return
	var s: String = str(whisper["text"])
	var w: float = float(UiPixelFont.ui_width(s)) + 22.0
	var rc := Rect2(320.0 - w * 0.5, 24.0 - (1.0 - a) * 12.0, w, 15.0)
	hud._frame(rc, "note")
	hud._text(rc.position + Vector2(11.0, 4.0), s, 12 if int(age * 5.0) % 2 == 0 else 8, 1, false)
