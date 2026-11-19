class_name UiSpellBar
extends RefCounted
## The spell bar (keys 5-0) down the right edge under the Dread candle, plus the held-item chip row that Banish (and
## the table's item stake) use to pick an object. Only known spells get a slot. Each slot shows an icon, its key, its
## Dread cost, pips for the casts left tonight and the backfire odds. A cast flashes the slot, a backfire shakes it red.
## Widgets: "spell:<id>", "pick:<uid>", "pick_cancel".

const X: float = 588.0
const Y0: float = 94.0
const W: float = 46.0
const H: float = 32.0
const STEP: float = 35.0
const FLASH_SECS: float = 0.5
const SHAKE_SECS: float = 0.6
const CHIP: float = 40.0

var pending_item_spell: String = ""  ## "banish" while the player is choosing which held item to send away
var _t: float = 0.0
var _flash: Dictionary = {}  ## spell id -> age
var _shake: Dictionary = {}  ## spell id -> age
var _icons: Dictionary = {}
var _ambient: Dictionary = {}  ## id -> small seeded phase for the idle glint


func tick(delta: float) -> void:
	_t += delta
	for d: Dictionary in [_flash, _shake]:
		for id: Variant in d.keys():
			d[id] = float(d[id]) + delta
			if float(d[id]) > 2.0:
				d.erase(id)


