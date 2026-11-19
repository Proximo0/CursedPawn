extends SceneTree
## Renders every sprite on one labelled sheet: /tmp/shots/sprite_sheet.png
## Objects with their cursed overlays, customers (all idle frames), tools, cards, tiles and the horror props.
## xvfb-run -a godot --path . --resolution 1280x720 -s res://tests/shots/sprite_sheet.gd -- --scripted

const OUT_PATH: String = "/tmp/shots/sprite_sheet.png"
const SCALE: int = 2
const BG: Color = Color("3a2455")
const SHEET_W: int = 1320
const SHEET_H: int = 4600


func _initialize() -> void:
	var sheet: Image = Image.create_empty(SHEET_W, SHEET_H, false, Image.FORMAT_RGBA8)
	sheet.fill(BG)
	var y: int = 4
	if OS.get_cmdline_user_args().has("--c29"):  # lane C steps 29-31: new objects, detail renders, curse overlays, types, moods
		_lane_c()
		return
	if OS.get_cmdline_user_args().has("--c34"):  # lane C step 34: the five ending tableaux at 1x
		var t0: int = Time.get_ticks_msec()
		var ts: Image = Image.create_empty(1300, 1120, false, Image.FORMAT_RGBA8)
		ts.fill(BG)
		var ti: int = 0
		for eid: String in EndingArt.IDS:
			ts.blend_rect(EndingArt.tableau_image(eid), Rect2i(0, 0, 640, 360), Vector2i(4 + (ti % 2) * 650, 4 + (ti / 2) * 370))
			ti += 1
		ts.save_png("/tmp/shots/tableaux.png")
		print("TABLEAUX /tmp/shots/tableaux.png ms=", Time.get_ticks_msec() - t0)
		quit()
		return
	if OS.get_cmdline_user_args().has("--r6"):  # only the round 6 cells: regulars, deed seals, the Collector, two omens
		_round6(sheet)
		return
	var objs: Array = _load("res://game/data/objects.json")
	var col: int = 0
	# the redrawn toys and books first, at 3x
	for rid: String in ["porcelain_doll", "jack_in_box", "marionette", "toy_theatre", "diary", "hymnal", "almanac", "photo_album", "herbarium", "first_edition"]:
		_put(sheet, SpriteKit.object_texture(rid, "toy").get_image(), col * 132 + 4, y, rid, 3)
		col += 1
	y += 120
	col = 0
	for o: Dictionary in objs:
		var tex: Image = SpriteKit.object_texture(str(o["id"]), str(o["category"])).get_image()
		_put(sheet, tex, col * 132 + 4, y, str(o["id"]), SCALE)
		col += 1
		if col == 10:
			col = 0
			y += 88
	# the same objects again with the cursed overlay composited on top, at 3x for a good look
	y += 4
	col = 0
	for o: Dictionary in objs:
		var base: Image = SpriteKit.object_texture(str(o["id"]), str(o["category"])).get_image()
		base.blend_rect(SpriteKit.object_cursed_overlay(str(o["id"])).get_image(), Rect2i(Vector2i.ZERO, base.get_size()), Vector2i.ZERO)
		_put(sheet, base, col * 132 + 4, y, str(o["id"]), SCALE)
		col += 1
		if col == 10:
			col = 0
			y += 88
	y += 4
	var x: int = 4
	var row_h: int = 0
	var n: int = 0
	for c: Dictionary in _load("res://game/data/customers.json"):
		var tex: Image = SpriteKit.customer_texture(c).get_image()
		_put(sheet, tex, x, y, str(c["id"]), SCALE)
		x += 136
		row_h = maxi(row_h, tex.get_height() * SCALE + 14)
		n += 1
		if n == 9:
			n = 0
			x = 4
			y += row_h + 4
			row_h = 0
	y += row_h + 8
	# idle frames of a few types side by side at 2x
	x = 4
	row_h = 0
	for cid: String in ["widow", "haggler", "priest", "rival"]:
		for c: Dictionary in _load("res://game/data/customers.json"):
			if str(c["id"]) != cid:
				continue
			var fi: int = 0
			for f: ImageTexture in SpriteKit.customer_frames(c):
				_put(sheet, f.get_image(), x, y, cid.substr(0, 4) + str(fi), SCALE)
				x += 136
				row_h = maxi(row_h, f.get_height() * SCALE + 14)
				fi += 1
				if x > SHEET_W - 136:
					x = 4
					y += row_h + 4
					row_h = 0
	y += row_h + 8
	x = 4
	for t: String in ["uv", "scale", "listen", "touch"]:
		_put(sheet, SpriteKit.tool_texture(t).get_image(), x, y, t, SCALE)
		x += 100
	for nm: String in ["The Sun", "Wheel of Fortune", "The Fool", "Death", "The Tower"]:
		_put(sheet, SpriteKit.card_texture(nm, true).get_image(), x, y, nm.substr(0, 12), SCALE)
		x += 80
	_put(sheet, SpriteKit.card_texture("x", false).get_image(), x, y, "back", SCALE)
	y += 40 * SCALE + 18
	x = 4
	for k: String in ["wall", "floor", "shelf", "counter", "door"]:
		var tile: Image = SpriteKit.tile_texture(k).get_image()
		# tile 2x2 across so tiling seams show
		var big: Image = Image.create_empty(tile.get_width() * 2, tile.get_height() * 2, false, Image.FORMAT_RGBA8)
		for i: int in range(4):
			big.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i((i % 2) * tile.get_width(), (i / 2) * tile.get_height()))
		_put(sheet, big, x, y, k, SCALE)
		x += big.get_width() * SCALE + 16
	y += 96 * SCALE + 18
	x = 4
	for k: String in ["eyes", "portrait", "silhouette", "hand", "moth", "clock"]:
		var img: Image = SpriteKit.horror_texture(k).get_image()
		# on black, as the room shows them
		var bg: Image = Image.create_empty(img.get_width() + 8, img.get_height() + 8, false, Image.FORMAT_RGBA8)
		bg.fill(Color("0b0710"))
		bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(4, 4))
		_put(sheet, bg, x, y, k, 3 if k == "moth" else SCALE)
		x += bg.get_width() * (3 if k == "moth" else SCALE) + 16
	y += 152 * SCALE + 18
	# the occult round: croupier frames, dice, cards, wheel, lot, page, spell icons, then every curio icon at 3x
	x = 4
	var rh: int = 0
	for f: ImageTexture in SpriteKit.croupier_frames():
		_put(sheet, f.get_image(), x, y, "croupier", SCALE)
		x += 136
		rh = maxi(rh, 96 * SCALE + 14)
	_put(sheet, SpriteKit.wheel_texture().get_image(), x, y, "wheel", 3)
	x += 200
	_put(sheet, SpriteKit.lot_texture().get_image(), x, y, "lot", 3)
	x += 110
	_put(sheet, SpriteKit.spell_page_texture().get_image(), x, y, "page", 3)
	y += rh + 8
	x = 4
	for fc: int in range(1, 7):
		_put(sheet, SpriteKit.dice_texture(fc).get_image(), x, y, "d%d" % fc, 3)
		x += 48
	for sid: String in SpriteKit.SK_SPELL_IDS:
		_put(sheet, SpriteKit.spell_icon(sid).get_image(), x, y, sid, 3)
		x += 64
	y += 56
	x = 4
	for rk: int in range(1, 14):
		_put(sheet, SpriteKit.card_face_texture(rk).get_image(), x, y, "r%d" % rk, 2)
		x += 50
	y += 30 * 2 + 18
	x = 4
	var cn: int = 0
	for cr: Dictionary in _load("res://game/data/curios.json"):
		_put(sheet, SpriteKit.curio_icon(str(cr["id"])).get_image(), x, y, str(cr["id"]).substr(0, 14), 3)
		x += 108
		cn += 1
		if cn % 12 == 0:
			x = 4
			y += 24 * 3 + 18
	y += 24 * 3 + 18
	# round 5: the Collector (4 frames), omen art, altar, pendulum, upgrade icons, banish icon, hands per body plan
	x = 4
	for f: ImageTexture in SpriteKit.collector_frames():
		_put(sheet, f.get_image(), x, y, "collector", SCALE)
		x += 160
	_put(sheet, SpriteKit.altar_texture().get_image(), x, y, "altar", 2)
	x += 210
	_put(sheet, SpriteKit.pendulum_texture().get_image(), x, y, "pendulum", 4)
	x += 110
	_put(sheet, SpriteKit.spell_icon("banish").get_image(), x, y, "banish", 4)
	y += 110 * SCALE + 18
	x = 4
	var on: int = 0
	for om: Dictionary in _load("res://game/data/omens.json"):
		_put(sheet, SpriteKit.omen_art(str(om["id"])).get_image(), x, y, str(om["id"]), 3)
		x += 160
		on += 1
		if on % 8 == 0:
			x = 4
			y += 40 * 3 + 18
	y += 40 * 3 + 18
	x = 4
	for uid: String in ["extra_shelf", "spell_slot", "extra_cast", "tell_chance", "cheap_rent", "pendulum", "altar_candle", "keep_cash", "u9", "u10"]:
		_put(sheet, SpriteKit.upgrade_icon(uid).get_image(), x, y, uid.substr(0, 10), 4)
		x += 100
	y += 16 * 4 + 18
	x = 4
	for plan: String in ["normal", "hunched", "tall", "broad", "child"]:
		var look: Dictionary = {"id": "x_" + plan, "cloak": "#4b2a78", "eyes": "#ffd27a", "height": 1.0, "plan": plan}
		var himg: Image = SpriteKit.customer_texture(look).get_image().get_region(Rect2i(4, 70, 56, 26))
		_put(sheet, himg, x, y, plan, 3)
		x += 190
	y += 26 * 3 + 18
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	sheet.get_region(Rect2i(0, 0, SHEET_W, mini(y, SHEET_H))).save_png(OUT_PATH)
	print("SPRITE SHEET ", OUT_PATH, " h=", y)
	quit()


