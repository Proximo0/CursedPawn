class_name ArtContent
extends RefCounted
## Art for the full-game content (docs/full_game_plan.md steps 29-31), drawn with SpriteKit's pixel helpers so it
## stays palette-locked. Lane A's ids are read at call time: an id this file does not know is mapped to one of the
## 16 new object drawings by keyword, then by category, so every new object gets a distinct sprite whatever it is called.
##  - draw_object(g, id, category): 16 new 32x32 objects (kinds in OBJ_KINDS).
##  - object_detail(id, category): the 64x64 detail render for the inspect card (step 30).
##  - curse_overlay(curse_id, object_id): four more wrongness overlays (step 29).
##  - plan_for / eye_style_for / extras: four more customer types (step 29); mood_face: expressions (step 31).

## The 16 objects Lane A added (objects.json 41-56), then 12 spares used for any other unknown id.
const PRIMARY_KINDS: Array[String] = ["wind_up_frog", "kaleidoscope", "paper_kite", "tiepin", "opal_earrings", "hair_comb", "kazoo",
	"pan_pipes", "zither", "sheet_music", "bestiary", "guestbook", "horseshoe", "lantern", "death_mask", "wax_seal"]
const OBJ_KINDS: Array[String] = ["wind_up_frog", "kaleidoscope", "paper_kite", "tiepin", "opal_earrings", "hair_comb", "kazoo",
	"pan_pipes", "zither", "sheet_music", "bestiary", "guestbook", "horseshoe", "lantern", "death_mask", "wax_seal",
	"wind_up_monkey", "toy_train", "tiara", "cufflinks", "amber_pendant", "bone_flute", "snare_drum", "grimoire", "scroll",
	"prayer_book", "crystal_ball", "skull"]
const KIND_CATEGORY: Dictionary = {"wind_up_frog": "toy", "paper_kite": "toy", "tiepin": "jewelry", "opal_earrings": "jewelry",
	"hair_comb": "jewelry", "kazoo": "instrument", "pan_pipes": "instrument", "sheet_music": "book", "bestiary": "book",
	"guestbook": "book", "horseshoe": "relic", "wax_seal": "relic","kaleidoscope": "toy", "wind_up_monkey": "toy", "toy_train": "toy", "tiara": "jewelry",
	"cufflinks": "jewelry", "amber_pendant": "jewelry", "bone_flute": "instrument", "snare_drum": "instrument",
	"zither": "instrument", "grimoire": "book", "scroll": "book", "prayer_book": "book", "crystal_ball": "relic",
	"skull": "relic", "lantern": "relic", "death_mask": "relic"}
## keyword -> kind, first hit wins (an id containing the keyword)
const KIND_WORDS: Array = [["frog", "wind_up_frog"], ["kite", "paper_kite"], ["tiepin", "tiepin"], ["earring", "opal_earrings"],
	["comb", "hair_comb"], ["kazoo", "kazoo"], ["panpipe", "pan_pipes"], ["pan_pipe", "pan_pipes"], ["sheet_music", "sheet_music"],
	["bestiary", "bestiary"], ["guestbook", "guestbook"], ["horseshoe", "horseshoe"], ["wax_seal", "wax_seal"], ["seal", "wax_seal"],["kaleido", "kaleidoscope"], ["monkey", "wind_up_monkey"], ["wind", "wind_up_monkey"],
	["train", "toy_train"], ["engine", "toy_train"], ["tiara", "tiara"], ["crown", "tiara"], ["diadem", "tiara"],
	["cuff", "cufflinks"], ["amber", "amber_pendant"], ["pendant", "amber_pendant"], ["flute", "bone_flute"],
	["pipe", "bone_flute"], ["whistle", "bone_flute"], ["drum", "snare_drum"], ["zither", "zither"], ["lyre", "zither"],
	["harp", "zither"], ["dulcimer", "zither"], ["grimoire", "grimoire"], ["spellbook", "grimoire"], ["tome", "grimoire"],
	["scroll", "scroll"], ["map", "scroll"], ["deed", "scroll"], ["prayer", "prayer_book"], ["bible", "prayer_book"],
	["missal", "prayer_book"], ["crystal", "crystal_ball"], ["orb", "crystal_ball"], ["skull", "skull"], ["bone", "skull"],
	["lantern", "lantern"], ["lamp", "lantern"], ["mask", "death_mask"]]
const MOODS: Array[String] = ["calm", "nervous", "greedy"]
const CURSE_KINDS: Array[String] = ["shift", "echo", "seal", "hush"]
## customer type id keyword -> body plan "body,accessory" (ledger, basket and twin are drawn by extras())
const PLAN_WORDS: Array = [["child", "child,basket"], ["errand", "child,basket"], ["debt", "normal,ledger"], ["bailiff", "normal,ledger"],
	["twin", "tall,twin"], ["seer", "tall,veil"], ["oracle", "tall,veil"]]


static func kind_for(id: String, category: String) -> String:
	if OBJ_KINDS.has(id):
		return id
	for w: Array in KIND_WORDS:
		if id.contains(str(w[0])):
			return str(w[1])
	var pool: Array[String] = []
	for k: String in OBJ_KINDS:
		if category == "" or str(KIND_CATEGORY[k]) == category:
			pool.append(k)
	if pool.is_empty():
		pool = OBJ_KINDS
	return pool[absi(hash(id)) % pool.size()]


## Draws a new object onto the 32x32 image g. Returns false for an old (hand-drawn elsewhere) category-less call.
static func draw_object(g: Image, id: String, category: String) -> bool:
	var kind: String = kind_for(id, category)
	match kind:
		"wind_up_frog": ac_frog(g)
		"paper_kite": ac_kite(g)
		"tiepin": ac_tiepin(g)
		"opal_earrings": ac_earrings(g)
		"hair_comb": ac_comb(g)
		"kazoo": ac_kazoo(g)
		"pan_pipes": ac_pipes(g)
		"sheet_music": ac_sheet(g)
		"bestiary": ac_bestiary(g)
		"guestbook": ac_guestbook(g)
		"horseshoe": ac_horseshoe(g)
		"wax_seal": ac_waxseal(g)
		"kaleidoscope": ac_kaleidoscope(g)
		"wind_up_monkey": ac_monkey(g)
		"toy_train": ac_train(g)
		"tiara": ac_tiara(g)
		"cufflinks": ac_cufflinks(g)
		"amber_pendant": ac_pendant(g)
		"bone_flute": ac_flute(g)
		"snare_drum": ac_drum(g)
		"zither": ac_zither(g)
		"grimoire": ac_grimoire(g)
		"scroll": ac_scroll(g)
		"prayer_book": ac_prayer(g)
		"crystal_ball": ac_orb(g)
		"skull": ac_skull(g)
		"lantern": ac_lantern(g)
		"death_mask": ac_mask(g)
		_: return false
	return true


# ---------------------------------------------------------------- the 16 objects

