class_name ShopGame
extends Control
## The player-facing pixel-art shop screen (docs/ui_brief.md). The 2D room draws behind; UiHud draws every panel,
## button and word at the room's native 640x360 grid into its own SubViewport that is scaled exactly like the room.
## All input is mapped back to that grid. Every command goes through RunRecording.drive (see act).
## Keys: 1-4 tools, Left/Right offer (or pick an item), Enter offer/sell, B buy, P pass/decline, T tarot, R replay,
## F1 tuning, F2 debug overlay, F3 reliquary, F5 save recording, F11 room dither.

const VIEW := Vector2(640.0, 360.0)
const WHOLE_SCALE_MIN: float = 0.8  ## use a whole-number scale when it keeps at least this share of the fitted size
const RECORDING_PATH: String = "user://last_run.json"
const CARD_SECS: float = 2.0
const PENDULUM_KEY: int = KEY_Q  ## the Altar tool: is it cursed, yes or no
const COLLECTOR_CARD_SECS: float = 4.6
const EVENT_CARD_SECS: float = 4.2
const CARD_SKIP_AFTER: float = 0.35
const REPLAY_BEFORE: int = 4
const REPLAY_STEP_SECS: float = 0.9
const REPLAY_TAIL_SECS: float = 4.5
const HOLD_DELAY: float = 0.4
const HOLD_STEP: float = 0.06
const LOG_KEEP: int = 12
const DEEDS_SCRIPT: String = "res://game/logic/deeds.gd"
const TUTORIAL_SCRIPT: String = "res://game/logic/tutorial.gd"
const DISPLAY_MAX: int = 12
const REPEAT_IDS: PackedStringArray = ["dec", "inc", "stake_dec", "stake_inc", "t_stake_dec", "t_stake_inc"]

var run: RunState = RunState.new()
var rec: RunRecording
var catalog: Catalog
var seed_now: int = 1
var tell_texts: Dictionary = {}  ## tool -> tell text for the current seller
var log_lines: Array[String] = []
var log_age: Array[float] = []  ## seconds since each log line was written (the HUD writes the newest in like ink)
var offer_amount: int = 1
const OFFER_RAISE: float = 0.25  # the counter box opens this far above the buyer's offer
const OFFER_CAP_MULT: int = 3
const COUNTER_KEY: int = KEY_C
var stake_amount: int = 1
var stake_open: bool = false
var selected_uid: int = -1  ## buyer: the shelf item picked (click again to sell)
var cards: Array[Dictionary] = []  ## title cards waiting to show: {title, sub, tone, age}
var ending_id: String = ""  ## how a won run ended (UiEndings.IDS)
var patience_start: int = 3  ## the seller's patience when they walked in (the candle's full height)
var mood: String = "calm"
var mood_known: bool = false  ## true after the first counter-offer shows it
var item_tells: Dictionary = {}  ## held item uid -> {tool: tell text} found before it was bought
var gift_text: String = ""
var gift_status: String = ""
var handle: String = ""
var hover_id: String = ""
var down_id: String = ""
var room: ShopRoom2D
var altar: UiAltar
var hud: UiHud
var sfx: SfxPlayer  ## procedural sound (game/audio)
var settings: TsSettings = TsSettings.shared()
var hints: TsHintTracker
var pause: PauseMenu
var title: TitleScreen
var setup: UiRunSetup  ## the haunting picker and omen draw while open
var daily_run: bool = false  ## the run in progress is today's Daily Seance
var daily_no: int = 0
var ecto_earned: int = 0  ## ectoplasm the finished run earned (shown at the run end)
var carried_cash: int = 0  ## cash a lost run carries to the next one
var unlocked_text: String = ""  ## "HAUNTING 3 UNLOCKED" once a won run earned it
var pad_focus: String = ""  ## the widget a controller has focused
var test_active: bool = false  ## a test-menu scene is up: nothing is saved, Esc returns to the menu
var test_slider: bool = false  ## the Dread slider tile
var test_menu: TestMenu
var _test_overlay: TestOverlay
var _test_screen: TsScreen  ## the altar, journal or run setup a tile opened
var _test_token: int = 0
var _test_store: RelicStore  ## the real profile, set aside while the menu is open
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
var _banked: bool = false  ## this run's finds were handed to the profile
var _recorded: bool = false  ## record_result was called for this run
var _daily_done: Dictionary = {}  ## {key, line}: today's daily played in this session (when the profile cannot say)
var _last_invalid: bool = false
var _toasted: PackedStringArray = PackedStringArray()  ## deeds already toasted this run
var _deeds_gd: GDScript


# ---------------------------------------------------------------- pure helpers (unit-tested)

## The scale the 640x360 grid is drawn at in a window of size win: the largest whole number (2x at 1280x720, 3x at
## 1920x1080) when it keeps at least WHOLE_SCALE_MIN of the fitted size, else the plain fit (never below it for tiny windows).
static func ui_scale(win: Vector2) -> float:
	var fit: float = minf(win.x / VIEW.x, win.y / VIEW.y)
	if fit < 1.0:
		return fit
	var whole: float = floorf(fit + 0.0001)
	return whole if whole >= fit * WHOLE_SCALE_MIN else fit


## Where the grid sits in the window: scaled by ui_scale, centred on whole pixels (letterboxed, never cropped).
static func ui_rect(win: Vector2) -> Rect2:
	var s: float = ui_scale(win)
	var sz: Vector2 = VIEW * s
	return Rect2(((win - sz) * 0.5).floor(), sz)


## Puts a TextureRect showing a 640x360 SubViewport where ui_rect says.
static func ui_place(view: TextureRect, win: Vector2) -> void:
	var r: Rect2 = ui_rect(win)
	view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.position = r.position
	view.size = r.size


## Window pixel position -> 640x360 UI grid position, matching ui_rect.
static func ui_to_view(p: Vector2, win: Vector2) -> Vector2:
	var r: Rect2 = ui_rect(win)
	return (p - r.position) / ui_scale(win)


## The command a key press means for this run ({} when it means none). offer = coins in the offer row,
## selected_uid = the shelf item a buyer has picked (-1 none).
static func ui_key_command(key: int, state: RunState, offer: int, picked: int) -> Dictionary:
	var kind: String = str(state.customer.get("kind", ""))
	if kind == RunState.SELLER:
		var tools: Array = state.customer.get("tools", []) as Array
		var slot: int = key - KEY_1
		if slot >= 0 and slot < Catalog.TOOLS.size():
			return {} if tools.has(Catalog.TOOLS[slot]) else {"t": "inspect", "tool": Catalog.TOOLS[slot]}
		if key == PENDULUM_KEY and state.tool_ok("pendulum"):
			return {} if tools.has("pendulum") else {"t": "inspect", "tool": "pendulum"}
		match key:
			KEY_ENTER, KEY_KP_ENTER:
				return {"t": "offer", "amount": offer}
			KEY_B:
				return {"t": "buy"}
			KEY_P:
				return {"t": "pass"}
	elif kind == RunState.BUYER:
		var offering: bool = not (state.customer.get("offer", {}) as Dictionary).is_empty()
		if offering and key == COUNTER_KEY:
			return {"t": "counter", "amount": offer}
		match key:
			KEY_ENTER, KEY_KP_ENTER:
				if offering:
					return {"t": "accept"}
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

