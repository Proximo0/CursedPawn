class_name ShopGame
extends Control
## The player-facing pixel-art shop screen (docs/ui_brief.md). The 2D room draws behind; UiHud draws every panel,
## button and word at the room's native 480x270 grid into its own SubViewport that is scaled exactly like the room.
## All input is mapped back to that grid. Every command goes through RunRecording.drive (see act).
## Keys: 1-4 tools, Left/Right offer (or pick an item), Enter offer/sell, B buy, P pass/decline, T tarot, R replay,
## F1 tuning, F2 debug overlay, F3 reliquary, F5 save recording, F11 room dither.

const VIEW := Vector2(480.0, 270.0)
const RECORDING_PATH: String = "user://last_run.json"
const CARD_SECS: float = 2.0
const CARD_SKIP_AFTER: float = 0.35
const REPLAY_BEFORE: int = 4
const REPLAY_STEP_SECS: float = 0.9
const REPLAY_TAIL_SECS: float = 4.5
const HOLD_DELAY: float = 0.4
const HOLD_STEP: float = 0.06
const LOG_KEEP: int = 12
const REPEAT_IDS: PackedStringArray = ["dec", "inc", "stake_dec", "stake_inc"]

var run: RunState = RunState.new()
var rec: RunRecording
var catalog: Catalog
var seed_now: int = 1
var tell_texts: Dictionary = {}  ## tool -> tell text for the current seller
var log_lines: Array[String] = []
var offer_amount: int = 1
var stake_amount: int = 1
var stake_open: bool = false
var selected_uid: int = -1  ## buyer: the shelf item picked (click again to sell)
var cards: Array[Dictionary] = []  ## title cards waiting to show: {title, sub, tone, age}
var gift_text: String = ""
var gift_status: String = ""
var handle: String = ""
var hover_id: String = ""
var down_id: String = ""
var room: ShopRoom2D
var hud: UiHud
var sfx: SfxPlayer  ## procedural sound (game/audio)
var settings: TsSettings = TsSettings.shared()
var hints: TsHintTracker
var pause: PauseMenu
var title: TitleScreen
var _saved: Dictionary = {}  ## a run saved by an earlier launch, offered as Continue on the title

var _overlay: DebugOverlay
var _relics: RelicShopPanel
var _rewarded: bool = false
var _replay_run: RunState  ## non-null while an instant replay plays
var _replay_cmds: Array[Dictionary] = []
var _replay_wait: float = 0.0
var _hold_t: float = 0.0
var _hud_vp: SubViewport
var _hud_view: TextureRect
var _last_serial: int = -1


# ---------------------------------------------------------------- pure helpers (unit-tested)

## Window pixel position -> 480x270 UI grid position, matching the room's keep-aspect (letterboxed, never cropped) scaling.
static func ui_to_view(p: Vector2, win: Vector2) -> Vector2:
	var s: float = minf(win.x / VIEW.x, win.y / VIEW.y)
	var off: Vector2 = (win - VIEW * s) * 0.5
	return (p - off) / s


## The command a key press means for this run ({} when it means none). offer = coins in the offer row,
## selected_uid = the shelf item a buyer has picked (-1 none).
static func ui_key_command(key: int, state: RunState, offer: int, picked: int) -> Dictionary:
	var kind: String = str(state.customer.get("kind", ""))
	if kind == RunState.SELLER:
		var tools: Array = state.customer.get("tools", []) as Array
		var slot: int = key - KEY_1
		if slot >= 0 and slot < Catalog.TOOLS.size():
			return {} if tools.has(Catalog.TOOLS[slot]) else {"t": "inspect", "tool": Catalog.TOOLS[slot]}
		match key:
			KEY_ENTER, KEY_KP_ENTER:
				return {"t": "offer", "amount": offer}
			KEY_B:
				return {"t": "buy"}
			KEY_P:
				return {"t": "pass"}
	elif kind == RunState.BUYER:
		match key:
			KEY_ENTER, KEY_KP_ENTER:
				return {"t": "sell", "uid": picked} if picked >= 0 else {}
			KEY_P:
				return {"t": "pass"}
	return {}


static func ui_estimate_text(est: Dictionary) -> String:
	if est.is_empty():
		return "?"
	return "~%d +-%d%%" % [int(est["mid"]), int(round(float(est["spread"]) * 100.0))]


## "12:30"-style night clock text from the minutes left in the day.
static func ui_clock_text(minutes_left: float) -> String:
	return "%dM LEFT" % int(ceil(minutes_left))