static func ac_kaleidoscope(g: Image) -> void:
	SpriteKit._sk_r(g, 6, 13, 18, 8, 9)  # wood tube
	SpriteKit._sk_r(g, 6, 13, 18, 1, 10)
	SpriteKit._sk_r(g, 6, 20, 18, 1, 8)
	SpriteKit._sk_r(g, 2, 14, 5, 6, 8)  # eyepiece
	SpriteKit._sk_r(g, 2, 14, 5, 1, 9)
	SpriteKit._sk_r(g, 24, 11, 5, 12, 10)  # brass flare around the object glass
	SpriteKit._sk_r(g, 24, 11, 5, 1, 11)
	SpriteKit._sk_r(g, 8, 12, 2, 10, 10)  # bands
	SpriteKit._sk_r(g, 19, 12, 2, 10, 10)
	SpriteKit._sk_e(g, 27, 17, 2.0, 4.0, 0)
	SpriteKit._sk_p(g, 27, 15, 13)
	SpriteKit._sk_p(g, 26, 17, 6)
	SpriteKit._sk_p(g, 27, 19, 4)
	SpriteKit._sk_p(g, 28, 17, 11)
	SpriteKit._sk_r(g, 11, 23, 12, 3, 8)  # a little stand
	SpriteKit._sk_r(g, 9, 26, 16, 2, 8)
	SpriteKit._sk_outline(g)
	for x: int in range(11, 18, 3):
		SpriteKit._sk_p(g, x, 16, 8)


static func ac_monkey(g: Image) -> void:
	SpriteKit._sk_e(g, 8, 8, 2.5, 2.5, 9)  # ears
	SpriteKit._sk_e(g, 24, 8, 2.5, 2.5, 9)
	SpriteKit._sk_e(g, 16, 9, 7.0, 6.0, 9)  # head
	SpriteKit._sk_e(g, 16, 11, 4.5, 3.5, 14)  # muzzle
	SpriteKit._sk_p(g, 13, 8, 0)
	SpriteKit._sk_p(g, 19, 8, 0)
	SpriteKit._sk_p(g, 13, 7, 15)
	SpriteKit._sk_p(g, 19, 7, 15)
	SpriteKit._sk_r(g, 15, 11, 2, 1, 0)
	SpriteKit._sk_r(g, 12, 15, 9, 9, 13)  # red waistcoat
	SpriteKit._sk_r(g, 16, 15, 1, 9, 12)
	SpriteKit._sk_r(g, 13, 16, 1, 1, 11)
	SpriteKit._sk_r(g, 13, 19, 1, 1, 11)
	SpriteKit._sk_r(g, 9, 16, 3, 6, 9)  # arms
	SpriteKit._sk_r(g, 21, 16, 3, 6, 9)
	SpriteKit._sk_e(g, 6, 21, 4.0, 4.0, 10)  # cymbals
	SpriteKit._sk_e(g, 26, 21, 4.0, 4.0, 10)
	SpriteKit._sk_p(g, 6, 21, 11)
	SpriteKit._sk_p(g, 26, 21, 11)
	SpriteKit._sk_r(g, 12, 24, 3, 5, 9)  # legs and feet
	SpriteKit._sk_r(g, 18, 24, 3, 5, 9)
	SpriteKit._sk_r(g, 11, 28, 5, 2, 8)
	SpriteKit._sk_r(g, 18, 28, 5, 2, 8)
	SpriteKit._sk_r(g, 24, 11, 3, 1, 11)  # winding key
	SpriteKit._sk_r(g, 26, 9, 1, 5, 11)
	SpriteKit._sk_outline(g)


static func ac_train(g: Image) -> void:
	SpriteKit._sk_r(g, 8, 8, 4, 6, 0)  # chimney
	SpriteKit._sk_r(g, 7, 7, 6, 2, 10)
	SpriteKit._sk_p(g, 6, 4, 14)
	SpriteKit._sk_p(g, 4, 2, 2)
	SpriteKit._sk_r(g, 4, 13, 17, 9, 6)  # boiler
	SpriteKit._sk_r(g, 4, 13, 17, 2, 7)
	SpriteKit._sk_r(g, 4, 20, 17, 2, 5)
	SpriteKit._sk_r(g, 8, 13, 2, 9, 10)
	SpriteKit._sk_r(g, 15, 13, 2, 9, 10)
	SpriteKit._sk_r(g, 20, 8, 9, 15, 13)  # cab
	SpriteKit._sk_r(g, 19, 7, 11, 2, 12)
	SpriteKit._sk_r(g, 22, 11, 4, 5, 0)
	SpriteKit._sk_p(g, 23, 12, 11)
	SpriteKit._sk_r(g, 3, 22, 27, 2, 1)  # frame
	for cx: int in [8, 15, 25]:
		SpriteKit._sk_e(g, float(cx), 25.0, 3.4, 3.4, 14)
		SpriteKit._sk_e(g, float(cx), 25.0, 1.0, 1.0, 0)
	SpriteKit._sk_r(g, 4, 18, 2, 3, 11)  # lamp
	SpriteKit._sk_outline(g)


static func ac_tiara(g: Image) -> void:
	SpriteKit._sk_r(g, 4, 23, 24, 3, 10)  # band
	SpriteKit._sk_r(g, 4, 23, 24, 1, 11)
	SpriteKit._sk_r(g, 4, 25, 24, 1, 9)
	var spikes: Array = [[6, 15], [11, 11], [16, 6], [21, 11], [26, 15]]
	for s: Array in spikes:
		var sx: int = int(s[0])
		var sy: int = int(s[1])
		for y: int in range(sy, 23):
			var half: int = 1 + (y - sy) / 4
			SpriteKit._sk_r(g, sx - half, y, half * 2 + 1, 1, 10)
			SpriteKit._sk_p(g, sx - half, y, 11)
	SpriteKit._sk_e(g, 16, 6, 2.0, 2.0, 15)
	SpriteKit._sk_p(g, 16, 6, 14)
	SpriteKit._sk_e(g, 11, 11, 1.2, 1.2, 13)
	SpriteKit._sk_e(g, 21, 11, 1.2, 1.2, 13)
	SpriteKit._sk_p(g, 6, 15, 4)
	SpriteKit._sk_p(g, 26, 15, 4)
	SpriteKit._sk_p(g, 16, 24, 13)
	SpriteKit._sk_p(g, 10, 24, 15)
	SpriteKit._sk_p(g, 22, 24, 15)
	SpriteKit._sk_outline(g)


static func ac_cufflinks(g: Image) -> void:
	for cx: int in [9, 23]:
		SpriteKit._sk_e(g, float(cx), 14.0, 6.0, 6.0, 10)
		SpriteKit._sk_e(g, float(cx), 14.0, 4.0, 4.0, 11)
		SpriteKit._sk_e(g, float(cx), 14.0, 2.0, 2.0, 12)
		SpriteKit._sk_p(g, cx - 1, 13, 13)
		SpriteKit._sk_p(g, cx - 3, 11, 15)
		SpriteKit._sk_r(g, cx - 1, 20, 3, 4, 10)  # post
	for x: int in range(15, 18):  # the chain
		SpriteKit._sk_p(g, x, 14 + (x % 2), 14)
	SpriteKit._sk_r(g, 15, 13, 3, 1, 14)
	SpriteKit._sk_r(g, 7, 24, 5, 2, 10)
	SpriteKit._sk_r(g, 21, 24, 5, 2, 10)
	SpriteKit._sk_outline(g)


static func ac_pendant(g: Image) -> void:
	SpriteKit._sk_l(g, 6, 2, 15, 12, 14)  # chain
	SpriteKit._sk_l(g, 26, 2, 17, 12, 14)
	SpriteKit._sk_l(g, 7, 2, 15, 13, 4)
	SpriteKit._sk_r(g, 13, 11, 6, 3, 11)  # cap
	SpriteKit._sk_r(g, 13, 11, 6, 1, 15)
	SpriteKit._sk_e(g, 16, 21, 6.5, 8.0, 10)  # amber teardrop
	SpriteKit._sk_e(g, 16, 22, 4.5, 6.0, 11)
	SpriteKit._sk_p(g, 13, 17, 15)
	SpriteKit._sk_p(g, 13, 18, 15)
	SpriteKit._sk_r(g, 15, 20, 3, 2, 0)  # the fly in it
	SpriteKit._sk_p(g, 14, 19, 14)
	SpriteKit._sk_p(g, 18, 19, 14)
	SpriteKit._sk_p(g, 14, 23, 14)
	SpriteKit._sk_p(g, 18, 23, 14)
	SpriteKit._sk_outline(g)