## The owned curio ids the shop cabinet shows: up to DISPLAY_MAX, rarest first (then by id). `owned` is id -> copies,
## `rarity_of` maps id -> "common" | "rare" | "legendary".
static func ui_displayed_curios(owned: Dictionary, rarity_of: Dictionary) -> PackedStringArray:
	var rank: Dictionary = {"legendary": 0, "rare": 1, "common": 2}
	var ids: Array = []
	for id: Variant in owned.keys():
		if int(owned[id]) > 0:
			ids.append(str(id))
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ra: int = int(rank.get(str(rarity_of.get(str(a), "common")), 2))
		var rb: int = int(rank.get(str(rarity_of.get(str(b), "common")), 2))
		return str(a) < str(b) if ra == rb else ra < rb)
	var out := PackedStringArray()
	for id: Variant in ids:
		if out.size() < DISPLAY_MAX:
			out.append(str(id))
	return out


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sfx = SfxPlayer.new()
	add_child(sfx)
	DiagLog.context = func() -> String:
		return "night %d cash %d dread %.1f seed %d" % [run.night, run.cash, run.dread, run.seed_used] if run != null else "no run"
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
	room.bubble_blip.connect(sfx.blip)
	_relics = RelicShopPanel.new()
	add_child(_relics)
	_build_hud()
	catalog = Catalog.load_default()
	hints = TsHintTracker.new(settings)
	settings.apply(sfx, room)
	pause = PauseMenu.new()
	pause.sfx = sfx
	pause.room = room
	pause.profile = _relics.store if _relics != null else null
	add_child(pause)
	pause.quit_to_title.connect(_show_title)
	pause.replay_seed.connect(replay_seed)
	# Scripted runs (tests, captures) skip the title and play straight away.
	new_run(Flags.seed_value(), {})
	if Flags.get_arg("bot") != "":
		add_child(BotPilot.new(self, Flags.get_arg("bot")))  # the play-bot drives this screen (game/debug/bot_pilot.gd)
	if not Flags.is_scripted_run():
		gift_text = _link_in_page()
		_saved = PlayerProfile.load_run(catalog)
		_show_title()


## Shows the title over a dimmed shop. New run starts fresh (with a friend's gift if the page carries one);
## Continue resumes the run saved by an earlier launch.
func _show_title() -> void:
	if room != null:
		room.set_title_mode(true)
	if sfx != null and sfx.music != null:
		sfx.music.play_track("title")
	if title != null:
		title.queue_free()
	title = TitleScreen.new()
	title.sfx = sfx
	title.room = room
	title.has_save = not _saved.is_empty() or (rec != null and not rec.commands.is_empty() and not run.is_over())
	title.parcel = TitleScreen.ts_parcel_in_page()
	title.altar_on = UiAltar.available()
	title.altar_ecto = UiAltar.store_ecto(_relics.store if _relics != null else null)
	title.profile = _relics.store if _relics != null else null
	title.tutorial_on = tutorial_pending()
	title.preview = TitleScreen.ts_preview_of(_saved.get("run") if not _saved.is_empty() else (run if rec != null and not rec.commands.is_empty() and not run.is_over() else null))
	title.test_on = TitleScreen.ts_test_allowed()
	title.notice = _save_notice()
	title.open_test_menu.connect(open_test_menu)
	title.daily_on = UiEngage.daily_available()
	if title.daily_on:
		title.daily_number = UiEngage.daily_number(UiEngage.today())
		title.daily_line = _daily_played_line()
	add_child(title)
	title.start_new.connect(func() -> void:
		title.hide()
		_begin_setup(true))
	title.open_altar.connect(_open_altar)
	title.replay_seed.connect(replay_seed)
	title.skip_tutorial.connect(skip_tutorial)
	title.start_daily.connect(func() -> void:
		title.hide()
		_saved = {}
		start_daily())
	title.continue_run.connect(func() -> void:
		title.hide()
		if not _saved.is_empty():
			_resume(_saved["run"], RunRecording.from_dict(_saved["rec"]))
			_saved = {}
		_refresh())
	title.quit.connect(get_tree().quit)
	title.visibility_changed.connect(func() -> void:
		_hud_view.visible = not title.visible and setup == null
		if room != null:
			room.set_title_mode(title.visible))
	_hud_view.visible = false  # the title owns the screen; the shop shows dimly behind it


## A journal run entry's "replay seed": a new run on the same seed, haunting and omen.
func replay_seed(entry: Dictionary) -> void:
	if title != null:
		title.hide()
	if pause != null:
		pause.close()
	_saved = {}
	gift_text = ""
	new_run(int(entry.get("seed", 1)), {}, UiJournalLog.replay_opts(entry))
	_log("Seed %d again. The shop remembers." % int(entry.get("seed", 1)))


func _journal() -> UiJournalLog:
	return UiJournalLog.shared()


## The Altar over the title: spend ectoplasm on upgrades. Closing returns to the title with the new count.
func _open_altar() -> void:
	if altar != null:
		altar.queue_free()
	title.hide()
	altar = UiAltar.new()
	altar.sfx = sfx
	altar.room = room
	altar.store = _relics.store if _relics != null else null
	add_child(altar)
	altar.bought.connect(func(_id: String) -> void:
		if _relics != null:
			_relics.save_profile())
	altar.closed.connect(func() -> void:
		altar.queue_free()
		altar = null
		title.altar_ecto = UiAltar.store_ecto(_relics.store if _relics != null else null)
		title.show())


func _build_hud() -> void:
	_hud_vp = SubViewport.new()
	_hud_vp.size = Vector2i(VIEW)
	_hud_vp.transparent_bg = true
	_hud_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_hud_vp.gui_disable_input = true
	add_child(_hud_vp)
	hud = UiHud.new()
	hud.game = self
	hud.table.sfx = sfx
	hud.found.sfx = sfx
	hud.inspect.sfx = sfx
	hud.toasts.sfx = sfx
	_hud_vp.add_child(hud)
	var layer := CanvasLayer.new()
	layer.layer = -5  # above the room (-10), below the debug panels
	add_child(layer)
	_hud_view = TextureRect.new()
	_hud_view.texture = _hud_vp.get_texture()
	_hud_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hud_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hud_view.stretch_mode = TextureRect.STRETCH_SCALE
	_hud_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_place(_hud_view, get_viewport().get_visible_rect().size)
	layer.add_child(_hud_view)


