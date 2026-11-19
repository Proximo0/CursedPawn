class_name UiRunSetup
extends TsScreen
## The new-run flow after the title: a Haunting picker (only when one is unlocked: arrows, the level's name and its
## stacked rules) and then the Omen draw: three tarot cards deal in face down and flip as you look at one (hover or
## the arrow keys), click or Enter takes it; a fourth button takes no omen. Emits `chosen(opts)` or `cancelled`.
##   var s := UiRunSetup.new(); s.unlocked = 3; s.omen_ids = UiEngage.omen_offer(seed); add_child(s)
##   s.chosen.connect(func(opts: Dictionary) -> void: ...)

signal chosen(opts: Dictionary)
signal cancelled

const STAGE_HAUNT: String = "haunt"
const STAGE_OMEN: String = "omen"
const CARD_SIZE := Vector2(100.0, 196.0)
const CARD_Y: float = 80.0
const CARD_CX: Array[float] = [140.0, 320.0, 500.0]
const DEAL_STEP: float = 0.2
const DEAL_SECS: float = 0.45
const FLIP_RATE: float = 7.0
const PICK_SECS: float = 0.7
const NONE_RECT := Rect2(260.0, 322.0, 120.0, 20.0)
const FACE_UP: float = 0.9  ## a card this far over counts as turned up
const LEVEL_RULE_LINES: int = 11

var unlocked: int = 0  ## the highest Haunting the profile allows
var omen_ids: Array[String] = []
var stage: String = STAGE_OMEN
var level: int = 0
var flips: Array[float] = [0.0, 0.0, 0.0]  ## 0 face down .. 1 face up, per card
var picked: int = -2  ## -2 nothing, -1 no omen, 0..2 a card

var _stage_t: float = 0.0  ## canvas.t when the stage began
var _pick_t: float = 0.0
var _seen: Array[bool] = [false, false, false]
var _flip_snd: Array[bool] = [false, false, false]  ## the omen_flip sound played for this card
var _back: ImageTexture
var _emitted: bool = false


func ts_ready() -> void:
	level = UiEngage.picker_max(unlocked)  # start at the hardest the player has earned
	_set_stage(STAGE_HAUNT if UiEngage.picker_max(unlocked) > 0 else STAGE_OMEN)
	if stage == STAGE_OMEN and omen_ids.is_empty():
		chosen.emit.call_deferred(UiEngage.make_opts(0, "", false))  # no omens to draw: straight to the run


func _set_stage(s: String) -> void:
	stage = s
	_stage_t = canvas.t if canvas != null else 0.0
	focus_id = "h_go" if s == STAGE_HAUNT else "card0"


## The picker's options for the current choices (also what `chosen` emits).
func current_opts(omen_index: int) -> Dictionary:
	var omen: String = omen_ids[omen_index] if omen_index >= 0 and omen_index < omen_ids.size() else ""
	return UiEngage.make_opts(level, omen, false)


func ts_menu_ids() -> Array[String]:
	var ids: Array[String] = []
	if stage == STAGE_HAUNT:
		ids.append_array(["h_dec", "h_inc", "h_go", "back"] as Array[String])
	else:
		for i: int in range(omen_ids.size()):
			ids.append("card%d" % i)
		ids.append("none")
		if UiEngage.picker_max(unlocked) > 0:
			ids.append("back")
	return ids


func ts_activate_menu(id: String) -> void:
	if picked != -2:
		return
	match id:
		"h_dec":
			level = clampi(level - 1, 0, UiEngage.picker_max(unlocked))
		"h_inc":
			level = clampi(level + 1, 0, UiEngage.picker_max(unlocked))
		"h_go":
			_set_stage(STAGE_OMEN)
			if omen_ids.is_empty():
				chosen.emit(current_opts(-1))
		"back":
			if stage == STAGE_OMEN:
				_set_stage(STAGE_HAUNT)
			else:
				cancelled.emit()
		"none":
			picked = -1
			_pick_t = 0.0
		_:
			if id.begins_with("card"):
				picked = int(id.trim_prefix("card"))
				_pick_t = 0.0


func ts_escape_menu() -> void:
	if picked != -2:
		return
	if stage == STAGE_OMEN and UiEngage.picker_max(unlocked) > 0:
		_set_stage(STAGE_HAUNT)
	else:
		cancelled.emit()