static func ac_flute(g: Image) -> void:
	for o: int in range(-1, 2):
		SpriteKit._sk_l(g, 3, 27 + o, 28, 5 + o, 15 if o == -1 else (14 if o == 0 else 9))
	SpriteKit._sk_l(g, 2, 28, 4, 26, 10)
	for t: int in range(6):
		var hx: int = 10 + t * 3
		var hy: int = 27 - roundi(float(hx - 3) * 0.88)
		SpriteKit._sk_p(g, hx, hy, 0)
		SpriteKit._sk_p(g, hx, hy + 1, 0)
	SpriteKit._sk_l(g, 24, 9, 28, 14, 10)
	SpriteKit._sk_r(g, 25, 4, 3, 2, 0)
	SpriteKit._sk_outline(g)


static func ac_drum(g: Image) -> void:
	SpriteKit._sk_r(g, 5, 11, 22, 13, 13)  # shell
	SpriteKit._sk_r(g, 5, 11, 3, 13, 12)
	SpriteKit._sk_r(g, 23, 11, 4, 13, 12)
	SpriteKit._sk_e(g, 16, 24, 11.0, 3.0, 12)
	SpriteKit._sk_r(g, 5, 14, 22, 8, 13)
	for x: int in range(6, 27, 4):  # tension cords in a zigzag
		SpriteKit._sk_l(g, x, 14, x + 2, 22, 14)
		SpriteKit._sk_l(g, x + 4, 14, x + 2, 22, 14)
	SpriteKit._sk_r(g, 5, 11, 22, 2, 10)
	SpriteKit._sk_r(g, 5, 23, 22, 2, 10)
	SpriteKit._sk_e(g, 16, 11, 11.0, 3.5, 15)  # skin
	SpriteKit._sk_e(g, 16, 11, 9.0, 2.2, 14)
	SpriteKit._sk_l(g, 8, 4, 19, 11, 9)  # sticks
	SpriteKit._sk_l(g, 24, 4, 13, 11, 9)
	SpriteKit._sk_p(g, 8, 4, 15)
	SpriteKit._sk_p(g, 24, 4, 15)
	SpriteKit._sk_outline(g)


static func ac_zither(g: Image) -> void:
	for y: int in range(6, 27):
		var half: int = 7 + (y - 6) * 6 / 20
		SpriteKit._sk_r(g, 16 - half, y, half * 2 + 1, 1, 9)
		SpriteKit._sk_p(g, 16 - half, y, 10)
		SpriteKit._sk_p(g, 16 + half, y, 8)
	SpriteKit._sk_r(g, 8, 6, 17, 2, 8)
	for x: int in range(10, 23, 2):
		SpriteKit._sk_r(g, x, 8, 1, 17, 14)
		SpriteKit._sk_p(g, x, 6, 10)
	SpriteKit._sk_e(g, 16, 20, 4.0, 3.5, 0)
	SpriteKit._sk_e_ring(g, 16.0, 20.0, 4.0, 3.5, 10, 0.3, 0.0)
	SpriteKit._sk_r(g, 8, 25, 17, 1, 8)
	SpriteKit._sk_p(g, 12, 12, 13)  # one string has snapped
	SpriteKit._sk_outline(g)


static func ac_grimoire(g: Image) -> void:
	SpriteKit._sk_r(g, 6, 3, 21, 26, 12)  # cover
	SpriteKit._sk_r(g, 6, 3, 3, 26, 0)
	SpriteKit._sk_r(g, 9, 3, 18, 1, 13)
	SpriteKit._sk_r(g, 27, 5, 2, 23, 15)  # pages
	SpriteKit._sk_r(g, 27, 8, 2, 1, 14)
	SpriteKit._sk_r(g, 27, 13, 2, 1, 14)
	SpriteKit._sk_r(g, 27, 19, 2, 1, 14)
	for c: Vector2i in [Vector2i(10, 4), Vector2i(24, 4), Vector2i(10, 26), Vector2i(24, 26)]:  # brass corners
		SpriteKit._sk_r(g, c.x - 1, c.y - 1, 4, 4, 10)
		SpriteKit._sk_p(g, c.x - 1, c.y - 1, 11)
	SpriteKit._sk_e(g, 17, 15, 6.0, 3.5, 15)  # the eye
	SpriteKit._sk_e(g, 17, 15, 2.2, 2.2, 13)
	SpriteKit._sk_p(g, 17, 15, 0)
	SpriteKit._sk_l(g, 17, 7, 17, 9, 11)
	SpriteKit._sk_l(g, 17, 21, 17, 23, 11)
	SpriteKit._sk_r(g, 5, 14, 24, 2, 14)  # clasp strap
	SpriteKit._sk_r(g, 25, 12, 4, 6, 10)
	SpriteKit._sk_outline(g)


static func ac_scroll(g: Image) -> void:
	SpriteKit._sk_r(g, 6, 9, 20, 15, 15)  # sheet
	SpriteKit._sk_r(g, 6, 9, 20, 1, 14)
	SpriteKit._sk_r(g, 24, 9, 2, 15, 14)
	for y: int in range(12, 22, 2):
		SpriteKit._sk_r(g, 8 + (y % 3), y, 12 - (y % 4), 1, 8)
	SpriteKit._sk_r(g, 4, 5, 24, 4, 14)  # top roll
	SpriteKit._sk_r(g, 4, 5, 24, 1, 15)
	SpriteKit._sk_r(g, 4, 8, 24, 1, 9)
	SpriteKit._sk_r(g, 3, 4, 2, 6, 9)
	SpriteKit._sk_r(g, 27, 4, 2, 6, 9)
	SpriteKit._sk_r(g, 4, 24, 24, 4, 14)  # bottom roll
	SpriteKit._sk_r(g, 4, 24, 24, 1, 15)
	SpriteKit._sk_r(g, 3, 23, 2, 6, 9)
	SpriteKit._sk_r(g, 27, 23, 2, 6, 9)
	SpriteKit._sk_e(g, 20, 20, 3.0, 3.0, 13)  # wax seal
	SpriteKit._sk_p(g, 19, 19, 12)
	SpriteKit._sk_p(g, 21, 21, 12)
	SpriteKit._sk_outline(g)


static func ac_prayer(g: Image) -> void:
	SpriteKit._sk_r(g, 8, 4, 17, 25, 1)
	SpriteKit._sk_r(g, 8, 4, 2, 25, 0)
	SpriteKit._sk_r(g, 10, 4, 15, 1, 2)
	SpriteKit._sk_r(g, 25, 6, 2, 22, 14)
	SpriteKit._sk_r(g, 25, 10, 2, 1, 15)
	SpriteKit._sk_r(g, 25, 18, 2, 1, 15)
	SpriteKit._sk_r(g, 16, 8, 2, 12, 11)  # gilt cross
	SpriteKit._sk_r(g, 13, 11, 8, 2, 11)
	SpriteKit._sk_p(g, 16, 8, 15)
	SpriteKit._sk_r(g, 12, 23, 10, 1, 10)
	SpriteKit._sk_r(g, 20, 28, 2, 4, 13)  # ribbon
	SpriteKit._sk_p(g, 20, 31, 12)
	for c: Vector2i in [Vector2i(8, 4), Vector2i(8, 27), Vector2i(23, 27)]:
		SpriteKit._sk_r(g, c.x, c.y, 3, 2, 10)
	SpriteKit._sk_outline(g)


