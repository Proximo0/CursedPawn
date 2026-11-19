class_name TestMenu
extends TsScreen
## The test menu: a grid of scenes (TestScenes.tiles) so any part of the game can be seen without playing to it.
## Tiles flow into pages by group; arrows move over the grid, Enter or a click opens a tile, Esc leaves. Three options
## apply to the tiles that read them: scares (full or gentle), which regular, and which chapter of theirs.
##   var m := TestMenu.new(); add_child(m); m.picked.connect(func(id, opt): ...); m.closed.connect(...)

signal picked(id: String, opt: Dictionary)
signal closed

const COLS: int = 4
const TILE_W: float = 148.0
const TILE_H: float = 16.0
const GAP_X: float = 6.0
const ROW_H: float = 18.0
const GRID_X: float = 17.0
const GRID_Y: float = 54.0
const MAX_ROWS: int = 14
const OPT_Y: float = 24.0

var scares: int = 1
var regular: int = 0
var chapter: int = 0
var page: int = 0
var last_id: String = ""


## Rows per page: [{rows: [{head: String, ids: Array[String]}]}]. Groups never share a row; a group that does not fit starts a page.
static func tm_pages(tiles: Array[Dictionary]) -> Array[Array]:
	var pages: Array[Array] = []
	var cur: Array[Dictionary] = []
	var used: int = 0
	for g: String in TestScenes.GROUPS:
		var ids: Array[String] = []
		for t: Dictionary in tiles:
			if str(t["group"]) == g:
				ids.append(str(t["id"]))
		if ids.is_empty():
			continue
		var need: int = 1 + int(ceil(float(ids.size()) / float(COLS)))
		if used + need > MAX_ROWS and not cur.is_empty():
			pages.append(cur)
			cur = []
			used = 0
		cur.append({"head": g, "ids": ids})
		used += need
	if not cur.is_empty():
		pages.append(cur)
	return pages


func opts() -> Dictionary:
	return {"scares": scares, "regular": regular, "chapter": chapter}


func tm_page_count() -> int:
	return tm_pages(TestScenes.tiles()).size()


## Every tile id on the current page, in reading order.
func tm_page_ids() -> Array[String]:
	var out: Array[String] = []
	var pages: Array[Array] = tm_pages(TestScenes.tiles())
	if pages.is_empty():
		return out
	for grp: Dictionary in pages[clampi(page, 0, pages.size() - 1)]:
		out.append_array(grp["ids"] as Array[String])
	return out


## The rectangle of a tile on the current page ({} position zero when absent).
func tm_rect(id: String) -> Rect2:
	var y: float = GRID_Y
	var pages: Array[Array] = tm_pages(TestScenes.tiles())
	if pages.is_empty():
		return Rect2()
	for grp: Dictionary in pages[clampi(page, 0, pages.size() - 1)]:
		y += ROW_H
		var ids: Array[String] = grp["ids"] as Array[String]
		for i: int in range(ids.size()):
			if ids[i] == id:
				return Rect2(GRID_X + float(i % COLS) * (TILE_W + GAP_X), y + float(i / COLS) * ROW_H, TILE_W, TILE_H)
		y += ROW_H * ceilf(float(ids.size()) / float(COLS))
	return Rect2()


func ts_ready() -> void:
	focus_id = tm_page_ids()[0]


func ts_menu_ids() -> Array[String]:
	var ids: Array[String] = tm_page_ids()
	ids.append_array(["opt_scares", "opt_regular", "opt_chapter", "page_next", "back"] as Array[String])
	return ids


func ts_activate_menu(id: String) -> void:
	match id:
		"opt_scares":
			scares = 0 if scares == 1 else 1
		"opt_regular":
			regular = (regular + 1) % TestScenes.REGULAR_IDS.size()
			chapter = 0
		"opt_chapter":
			chapter = (chapter + 1) % maxi(Regulars.chapter_count(TestScenes.REGULAR_IDS[regular]), 1)
		"page_next":
			page = (page + 1) % maxi(tm_page_count(), 1)
			focus_id = tm_page_ids()[0]
		"back":
			closed.emit()
		_:
			last_id = id
			picked.emit(id, opts())