func ts_key(k: int) -> bool:
	if k == KEY_LEFT or k == KEY_RIGHT:
		if stage == STAGE_HAUNT:
			ts_activate("h_inc" if k == KEY_RIGHT else "h_dec")
		elif picked == -2:
			ts_move_focus(1 if k == KEY_RIGHT else -1)
		return true
	if (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE) and stage == STAGE_OMEN and picked == -2:
		var i: int = card_index(focus_id)
		if i >= 0 and i < flips.size() and not turned_up(i):
			_seen[i] = true  # the first press turns the card over; only the next one takes it
			return true
	return super.ts_key(k)


## The card index of a widget id ("card1" is 1), -1 for anything else.
static func card_index(id: String) -> int:
	return int(id.trim_prefix("card")) if id.begins_with("card") and id.length() > 4 else -1


## True once card i has turned face up (or is far enough over that the player has read it).
func turned_up(i: int) -> bool:
	return i >= 0 and i < flips.size() and flips[i] >= FACE_UP


func _process(delta: float) -> void:
	super._process(delta)
	if stage != STAGE_OMEN or canvas == null:
		return
	# the focused card turns face up and stays up once seen; the others rest where they are
	for i: int in range(flips.size()):
		var want: float = 1.0 if (focus_id == "card%d" % i or _seen[i]) else 0.0
		if focus_id == "card%d" % i and canvas.t - _stage_t > DEAL_STEP * float(i) + DEAL_SECS:
			_seen[i] = true
		if canvas.t - _stage_t < DEAL_STEP * float(i) + DEAL_SECS:
			want = 0.0
		flips[i] = UiMotion.ui_approach(flips[i], want, delta, FLIP_RATE)
		if flips[i] > 0.5 and not _flip_snd[i]:
			_flip_snd[i] = true
			if sfx != null:
				sfx.ui("omen_flip")
	if picked != -2 and not _emitted:
		_pick_t += delta
		if _pick_t >= PICK_SECS:
			_emitted = true
			chosen.emit(current_opts(picked))


# ---------------------------------------------------------------- drawing

func ts_draw_scene(c: TsCanvas) -> void:
	c.dim(Rect2(Vector2.ZERO, ShopGame.VIEW), 13)
	var flick: bool = UiMotion.ui_hash(int(c.t * 9.0), 2) < 0.5
	UiFrames.ui_glow(c, Vector2(320.0, 200.0), 150 if flick else 156, 8, 9, 0.5)


func ts_draw_menu(c: TsCanvas) -> void:
	if stage == STAGE_HAUNT:
		_draw_haunt(c)
	else:
		_draw_omen(c)