static func ac_orb(g: Image) -> void:
	SpriteKit._sk_r(g, 9, 24, 14, 3, 10)  # pedestal
	SpriteKit._sk_r(g, 9, 24, 14, 1, 11)
	SpriteKit._sk_r(g, 7, 27, 18, 2, 9)
	SpriteKit._sk_r(g, 8, 22, 3, 3, 10)
	SpriteKit._sk_r(g, 21, 22, 3, 3, 10)
	SpriteKit._sk_e(g, 16, 13, 10.0, 10.0, 2)  # glass
	SpriteKit._sk_e(g, 16, 14, 8.0, 8.0, 3)
	SpriteKit._sk_e(g, 18, 16, 5.0, 4.0, 6)  # green smoke
	SpriteKit._sk_e(g, 19, 17, 3.0, 2.0, 7)
	SpriteKit._sk_p(g, 13, 11, 15)  # glints
	SpriteKit._sk_p(g, 12, 12, 15)
	SpriteKit._sk_p(g, 12, 13, 14)
	SpriteKit._sk_p(g, 21, 9, 14)
	SpriteKit._sk_outline(g)


static func ac_skull(g: Image) -> void:
	SpriteKit._sk_e(g, 16, 12, 10.0, 9.5, 15)
	SpriteKit._sk_e(g, 20, 14, 6.0, 7.0, 14)
	SpriteKit._sk_r(g, 10, 19, 13, 8, 14)  # jaw
	SpriteKit._sk_r(g, 10, 19, 3, 8, 15)
	SpriteKit._sk_e(g, 12, 13, 3.0, 3.2, 0)
	SpriteKit._sk_e(g, 20, 13, 3.0, 3.2, 0)
	SpriteKit._sk_p(g, 12, 14, 12)
	SpriteKit._sk_p(g, 20, 14, 12)
	SpriteKit._sk_r(g, 15, 17, 3, 3, 0)
	for x: int in range(11, 23, 2):
		SpriteKit._sk_r(g, x, 23, 1, 4, 0)
	SpriteKit._sk_r(g, 10, 22, 13, 1, 4)
	SpriteKit._sk_l(g, 17, 3, 15, 7, 4)  # old crack
	SpriteKit._sk_l(g, 15, 7, 16, 9, 4)
	SpriteKit._sk_outline(g)


static func ac_lantern(g: Image) -> void:
	SpriteKit._sk_ring(g, 16.0, 6.0, 7.0, 5.0, 1.5, 1)  # handle
	SpriteKit._sk_r(g, 8, 8, 17, 3, 2)  # cap
	SpriteKit._sk_r(g, 10, 6, 13, 2, 2)
	SpriteKit._sk_r(g, 9, 11, 15, 13, 10)  # glass
	SpriteKit._sk_r(g, 10, 12, 13, 11, 11)
	SpriteKit._sk_e(g, 16, 18, 3.0, 5.0, 15)  # flame
	SpriteKit._sk_e(g, 16, 19, 1.5, 3.0, 11)
	SpriteKit._sk_r(g, 15, 23, 2, 1, 0)
	for x: int in [9, 15, 23]:
		SpriteKit._sk_r(g, x, 11, 1, 13, 1)
	SpriteKit._sk_r(g, 8, 24, 17, 3, 2)
	SpriteKit._sk_r(g, 8, 24, 17, 1, 3)
	SpriteKit._sk_r(g, 7, 27, 19, 2, 1)
	SpriteKit._sk_outline(g)


static func ac_mask(g: Image) -> void:
	SpriteKit._sk_e(g, 16, 15, 9.5, 12.5, 15)
	SpriteKit._sk_e(g, 19, 17, 6.0, 9.0, 14)
	SpriteKit._sk_e(g, 12, 13, 3.0, 1.8, 0)  # eye slits
	SpriteKit._sk_e(g, 20, 13, 3.0, 1.8, 0)
	SpriteKit._sk_r(g, 15, 16, 2, 5, 4)  # nose ridge
	SpriteKit._sk_p(g, 15, 21, 0)
	SpriteKit._sk_p(g, 17, 21, 0)
	SpriteKit._sk_e(g, 16, 25, 2.5, 1.0, 0)  # a thin, patient mouth
	SpriteKit._sk_p(g, 11, 19, 4)
	SpriteKit._sk_p(g, 21, 19, 4)
	SpriteKit._sk_r(g, 5, 11, 2, 12, 13)  # ribbons
	SpriteKit._sk_r(g, 26, 11, 2, 12, 12)
	SpriteKit._sk_outline(g)


# ---------------------------------------------------------------- the 12 objects drawn for Lane A's ids

static func ac_frog(g: Image) -> void:
	SpriteKit._sk_e(g, 16, 20, 10.0, 6.5, 6)  # tin body
	SpriteKit._sk_e(g, 16, 22, 7.0, 3.5, 7)
	SpriteKit._sk_e(g, 10, 12, 3.5, 3.5, 6)  # eye bumps
	SpriteKit._sk_e(g, 22, 12, 3.5, 3.5, 6)
	SpriteKit._sk_e(g, 10, 12, 2.0, 2.0, 15)
	SpriteKit._sk_e(g, 22, 12, 2.0, 2.0, 15)
	SpriteKit._sk_p(g, 11, 12, 0)
	SpriteKit._sk_p(g, 23, 12, 0)
	SpriteKit._sk_r(g, 10, 17, 12, 1, 0)  # wide mouth
	SpriteKit._sk_r(g, 4, 25, 7, 4, 5)  # hind legs
	SpriteKit._sk_r(g, 21, 25, 7, 4, 5)
	SpriteKit._sk_r(g, 2, 28, 5, 1, 6)
	SpriteKit._sk_r(g, 25, 28, 5, 1, 6)
	SpriteKit._sk_r(g, 15, 21, 2, 5, 12)  # a red painted stripe
	SpriteKit._sk_r(g, 27, 18, 3, 1, 11)  # key
	SpriteKit._sk_r(g, 29, 16, 1, 5, 11)
	SpriteKit._sk_outline(g)


static func ac_kite(g: Image) -> void:
	for y: int in range(3, 22):  # a diamond of paper
		var half: int = (y - 3) if y < 11 else (19 - (y - 3)) * 10 / 11
		SpriteKit._sk_r(g, 15 - half, y, half * 2 + 2, 1, 15 if y % 2 == 0 else 14)
	SpriteKit._sk_l(g, 15, 3, 15, 22, 9)
	SpriteKit._sk_l(g, 5, 11, 26, 11, 9)
	SpriteKit._sk_r(g, 10, 7, 4, 3, 13)  # painted patch
	SpriteKit._sk_r(g, 17, 12, 4, 3, 12)
	SpriteKit._sk_p(g, 15, 11, 11)
	SpriteKit._sk_l(g, 15, 22, 20, 27, 13)  # tail with bows
	SpriteKit._sk_l(g, 20, 27, 16, 30, 13)
	for b: Vector2i in [Vector2i(18, 25), Vector2i(17, 29)]:
		SpriteKit._sk_r(g, b.x - 1, b.y, 4, 2, 12)
	SpriteKit._sk_outline(g)