# ---------------------------------------------------------------- setup

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sfx = SfxPlayer.new()
	add_child(sfx)
	sfx.start_ambient()
	add_child(TuningPanel.new())
	_overlay = DebugOverlay.new()
	_overlay.run = run
	add_child(_overlay)
	add_child(FrameStamp.new())
	var toggles := RenderToggles.new()
	toggles.visible = Flags.dev_menu()  # the F-key line is for us; players see it only after pressing F4
	add_child(toggles)
	room = ShopRoom2D.new()
	add_child(room)
	_relics = RelicShopPanel.new()
	add_child(_relics)
	_build_hud()
	catalog = Catalog.load_default()
	hints = TsHintTracker.new(settings)
	settings.apply(sfx, room)
	pause = PauseMenu.new()
	pause.sfx = sfx
	pause.room = room
	add_child(pause)
	pause.quit_to_title.connect(_show_title)
	# Scripted runs (tests, captures) skip the title and play straight away.
	new_run(Flags.seed_value(), {})
	if not Flags.is_scripted_run():
		gift_text = _link_in_page()
		_saved = PlayerProfile.load_run(catalog)
		_show_title()


## Shows the title over a dimmed shop. New run starts fresh (with a friend's gift if the page carries one);
## Continue resumes the run saved by an earlier launch.
func _show_title() -> void:
	if title != null:
		title.queue_free()
	title = TitleScreen.new()
	title.sfx = sfx
	title.room = room
	title.has_save = not _saved.is_empty() or (rec != null and not rec.commands.is_empty() and not run.is_over())
	title.parcel = TitleScreen.ts_parcel_in_page()
	add_child(title)
	title.start_new.connect(func() -> void:
		title.hide()
		_saved = {}
		new_run(seed_now + 1, _gift_from_text(gift_text)))
	title.continue_run.connect(func() -> void:
		title.hide()
		if not _saved.is_empty():
			_resume(_saved["run"], RunRecording.from_dict(_saved["rec"]))
			_saved = {}
		_refresh())
	title.quit.connect(get_tree().quit)
	title.visibility_changed.connect(func() -> void: _hud_view.visible = not title.visible)
	_hud_view.visible = false  # the title owns the screen; the shop shows dimly behind it


func _build_hud() -> void:
	_hud_vp = SubViewport.new()
	_hud_vp.size = Vector2i(VIEW)
	_hud_vp.transparent_bg = true
	_hud_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hud_vp.gui_disable_input = true
	add_child(_hud_vp)
	hud = UiHud.new()
	hud.game = self
	_hud_vp.add_child(hud)
	var layer := CanvasLayer.new()
	layer.layer = -5  # above the room (-10), below the debug panels
	add_child(layer)
	_hud_view = TextureRect.new()
	_hud_view.texture = _hud_vp.get_texture()
	_hud_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hud_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hud_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hud_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_hud_view)


func _link_in_page() -> String:
	if not OS.has_feature("web"):
		return ""
	var hash_text: String = str(JavaScriptBridge.eval("window.location.hash", true))
	return PassLink.code_from_text(hash_text) if hash_text.begins_with(PassLink.FRAGMENT_KEY) else ""


func _gift_from_text(text: String) -> Dictionary:
	var code: String = PassLink.code_from_text(text)
	return {} if code == "" else PassLink.decode(code, catalog, Tuning.shared())


func new_run(seed_in: int, gift: Dictionary = {}) -> void:
	if catalog == null:
		catalog = Catalog.load_default()
	seed_now = seed_in
	_replay_run = null
	run = RunState.new()
	if _overlay != null:
		_overlay.run = run
	rec = RunRecording.begin(run, seed_in, catalog, Tuning.shared(), gift)
	if room != null:
		room.setup(run)
	log_lines.clear()
	cards.clear()
	tell_texts.clear()
	_rewarded = false
	stake_open = false
	selected_uid = -1
	_on_events(run.last_events)
	_refresh()


func _resume(saved_run: RunState, saved_rec: RunRecording) -> void:
	_replay_run = null
	run = saved_run
	rec = saved_rec
	seed_now = run.seed_used
	_overlay.run = run
	room.setup(run)
	log_lines.clear()
	cards.clear()
	_rewarded = false
	_log("Welcome back. Night %d, the shop is as you left it." % run.night)
	_refresh()


# ---------------------------------------------------------------- state

## The run being shown (the replay's while an instant replay plays).
func view_run() -> RunState:
	return _replay_run if _replay_run != null else run


func is_replaying() -> bool:
	return _replay_run != null


func is_end_screen() -> bool:
	return run.is_over() and _replay_run == null