func ts_escape_menu() -> void:
	closed.emit()


## Up and down walk the grid by position; left and right by reading order; PgUp and PgDn turn pages.
func ts_key(k: int) -> bool:
	var tiles_here: Array[String] = tm_page_ids()
	if tiles_here.has(focus_id) and (k == KEY_UP or k == KEY_DOWN):
		var from: Rect2 = tm_rect(focus_id)
		var best: String = ""
		var best_d: float = INF
		for id: String in tiles_here:
			var r: Rect2 = tm_rect(id)
			var dy: float = r.position.y - from.position.y
			if (k == KEY_DOWN and dy > 1.0) or (k == KEY_UP and dy < -1.0):
				var d: float = absf(dy) * 4.0 + absf(r.position.x - from.position.x)
				if d < best_d:
					best_d = d
					best = id
		if best != "":
			focus_id = best
		elif k == KEY_DOWN:
			focus_id = "opt_scares"
		if sfx != null:
			sfx.ui("hover")
		return true
	if k == KEY_UP and not tiles_here.has(focus_id):
		focus_id = tiles_here[tiles_here.size() - 1]
		return true
	if k == KEY_LEFT or k == KEY_RIGHT:
		ts_move_focus(-1 if k == KEY_LEFT else 1)
		return true
	if k == KEY_PAGEDOWN or k == KEY_PAGEUP:
		ts_activate_menu("page_next")
		return true
	return super.ts_key(k)


func ts_draw_scene(c: TsCanvas) -> void:
	c.fill(Rect2(Vector2.ZERO, ShopGame.VIEW), 0)
	c.head_c(320.0, 6.0, "TEST MENU", 11, 2)
	c.text_c(320.0, 40.0, "SEE ANY PART OF THE GAME. NOTHING IS SAVED. ESC LEAVES A SCENE.", 4, 1)


func ts_draw_menu(c: TsCanvas) -> void:
	var pages: Array[Array] = tm_pages(TestScenes.tiles())
	if pages.is_empty():
		return
	page = clampi(page, 0, pages.size() - 1)
	var reg_id: String = TestScenes.REGULAR_IDS[regular]
	c.button("opt_scares", Rect2(17.0, OPT_Y, 132.0, TILE_H), "SCARES: " + ("FULL" if scares == 1 else "GENTLE"), true)
	c.button("opt_regular", Rect2(155.0, OPT_Y, 190.0, TILE_H), "REGULAR: " + reg_id.to_upper(), true)
	c.button("opt_chapter", Rect2(351.0, OPT_Y, 110.0, TILE_H), "CHAPTER %d/%d" % [chapter + 1, Regulars.chapter_count(reg_id)], true)
	c.button("page_next", Rect2(467.0, OPT_Y, 90.0, TILE_H), "PAGE %d/%d" % [page + 1, pages.size()], true)
	c.button("back", Rect2(563.0, OPT_Y, 60.0, TILE_H), "BACK", true, true)
	var y: float = GRID_Y
	for grp: Dictionary in pages[page]:
		c.text(Vector2(GRID_X, y + 4.0), str(grp["head"]), 9, 1)
		c.fill(Rect2(GRID_X + float(UiPixelFont.ui_width(str(grp["head"]))) + 6.0, y + 8.0, 560.0 - float(UiPixelFont.ui_width(str(grp["head"]))), 1.0), 8)
		y += ROW_H
		var ids: Array[String] = grp["ids"] as Array[String]
		for i: int in range(ids.size()):
			var r := Rect2(GRID_X + float(i % COLS) * (TILE_W + GAP_X), y + float(i / COLS) * ROW_H, TILE_W, TILE_H)
			c.button(ids[i], r, TestScenes.label_of(ids[i]), true, ids[i] == last_id)
			if is_focused(ids[i]):
				c.cursor_flame(Vector2(r.position.x - 3.0, r.position.y + 5.0))
		y += ROW_H * ceilf(float(ids.size()) / float(COLS))