static func ac_tiepin(g: Image) -> void:
	SpriteKit._sk_l(g, 4, 27, 24, 7, 14)  # the pin
	SpriteKit._sk_l(g, 5, 27, 25, 7, 15)
	SpriteKit._sk_p(g, 3, 28, 14)
	SpriteKit._sk_e(g, 24, 8, 5.0, 5.0, 10)  # head: a gilt setting with a dark stone
	SpriteKit._sk_e(g, 24, 8, 3.0, 3.0, 12)
	SpriteKit._sk_p(g, 23, 7, 13)
	SpriteKit._sk_p(g, 22, 6, 15)
	SpriteKit._sk_r(g, 19, 4, 1, 1, 11)
	SpriteKit._sk_r(g, 9, 21, 5, 2, 10)  # a little keeper
	SpriteKit._sk_outline(g)


static func ac_earrings(g: Image) -> void:
	for cx: int in [9, 23]:
		SpriteKit._sk_ring(g, float(cx), 5.0, 3.0, 3.0, 1.0, 14)  # hook
		SpriteKit._sk_r(g, cx - 1, 8, 3, 2, 10)
		SpriteKit._sk_e(g, float(cx), 17.0, 5.0, 7.0, 10)  # gilt bezel
		SpriteKit._sk_e(g, float(cx), 17.0, 3.5, 5.5, 15)  # opal
		SpriteKit._sk_e(g, float(cx) + 1.0, 18.0, 2.0, 3.0, 4)
		SpriteKit._sk_p(g, cx - 2, 15, 6)
		SpriteKit._sk_p(g, cx, 19, 13)
		SpriteKit._sk_p(g, cx - 1, 14, 14)
	SpriteKit._sk_outline(g)


static func ac_comb(g: Image) -> void:
	SpriteKit._sk_r(g, 4, 6, 24, 6, 15)  # bone back
	SpriteKit._sk_r(g, 4, 6, 24, 1, 14)
	SpriteKit._sk_r(g, 4, 11, 24, 1, 14)
	for x: int in range(5, 28, 3):  # decoration
		SpriteKit._sk_p(g, x, 8, 13)
		SpriteKit._sk_p(g, x + 1, 9, 12)
	for x: int in range(5, 28, 2):  # teeth
		SpriteKit._sk_r(g, x, 12, 1, 14 - (x % 3), 14 if x % 4 == 1 else 15)
	SpriteKit._sk_p(g, 13, 24, -1)  # a broken tooth
	SpriteKit._sk_p(g, 13, 25, -1)
	SpriteKit._sk_r(g, 17, 24, 1, 3, -1)
	SpriteKit._sk_p(g, 12, 6, 12)  # something dark caught in it
	SpriteKit._sk_l(g, 12, 13, 14, 22, 0)
	SpriteKit._sk_outline(g)


static func ac_kazoo(g: Image) -> void:
	SpriteKit._sk_e(g, 16, 14, 13.0, 4.5, 10)  # brass tube, slightly tapered
	SpriteKit._sk_r(g, 4, 10, 24, 9, 10)
	SpriteKit._sk_r(g, 4, 10, 24, 2, 11)
	SpriteKit._sk_r(g, 4, 17, 24, 2, 9)
	SpriteKit._sk_r(g, 2, 11, 3, 7, 11)
	SpriteKit._sk_r(g, 27, 11, 3, 7, 11)
	SpriteKit._sk_r(g, 13, 6, 6, 5, 11)  # the membrane port
	SpriteKit._sk_r(g, 14, 7, 4, 3, 0)
	SpriteKit._sk_p(g, 15, 8, 14)
	SpriteKit._sk_r(g, 7, 12, 1, 5, 11)
	SpriteKit._sk_outline(g)


static func ac_pipes(g: Image) -> void:
	for i: int in range(6):
		var x: int = 3 + i * 4
		var hgt: int = 22 - i * 3
		SpriteKit._sk_r(g, x, 5 + i * 3, 4, hgt, 9)
		SpriteKit._sk_r(g, x, 5 + i * 3, 1, hgt, 10)
		SpriteKit._sk_r(g, x + 3, 5 + i * 3, 1, hgt, 8)
		SpriteKit._sk_r(g, x + 1, 5 + i * 3, 2, 2, 0)
	SpriteKit._sk_r(g, 3, 14, 24, 2, 12)  # binding
	SpriteKit._sk_r(g, 3, 21, 24, 1, 12)
	SpriteKit._sk_p(g, 12, 15, 13)
	SpriteKit._sk_outline(g)


static func ac_sheet(g: Image) -> void:
	SpriteKit._sk_r(g, 5, 4, 22, 24, 15)
	SpriteKit._sk_r(g, 5, 4, 22, 1, 14)
	SpriteKit._sk_r(g, 26, 4, 1, 24, 14)
	for sy: int in [7, 14, 21]:  # staves
		for k: int in range(5):
			SpriteKit._sk_r(g, 7, sy + k, 18, 1, 14 if k % 2 == 0 else 15)
		SpriteKit._sk_r(g, 7, sy, 18, 1, 8)
		SpriteKit._sk_r(g, 7, sy + 2, 18, 1, 8)
		SpriteKit._sk_r(g, 7, sy + 4, 18, 1, 8)
	for n: Vector2i in [Vector2i(10, 9), Vector2i(15, 7), Vector2i(20, 10), Vector2i(12, 16), Vector2i(18, 14), Vector2i(22, 18),
			Vector2i(9, 23), Vector2i(16, 25)]:
		SpriteKit._sk_r(g, n.x, n.y, 3, 2, 0)
		SpriteKit._sk_r(g, n.x + 2, n.y - 4, 1, 5, 0)
	SpriteKit._sk_p(g, 20, 5, 13)  # one blot of blood-red ink
	SpriteKit._sk_p(g, 21, 6, 12)
	SpriteKit._sk_outline(g)


static func ac_bestiary(g: Image) -> void:
	SpriteKit._sk_r(g, 5, 3, 22, 26, 6)  # scaly green hide cover
	SpriteKit._sk_r(g, 5, 3, 3, 26, 5)
	SpriteKit._sk_r(g, 8, 3, 19, 1, 7)
	for y: int in range(5, 28, 2):
		for x: int in range(9 + (y % 4) / 2, 26, 4):
			SpriteKit._sk_p(g, x, y, 5)
	SpriteKit._sk_r(g, 27, 5, 2, 23, 15)
	SpriteKit._sk_r(g, 27, 11, 2, 1, 14)
	SpriteKit._sk_r(g, 27, 20, 2, 1, 14)
	SpriteKit._sk_l(g, 13, 8, 17, 22, 12)  # three claw scratches
	SpriteKit._sk_l(g, 16, 8, 20, 22, 12)
	SpriteKit._sk_l(g, 19, 8, 23, 22, 12)
	SpriteKit._sk_l(g, 14, 8, 18, 22, 13)
	SpriteKit._sk_r(g, 10, 12, 14, 5, 10)  # nameplate
	SpriteKit._sk_r(g, 11, 13, 12, 3, 9)
	SpriteKit._sk_outline(g)