## True once the end panel may show (the final title card has finished).
func end_panel_visible() -> bool:
	return is_end_screen() and cards.is_empty()


## Sends a command through the recorder and shows what happened.
func act(cmd: Dictionary) -> void:
	if run.is_over() or _replay_run != null:
		return
	_on_events(rec.drive(run, cmd))
	if not Flags.is_scripted_run():
		PlayerProfile.save_run(run, rec.to_dict())
	_refresh()


func push_card(title: String, sub: String, tone: int) -> void:
	cards.append({"title": title, "sub": sub, "tone": tone, "age": 0.0})


func _on_events(events: Array[Dictionary]) -> void:
	if room != null:
		room.apply_events(events)
	if sfx != null:
		sfx.on_events(events)
	for e: Dictionary in events:
		match str(e["e"]):
			"customer":
				tell_texts.clear()
				selected_uid = -1
				stake_open = false
				if str(e.get("kind", "")) == RunState.SELLER:
					offer_amount = clampi(int(e["ask"]) / 2, 1, maxi(1, run.cash))
			"inspected":
				if str(e["tell"]) != "":
					tell_texts[str(e["tool"])] = str(e["tell"])
			"night_start":
				push_card("NIGHT %d" % int(e["night"]), "RENT DUE: %d" % int(e["rent"]), 11)
			"night_end":
				push_card("NIGHT %d DONE" % int(e["night"]), "RENT %d PAID. CASH %d" % [int(e["rent"]), int(e["cash"])], 14)
			"wake":
				var broke: String = str(e.get("broke", ""))
				push_card("SOMETHING WOKE", ("THE %s SHATTERED" % broke.to_upper()) if broke != "" else "NOTHING LEFT TO BREAK", 13)
			"run_won":
				push_card("YOU SURVIVED", "%d COINS IN HAND" % int(e["cash"]), 7)
			"run_lost":
				push_card("THE SHOP IS LOST", "NIGHT %d. RENT %d. CASH %d" % [int(e["night"]), int(e["rent"]), int(e["cash"])], 13)
		_log(ShopDebug.sd_event_text(e))


func _log(line: String) -> void:
	log_lines.append(line)
	while log_lines.size() > LOG_KEEP:
		log_lines.pop_front()


func _refresh() -> void:
	var r: RunState = view_run()
	if hints != null:
		hints.refresh(r)
	if room != null:
		room.set_dread(r.dread)
	if sfx != null:
		sfx.set_dread(clampf(r.dread / maxf(r.tuning.wake_threshold, 0.1), 0.0, 1.0))
	var cap: int = r.max_wager()
	stake_amount = clampi(stake_amount, 1, maxi(1, cap))
	if cap < 1 or r.customer.is_empty():
		stake_open = false
	offer_amount = clampi(offer_amount, 1, maxi(1, r.cash))
	if selected_uid >= 0 and not _held(selected_uid):
		selected_uid = -1
	if run.is_over() and run.won and not _rewarded and _relics != null:
		_rewarded = true
		_relics.reward_run(run)
		_log("A free reliquary appears on the counter.")


func _held(uid: int) -> bool:
	for item: Dictionary in view_run().inventory:
		if int(item["uid"]) == uid:
			return true
	return false


## What the end screen offers to pass on: a share link on the web, the bare code elsewhere.
func pass_text() -> String:
	var code: String = PassLink.encode(PassLink.pick_worst(run), run, handle)
	if code == "":
		return ""
	if OS.has_feature("web"):
		var page: String = str(JavaScriptBridge.eval("window.location.origin + window.location.pathname", true))
		return PassLink.url(page, code)
	return code


## Shelf item rectangles by uid (props follow run.inventory order in the room). Empty when the room is absent.
func shelf_rects() -> Dictionary:
	var out: Dictionary = {}
	if room == null:
		return out
	var bodies: Array[RigidBody2D] = room.prop_bodies()
	var inv: Array = view_run().inventory
	if bodies.size() != inv.size():
		return out
	for i: int in range(bodies.size()):
		var c: Vector2 = bodies[i].position
		out[int((inv[i] as Dictionary)["uid"])] = Rect2(c - Vector2(17.0, 17.0), Vector2(34.0, 34.0))
	return out


# ---------------------------------------------------------------- actions