func _link_in_page() -> String:
	if not OS.has_feature("web"):
		return ""
	var hash_text: String = str(JavaScriptBridge.eval("window.location.hash", true))
	return PassLink.code_from_text(hash_text) if hash_text.begins_with(PassLink.FRAGMENT_KEY) else ""


func _gift_from_text(text: String) -> Dictionary:
	var code: String = PassLink.code_from_text(text)
	return {} if code == "" else PassLink.decode(code, catalog, Tuning.shared())


## F12: re-reads game/data/*.json and restarts the run on the same seed, so a content edit shows without a relaunch.
## Tuning presets reload from the tuning panel (F1). Problems in the new data are logged and the old data is kept.
func reload_data() -> PackedStringArray:
	var fresh: Catalog = Catalog.load_default()
	var problems: PackedStringArray = fresh.problems()
	if not problems.is_empty():
		_log("Data NOT reloaded: %s" % "; ".join(problems))
		_refresh()
		return problems
	catalog = fresh
	new_run(seed_now)
	_log("Data reloaded: %d objects, %d curses, %d customer types. New run, seed %d." % [catalog.objects.size(),
		catalog.curses.size(), catalog.customers.size(), seed_now])
	_refresh()
	return problems


func new_run(seed_in: int, gift: Dictionary = {}, opts: Dictionary = {}) -> void:
	if catalog == null:
		catalog = Catalog.load_default()
	seed_now = seed_in
	_replay_run = null
	run = RunState.new()
	if _relics != null and _relics.store != null:
		run.spells_known = _relics.store.grimoire.duplicate()  # pages found in earlier runs carry into this one
	if _overlay != null:
		_overlay.run = run
	var all_opts: Dictionary = opts.duplicate()
	all_opts.merge(altar_run_opts(), false)  # the Altar's upgrades and carried cash ride along on every new run
	rec = UiEngage.begin(run, seed_in, catalog, Tuning.shared(), gift, all_opts)
	daily_run = bool(opts.get("daily", false))
	unlocked_text = ""
	ecto_earned = 0
	carried_cash = 0
	_recorded = false
	if room != null:
		room.setup(run)
		_show_displayed()
	_toasted = PackedStringArray()
	log_lines.clear()
	log_age.clear()
	cards.clear()
	tell_texts.clear()
	ending_id = ""
	item_tells.clear()
	if hud != null:
		hud.inspect.close()
	_rewarded = false
	_banked = false
	stake_open = false
	selected_uid = -1
	if hud != null:
		hud.spell_bar.pending_item_spell = ""
		hud.table.reset_stage()
		hud.found.popups.clear()
		hud.requests.clear()
		hud.toasts.clear()
		hud.tutorial.clear()
	_on_events(run.last_events)
	_refresh()


## Hands the owned curios to the room's display cabinet (the art worker's set_displayed), when the room has one.
func _show_displayed() -> void:
	if room == null or not room.has_method("set_displayed") or _relics == null or _relics.store == null:
		return
	var col: CurioCollection = _relics.store.collection
	if col == null:
		return
	var rarity_of: Dictionary = {}
	for id: Variant in col.owned.keys():
		rarity_of[str(id)] = str(col.curio(str(id)).get("rarity", "common"))
	room.call("set_displayed", ui_displayed_curios(col.owned, rarity_of))


## True for a first-time player: the guided first night is built (logic) and the profile has not finished or skipped it.
func tutorial_pending() -> bool:
	if Flags.is_scripted_run() or not ResourceLoader.exists(TUTORIAL_SCRIPT) or _relics == null or _relics.store == null:
		return false
	return "tutorial_done" in _relics.store and not bool(_relics.store.get("tutorial_done"))


## Skip tutorial on the title: marks it done and saves.
func skip_tutorial() -> void:
	if _relics == null or _relics.store == null or not "tutorial_done" in _relics.store:
		return
	_relics.store.set("tutorial_done", true)
	_relics.save_profile()


## The seed the scripted first night uses (Tutorial.SEED when the logic names one).
func _tutorial_seed(fallback: int) -> int:
	var sc: GDScript = load(TUTORIAL_SCRIPT) as GDScript
	return int(sc.get_script_constant_map().get("SEED", fallback)) if sc != null else fallback


## The options the profile's Altar adds to a new run (none in scripted runs, which never read player data).
func altar_run_opts() -> Dictionary:
	if Flags.is_scripted_run() or _relics == null or _relics.store == null:
		return {}
	return PlayerProfile.altar_opts(_relics.store)


func _resume(saved_run: RunState, saved_rec: RunRecording) -> void:
	_replay_run = null
	run = saved_run
	rec = saved_rec
	seed_now = run.seed_used
	_overlay.run = run
	room.setup(run)
	log_lines.clear()
	log_age.clear()
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
		if not test_active:
			PlayerProfile.save_run(run, rec.to_dict())
	_refresh()


func push_card(title: String, sub: String, tone: int, extra: Dictionary = {}) -> void:
	var c: Dictionary = {"title": title, "sub": sub, "tone": tone, "age": 0.0}
	c.merge(extra, true)
	cards.append(c)


## The ledger line for the engagement and Collector events that carry no animation text of their own ("" for none).
static func ui_event_line(e: Dictionary) -> String:
	match str(e.get("e", "")):
		"request_new":
			var line: String = str(e.get("line", ""))
			return line if line != "" else "%s wants %s." % [str(e.get("who", "Someone")), str(e.get("want_text", "something"))]
		"request_due":
			return "%s is here about their order." % str(e.get("who", "Someone"))
		"request_done":
			return "Request filled. They paid %d." % int(e.get("pay", 0))
		"request_failed":
			return "A request slipped away unfilled."
		"run_opts", "tutorial_step", "regular_pending":
			return ""
		"night_event":
			return "Tonight: %s." % str(e.get("name", "something odd"))
		"curse_copied":
			return "The curse crept from the %s into the %s." % [str(e.get("from", "old piece")).to_lower(), str(e.get("name", "new piece")).to_lower()]
		"curse_shift":
			return "The %s changed. It is a %s now." % [str(e.get("name", "piece")).to_lower(), str(e.get("to", "thing")).to_lower()]
		"whispered_away":
			return "A lullaby drifted out. Someone turned back at the door."
		"debt_taken":
			return "%s took %d coins from the till." % [str(e.get("who", "Someone")), int(e.get("amount", 0))]
		"buyer_offer":
			return "They offer %d for the %s." % [int(e.get("offer", 0)), str(e.get("name", "piece")).to_lower()]
		"regular":
			return "%s walks in. Chapter %d." % [str(e.get("name", "A regular")), maxi(int(e.get("chapter", 1)), 1)]
		"regular_done":
			var rl: String = str(e.get("line", ""))
			return rl if rl != "" else "A regular's story moves on."
		"regular_refused":
			var rr: String = str(e.get("line", ""))
			return rr if rr != "" else "A regular leaves unsatisfied."
		"collector_omen":
			return "A card under the door: %s." % UiEngage.collector_line(str(e.get("text", ""))).capitalize()
		"collector_arrives":
			return str(e.get("line", "The Collector is here."))
		"collector_pleased":
			return "The Collector is pleased. Something is left behind."
		"collector_refused":
			return "The Collector leaves you a parting curse, and takes his toll."
	return "Unknown event %s" % str(e.get("e", "?"))