static func ac_guestbook(g: Image) -> void:
	SpriteKit._sk_r(g, 4, 8, 24, 18, 8)  # open book, seen from the front
	SpriteKit._sk_r(g, 5, 7, 11, 18, 15)
	SpriteKit._sk_r(g, 16, 7, 11, 18, 14)
	SpriteKit._sk_r(g, 15, 7, 2, 18, 9)
	for y: int in range(10, 23, 3):
		SpriteKit._sk_r(g, 7, y, 7, 1, 8)
		SpriteKit._sk_r(g, 18, y, 4 + (y % 3) * 2, 1, 4)
	SpriteKit._sk_r(g, 7, 22, 4, 1, 13)  # a name that has been crossed out
	SpriteKit._sk_l(g, 24, 4, 20, 12, 15)  # quill
	SpriteKit._sk_l(g, 25, 4, 21, 12, 14)
	SpriteKit._sk_p(g, 20, 13, 0)
	SpriteKit._sk_r(g, 4, 26, 24, 2, 0)
	SpriteKit._sk_outline(g)


static func ac_horseshoe(g: Image) -> void:
	for a: int in range(-20, 201, 4):  # an open ring, ends pointing down
		var ang: float = deg_to_rad(float(a))
		for r: int in range(7, 12):
			var px: int = 16 + roundi(cos(ang) * float(r))
			var py: int = 17 - roundi(sin(ang) * float(r))
			SpriteKit._sk_p(g, px, py, 2 if r == 7 else (14 if r == 11 else 4))
	for sx: int in [5, 6, 25, 26]:
		SpriteKit._sk_r(g, sx, 18, 1, 9, 2)
	SpriteKit._sk_r(g, 4, 17, 4, 10, 4)
	SpriteKit._sk_r(g, 24, 17, 4, 10, 4)
	SpriteKit._sk_r(g, 4, 17, 1, 10, 4)
	SpriteKit._sk_r(g, 24, 17, 1, 10, 4)
	for n: Vector2i in [Vector2i(9, 7), Vector2i(7, 12), Vector2i(23, 7), Vector2i(25, 12), Vector2i(16, 5), Vector2i(6, 21), Vector2i(26, 21)]:
		SpriteKit._sk_p(g, n.x, n.y, 0)  # nail holes
	SpriteKit._sk_p(g, 12, 6, 14)
	SpriteKit._sk_p(g, 14, 5, 4)
	SpriteKit._sk_outline(g)


static func ac_waxseal(g: Image) -> void:
	SpriteKit._sk_e(g, 16, 16, 11.0, 10.0, 12)  # an irregular blob of dark wax
	SpriteKit._sk_e(g, 10, 24, 3.0, 2.5, 12)
	SpriteKit._sk_e(g, 24, 8, 3.0, 2.5, 12)
	SpriteKit._sk_e(g, 16, 16, 8.5, 7.5, 13)
	SpriteKit._sk_e(g, 17, 17, 6.0, 5.0, 12)
	SpriteKit._sk_ring(g, 16.0, 16.0, 6.0, 5.5, 1.0, 13)
	SpriteKit._sk_r(g, 15, 12, 2, 9, 13)  # a stamped sigil: a spoked eye
	SpriteKit._sk_r(g, 12, 15, 8, 2, 13)
	SpriteKit._sk_p(g, 16, 16, 12)
	SpriteKit._sk_p(g, 11, 11, 15)
	SpriteKit._sk_p(g, 12, 10, 14)
	SpriteKit._sk_r(g, 5, 4, 7, 1, 15)  # a torn corner of the paper it sealed
	SpriteKit._sk_r(g, 4, 5, 6, 2, 14)
	SpriteKit._sk_outline(g)


# ---------------------------------------------------------------- step 30: the 64x64 detail render

## A 64x64 render of an object for the inspect card: the 32x32 sprite at 2x with the dark outline redrawn 1 px thick, a
## second light ramp on edges facing the top-left candle, specular glints on shiny materials and a wood-grain or
## weave dither on mid tones. Same palette, transparent surroundings. Unknown ids use the same fallbacks as the room.
static func object_detail(id: String, category: String) -> ImageTexture:
	return ImageTexture.create_from_image(object_detail_image(id, category))


static func object_detail_image(id: String, category: String) -> Image:
	var small: Image = SpriteKit._sk_object_image(id, category)
	var w: int = small.get_width() * 2
	var h: int = small.get_height() * 2
	var big: Image = SpriteKit._sk_new(w, h)
	var idx: PackedInt32Array = PackedInt32Array()
	idx.resize(w * h)
	for y: int in range(h):
		for x: int in range(w):
			idx[y * w + x] = SpriteKit._sk_idx(small, x / 2, y / 2)
	# drop the doubled black outline (outside edge pixels of index 0) so a 1 px one can be redrawn
	var body: PackedInt32Array = idx.duplicate()
	for y: int in range(h):
		for x: int in range(w):
			if idx[y * w + x] == 0 and ac_open_near(idx, w, h, x, y):
				body[y * w + x] = -1
	var out: PackedInt32Array = body.duplicate()
	for y: int in range(h):
		for x: int in range(w):
			var c: int = body[y * w + x]
			if c <= 0:
				continue
			var up: int = ac_at(body, w, h, x, y - 1)
			var left: int = ac_at(body, w, h, x - 1, y)
			var down: int = ac_at(body, w, h, x, y + 1)
			var right: int = ac_at(body, w, h, x + 1, y)
			var n: int = c
			if up < 0 or left < 0:
				n = SpriteKit.SK_LIGHT[c]
			elif down < 0 or right < 0:
				n = SpriteKit.SK_DARK[c]
			elif (x + y) % 4 == 0 and (c == 9 or c == 8 or c == 3 or c == 2):
				n = SpriteKit.SK_DARK[c]  # grain on wood and cloth
			elif (x * 3 + y * 5) % 17 == 0 and (c == 10 or c == 11 or c == 15 or c == 14):
				n = 15 if c != 15 else 11  # a glint of polish
			out[y * w + x] = n
	for y: int in range(h):
		for x: int in range(w):
			var v: int = out[y * w + x]
			if v >= 0:
				SpriteKit._sk_p(big, x, y, v)
	SpriteKit._sk_outline(big)
	return big