## One UI widget was activated (clicked or its repeat fired).
func activate(id: String) -> void:
	if sfx != null:
		sfx.ui("click")
	if end_panel_visible():
		_activate_end(id)
		return
	var r: RunState = view_run()
	if id.begins_with("tool:"):
		act({"t": "inspect", "tool": id.trim_prefix("tool:")})
	elif id.begins_with("item:"):
		_pick_item(int(id.trim_prefix("item:")))
	else:
		match id:
			"offer":
				act({"t": "offer", "amount": offer_amount})
			"buy":
				act({"t": "buy"})
			"pass":
				act({"t": "pass"})
			"dec":
				offer_amount = clampi(offer_amount - 1, 1, maxi(1, r.cash))
			"inc":
				offer_amount = clampi(offer_amount + 1, 1, maxi(1, r.cash))
			"sell":
				if selected_uid >= 0:
					act({"t": "sell", "uid": selected_uid})
			"tarot":
				toggle_tarot()
			"stake_dec":
				stake_amount = clampi(stake_amount - 1, 1, maxi(1, r.max_wager()))
			"stake_inc":
				stake_amount = clampi(stake_amount + 1, 1, maxi(1, r.max_wager()))
			"draw":
				act({"t": "wager", "amount": stake_amount})
			"stake_close":
				stake_open = false
			"replay":
				start_replay()
			"relics":
				if _relics != null:
					_relics.toggle()


func _activate_end(id: String) -> void:
	match id:
		"copy":
			DisplayServer.clipboard_set(pass_text())
			gift_status = "COPIED. SEND IT TO A FRIEND."
		"paste":
			paste_gift(DisplayServer.clipboard_get())
		"newrun":
			start_next_run()


func toggle_tarot() -> void:
	var r: RunState = view_run()
	if r.max_wager() < 1 or r.customer.is_empty():
		stake_open = false
		return
	stake_open = not stake_open


func _pick_item(uid: int) -> void:
	if view_run().customer.get("kind", "") != RunState.BUYER:
		return
	var ok: bool = false
	for item: Dictionary in view_run().sellable():
		ok = ok or int(item["uid"]) == uid
	if not ok:
		return
	if selected_uid == uid:
		act({"t": "sell", "uid": uid})
	else:
		selected_uid = uid


## Left/Right: adjust the offer or stake, or step the buyer's shelf pick.
func step_value(dir: int) -> void:
	var r: RunState = view_run()
	if stake_open:
		stake_amount = clampi(stake_amount + dir, 1, maxi(1, r.max_wager()))
	elif r.customer.get("kind", "") == RunState.BUYER:
		var items: Array[Dictionary] = r.sellable()
		if items.is_empty():
			return
		var at: int = -1
		for i: int in range(items.size()):
			if int(items[i]["uid"]) == selected_uid:
				at = i
		selected_uid = int(items[posmod(at + dir, items.size())]["uid"])
	else:
		offer_amount = clampi(offer_amount + dir, 1, maxi(1, r.cash))


func paste_gift(text: String) -> void:
	var code: String = PassLink.code_from_text(text)
	if code == "":
		gift_text = ""
		gift_status = "NO LINK ON THE CLIPBOARD."
		return
	var gift: Dictionary = PassLink.decode(code, catalog, Tuning.shared())
	if gift.is_empty():
		gift_text = ""
		gift_status = "THAT LINK DID NOT TAKE."
	else:
		gift_text = text
		gift_status = "READY: %s" % str(gift["name"]).to_upper()


func start_next_run() -> void:
	var gift: Dictionary = _gift_from_text(gift_text)
	var tried: bool = gift_text.strip_edges() != ""
	gift_text = ""
	gift_status = ""
	new_run(seed_now + 1, gift)
	if tried and gift.is_empty():
		_log("That link didn't take. The object is still out there somewhere.")
	elif not gift.is_empty():
		_log("A parcel arrives: %s." % gift["name"])


## Instant replay of the last wake: rebuilds the run a few commands before it and plays them back into the room.
func start_replay() -> void:
	if rec == null or rec.wake_at.is_empty() or _replay_run != null:
		return
	var clip: Vector2i = rec.wake_clip(rec.wake_at.size() - 1, REPLAY_BEFORE)
	_replay_run = rec.replay(catalog, clip.x)
	_replay_cmds.clear()
	for i: int in range(clip.x, clip.y):
		_replay_cmds.append(rec.commands[i])
	_replay_wait = REPLAY_STEP_SECS
	stake_open = false
	selected_uid = -1
	if room != null:
		room.setup(_replay_run)
	_log("REPLAY: the moments before it woke...")
	_refresh()