## Sounds for events the audio lane has no mapping for (reusing its existing names), so nothing the player does or
## suffers is silent. Silent-in-audio events: request_due, regular_done, regular_refused, debt_taken.
const FEEDBACK_SOUNDS: Dictionary = {"request_due": "request_pinned", "regular_done": "deed",
	"regular_refused": "customer_left", "debt_taken": "wrong_note"}


func _feedback_sounds(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		var name: String = str(FEEDBACK_SOUNDS.get(str(e.get("e", "")), ""))
		if name == "":
			continue
		if name == "request_pinned" or name == "deed":
			sfx.ui(name)
		else:
			sfx.play(name)


func _on_events(events: Array[Dictionary]) -> void:
	if room != null:
		room.apply_events(events)
	if sfx != null:
		sfx.on_events(events)
		_feedback_sounds(events)
	_last_invalid = false
	if hud != null:
		hud.feed(events)
	for e: Dictionary in events:
		if (str(e["e"]) == "request_new" or str(e["e"]) == "collector_omen") and sfx != null:
			sfx.ui("request_pinned")
		match str(e["e"]):
			"invalid":
				_last_invalid = true
			"table_open":
				push_card("THE MIDNIGHT TABLE", "STAKE WHAT YOU DARE", 11)
			"customer":
				if not test_active:
					_journal().note_customer(str(e.get("tid", "")))
				tell_texts.clear()
				selected_uid = -1
				stake_open = false
				mood = str(e.get("mood", "calm"))
				mood_known = false
				patience_start = int(run.customer.get("patience", 3))
				if str(e.get("mood_line", "")) != "":
					_log(str(e["mood_line"]))
				if str(e.get("kind", "")) == RunState.SELLER:
					offer_amount = clampi(int(e["ask"]) / 2, 1, maxi(1, run.cash))
			"counter":
				mood = str(e.get("mood", mood))
				mood_known = true
				if UiHaggle.counter_line(e) != "":
					_log(UiHaggle.counter_line(e))
			"buyer_offer":
				mood = str(e.get("mood", mood))
				mood_known = mood_known or bool(e.get("counter", false))
				var quoted: int = int(e.get("offer", 1))
				offer_amount = quoted + maxi(1, int(round(float(quoted) * OFFER_RAISE)))
				if str(e.get("tell", "")) != "":
					_log(str(e["tell"]))
			"bought":
				item_tells[int(e["uid"])] = tell_texts.duplicate()
			"inspected":
				if str(e["tell"]) != "":
					tell_texts[str(e["tool"])] = str(e["tell"])
					_note_curse_known()
			"night_start":
				var relief: float = float(e.get("dread_relief", 0.0))
				push_card("NIGHT %d" % int(e["night"]), "RENT DUE: %d" % int(e["rent"]) + ("   THE CANDLE EASES DREAD BY %.1f" % relief if relief > 0.0 else ""), 11)
			"debt_taken":
				if int(e.get("amount", 0)) > 0:
					push_card("THE TILL IS LIGHTER", "%s TOOK %d" % [UiEngage.ascii_up(str(e.get("who", "SOMEONE"))), int(e["amount"])], 13)
			"night_end":
				push_card("NIGHT %d DONE" % int(e["night"]), "RENT %d PAID. CASH %d" % [int(e["rent"]), int(e["cash"])], 14)
			"wake":
				var broke: String = str(e.get("broke", ""))
				push_card("SOMETHING WOKE", ("THE %s SHATTERED" % broke.to_upper()) if broke != "" else "NOTHING LEFT TO BREAK", 13)
			"night_event":
				var nd: Dictionary = UiNightEvent.data(str(e.get("id", "")))
				push_card(UiEngage.ascii_up(str(e.get("name", nd["name"]))), UiEngage.ascii_up(str(e.get("text", nd["text"]))), 11,
					{"style": "event", "event_id": str(e.get("id", "")), "secs": EVENT_CARD_SECS,
					"rules": UiNightEvent.rule_lines(nd.get("mods", {}) as Dictionary)})
			"collector_arrives":
				push_card("THE COLLECTOR", UiEngage.ascii_up(str(e.get("line", ""))), 14, {"style": "collector", "secs": COLLECTOR_CARD_SECS,
					"sub2": "HE WANTS: " + UiEngage.ascii_up(str(e.get("want_text", "")))})
			"collector_pleased":
				push_card("HE IS PLEASED", "SOMETHING IS LEFT BEHIND", 11)
			"collector_refused":
				push_card("HE IS NOT PLEASED", "A CURSE, AND HIS TOLL", 13)
			"run_won":
				ending_id = UiEndings.ending_of(run, e)
				push_card("YOU SURVIVED", "%d COINS IN HAND" % int(e["cash"]), 7)
				cards.append(UiEndings.card_for(ending_id, int(e["cash"]), e))
			"run_lost":
				push_card("THE SHOP IS LOST", "NIGHT %d. RENT %d. CASH %d" % [int(e["night"]), int(e["rent"]), int(e["cash"])], 13)
		if UiOccult.OCCULT_EVENTS.has(str(e["e"])):
			var line: String = UiOccult.event_text(e)
			if line != "":
				_log(line)
		elif ShopDebug.SD_KNOWN_EVENTS.has(str(e["e"])):
			_log(ShopDebug.sd_event_text(e))
		else:
			var extra_line: String = ui_event_line(e)
			if extra_line != "":
				_log(extra_line)


## A tell that matches the counter object's curse identifies that curse for the bestiary.
func _note_curse_known() -> void:
	if test_active or str(run.customer.get("kind", "")) != RunState.SELLER:
		return
	var curse: String = str((run.customer.get("item", {}) as Dictionary).get("curse", ""))
	var label: String = UiInspect.curse_label(curse, tell_texts, catalog)
	if curse != "" and label != "" and not label.begins_with("CURSED,") and not label.begins_with("CLEAN"):
		if _journal().note_curse(curse):
			_journal().save_player()


func _log(line: String) -> void:
	log_lines.append(line)
	log_age.append(0.0)
	while log_lines.size() > LOG_KEEP:
		log_lines.pop_front()
		log_age.pop_front()


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
	offer_amount = clamp_offer(r, offer_amount)
	if selected_uid >= 0 and not _held(selected_uid):
		selected_uid = -1
	if hud != null:
		hud.table.clamp_stake(r)
	_check_deeds()
	if run.is_over() and not _banked and _relics != null:
		_banked = true
		_relics.bank_finds(run)
	if run.is_over() and not _recorded and _relics != null:
		_recorded = true
		_record_result()
	if run.is_over() and run.won and not _rewarded and _relics != null:
		_rewarded = true
		_relics.reward_run(run)
		_log("A free reliquary appears on the counter.")


## Hands the finished run to the profile (best cash, Haunting unlocks, daily record, ectoplasm) and notes a new Haunting.
## A scripted run saves nothing.
func _record_result() -> void:
	if Flags.is_scripted_run() or test_active:
		ecto_earned = Upgrades.ecto_for(run)  # shown, never saved
		return
	_journal().record_run(run, ending_id, daily_run)
	_journal().save_player()
	var before: int = _profile_int("haunting_unlocked")
	var res: Dictionary = PlayerProfile.record_result(run, _relics.store)
	if res.get("deeds_new") is PackedStringArray or res.get("deeds_new") is Array:
		var fresh := PackedStringArray()
		for id: Variant in res["deeds_new"]:
			if not _toasted.has(str(id)):
				fresh.append(str(id))
		_toast_deeds(fresh)
	ecto_earned = int(res.get("ecto", 0))
	carried_cash = int(res.get("carried", 0))
	var after: int = _profile_int("haunting_unlocked")
	if after > before:
		unlocked_text = "HAUNTING %d UNLOCKED" % after
	if daily_run:
		var nights: int = run.night
		_daily_done = {"key": UiEngage.date_key(UiEngage.today()), "line": "NIGHT %d, %d COINS" % [nights, run.cash]}
	_relics.save_profile()


## Toasts the deeds the logic says the run has earned so far (once each). Quiet when the logic has no Deeds yet.
func _check_deeds() -> void:
	if hud == null or _relics == null or _relics.store == null or _replay_run != null:
		return
	if _deeds_gd == null and ResourceLoader.exists(DEEDS_SCRIPT):
		_deeds_gd = load(DEEDS_SCRIPT) as GDScript
	if _deeds_gd == null or not UiOccult.static_has(_deeds_gd, "check"):
		return
	var ids: Variant = _deeds_gd.call("check", run, _relics.store)
	if ids is PackedStringArray or ids is Array:
		_toast_deeds(PackedStringArray(ids))


func _toast_deeds(ids: PackedStringArray) -> void:
	for id: String in ids:
		if _toasted.has(id):
			continue
		_toasted.append(id)
		hud.toasts.push_deed(id)
		_log("Deed earned: %s." % UiToasts.deed_name(id).capitalize())


func _profile_int(field: String) -> int:
	if _relics != null and _relics.store != null and field in _relics.store:
		return int(_relics.store.get(field))
	return 0


func _daily_played_line() -> String:
	var d: Dictionary = UiEngage.today()
	var line: String = UiEngage.played_line(_relics.store if _relics != null else null, d)
	if line == "" and str(_daily_done.get("key", "")) == UiEngage.date_key(d):
		line = str(_daily_done["line"])
	return line


## New run flow: the Haunting picker (when one is unlocked) and the Omen draw, then the run. Scripted runs, and
## logic without hauntings or omens, start at once with today's behaviour.
## A short title notice when the profile file was damaged and moved to its backup.
func _save_notice() -> String:
	var ll: Dictionary = PlayerProfile.last_load
	return "YOUR SAVE WAS DAMAGED. A COPY IS KEPT AS A BACKUP." if str(ll.get("status", "")) == "reset" else ""


func _begin_setup(from_title: bool) -> void:
	if room != null:
		room.set_title_mode(false)
	var seed_next: int = seed_now + 1
	if tutorial_pending():  # the very first run is the guided night: fixed seed, no picker
		_saved = {}
		_start_chosen(_tutorial_seed(seed_next), {"tutorial": true})
		return
	var unlocked: int = UiEngage.picker_max(_profile_int("haunting_unlocked"))
	var omens: Array[String] = UiEngage.omen_offer(seed_next)
	if Flags.is_scripted_run() or (unlocked == 0 and omens.is_empty()):
		_saved = {}
		_start_chosen(seed_next, {})
		return
	if setup != null:
		setup.queue_free()
	setup = UiRunSetup.new()
	setup.sfx = sfx
	setup.room = room
	setup.unlocked = unlocked
	setup.omen_ids = omens
	add_child(setup)
	_hud_view.visible = false
	setup.chosen.connect(func(opts: Dictionary) -> void:
		setup.queue_free()
		setup = null
		_saved = {}
		_hud_view.visible = true
		_start_chosen(seed_next, opts))
	setup.cancelled.connect(func() -> void:
		setup.queue_free()
		setup = null
		if from_title and title != null:
			title.show()
		else:
			_hud_view.visible = true)


## Starts the run the picker chose, consuming a pasted gift link.
func _start_chosen(seed_in: int, opts: Dictionary) -> void:
	var gift: Dictionary = _gift_from_text(gift_text)
	var tried: bool = gift_text.strip_edges() != ""
	gift_text = ""
	gift_status = ""
	new_run(seed_in, gift, opts)
	if tried and gift.is_empty():
		_log("That link didn't take. The object is still out there somewhere.")
	elif not gift.is_empty():
		_log("A parcel arrives: %s." % gift["name"])


## Today's Daily Seance: the day's seed, haunting 0, the day's first omen, no gift. The date is read here, in the UI.
func start_daily() -> void:
	if not UiEngage.daily_available():
		return
	var d: Dictionary = UiEngage.today()
	var seed_in: int = UiEngage.daily_seed(d)
	daily_no = UiEngage.daily_number(d)
	gift_text = ""
	new_run(seed_in, {}, UiEngage.daily_opts(seed_in, d))
	_log("Daily Seance #%d. Everyone gets this shop today." % daily_no)


## Opens the detail card: the counter object (uid -1), a shelf object, or (uid -2) the buyer's picked item.
func open_inspect(uid: int) -> void:
	if hud == null or is_replaying():
		return
	if uid == -2:
		uid = selected_uid
		if buyer_offering(view_run()):
			uid = int((view_run().customer["offer"] as Dictionary).get("uid", -1))
		if uid < 0:
			return
	if uid == -1:
		if str(view_run().customer.get("kind", "")) != RunState.SELLER:
			return
		hud.inspect.open_counter()
	elif _held(uid):
		hud.inspect.open_held(uid)
	else:
		return
	if sfx != null:
		sfx.ui("click")


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
func shelf_rect_list() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Variant in shelf_rects().values():
		out.append(r as Rect2)
	return out


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
		out[int((inv[i] as Dictionary)["uid"])] = Rect2(c - Vector2(20.0, 20.0), Vector2(40.0, 40.0))
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
	elif id.begins_with("spell:"):
		cast_spell(id.trim_prefix("spell:"))
	elif id.begins_with("look:"):
		open_inspect(int(id.trim_prefix("look:")))
	elif id.begins_with("pick:"):
		pick_held(int(id.trim_prefix("pick:")))
	elif id.begins_with("pair:"):
		act({"t": "pairs_flip", "i": int(id.trim_prefix("pair:"))})
	elif id.begins_with("t_") or id == "pick_cancel":
		_activate_table(id)
	else:
		match id:
			"look":
				open_inspect(-1)
			"offer":
				act({"t": "offer", "amount": offer_amount})
			"buy":
				act({"t": "buy"})
			"pass":
				act({"t": "pass"})
			"dec":
				offer_amount = clamp_offer(r, offer_amount - 1)
			"inc":
				offer_amount = clamp_offer(r, offer_amount + 1)
			"accept":
				act({"t": "accept"})
			"counter_go":
				act({"t": "counter", "amount": offer_amount})
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


## Casts a known spell (keys 5-0 or its bar slot). Banish first asks which held item to send away.
func cast_spell(id: String) -> void:
	var r: RunState = view_run()
	if hud == null or is_replaying() or not UiOccult.spells_enabled(r) or not UiOccult.known_spells(r).has(id):
		return
	if UiOccult.needs_item(id):
		hud.spell_bar.pending_item_spell = "" if hud.spell_bar.pending_item_spell == id else id
		return
	act(UiOccult.cast_command(id))


## A held item was picked: for a pending Banish, or as the item stake at the Midnight Table.
func pick_held(uid: int) -> void:
	if hud == null or not _held(uid):
		return
	if hud.spell_bar.pending_item_spell != "":
		var spell: String = hud.spell_bar.pending_item_spell
		hud.spell_bar.pending_item_spell = ""
		act(UiOccult.cast_command(spell, uid))
	elif UiOccult.in_table(view_run()):
		hud.table.picker_open = false
		act({"t": "table_stake_item", "uid": uid})


func _activate_table(id: String) -> void:
	if hud == null:
		return
	var tb: UiTable = hud.table
	var r: RunState = view_run()
	match id:
		"pick_cancel":
			hud.spell_bar.pending_item_spell = ""
		"t_stake_dec":
			tb.stake = clampi(tb.stake - 1, 1, tb.stake_max(r))
		"t_stake_inc":
			tb.stake = clampi(tb.stake + 1, 1, tb.stake_max(r))
		"t_stake_max":
			tb.stake = tb.stake_max(r)
		"t_dice_high":
			act({"t": "table_dice", "stake": tb.stake, "call": "high"})
		"t_dice_low":
			act({"t": "table_dice", "stake": tb.stake, "call": "low"})
		"t_hand":
			act({"t": "table_hand", "stake": tb.stake})
			tb.hand_active = tb.hand_active or not _last_invalid
		"t_draw":
			act({"t": "hand_draw"})
		"t_stand":
			act({"t": "hand_stand"})
		"t_wheel":
			act({"t": "table_wheel", "stake": tb.stake})
		"t_pairs":
			act({"t": "table_pairs", "stake": tb.stake})
		"t_item":
			tb.picker_open = not tb.picker_open
		"t_lot":
			act({"t": "table_lot"})
		"t_leave":
			act({"t": "table_leave"})


func _activate_end(id: String) -> void:
	match id:
		"copy":
			DisplayServer.clipboard_set(pass_text())
			gift_status = "COPIED. SEND IT TO A FRIEND."
		"copy_daily":
			DisplayServer.clipboard_set(UiEngage.daily_result(run, daily_no))
			gift_status = "RESULT COPIED. PASTE IT ANYWHERE."
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
	if buyer_offering(view_run()):
		open_inspect(uid)  # the offered piece: look closer before answering
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


## True while an ordinary buyer has an offer on the table (accept or counter it).
static func buyer_offering(r: RunState) -> bool:
	return str(r.customer.get("kind", "")) == RunState.BUYER and not (r.customer.get("offer", {}) as Dictionary).is_empty()


## The offer or counter amount kept in range: a seller offer is capped by cash, a buyer counter sits above their offer.
static func clamp_offer(r: RunState, v: int) -> int:
	if buyer_offering(r):
		var cur: int = int((r.customer["offer"] as Dictionary).get("price", 1))
		return clampi(v, cur + 1, maxi(cur + 1, cur * OFFER_CAP_MULT))
	return clampi(v, 1, maxi(1, r.cash))


## Left/Right: adjust the offer or stake, or step the buyer's shelf pick.
func step_value(dir: int) -> void:
	var r: RunState = view_run()
	if stake_open:
		stake_amount = clampi(stake_amount + dir, 1, maxi(1, r.max_wager()))
	elif r.customer.get("kind", "") == RunState.BUYER and not buyer_offering(r):
		var items: Array[Dictionary] = r.sellable()
		if items.is_empty():
			return
		var at: int = -1
		for i: int in range(items.size()):
			if int(items[i]["uid"]) == selected_uid:
				at = i
		selected_uid = int(items[posmod(at + dir, items.size())]["uid"])
	else:
		offer_amount = clamp_offer(r, offer_amount + dir)


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
	_begin_setup(false)


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
	if _hud_view != null:
		ui_place(_hud_view, get_viewport().get_visible_rect().size)
	for i: int in range(log_age.size()):
		log_age[i] += delta
	if hints != null:
		hints.tick(delta)
	if _replay_run != null:
		_replay_tick(delta)
	if not cards.is_empty():
		cards[0]["age"] = float(cards[0]["age"]) + delta
		if float(cards[0]["age"]) >= float(cards[0].get("secs", CARD_SECS)):
			cards.pop_front()
	if down_id != "" and REPEAT_IDS.has(down_id):
		_hold_t -= delta
		if _hold_t <= 0.0:
			_hold_t = HOLD_STEP
			activate(down_id)
	if hud != null:
		hud.queue_redraw()


## True while an occult overlay owns Esc and clicks (a found popup, a pending Banish pick, the table's item picker).
func _occult_modal() -> bool:
	return hud != null and (hud.found.active() or hud.spell_bar.pending_item_spell != "" or hud.table.picker_open)


## Spells the player knows: this run's, plus the profile grimoire when the logic provides one.
func _known_spells() -> PackedStringArray:
	var out: PackedStringArray = UiOccult.known_spells(run)
	if _relics != null and UiOccult.has_prop(_relics.store, "grimoire"):
		for id: Variant in _relics.store.get("grimoire"):
			if not out.has(str(id)):
				out.append(str(id))
	return out


func _view_pos(p: Vector2) -> Vector2:
	return ui_to_view(p, get_viewport().get_visible_rect().size)


func _unhandled_input(event: InputEvent) -> void:
	TsPad.note(event)
	if TsPad.is_pad_event(event) and _pad_input(event):
		get_viewport().set_input_as_handled()
		return
	if pause != null:
		pause.blocked = test_active or (hud != null and hud.inspect.is_open()) or stake_open or not cards.is_empty() or (title != null and title.visible) or _occult_modal()
		pause.known = _known_spells()
	var mb := event as InputEventMouseButton
	if mb != null:
		if test_active and test_slider and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and test_slider_click(_view_pos(mb.position)):
			return
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
	if key != null and key.pressed and not key.echo and TsKeys.canonical(key.keycode) == KEY_M and sfx != null and not end_panel_visible():
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
	if mb.pressed and hud != null and hud.inspect.is_open():
		hud.inspect.close()
		get_viewport().set_input_as_handled()
		return
	if mb.pressed:
		if not cards.is_empty() and float(cards[0]["age"]) > CARD_SKIP_AFTER:
			cards.pop_front()
			get_viewport().set_input_as_handled()
			return
		if hud != null and hud.found.active():
			hud.found.dismiss()
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
	if test_active and not key.echo and k == KEY_ESCAPE and (hud == null or not hud.found.active()):
		exit_test_tile()
		get_viewport().set_input_as_handled()
		return
	if test_active and test_slider and (k == KEY_LEFT or k == KEY_RIGHT):
		test_set_dread(_test_overlay.frac + (0.05 if k == KEY_RIGHT else -0.05))
		get_viewport().set_input_as_handled()
		return
	if k == KEY_F11 and not key.echo:
		if room != null:
			room.dither_enabled = not room.dither_enabled
		get_viewport().set_input_as_handled()
		return
	if k == KEY_F12 and not key.echo:
		reload_data()
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
	if hud != null and hud.found.active():
		if (k == KEY_ENTER or k == KEY_ESCAPE or k == KEY_SPACE) and not key.echo:
			hud.found.dismiss()
		get_viewport().set_input_as_handled()
		return
	if hud != null and hud.inspect.is_open():
		if not key.echo and (k == KEY_ESCAPE or k == KEY_ENTER or TsKeys.canonical(k) == KEY_I or k == KEY_SPACE):
			hud.inspect.close()
		get_viewport().set_input_as_handled()
		return
	var ck: int = TsKeys.canonical(k)  # the key's action, whatever it is bound to
	if ck == KEY_I and not key.echo and cards.is_empty():
		open_inspect(-2 if view_run().customer.get("kind", "") == RunState.BUYER else -1)
		get_viewport().set_input_as_handled()
		return
	if not cards.is_empty() and k == KEY_ENTER:
		cards.pop_front()
		return
	if _replay_run != null:
		return
	if k == KEY_LEFT or k == KEY_RIGHT:
		step_value(1 if k == KEY_RIGHT else -1)
	elif ck == KEY_T and not key.echo:
		toggle_tarot()
	elif ck == KEY_R and not key.echo:
		start_replay()
	elif k == KEY_ESCAPE:
		stake_open = false
		if hud != null:
			hud.spell_bar.pending_item_spell = ""
			hud.table.picker_open = false
	elif UiOccult.spell_for_key(ck, UiOccult.known_spells(run)) != "" and not key.echo:
		cast_spell(UiOccult.spell_for_key(ck, UiOccult.known_spells(run)))
	elif k == KEY_ENTER and stake_open and not key.echo:
		act({"t": "wager", "amount": stake_amount})
	elif not key.echo:
		var cmd: Dictionary = ui_key_command(ck, run, offer_amount, selected_uid)
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


# ---------------------------------------------------------------- the test menu (TestMenu, TestScenes)

## The Dread slider spans 0 to this multiple of the wake threshold.
const TEST_DREAD_SPAN: float = 1.2


## Opens the menu over the title. The real profile is set aside for a throwaway one until the menu is left.
func open_test_menu() -> void:
	if _relics != null and _test_store == null:
		_test_store = _relics.store
		_relics.store = RelicStore.create(CurioCollection.create(SEED_TEST, Tuning.shared()))
		_relics.no_save = true
	if title != null:
		title.hide()
	_hud_view.visible = false
	if test_menu != null:
		test_menu.queue_free()
	test_menu = TestMenu.new()
	test_menu.sfx = sfx
	test_menu.room = room
	add_child(test_menu)
	test_menu.picked.connect(run_test_tile)
	test_menu.closed.connect(leave_test_menu)
	if _test_overlay == null:
		_test_overlay = TestOverlay.new()
		_test_overlay.game = self
		add_child(_test_overlay)
	_test_overlay.visible = false


const SEED_TEST: int = 77


## Back to the title: the real profile returns and a fresh run waits behind it.
func leave_test_menu() -> void:
	if test_menu != null:
		test_menu.queue_free()
		test_menu = null
	if _relics != null and _test_store != null:
		_relics.store = _test_store
		_relics.no_save = false
	_test_store = null
	test_active = false
	if _test_overlay != null:
		_test_overlay.visible = false
	new_run(seed_now)
	if title != null:
		title.show()
	_hud_view.visible = title == null  # scripted runs have no title: the shop is what shows


## Opens one tile of the menu.
func run_test_tile(id: String) -> void:
	if test_menu == null:
		return
	var opt: Dictionary = test_menu.opts()
	opt["regular"] = test_menu.regular
	_close_test_screen()
	test_menu.hide()
	test_active = true
	test_slider = false
	_test_token += 1
	pause.blocked = true
	_hud_view.visible = true
	_test_overlay.label = TestScenes.label_of(id)
	_test_overlay.note = TestScenes.note_of(id)
	_test_overlay.slider = false
	_test_overlay.visible = true
	TestScenes.build(id, self, opt)
	_test_overlay.slider = test_slider
	if test_slider:
		test_set_dread(0.0)


## Esc inside a tile: everything it opened is dropped and the menu comes back.
func exit_test_tile() -> void:
	_test_token += 1
	_close_test_screen()
	test_active = false
	test_slider = false
	_hud_view.visible = false
	_test_overlay.visible = false
	if hud != null:
		hud.found.popups.clear()
		hud.toasts.clear()
		hud.tutorial.clear()
	cards.clear()
	new_run(seed_now)
	if test_menu != null:
		test_menu.show()
		test_menu.focus_id = test_menu.last_id if test_menu.ts_menu_ids().has(test_menu.last_id) else test_menu.ts_menu_ids()[0]
	test_active = false


func _close_test_screen() -> void:
	if _test_screen != null:
		_test_screen.queue_free()
		_test_screen = null
	if setup != null:
		setup.queue_free()
		setup = null
	if altar != null:
		altar.queue_free()
		altar = null


## A clean seeded run for a tile; the profile is the throwaway one.
func test_begin(seed_in: int, opts: Dictionary = {}) -> void:
	new_run(seed_in, {}, opts)
	cards.clear()


## Rebuilds the room and HUD state after a tile edited the run directly.
func test_sync() -> void:
	if room != null:
		room.setup(run)
	_refresh()


## Feeds events as if the run had produced them.
func test_feed(events: Array[Dictionary]) -> void:
	_on_events(events)
	_refresh()


## Calls `fn` after `secs` unless the player has left the tile by then.
func test_later(secs: float, fn: Callable) -> void:
	if not is_inside_tree():
		return
	var token: int = _test_token
	get_tree().create_timer(secs).timeout.connect(func() -> void:
		if token == _test_token and test_active and not run.is_over():
			fn.call())


func test_set_dread(frac: float) -> void:
	var f: float = clampf(frac, 0.0, 1.0)
	run.dread = f * TEST_DREAD_SPAN * run.tuning.wake_threshold
	_test_overlay.frac = f
	_refresh()


## A click on the Dread slider bar sets it. True when the click was on the bar.
func test_slider_click(p: Vector2) -> bool:
	var f: float = TestOverlay.frac_at(p)
	if f < 0.0:
		return false
	test_set_dread(f)
	return true


func test_open_setup() -> void:
	setup = UiRunSetup.new()
	setup.sfx = sfx
	setup.room = room
	setup.unlocked = 10
	setup.omen_ids = UiEngage.omen_offer(seed_now + 1)
	add_child(setup)
	_hud_view.visible = false
	setup.chosen.connect(func(opts: Dictionary) -> void:
		setup.queue_free()
		setup = null
		_hud_view.visible = true
		test_begin(seed_now + 1, opts))
	setup.cancelled.connect(exit_test_tile)


func test_open_altar(ecto: int) -> void:
	_relics.store.ecto = ecto
	altar = UiAltar.new()
	altar.sfx = sfx
	altar.room = room
	altar.store = _relics.store
	add_child(altar)
	_hud_view.visible = false
	altar.closed.connect(exit_test_tile)


func test_open_journal() -> void:
	var st: RelicStore = _relics.store
	var ids := PackedStringArray()
	for d: Dictionary in UiLedger.deed_defs():
		ids.append(str(d["id"]))
	st.deeds = ids
	for d: Dictionary in UiLedger.regular_defs():
		st.regulars[str(d["id"])] = Regulars.chapter_count(str(d["id"]))
	var host := TestJournalHost.new()
	host.sfx = sfx
	host.room = room
	host.profile = st
	add_child(host)
	var lg := UiJournalLog.new()  # a full one: every curse known, every customer met, a few runs
	for cu: Dictionary in catalog.curses:
		lg.note_curse(str(cu["id"]))
	for ct: Dictionary in catalog.customers:
		lg.note_customer(str(ct["id"]))
	for i: int in range(7):
		lg.runs.append({"n": 7 - i, "seed": 100 + i, "omen": "", "omen_name": "", "haunting": i % 4, "nights": 5 if i % 2 == 0 else 3,
			"cash": 40 + i * 31, "won": i % 2 == 0, "ending": UiEndings.IDS[i % 4] if i % 2 == 0 else "", "daily": i == 2})
	lg.counter = 7
	host.ledger.log = lg
	_test_screen = host
	_hud_view.visible = false
	host.closed.connect(exit_test_tile)


# ---------------------------------------------------------------- controller

## A controller event on the shop screen. True when it was used. Stick and d-pad move a focus ring over the widgets,
## A activates, X passes, Y looks closer, the shoulders step the offer; Start (the pause menu) is left to PauseMenu.
func _pad_input(event: InputEvent) -> bool:
	var key: int = TsPad.key_for(event)
	var button: String = TsPad.shop_button(event)
	if key == 0 and button == "":
		return false
	if key == KEY_ESCAPE and (pause == null or not pause.blocked or test_active) and not test_active:
		if hud != null and hud.found.active():
			hud.found.dismiss()
			return true
		if hud != null and hud.inspect.is_open():
			hud.inspect.close()
			return true
		if stake_open or not cards.is_empty():
			stake_open = false
			return true
		return false  # Start or B: the pause menu opens
	if key == KEY_ESCAPE and test_active:
		exit_test_tile()
		return true
	if not cards.is_empty():
		if key == KEY_ENTER and float(cards[0]["age"]) > CARD_SKIP_AFTER:
			cards.pop_front()
		return true
	if hud != null and hud.found.active():
		if key == KEY_ENTER:
			hud.found.dismiss()
		return true
	if hud != null and hud.inspect.is_open():
		if key == KEY_ENTER:
			hud.inspect.close()
		return true
	if end_panel_visible():
		if key == KEY_ENTER:
			if pad_focus != "" and pad_focus != "newrun":
				activate(pad_focus)
			else:
				start_next_run()
		else:
			_pad_move(key)
		return true
	if _replay_run != null or (title != null and title.visible) or setup != null or altar != null or _test_screen != null:
		return false
	match button:
		"pass":
			activate("pass")
			return true
		"look":
			open_inspect(-2 if view_run().customer.get("kind", "") == RunState.BUYER else -1)
			return true
		"prev", "next":
			step_value(1 if button == "next" else -1)
			return true
	if key == KEY_ENTER:
		if pad_focus == "":
			pad_focus = _pad_default()
		if pad_focus != "":
			activate(pad_focus)
		return true
	return _pad_move(key)


func _pad_move(key: int) -> bool:
	var dir: Vector2 = {KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN, KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT}.get(key, Vector2.ZERO)
	if dir == Vector2.ZERO or hud == null:
		return false
	var nxt: String = TsPad.next_widget(hud.widgets, pad_focus, dir)
	if pad_focus == "" or (nxt == "" and not _pad_has(pad_focus)):
		nxt = _pad_default()
	if nxt != "":
		pad_focus = nxt
		if sfx != null:
			sfx.ui("hover")
	return true


func _pad_has(id: String) -> bool:
	for w: Dictionary in hud.widgets:
		if str(w["id"]) == id and bool(w["enabled"]):
			return true
	return false


## Where a controller's focus starts: the main button of the moment, else the first widget.
func _pad_default() -> String:
	if hud == null:
		return ""
	for id: String in ["offer", "sell", "t_dice_high", "t_leave", "newrun"]:
		if _pad_has(id):
			return id
	return TsPad.next_widget(hud.widgets, "", Vector2.RIGHT)