## Round 6: regular portraits (the six in regulars.json, else a hash set), 12 deed seals, the Collector frames, curio
## icons at the cabinet's 16 px size, and the two repainted omens.
func _round6(sheet: Image) -> void:
	var y: int = 4
	var x: int = 4
	var ids: PackedStringArray = PackedStringArray()
	if FileAccess.file_exists("res://game/data/regulars.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.open("res://game/data/regulars.json", FileAccess.READ).get_as_text())
		var rows: Array = parsed as Array if parsed is Array else ((parsed as Dictionary).get("regulars", []) as Array)
		for r: Variant in rows:
			ids.append(str((r as Dictionary).get("id", "")))
	for extra: String in ["widow_march", "boy_radio", "father_ash", "magician_vale", "monk_quill", "granny_pip"]:
		if ids.size() < 6:
			ids.append(extra)
	for id: String in ids:
		_put(sheet, SpriteKit.regular_portrait(id).get_image(), x, y, id.substr(0, 12), 4)
		x += 150
	y += 40 * 4 + 18
	x = 4
	for i: int in range(12):
		_put(sheet, SpriteKit.deed_seal("deed_%d" % i).get_image(), x, y, "seal %d" % i, 4)
		x += 100
	y += 20 * 4 + 18
	x = 4
	for f: ImageTexture in SpriteKit.collector_frames():
		_put(sheet, f.get_image(), x, y, "collector", 2)
		x += 160
	var face: Image = SpriteKit.collector_frames()[0].get_image().get_region(Rect2i(20, 0, 32, 44))
	_put(sheet, face, x, y, "face 4x", 4)
	x += 150
	for id: String in ["blind_lamp", "deaf_ear"]:
		_put(sheet, SpriteKit.omen_art(id).get_image(), x, y, id, 3)
		x += 150
	y += 110 * 2 + 18
	x = 4
	for cr: Dictionary in _load("res://game/data/curios.json").slice(0, 12):
		var ic: Image = SpriteKit.curio_icon(str(cr["id"])).get_image()
		ic.resize(16, 16, Image.INTERPOLATE_NEAREST)
		_put(sheet, ic, x, y, str(cr["id"]).substr(0, 8), 4)
		x += 80
	y += 16 * 4 + 18
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	sheet.get_region(Rect2i(0, 0, SHEET_W, mini(y, SHEET_H))).save_png("/tmp/shots/sprite_sheet_r6.png")
	print("SPRITE SHEET r6 /tmp/shots/sprite_sheet_r6.png h=", y)
	quit()


func _lane_c() -> void:
	var sheet: Image = Image.create_empty(SHEET_W, 1700, false, Image.FORMAT_RGBA8)
	sheet.fill(BG)
	var y: int = 4
	var x: int = 4
	for k: String in ArtContent.PRIMARY_KINDS:
		_put(sheet, SpriteKit.object_texture(k, str(ArtContent.KIND_CATEGORY[k])).get_image(), x, y, k.substr(0, 12), 3)
		x += 132
		if x > SHEET_W - 132:
			x = 4
			y += 116
	y += 120
	x = 4
	for k: String in ArtContent.PRIMARY_KINDS:
		_put(sheet, ArtContent.object_detail_image(k, str(ArtContent.KIND_CATEGORY[k])), x, y, "d " + k.substr(0, 10), 2)
		x += 136
		if x > SHEET_W - 136:
			x = 4
			y += 146
	y += 150
	x = 4
	var picks: Array = [["costume_change", "tiepin", "jewelry"], ["copycat", "kazoo", "instrument"], ["bashful_purse", "bestiary", "book"], ["landlord_lullaby", "horseshoe", "relic"],
		["copycat", "wind_up_frog", "toy"], ["costume_change", "lantern", "relic"]]
	x = 4
	for p: Array in picks:
		var base: Image = SpriteKit.object_texture(str(p[1]), str(p[2])).get_image()
		base.blend_rect(ArtContent.curse_overlay(str(p[0]), str(p[1]), str(p[2])).get_image(), Rect2i(Vector2i.ZERO, base.get_size()), Vector2i.ZERO)
		_put(sheet, base, x, y, str(p[0]) + " " + str(p[1]).substr(0, 6), 4)
		x += 150
	y += 150
	x = 4
	for tid: String in ["errand_child", "debt_collector", "twin", "seer"]:
		for mood: String in ArtContent.MOODS:
			var look: Dictionary = {"id": tid, "cloak": "#4b2a78", "eyes": "#ffd27a", "height": 1.0}
			var tex: Image = ArtContent.mood_texture(look, mood).get_image()
			_put(sheet, tex, x, y, tid.substr(0, 5) + " " + mood.substr(0, 4), 2)
			x += 104
		if x > SHEET_W - 330:
			x = 4
			y += 220
	y += 220
	DirAccess.make_dir_recursive_absolute("/tmp/shots")
	sheet.get_region(Rect2i(0, 0, SHEET_W, mini(y, 1700))).save_png("/tmp/shots/sprite_sheet_c.png")
	print("SPRITE SHEET c /tmp/shots/sprite_sheet_c.png h=", y)
	quit()


func _load(path: String) -> Array:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) as Array


func _put(sheet: Image, tex: Image, x: int, y: int, label: String, scale: int) -> void:
	var big: Image = tex.duplicate()
	big.resize(tex.get_width() * scale, tex.get_height() * scale, Image.INTERPOLATE_NEAREST)
	sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(x, y))
	var ly: int = y + big.get_height() + 2
	for i: int in range(label.length()):
		_glyph(sheet, label[i].to_upper(), x + i * 8, ly)


func _glyph(sheet: Image, ch: String, x: int, y: int) -> void:
	var rows: String = str(SpriteKit.SK_FONT.get(ch, ""))
	if rows.length() != 15:
		return
	for i: int in range(15):
		if rows[i] == "1":
			sheet.fill_rect(Rect2i(x + (i % 3) * 2, y + (i / 3) * 2, 2, 2), Color("f5efe0"))