func _draw_haunt(c: TsCanvas) -> void:
	var t: float = c.t - _stage_t
	var u: float = UiMotion.ui_out(t / 0.35)
	var r := Rect2(150.0, 28.0 + floorf((1.0 - u) * 12.0), 340.0, 304.0)
	c.frame(r, "panel")
	var cx: float = r.position.x + r.size.x * 0.5
	c.head_c(cx, r.position.y + 12.0, "CHOOSE YOUR HAUNTING", 11, 1)
	c.fill(Rect2(r.position.x + 14.0, r.position.y + 30.0, r.size.x - 28.0, 1.0), 9)
	var top: int = UiEngage.picker_max(unlocked)
	var y: float = r.position.y + 42.0
	c.button("h_dec", Rect2(r.position.x + 24.0, y, 24.0, 24.0), "<", level > 0)
	c.button("h_inc", Rect2(r.end.x - 48.0, y, 24.0, 24.0), ">", level < top)
	if focus_id == "h_dec" or focus_id == "h_inc":
		c.cursor_flame(Vector2(cx - 5.0, y + 28.0))
	var head: String = "NO HAUNTING" if level == 0 else "HAUNTING %d" % level
	var pulse: bool = level >= 8 and UiMotion.ui_hash(int(c.t * 12.0), level) < 0.1
	UiPixelFont.ui_draw_fx(c, Vector2(cx - float(UiPixelFont.ui_head_width(head, 2)) * 0.5, y), head, c.c(13 if pulse else (11 if level < 6 else 13)),
		UiPixelFont.HEAD, 2, c.t, 0.0, 0.4 if level >= 6 else 0.0, c.c(0))
	c.text_c(cx, y + 30.0, UiEngage.haunting_name(level), 15, 1)
	y += 50.0
	c.fill(Rect2(r.position.x + 14.0, y, r.size.x - 28.0, 1.0), 8)
	y += 6.0
	if level == 0:
		c.text_c(cx, y + 20.0, "THE SHOP AS IT WAS. NO EXTRA RULES.", 14)
	var rows: Array[Dictionary] = UiEngage.rule_rows(level)
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		var k: float = UiMotion.ui_out((t - 0.12 * float(i) - 0.15) / 0.25)
		if k <= 0.0:
			continue
		var newest: bool = i == rows.size() - 1
		var lines: PackedStringArray = UiPixelFont.ui_wrap(str(row["text"]), int(r.size.x) - 66)
		var xoff: float = floorf((1.0 - k) * 8.0)
		c.text(Vector2(r.position.x + 20.0 + xoff, y), "%d" % int(row["level"]), 13 if newest else 12)
		for j: int in range(mini(lines.size(), 2)):
			c.text(Vector2(r.position.x + 36.0 + xoff, y + float(j * UiPixelFont.LINE_H)), lines[j], 15 if newest else 14, 1, k > 0.6)
		y += float(UiPixelFont.LINE_H * mini(lines.size(), 2)) + 3.0
	if level >= top and top < UiEngage.MAX_HAUNTING:
		c.text_c(cx, r.end.y - 62.0, "WIN AT HAUNTING %d TO UNLOCK THE NEXT" % top if top > 0 else "WIN A RUN TO UNLOCK HAUNTINGS", 4)
	c.button("h_go", Rect2(cx - 70.0, r.end.y - 50.0, 140.0, 22.0), "DRAW AN OMEN", true, true)
	c.button("back", Rect2(cx - 40.0, r.end.y - 24.0, 80.0, 16.0), "BACK", true)
	if focus_id == "h_go":
		c.cursor_flame(Vector2(cx - 86.0, r.end.y - 44.0))
	elif focus_id == "back":
		c.cursor_flame(Vector2(cx - 56.0, r.end.y - 21.0))


func _back_tex() -> ImageTexture:
	if _back == null:
		_back = SpriteKit.card_texture("", false)
	return _back


func card_rect(i: int) -> Rect2:
	return Rect2(Vector2(CARD_CX[i] - CARD_SIZE.x * 0.5, CARD_Y), CARD_SIZE)


## Where card i is as it deals in: 0..1 progress (ease with a little overshoot), staggered per card.
func deal_progress(i: int, t: float) -> float:
	return UiMotion.ui_back((t - DEAL_STEP * float(i)) / DEAL_SECS)


func _draw_omen(c: TsCanvas) -> void:
	var t: float = c.t - _stage_t
	var cx: float = 320.0
	var hu: float = UiMotion.ui_out(t / 0.5)
	if hu > 0.0:
		c.head_c(cx, 24.0, "DRAW AN OMEN", 11 if hu > 0.7 else 9, 2)
		c.text_c(cx, 56.0, "ONE CARD. ITS BARGAIN HOLDS FOR THE WHOLE RUN.", 14 if hu > 0.9 else 4)
		if level > 0:
			c.text_c(cx, 68.0, "HAUNTING %d: %s" % [level, UiEngage.haunting_name(level)], 13)
	for i: int in range(omen_ids.size()):
		_draw_card(c, i, t)
	c.button("none", NONE_RECT, "NO OMEN", picked == -2, false)
	if focus_id == "none":
		c.cursor_flame(Vector2(NONE_RECT.position.x - 14.0, NONE_RECT.position.y + 6.0))
	if UiEngage.picker_max(unlocked) > 0:
		c.button("back", Rect2(20.0, 322.0, 70.0, 16.0), "BACK", picked == -2)
	if t > 1.4:
		c.text_c(cx, 300.0, "LOOK AT EACH. LEFT RIGHT ENTER, OR CLICK A CARD.", 4)