static func ac_at(a: PackedInt32Array, w: int, h: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return a[y * w + x]


static func ac_open_near(a: PackedInt32Array, w: int, h: int, x: int, y: int) -> bool:
	return ac_at(a, w, h, x - 1, y) < 0 or ac_at(a, w, h, x + 1, y) < 0 or ac_at(a, w, h, x, y - 1) < 0 or ac_at(a, w, h, x, y + 1) < 0


# ---------------------------------------------------------------- step 29: four more curse overlays

static func curse_kind(curse_id: String) -> String:
	for w: Array in [["swap", "shift"], ["shift", "shift"], ["categ", "shift"], ["change", "shift"], ["copy", "echo"], ["echo", "echo"],
			["replic", "echo"], ["spread", "echo"], ["inspect", "seal"], ["unseen", "seal"], ["blind", "seal"], ["never", "seal"],
			["silent", "seal"], ["whisper", "hush"], ["bashful", "seal"], ["purse", "seal"], ["lullaby", "hush"], ["landlord", "hush"], ["costume", "shift"], ["rent", "hush"], ["hush", "hush"], ["murmur", "hush"]]:
		if curse_id.contains(str(w[0])):
			return str(w[1])
	return CURSE_KINDS[absi(hash(curse_id)) % CURSE_KINDS.size()]


## A faint overlay for the new curses, same size as the object: "shift" a dithered ghost outline slipping off to one
## side, "echo" a smaller second copy of the object, "seal" a closed wax-red eyelid, "hush" rising rings of whisper.
## Shown over the object the way object_cursed_overlay is. An empty curse id returns the plain overlay.
static func curse_overlay(curse_id: String, object_id: String, category: String = "") -> ImageTexture:
	if curse_id == "":
		return SpriteKit.object_cursed_overlay(object_id)
	var base: Image = SpriteKit._sk_object_image(object_id, category)
	var w: int = base.get_width()
	var h: int = base.get_height()
	var g: Image = SpriteKit._sk_new(w, h)
	var solid: Array[Vector2i] = []
	var minp: Vector2i = Vector2i(w, h)
	var maxp: Vector2i = Vector2i.ZERO
	for y: int in range(h):
		for x: int in range(w):
			if SpriteKit._sk_idx(base, x, y) > 0:
				solid.append(Vector2i(x, y))
				minp = Vector2i(mini(minp.x, x), mini(minp.y, y))
				maxp = Vector2i(maxi(maxp.x, x), maxi(maxp.y, y))
	if solid.is_empty():
		return ImageTexture.create_from_image(g)
	var ctr: Vector2i = (minp + maxp) / 2
	match curse_kind(curse_id):
		"shift":
			for p: Vector2i in solid:
				var edge: bool = SpriteKit._sk_idx(base, p.x - 1, p.y) < 1 or SpriteKit._sk_idx(base, p.x + 1, p.y) < 1 or SpriteKit._sk_idx(base, p.x, p.y - 1) < 1 or SpriteKit._sk_idx(base, p.x, p.y + 1) < 1
				if edge:
					var q: Vector2i = p + Vector2i(2, -1)
					if q.x < w and q.y >= 0 and (p.x + p.y) % 2 == 0:
						SpriteKit._sk_p(g, q.x, q.y, 4)
					var q2: Vector2i = p + Vector2i(-2, 1)
					if q2.x >= 0 and q2.y < h and (p.x + p.y) % 3 == 0:
						SpriteKit._sk_p(g, q2.x, q2.y, 6)
		"echo":
			for p: Vector2i in solid:
				if p.x % 2 == 0 and p.y % 2 == 0:
					var q: Vector2i = Vector2i(ctr.x + (p.x - ctr.x) / 2 + 9, ctr.y + (p.y - ctr.y) / 2 + 7)
					if q.x < w and q.y < h:
						SpriteKit._sk_p(g, q.x, q.y, 3 + (p.y + p.x) % 2)
			SpriteKit._sk_p(g, mini(ctr.x + 9, w - 1), mini(ctr.y + 7, h - 1), 15)
		"seal":
			var ey: int = ctr.y
			SpriteKit._sk_e(g, float(ctr.x), float(ey), 6.0, 2.2, 12)
			for dx: int in range(-5, 6):
				SpriteKit._sk_p(g, ctr.x + dx, ey + 1 + (absi(dx) < 4 as int), 13)
			for dx: int in range(-4, 5, 2):
				SpriteKit._sk_l(g, ctr.x + dx, ey + 2, ctr.x + dx + dx / 3, ey + 4, 0)
			SpriteKit._sk_p(g, ctr.x, ey, 15)
		_:
			for r: int in range(3):
				var rad: float = 4.0 + float(r) * 3.0
				for a: int in range(-30, 31, 6):
					var ang: float = deg_to_rad(float(a) - 90.0)
					var q: Vector2i = Vector2i(ctr.x + roundi(cos(ang) * rad), minp.y - 1 + roundi(sin(ang) * rad * 0.6))
					if q.x >= 0 and q.x < w and q.y >= 0 and q.y < h:
						SpriteKit._sk_p(g, q.x, q.y, 14 if r == 0 else (4 if r == 1 else 3))
	return ImageTexture.create_from_image(g)


# ---------------------------------------------------------------- step 29: four more customer types

static func plan_for(id: String, table_plan: String) -> String:
	if table_plan != "":
		return table_plan
	for w: Array in PLAN_WORDS:
		if id.contains(str(w[0])):
			return str(w[1])
	return "normal"


static func eye_style_for(id: String, table_style: String, fallback: String) -> String:
	if table_style != "":
		return table_style
	if id.contains("child") or id.contains("errand"):
		return "wide"
	if id.contains("debt"):
		return "slit"
	if id.contains("twin"):
		return "mismatch"
	return fallback


## Accessories the base drawing has no branch for. "ledger" a bowler hat and a ledger book under the arm (a debt
## collector), "basket" a small basket on the arm (a child on an errand), "twin" a second, paler hood just behind the
## first (a twin who returns as someone else). hx, hy is the hood centre; the figure is already drawn.
static func extras(g: Image, acc: String, hx: int, hy: int, wf: float, base: int, lit: int, sh: int, sh2: int) -> void:
	match acc:
		"ledger":
			SpriteKit._sk_cust_hat(g, hx, hy - 11, "top", base, lit, sh, sh2)
			var bx: int = 32 + roundi(15.0 * wf)
			SpriteKit._sk_r(g, bx, 58, 11, 15, 12)
			SpriteKit._sk_r(g, bx, 58, 2, 15, 0)
			SpriteKit._sk_r(g, bx + 9, 59, 2, 13, 15)
			SpriteKit._sk_r(g, bx + 3, 62, 5, 1, 10)
			SpriteKit._sk_r(g, bx + 3, 65, 5, 1, 10)
		"basket":
			var cx: int = 32 - roundi(17.0 * wf)
			SpriteKit._sk_r(g, cx, 70, 12, 8, 9)
			SpriteKit._sk_r(g, cx, 70, 12, 1, 10)
			for x: int in range(cx, cx + 12, 2):
				SpriteKit._sk_r(g, x, 72, 1, 6, 8)
			SpriteKit._sk_ring(g, float(cx + 6), 69.0, 5.0, 5.0, 1.0, 9)
			SpriteKit._sk_p(g, cx + 3, 70, 13)  # something red under a cloth
			SpriteKit._sk_p(g, cx + 4, 69, 14)
		"twin":
			var t: Image = SpriteKit._sk_new(SpriteKit.SK_CUST_W, SpriteKit.SK_CUST_H)
			for y: int in range(hy - 13, hy + 30):
				for x: int in range(hx + 5, hx + 22):
					var dx: float = float(x - (hx + 13)) / 9.0
					var dy: float = float(y - (hy + 2)) / 15.0
					var inside: bool = dx * dx + dy * dy <= 1.0 or (y > hy + 8 and absf(dx) < 1.0 + float(y - hy - 8) * 0.03)
					if inside and g.get_pixel(clampi(x, 0, 63), clampi(y, 0, 95)).a < 0.5 and (x + y) % 3 != 0:
						SpriteKit._sk_p(t, x, y, sh2 if y > hy + 6 else 1)
			g.blend_rect(t, Rect2i(0, 0, 64, 96), Vector2i.ZERO)
			SpriteKit._sk_p(g, hx + 11, hy + 1, 15)
			SpriteKit._sk_p(g, hx + 15, hy + 1, 15)


# ---------------------------------------------------------------- step 31: moods

static func mood_for(look: Dictionary) -> String:
	var m: String = str(look.get("mood", "calm"))
	return m if m != "" else "calm"


## Expression marks on the figure's face: the hood is dark, so mood shows in the eyes and in a few pale marks.
## calm: heavy half-lids, nervous: eyes ringed wide with a sweat bead and trembling brows, greedy: coin-gold glints
## and a thin crescent of teeth below. Any other mood (angry, sad) falls back to calm. Frame 2 is the blink.
static func mood_face(g: Image, hx: int, hy: int, mood: String, frame: int, cs: Array[Vector2i]) -> void:
	if mood == "calm" or not (mood == "nervous" or mood == "greedy"):
		return
	var rnd: int = 1 if frame == 1 else 0
	if mood == "nervous":
		for c: Vector2i in cs:
			var cx: int = hx + c.x
			var cy: int = hy + c.y
			if frame != 2:
				SpriteKit._sk_p(g, cx - 2, cy - 1, 14)
				SpriteKit._sk_p(g, cx + 2, cy - 1, 14)
				SpriteKit._sk_p(g, cx - 1, cy - 2, 15)
				SpriteKit._sk_p(g, cx + 1, cy - 2, 15)
				SpriteKit._sk_p(g, cx, cy + 2 + rnd, 14)
			SpriteKit._sk_p(g, cx - 2, cy - 4 + (1 if c.x < 0 else 0), 4)  # brows tilted up in the middle
			SpriteKit._sk_p(g, cx - 1, cy - 4, 4)
			SpriteKit._sk_p(g, cx, cy - 4 - (1 if c.x > 0 else 0), 4)
		SpriteKit._sk_p(g, hx + 9, hy + 3 + rnd * 2, 15)  # sweat bead on the cheek
		SpriteKit._sk_p(g, hx + 9, hy + 4 + rnd * 2, 14)
		SpriteKit._sk_p(g, hx - 9, hy - 3, 14)
	else:
		for c: Vector2i in cs:
			var cx: int = hx + c.x
			var cy: int = hy + c.y
			if frame != 2:
				SpriteKit._sk_p(g, cx, cy, 11)
				SpriteKit._sk_p(g, cx - 1, cy - 1, 15)
			SpriteKit._sk_r(g, cx - 2, cy - 2, 5, 1, 12)  # lowered, scheming brows
		for dx: int in range(-4, 5):  # a crescent grin
			var gy: int = hy + 8 - (absi(dx) >> 1) + rnd
			SpriteKit._sk_p(g, hx + dx, gy, 15 if dx % 2 == 0 else 14)
		SpriteKit._sk_p(g, hx + 5, hy + 7, 4)
		SpriteKit._sk_p(g, hx - 5, hy + 7, 4)


## The four idle frames of a customer in a mood ("calm", "nervous", "greedy"; anything else is calm).
static func mood_frames(look: Dictionary, mood: String) -> Array[ImageTexture]:
	var l: Dictionary = look.duplicate()
	l["mood"] = mood
	return SpriteKit.customer_frames(l)


static func mood_texture(look: Dictionary, mood: String) -> ImageTexture:
	var l: Dictionary = look.duplicate()
	l["mood"] = mood
	return SpriteKit.customer_texture(l)


# ---------------------------------------------------------------- step 36: customer walk cycle

## A 4-frame walk cycle made from a standing figure: the hem sways in a travelling wave (the cloak drags along the floor),
## the head leans into each step, and the whole figure bobs up one pixel on the two footfalls. Same size as `base`,
## same palette. Play at about 8 fps; frames 0 and 2 are the passing poses, 1 and 3 the footfalls.
static func walk_frames(base: Image) -> Array[ImageTexture]:
	var out: Array[ImageTexture] = []
	for i: int in range(4):
		out.append(ImageTexture.create_from_image(walk_frame_image(base, i)))
	return out


static func walk_frame_image(base: Image, i: int) -> Image:
	var w: int = base.get_width()
	var h: int = base.get_height()
	var g: Image = SpriteKit._sk_new(w, h)
	var phase: float = float(i) * TAU / 4.0
	var lean: Array[int] = [0, 1, 0, -1]
	var bob: int = 1 if i % 2 == 1 else 0
	for y: int in range(h):
		var f: float = float(y) / float(h)
		var dx: int = roundi(sin(phase + float(y) * 0.11) * 2.2 * f * f) + int(lean[i] * roundf(1.0 - f))
		var dy: int = y - bob
		if dy < 0:
			continue
		for x: int in range(w):
			var c: Color = base.get_pixel(x, y)
			if c.a > 0.01:
				var nx: int = x + dx
				if nx >= 0 and nx < w:
					g.set_pixel(nx, dy, c)
	return g


# ---------------------------------------------------------------- polish: the regular's rim light

## A mask of a figure's lit edge for the rim light: bone-white pixels on the first body pixels just inside the black
## outline on the top and left sides (and a dithered second ring), nothing elsewhere. The room draws it unshaded over
## the figure and tints it with the rim colour (amber for a regular, silver in a full moon).
static func rim_mask(img: Image) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var out: Image = SpriteKit._sk_new(w, h)
	# "outside" = transparent or the black outline ring; the rim goes on body pixels whose left or upper neighbour is outside
	var outside: PackedByteArray = PackedByteArray()
	outside.resize(w * h)
	for y: int in range(h):
		for x: int in range(w):
			var i: int = SpriteKit._sk_idx(img, x, y)
			var out_here: bool = i < 0
			if i == 0:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if SpriteKit._sk_idx(img, x + d.x, y + d.y) < 0:
						out_here = true
			outside[y * w + x] = 1 if out_here else 0
	for y: int in range(h):
		for x: int in range(w):
			if outside[y * w + x] == 1:
				continue
			var l1: bool = x == 0 or outside[y * w + x - 1] == 1
			var u1: bool = y == 0 or outside[(y - 1) * w + x] == 1
			var l2: bool = x < 2 or outside[y * w + x - 2] == 1
			var u2: bool = y < 2 or outside[(y - 2) * w + x] == 1
			if l1 or u1:
				SpriteKit._sk_p(out, x, y, 15)
			elif (l2 or u2) and (x + y) % 2 == 0:
				SpriteKit._sk_p(out, x, y, 14)
	return out


# ---------------------------------------------------------------- polish: icon downscale for the cabinet

## Area downscale of a palette-locked sprite to size x size that keeps the outline: a destination pixel takes the
## dark outline when its source cell holds one next to empty space, else the most common colour (ties go to the
## lighter one), and is empty when most of the cell is empty. Nearest-neighbour resizing dropped whole outline rows.
static func downscale_mode(img: Image, size: int) -> Image:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var out: Image = SpriteKit._sk_new(size, size)
	var rx: float = float(w) / float(size)
	var ry: float = float(h) / float(size)
	for y: int in range(size):
		for x: int in range(size):
			var counts: Dictionary = {}
			var empty: int = 0
			var total: int = 0
			var has_dark: bool = false
			for sy: int in range(floori(float(y) * ry), mini(ceili(float(y + 1) * ry), h)):
				for sx: int in range(floori(float(x) * rx), mini(ceili(float(x + 1) * rx), w)):
					total += 1
					var i: int = SpriteKit._sk_idx(img, sx, sy)
					if i < 0:
						empty += 1
					else:
						counts[i] = int(counts.get(i, 0)) + 1
						if i == 0:
							has_dark = true
			if total == 0 or counts.is_empty() or empty * 2 > total:
				continue
			if has_dark and empty > 0:
				SpriteKit._sk_p(out, x, y, 0)
				continue
			var best: int = -1
			var best_n: int = 0
			for k: Variant in counts:
				var n: int = int(counts[k])
				if n > best_n or (n == best_n and int(k) > best):
					best = int(k)
					best_n = n
			SpriteKit._sk_p(out, x, y, best)
	return out