## Reacts to run events: a cast flashes its slot, a backfire shakes it.
func feed(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		match str(e.get("e", "")):
			"cast":
				if bool(e.get("ok", true)):
					_flash[str(e.get("spell", ""))] = 0.0
					if bool(e.get("backfire", false)):
						_shake[str(e.get("spell", ""))] = 0.0
			"backfire":
				_shake[str(e.get("spell", ""))] = 0.0


func flashing(id: String) -> bool:
	return _flash.has(id) and float(_flash[id]) < FLASH_SECS


func shaking(id: String) -> bool:
	return _shake.has(id) and float(_shake[id]) < SHAKE_SECS


## The slot rectangle for the i-th known spell.
static func slot_rect(i: int) -> Rect2:
	return Rect2(X, Y0 + STEP * float(i), W, H)


## The 16x16 icon: SpriteKit.spell_icon(id) when the art worker has shipped it, else a drawn placeholder glyph.
func icon(id: String) -> ImageTexture:
	if _icons.has(id):
		return _icons[id] as ImageTexture
	var tex: ImageTexture = null
	var sk: GDScript = load("res://game/room2d/sprite_kit.gd") as GDScript
	if sk != null and UiOccult.static_has(sk, "spell_icon"):
		tex = sk.call("spell_icon", id) as ImageTexture
	if tex == null:
		tex = placeholder_icon(id)
	_icons[id] = tex
	return tex


## A 16x16 stand-in glyph per spell, palette-coloured, so the bar works before the art lands.
static func placeholder_icon(id: String) -> ImageTexture:
	var pal: PackedColorArray = RoomPalette.colors()
	var img: Image = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var main: Color = pal[11]
	var dark: Color = pal[12]
	match id:
		"scry":
			for x: int in range(2, 14):
				var hh: int = int(round(sqrt(maxf(1.0 - pow((float(x) - 7.5) / 6.0, 2.0), 0.0)) * 4.0))
				for y: int in range(8 - hh, 8 + hh):
					img.set_pixel(x, y, main)
			for y: int in range(6, 10):
				for x: int in range(6, 10):
					img.set_pixel(x, y, pal[0])
			img.set_pixel(7, 7, pal[15])
		"hex":
			for i: int in range(12):
				img.set_pixel(2 + i, 2 + i, dark)
				img.set_pixel(13 - i, 2 + i, dark)
			for y: int in range(1, 15):
				img.set_pixel(7, y, main)
		"glamour":
			for i: int in range(1, 15):
				img.set_pixel(7, i, pal[15])
				img.set_pixel(i, 7, pal[15])
			for i: int in range(3, 12):
				img.set_pixel(i, i, main)
				img.set_pixel(15 - i, i, main)
		"banish":
			for y: int in range(2, 14):
				for x: int in range(5, 11):
					if (x + y) % 2 == 0:
						img.set_pixel(x, y, pal[14])
			for x: int in range(3, 13):
				img.set_pixel(x, 14, pal[3])
		"summon":
			for a: int in range(24):
				var v: Vector2 = Vector2.from_angle(float(a) * TAU / 24.0) * 6.0
				img.set_pixel(clampi(int(round(7.5 + v.x)), 0, 15), clampi(int(round(7.5 + v.y)), 0, 15), main)
			for i: int in range(4, 12):
				img.set_pixel(i, 6, dark)
				img.set_pixel(i, 10, dark)
		_:
			for a: int in range(24):
				var v2: Vector2 = Vector2.from_angle(float(a) * TAU / 24.0) * 6.5
				img.set_pixel(clampi(int(round(7.5 + v2.x)), 0, 15), clampi(int(round(7.5 + v2.y)), 0, 15), pal[13])
			for i: int in range(5, 11):
				img.set_pixel(i, 5 + (i % 2), main)
				img.set_pixel(i, 10 - (i % 2), main)
	return ImageTexture.create_from_image(img)


## Draws the bar and registers "spell:<id>" widgets. Known spells only; greyed and inert when not enabled.
func draw(hud: UiHud, r: RunState, hover: String) -> void:
	var known: PackedStringArray = UiOccult.known_spells(r)
	var on: bool = UiOccult.spells_enabled(r)
	var left: int = UiOccult.casts_left(r)
	var tip: String = ""
	var tip_rect := Rect2()
	for i: int in range(known.size()):
		var id: String = known[i]
		var def: Dictionary = UiOccult.spell_def(id)
		var rc: Rect2 = slot_rect(i)
		var wid: String = "spell:" + id
		var hot: bool = on and hover == wid
		if shaking(id):
			var u: float = float(_shake[id]) / SHAKE_SECS
			rc.position.x += UiOccult.shudder(u)
		hud._add(wid, rc, on)
		var kind: String = "btn_off" if not on else ("red" if shaking(id) else ("btn_hover" if hot else "btn"))
		if pending_item_spell == id:
			kind = "gold"
		hud._frame(rc, kind)
		var lift: float = -1.0 if hot else 0.0
		var tex: ImageTexture = icon(id)
		var tint: Color = Color.WHITE if on else hud._c(3)
		hud.draw_texture(tex, rc.position + Vector2(3.0, 3.0 + lift), tint)
		hud._text(rc.position + Vector2(25.0, 4.0 + lift), TsKeys.label_of("spell_" + id).left(2), 15 if on else 4)
		for p: int in range(clampi(maxi(left, 1), 1, 5)):
			var pc: int = 11 if p < left and on else 3
			hud._rect(Rect2(rc.position.x + 25.0 + float(p) * 4.0, rc.position.y + 15.0 + lift, 3.0, 3.0), pc)
		var pct: int = UiOccult.backfire_pct(r, id)
		var col_cost: int = 13 if on else 3
		var cost: String = UiOccult.dread_text(float(def.get("dread", 0.0)))
		hud._text(rc.position + Vector2(3.0, 22.0 + lift), cost, col_cost, 1, false)
		if pct >= 25:
			hud._text(rc.position + Vector2(27.0, 22.0 + lift), "%d%%" % pct, 12, 1, false)  # the risk, kept off the cost
		if flashing(id):
			var fu: float = float(_flash[id]) / FLASH_SECS
			var grow: float = UiMotion.ui_out(fu) * 5.0
			hud.draw_rect(rc.grow(grow), hud._c(11 if fu < 0.4 else 10), false, 1.0)
			var spark_x: float = rc.position.x + 2.0 + float(int(fu * 36.0))
			hud._rect(Rect2(spark_x, rc.position.y + 1.0, 2.0, 2.0), 15)
		if hot:
			tip = id
			tip_rect = rc
	if tip != "":
		_draw_tip(hud, r, tip, tip_rect)


func _draw_tip(hud: UiHud, r: RunState, id: String, rc: Rect2) -> void:
	var def: Dictionary = UiOccult.spell_def(id)
	var lines: PackedStringArray = UiPixelFont.ui_wrap(str(def.get("text", "")), 140)
	var back: PackedStringArray = UiPixelFont.ui_wrap("BACKFIRE (%d%%): %s" % [UiOccult.backfire_pct(r, id), str(def.get("backfire", ""))], 140)
	var h: float = 22.0 + float(UiPixelFont.LINE_H) * float(lines.size() + back.size())
	var box := Rect2(rc.position.x - 158.0, clampf(rc.position.y, 22.0, 300.0 - h), 152.0, h)
	hud._frame(box, "note")
	hud._text(box.position + Vector2(6.0, 5.0), "%s  %s DREAD" % [str(def.get("name", id)).to_upper(), UiOccult.dread_text(float(def.get("dread", 0.0)))], 12, 1, false)
	var y: float = box.position.y + 16.0
	for ln: String in lines:
		hud._text(Vector2(box.position.x + 6.0, y), ln, 0, 1, false)
		y += float(UiPixelFont.LINE_H)
	for ln: String in back:
		hud._text(Vector2(box.position.x + 6.0, y), ln, 12, 1, false)
		y += float(UiPixelFont.LINE_H)


## A row of held-item chips inside `area`; registers "pick:<uid>" widgets and a hover tag. Returns the chips drawn.
func draw_chips(hud: UiHud, r: RunState, area: Rect2, hover: String, title: String) -> int:
	hud._frame(area, "panel")
	hud._text(area.position + Vector2(8.0, 4.0), title, 11)
	var shown: int = 0
	var x: float = area.position.x + 8.0
	var y: float = area.position.y + 16.0
	var pulse: float = 0.5 + 0.5 * sin(_t * 5.0)
	for item: Dictionary in r.inventory:
		if x + CHIP > area.end.x - 6.0:
			break
		var uid: int = int(item["uid"])
		var rc := Rect2(x, y, CHIP, CHIP)
		var wid: String = "pick:%d" % uid
		hud._add(wid, rc, true)
		var hot: bool = hover == wid
		hud.draw_rect(rc, hud._c(1))
		hud.draw_rect(rc, hud._c(15 if hot else (11 if pulse > 0.5 else 10)), false, 1.0)
		var okey: String = "obj:%s:%s" % [str(item.get("id", "")), str(item.get("category", ""))]
		if not _icons.has(okey):
			_icons[okey] = SpriteKit.object_texture(str(item.get("id", "")), str(item.get("category", "")))
		var tex: ImageTexture = _icons[okey] as ImageTexture
		var ts: Vector2 = tex.get_size()
		hud.draw_texture(tex, rc.position + ((rc.size - ts) * 0.5).floor() + Vector2(0.0, -1.0 if hot else 0.0))
		if hot:
			var tag: String = "%s" % str(item.get("name", "?")).to_upper()
			var w: float = float(UiPixelFont.ui_width(tag)) + 12.0
			var tr := Rect2(clampf(rc.get_center().x - w * 0.5, 4.0, 630.0 - w), rc.end.y + 2.0, w, 13.0)
			hud._frame(tr, "note")
			hud._text(tr.position + Vector2(6.0, 3.0), tag, 0, 1, false)
		x += CHIP + 4.0
		shown += 1
	if r.inventory.is_empty():
		hud._text(area.position + Vector2(8.0, 24.0), "YOU HOLD NOTHING.", 14)
	return shown