func _draw_card(c: TsCanvas, i: int, t: float) -> void:
	var p: float = deal_progress(i, t)
	var rect: Rect2 = card_rect(i)
	var id: String = "card%d" % i
	var oid: String = omen_ids[i]
	if t >= DEAL_STEP * float(i) + DEAL_SECS:
		c.add(id, rect, picked == -2)
	if p <= 0.0:
		return
	var o := Vector2(0.0, -(1.0 - p) * 260.0)
	var focused: bool = is_focused(id) and picked == -2
	if focused:
		o.y -= 4.0  # the card you are looking at lifts a little
	var is_pick: bool = picked == i
	var rejected: bool = picked != -2 and picked != i
	if is_pick:
		o.y -= floorf(UiMotion.ui_out(_pick_t / 0.4) * 10.0)
	var pos: Vector2 = rect.position + o
	var f: float = flips[i]
	var wfac: float = maxf(UiOccult.flip_width(f), 0.06) if f > 0.001 and f < 0.999 else 1.0
	var w: float = floorf(CARD_SIZE.x * wfac)
	var dr := Rect2(Vector2(pos.x + floorf((CARD_SIZE.x - w) * 0.5), pos.y), Vector2(w, CARD_SIZE.y))
	# a soft pool of light under the card
	c.fill(Rect2(rect.position.x + 4.0, rect.end.y + 2.0, CARD_SIZE.x - 8.0, 3.0), 0)
	var face: bool = UiOccult.flip_face_up(f)
	if not face:
		c.draw_texture_rect(_back_tex(), dr, false)
	else:
		_draw_face(c, dr, oid, w >= CARD_SIZE.x - 1.0, is_pick)
	if focused or is_pick:
		var col: int = 11 if (is_pick or fmod(c.t, 1.0) < 0.7) else 10
		c.fill(Rect2(dr.position.x - 2.0, dr.position.y - 2.0, dr.size.x + 4.0, 1.0), col)
		c.fill(Rect2(dr.position.x - 2.0, dr.end.y + 1.0, dr.size.x + 4.0, 1.0), col)
	if rejected:
		c.dim(dr.grow(2.0), clampi(int(UiMotion.ui_out(_pick_t / 0.4) * 12.0), 0, 12))


func _draw_face(c: TsCanvas, r: Rect2, oid: String, full: bool, is_pick: bool) -> void:
	c.frame(r, "note")
	if not full:
		return
	var cx: float = r.position.x + r.size.x * 0.5
	c.fill(Rect2(r.position.x + 4.0, r.position.y + 4.0, r.size.x - 8.0, 1.0), 12)
	var lines: PackedStringArray = UiPixelFont.ui_wrap(UiEngage.omen_name(oid), int(r.size.x) - 12)
	var y: float = r.position.y + 9.0
	for j: int in range(mini(lines.size(), 2)):
		c.text_c(cx, y, lines[j], 12 if not is_pick else 13, 1, false)
		y += float(UiPixelFont.LINE_H)
	y = r.position.y + 31.0
	c.fill(Rect2(r.position.x + 12.0, y, r.size.x - 24.0, 1.0), 10)
	# the art slot: a small inset window with the omen's picture
	var slot := Rect2(cx - 26.0, y + 5.0, 52.0, 44.0)
	c.fill(slot, 1)
	c.fill(Rect2(slot.position.x, slot.position.y, slot.size.x, 1.0), 8)
	c.fill(Rect2(slot.position.x, slot.end.y - 1.0, slot.size.x, 1.0), 9)
	c.draw_texture(UiEngage.omen_icon(oid), slot.position + Vector2(2.0, 2.0))
	y = slot.end.y + 7.0
	var split: Dictionary = UiEngage.omen_split(oid)
	y = _draw_clause(c, r, y, "+", str(split["up"]), 7, 5, 4)
	y += 4.0
	_draw_clause(c, r, y, "-", str(split["down"]), 13, 12, 4)


## One coloured clause with its +/- mark; returns the y below it.
func _draw_clause(c: TsCanvas, r: Rect2, y: float, mark: String, text: String, col: int, mark_col: int, max_lines: int) -> float:
	if text == "":
		return y
	var lines: PackedStringArray = UiPixelFont.ui_wrap(text, int(r.size.x) - 28)
	c.text(Vector2(r.position.x + 7.0, y), mark, col, 1, false)
	for j: int in range(mini(lines.size(), max_lines)):
		var ln: String = lines[j]
		if j == max_lines - 1 and lines.size() > max_lines:
			ln = ln.substr(0, maxi(ln.length() - 2, 1)) + ".."
		c.text(Vector2(r.position.x + 16.0, y + float(j * UiPixelFont.LINE_H)), ln, col if j == 0 else mark_col + 2, 1, false)
	return y + float(mini(lines.size(), max_lines) * UiPixelFont.LINE_H)