func _replay_tick(delta: float) -> void:
	_replay_wait -= delta
	if _replay_wait > 0.0:
		return
	if _replay_cmds.is_empty():
		_replay_run = null
		if room != null:
			room.setup(run)
		_log("Back to the shop.")
		_refresh()
		return
	var ev: Array[Dictionary] = _replay_run.apply(_replay_cmds.pop_front())
	if room != null:
		room.set_dread(_replay_run.dread)
		room.apply_events(ev)
	_replay_wait = REPLAY_TAIL_SECS if _replay_cmds.is_empty() else REPLAY_STEP_SECS


# ---------------------------------------------------------------- frame and input

func _process(delta: float) -> void:
	if hints != null:
		hints.tick(delta)
	if _replay_run != null:
		_replay_tick(delta)
	if not cards.is_empty():
		cards[0]["age"] = float(cards[0]["age"]) + delta
		if float(cards[0]["age"]) >= CARD_SECS:
			cards.pop_front()
	if down_id != "" and REPEAT_IDS.has(down_id):
		_hold_t -= delta
		if _hold_t <= 0.0:
			_hold_t = HOLD_STEP
			activate(down_id)
	if hud != null:
		hud.queue_redraw()


func _view_pos(p: Vector2) -> Vector2:
	return ui_to_view(p, get_viewport().get_visible_rect().size)


func _unhandled_input(event: InputEvent) -> void:
	if pause != null:
		pause.blocked = stake_open or not cards.is_empty() or (title != null and title.visible)
	var mb := event as InputEventMouseButton
	if mb != null:
		_on_mouse_button(mb)
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		var was: String = hover_id
		hover_id = hud.widget_at(_view_pos(mm.position)) if hud != null else ""
		if hover_id != "" and hover_id != was and sfx != null:
			sfx.ui("hover")
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_M and sfx != null and not end_panel_visible():
		settings.muted = not settings.muted
		settings.apply(sfx, room)
		settings.save_player()
		get_viewport().set_input_as_handled()
		return
	if key != null and key.pressed:
		_on_key(key)


func _on_mouse_button(mb: InputEventMouseButton) -> void:
	var p: Vector2 = _view_pos(mb.position)
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if mb.pressed and not end_panel_visible():
			step_value(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		if not cards.is_empty() and float(cards[0]["age"]) > CARD_SKIP_AFTER:
			cards.pop_front()
			get_viewport().set_input_as_handled()
			return
		var id: String = hud.widget_at(p) if hud != null else ""
		down_id = id
		if id != "" and REPEAT_IDS.has(id):
			_hold_t = HOLD_DELAY
			activate(id)
		get_viewport().set_input_as_handled()
	else:
		var id: String = hud.widget_at(p) if hud != null else ""
		if id != "" and id == down_id and not REPEAT_IDS.has(id):
			activate(id)
		down_id = ""


func _on_key(key: InputEventKey) -> void:
	var k: int = key.keycode
	if k == KEY_F11 and not key.echo:
		if room != null:
			room.dither_enabled = not room.dither_enabled
		get_viewport().set_input_as_handled()
		return
	if k == KEY_F5 and not key.echo:
		if not Flags.is_scripted_run():
			rec.save_json(RECORDING_PATH)
			_log("Recording saved to %s" % RECORDING_PATH)
		get_viewport().set_input_as_handled()
		return
	if end_panel_visible():
		_end_key(key)
		return
	if not cards.is_empty() and k == KEY_ENTER:
		cards.pop_front()
		return
	if _replay_run != null:
		return
	if k == KEY_LEFT or k == KEY_RIGHT:
		step_value(1 if k == KEY_RIGHT else -1)
	elif k == KEY_T and not key.echo:
		toggle_tarot()
	elif k == KEY_R and not key.echo:
		start_replay()
	elif k == KEY_ESCAPE:
		stake_open = false
	elif k == KEY_ENTER and stake_open and not key.echo:
		act({"t": "wager", "amount": stake_amount})
	elif not key.echo:
		var cmd: Dictionary = ui_key_command(k, run, offer_amount, selected_uid)
		if not cmd.is_empty():
			act(cmd)
			return
		return
	get_viewport().set_input_as_handled()


func _end_key(key: InputEventKey) -> void:
	var k: int = key.keycode
	if key.ctrl_pressed or key.meta_pressed:
		if k == KEY_V:
			paste_gift(DisplayServer.clipboard_get())
		elif k == KEY_C:
			_activate_end("copy")
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		start_next_run()
	elif k == KEY_BACKSPACE:
		handle = handle.substr(0, handle.length() - 1)
	elif key.unicode >= 32 and key.unicode < 127 and handle.length() < PassLink.MAX_HANDLE:
		handle += char(key.unicode)
	get_viewport().set_input_as_handled()
