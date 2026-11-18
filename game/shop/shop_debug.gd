class_name ShopDebug
extends Control
## Playable debug shop: plain Control UI over RunState. Every action goes through RunRecording.drive.
## Keys: F1 tuning panel, F2 debug overlay, F5 save the recording to user://last_run.json, F11 room dither.
## The 3D shop room (ShopRoom) draws behind the UI and follows the run's events.
## The run in progress is saved after every action and resumed on launch; the end screen makes a pass-on link,
## and a gift link (in the web page URL or pasted) starts the next run with a friend's object.

const LOG_LINES: int = 12
const WAKE_SECS: float = 2.0
const RECORDING_PATH: String = "user://last_run.json"
const REPLAY_BEFORE: int = 4  ## commands shown before the wake in an instant replay
const REPLAY_STEP_SECS: float = 0.9  ## pause between replayed commands
const REPLAY_TAIL_SECS: float = 4.5  ## time left for the wake itself before returning to the live shop
const DREAD_BAR_MAX: float = 8.0

var run: RunState = RunState.new()
var rec: RunRecording
var catalog: Catalog
var seed_now: int = 1
var log_lines: Array[String] = []
var tell_texts: Dictionary = {}  ## tool -> tell text for the current seller
var wake_left: float = 0.0

var _overlay: DebugOverlay
var _night_label: Label
var _clock_label: Label
var _cash_label: Label
var _rent_label: Label
var _dread_bar: ProgressBar
var _dread_label: Label
var _inventory_label: Label
var _customer_box: VBoxContainer
var _log_label: Label
var _wake_label: Label
var _end_box: VBoxContainer
var _end_label: Label
var _offer_spin: SpinBox
var _wager_spin: SpinBox
var _wager_btn: Button
var _relics: RelicShopPanel
var _rewarded: bool = false
var _room: ShopRoom
var _replay_btn: Button
var _replay_run: RunState  ## non-null while an instant replay plays
var _replay_cmds: Array[Dictionary] = []
var _replay_wait: float = 0.0
var _pass_edit: LineEdit
var _handle_edit: LineEdit
var _gift_edit: LineEdit


## One event Dictionary as a readable log line.
static func sd_event_text(e: Dictionary) -> String:
	match str(e.get("e", "")):
		"night_start":
			return "Night %d begins. Rent due tonight: %d." % [int(e["night"]), int(e["rent"])]
		"customer":
			var who: String = str(e.get("type", ""))
			var said: String = " \"%s\"" % str(e["line"]) if str(e.get("line", "")) != "" else ""
			if str(e.get("kind", "")) == "seller":
				return "%s arrives with %s, asking %d.%s" % [who if who != "" else "Seller", str(e["name"]), int(e["ask"]), said]
			return "%s arrives, wants %s.%s" % [who if who != "" else "Buyer", str(e.get("category", "?")), said]
		"inspected":
			var tell: String = str(e.get("tell", ""))
			var est: Dictionary = e.get("estimate", {})
			var shown: String = tell if tell != "" else "nothing odd"
			return "%s: %s. Estimate now %s." % [sd_tool_name(str(e["tool"])), shown, sd_estimate_text(est)]
		"counter":
			return "You offered %d. Counter: %d (patience %d)." % [int(e["offer"]), int(e["ask"]), int(e["patience"])]
		"left":
			return "Your offer of %d insulted them. They left." % int(e["offer"])
		"bought":
			return "Bought %s for %d." % [str(e["name"]), int(e["price"])]
		"sold":
			var extra: String = " (it was an imposter, no pay)" if bool(e.get("imposter", false)) else ""
			return "Sold %s for %d.%s" % [str(e["name"]), int(e["price"]), extra]
		"passed":
			return "You passed on the %s." % str(e.get("kind", "customer"))
		"wake":
			var broke: String = str(e.get("broke", ""))
			var what: String = "%s shattered" % broke if broke != "" else "nothing left to break"
			var closed: String = " The door locks, the day is over." if bool(e.get("closed", false)) else ""
			return "SOMETHING WOKE on night %d (dread %.1f): %s.%s" % [int(e["night"]), float(e["dread"]), what, closed]
		"night_end":
			var cc: int = int(e.get("curse_cash", 0))
			var extra: String = "" if cc == 0 else (" Something left %d coins on the counter." % cc if cc > 0
				else " Something ate %d coins from the till." % -cc)
			return "Night %d ends. Rent %d, cash %d.%s" % [int(e["night"]), int(e["rent"]), int(e["cash"]), extra]
		"run_lost":
			return "RUN LOST on night %d: cash %d, rent %d." % [int(e["night"]), int(e["cash"]), int(e["rent"])]
		"run_won":
			return "RUN WON with %d cash." % int(e["cash"])
		"wager":
			return "Tarot: %s. %s Stake %d, payout %d%s." % [str(e["card"]), str(e.get("text", "")), int(e["stake"]),
				int(e["payout"]), " (dread +%.1f)" % float(e["dread"]) if float(e.get("dread", 0.0)) > 0.0 else ""]
		"invalid":
			return "Can't do that: %s." % str(e.get("why", "?"))
	return "Unknown event %s" % str(e.get("e", "?"))


static func sd_tool_name(tool: String) -> String:
	match tool:
		"uv":
			return "UV lamp"
		"scale":
			return "Scale"
		"listen":
			return "Listen"
		"touch":
			return "Touch"
	return tool


## "mid +- spread%" for an estimate dictionary ({} gives "?").
static func sd_estimate_text(est: Dictionary) -> String:
	if est.is_empty():
		return "?"
	return "%d +- %d%%" % [int(est["mid"]), int(round(float(est["spread"]) * 100.0))]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	add_child(TuningPanel.new())
	_overlay = DebugOverlay.new()
	_overlay.run = run
	add_child(_overlay)
	add_child(FrameStamp.new())
	add_child(RenderToggles.new())
	_room = ShopRoom.new()
	add_child(_room)
	_relics = RelicShopPanel.new()
	add_child(_relics)
	catalog = Catalog.load_default()
	if not Flags.is_scripted_run():
		_gift_edit.text = _link_in_page()
		var saved: Dictionary = PlayerProfile.load_run(catalog)
		if not saved.is_empty():
			_resume(saved["run"], RunRecording.from_dict(saved["rec"]))
			return
	new_run(Flags.seed_value(), _gift_from_text(_gift_edit.text))


## A gift code in the page URL (web build): "#gift=..." -> the code, else "".
func _link_in_page() -> String:
	if not OS.has_feature("web"):
		return ""
	var hash_text: String = str(JavaScriptBridge.eval("window.location.hash", true))
	return PassLink.code_from_text(hash_text) if hash_text.begins_with(PassLink.FRAGMENT_KEY) else ""


func _gift_from_text(text: String) -> Dictionary:
	var code: String = PassLink.code_from_text(text)
	return {} if code == "" else PassLink.decode(code, catalog, Tuning.shared())


## Picks up a run saved by a previous launch.
func _resume(saved_run: RunState, saved_rec: RunRecording) -> void:
	_replay_run = null
	run = saved_run
	rec = saved_rec
	seed_now = run.seed_used
	_overlay.run = run
	_room.setup(run)
	log_lines.clear()
	_end_box.visible = false
	_rewarded = false
	_log("Welcome back. Night %d, the shop is as you left it." % run.night)
	_refresh()


func _process(delta: float) -> void:
	if _replay_run != null:
		_replay_tick(delta)
	if wake_left > 0.0:
		wake_left -= delta
		_wake_label.visible = wake_left > 0.0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F11:
		_room.dither_enabled = not _room.dither_enabled
		get_viewport().set_input_as_handled()
		return
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F12:
		reload_data()
		get_viewport().set_input_as_handled()
		return
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F5:
		if not Flags.is_scripted_run():
			rec.save_json(RECORDING_PATH)
			_log("Recording saved to %s" % RECORDING_PATH)
			_refresh()
		get_viewport().set_input_as_handled()


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


func new_run(seed_in: int, gift: Dictionary = {}) -> void:
	seed_now = seed_in
	_replay_run = null
	run = RunState.new()
	_overlay.run = run
	rec = RunRecording.begin(run, seed_in, catalog, Tuning.shared(), gift)
	_room.setup(run)
	log_lines.clear()
	_end_box.visible = false
	_rewarded = false
	_wake_label.visible = false
	wake_left = 0.0
	_on_events(run.last_events)
	_refresh()


## Sends a command through the recorder and shows what happened.
func act(cmd: Dictionary) -> void:
	if run.is_over() or _replay_run != null:
		return
	_on_events(rec.drive(run, cmd))
	if not Flags.is_scripted_run():
		PlayerProfile.save_run(run, rec.to_dict())
	_refresh()


func _on_events(events: Array[Dictionary]) -> void:
	_room.apply_events(events)
	for e: Dictionary in events:
		var en: String = str(e["e"])
		if en == "customer":
			tell_texts.clear()
		elif en == "inspected" and str(e["tell"]) != "":
			tell_texts[str(e["tool"])] = str(e["tell"])
		elif en == "wake":
			wake_left = WAKE_SECS
			_wake_label.text = "SOMETHING WOKE\n%s" % sd_event_text(e)
			_wake_label.visible = true
		_log(sd_event_text(e))


func _log(line: String) -> void:
	log_lines.append(line)
	while log_lines.size() > LOG_LINES:
		log_lines.pop_front()
	_log_label.text = "\n".join(log_lines)


func _refresh() -> void:
	_night_label.text = "Night %d / %d" % [run.night, int(run.tuning.nights)]
	_clock_label.text = "Clock %d min" % int(run.clock)
	_cash_label.text = "Cash %d" % run.cash
	_rent_label.text = "Rent due %d" % run.rent_for(run.night)
	_dread_bar.value = run.dread
	_replay_btn.disabled = rec.wake_at.is_empty() or _replay_run != null
	_room.set_dread(run.dread)
	_dread_label.text = "Dread %.1f / %.1f" % [run.dread, run.tuning.wake_threshold]
	_dread_bar.max_value = maxf(DREAD_BAR_MAX, run.tuning.wake_threshold)
	var lines: PackedStringArray = []
	for item: Dictionary in run.inventory:
		lines.append("%s  est %d  tells %d" % [item["name"], int(item["est"]), int(item["tells"])])
	_inventory_label.text = "\n".join(lines) if not lines.is_empty() else "(empty)"
	_rebuild_customer()
	var cap: int = run.max_wager()
	_wager_spin.max_value = maxi(1, cap)
	_wager_spin.value = clampi(int(_wager_spin.value), 1, maxi(1, cap))
	_wager_btn.disabled = cap < 1 or run.customer.is_empty()
	if run.is_over():
		if run.won and not _rewarded and _relics != null:
			_rewarded = true
			_relics.reward_run(run)
			_log("A free reliquary appears on the counter.")
		_end_box.visible = true
		_end_label.text = "RUN WON, cash %d" % run.cash if run.won else "RUN LOST on night %d" % run.night
		_end_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5) if run.won else Color(1.0, 0.35, 0.35))
		_pass_edit.text = pass_text()


## What the end screen offers to pass on: a share link on the web, the bare code elsewhere.
func pass_text() -> String:
	var code: String = PassLink.encode(PassLink.pick_worst(run), run, _handle_edit.text)
	if code == "":
		return "Nothing left to pass on."
	if OS.has_feature("web"):
		var page: String = str(JavaScriptBridge.eval("window.location.origin + window.location.pathname", true))
		return PassLink.url(page, code)
	return code


func _rebuild_customer() -> void:
	for c: Node in _customer_box.get_children():
		_customer_box.remove_child(c)
		c.queue_free()
	var cust: Dictionary = run.customer
	if cust.is_empty():
		_customer_box.add_child(_label_of("No customer."))
		return
	if str(cust["kind"]) == RunState.SELLER:
		_build_seller(cust)
	else:
		_build_buyer(cust)


func _build_seller(cust: Dictionary) -> void:
	var tools: Array = cust["tools"]
	_customer_box.add_child(_label_of("SELLER: %s" % str(cust["item"]["name"]), 20))
	_customer_box.add_child(_label_of("Ask: %d     Patience: %d" % [int(cust["ask"]), int(cust["patience"])]))
	_customer_box.add_child(_label_of("Estimate: %s" % sd_estimate_text(run.estimate())))
	var found: PackedStringArray = []
	for tool: String in tools:
		if tell_texts.has(tool):
			found.append("%s: %s" % [sd_tool_name(tool), tell_texts[tool]])
	var tells: Label = _label_of("Tells found: %s" % ("\n  ".join(found) if not found.is_empty() else "none yet"), 16, 480.0)
	_customer_box.add_child(tells)
	var tool_row := HBoxContainer.new()
	_customer_box.add_child(tool_row)
	for tool: String in Catalog.TOOLS:
		var b := Button.new()
		b.text = sd_tool_name(tool)
		b.disabled = tools.has(tool)
		b.pressed.connect(act.bind({"t": "inspect", "tool": tool}))
		tool_row.add_child(b)
	var offer_row := HBoxContainer.new()
	_customer_box.add_child(offer_row)
	_offer_spin = SpinBox.new()
	_offer_spin.min_value = 1
	_offer_spin.max_value = maxi(1, run.cash)
	_offer_spin.value = mini(maxi(1, run.cash), int(cust["ask"]) / 2)
	offer_row.add_child(_offer_spin)
	var offer := Button.new()
	offer.text = "Offer"
	offer.pressed.connect(_on_offer)
	offer_row.add_child(offer)
	var buy := Button.new()
	buy.text = "Buy at %d" % int(cust["ask"])
	buy.disabled = int(cust["ask"]) > run.cash
	buy.pressed.connect(act.bind({"t": "buy"}))
	offer_row.add_child(buy)
	var pass_btn := Button.new()
	pass_btn.text = "Pass"
	pass_btn.pressed.connect(act.bind({"t": "pass"}))
	offer_row.add_child(pass_btn)


func _build_buyer(cust: Dictionary) -> void:
	_customer_box.add_child(_label_of("BUYER wants: %s" % str(cust["category"]), 20))
	var items: Array[Dictionary] = run.sellable()
	if items.is_empty():
		_customer_box.add_child(_label_of("You hold nothing they want."))
	for item: Dictionary in items:
		var row := HBoxContainer.new()
		_customer_box.add_child(row)
		row.add_child(_label_of("%s (est %d)" % [item["name"], int(item["est"])]))
		var b := Button.new()
		b.text = "Sell for %d" % run.sale_price(item)
		b.pressed.connect(act.bind({"t": "sell", "uid": int(item["uid"])}))
		row.add_child(b)
	var decline := Button.new()
	decline.text = "Decline"
	decline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	decline.pressed.connect(act.bind({"t": "pass"}))
	_customer_box.add_child(decline)


func _on_wager() -> void:
	act({"t": "wager", "amount": int(_wager_spin.value)})


func _on_reliquary() -> void:
	_relics.toggle()


func _on_offer() -> void:
	act({"t": "offer", "amount": int(_offer_spin.value)})


func _label_of(text: String, size: int = 16, wrap_width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_width, 0)
	return l


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 18
	var states: Dictionary = {
		"normal": Color(0.28, 0.26, 0.36), "hover": Color(0.38, 0.35, 0.5),
		"pressed": Color(0.5, 0.3, 0.3), "disabled": Color(0.18, 0.17, 0.2),
	}
	for st: String in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[st]
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 6.0
		th.set_stylebox(st, "Button", sb)
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.18, 0.16, 0.22, 0.82)  ## the 3D shop room shows through
	panel.set_content_margin_all(10.0)
	th.set_stylebox("panel", "PanelContainer", panel)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.2, 0.25)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.3, 0.3, 0.34)
	th.set_stylebox("fill", "ProgressBar", fill)
	th.set_stylebox("background", "ProgressBar", back)
	return th


func _build_ui() -> void:
	theme = _make_theme()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	margin.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 24)
	left.add_child(bar)
	_night_label = _label_of("", 20)
	_clock_label = _label_of("", 20)
	_cash_label = _label_of("", 20)
	_rent_label = _label_of("", 20)
	for l: Label in [_night_label, _clock_label, _cash_label, _rent_label]:
		bar.add_child(l)
	var dread_row := HBoxContainer.new()
	left.add_child(dread_row)
	_dread_label = _label_of("")
	_dread_label.custom_minimum_size = Vector2(170, 0)
	dread_row.add_child(_dread_label)
	_dread_bar = ProgressBar.new()
	_dread_bar.show_percentage = false
	_dread_bar.min_value = 0.0
	_dread_bar.max_value = DREAD_BAR_MAX
	_dread_bar.custom_minimum_size = Vector2(300, 22)
	_dread_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dread_row.add_child(_dread_bar)
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 12)
	left.add_child(mid)
	var inv_panel := PanelContainer.new()
	inv_panel.custom_minimum_size = Vector2(300, 0)
	inv_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mid.add_child(inv_panel)
	var inv_box := VBoxContainer.new()
	inv_panel.add_child(inv_box)
	inv_box.add_child(_label_of("Inventory"))
	_inventory_label = _label_of("")
	inv_box.add_child(_inventory_label)
	var cust_panel := PanelContainer.new()
	cust_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cust_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mid.add_child(cust_panel)
	_customer_box = VBoxContainer.new()
	cust_panel.add_child(_customer_box)
	var wager_row := HBoxContainer.new()
	left.add_child(wager_row)
	wager_row.add_child(_label_of("Tarot wager stake"))
	_wager_spin = SpinBox.new()
	_wager_spin.min_value = 1
	_wager_spin.max_value = 1
	wager_row.add_child(_wager_spin)
	_wager_btn = Button.new()
	_wager_btn.text = "Draw a card"
	_wager_btn.pressed.connect(_on_wager)
	wager_row.add_child(_wager_btn)
	var relic_btn := Button.new()
	relic_btn.text = "Reliquary"
	relic_btn.pressed.connect(_on_reliquary)
	wager_row.add_child(relic_btn)
	_replay_btn = Button.new()
	_replay_btn.text = "Replay the wake"
	_replay_btn.disabled = true
	_replay_btn.pressed.connect(start_replay)
	wager_row.add_child(_replay_btn)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	cols.add_child(right)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 190)
	right.add_child(spacer)
	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(log_panel)
	var log_box := VBoxContainer.new()
	log_panel.add_child(log_box)
	log_box.add_child(_label_of("Events"))
	_log_label = _label_of("", 15, 360.0)
	log_box.add_child(_log_label)
	_wake_label = _label_of("", 44)
	_wake_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15))
	_wake_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_wake_label.add_theme_constant_override("outline_size", 8)
	_wake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wake_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wake_label.set_anchors_preset(Control.PRESET_CENTER)
	_wake_label.custom_minimum_size = Vector2(700, 200)
	_wake_label.position = Vector2(-350, -100)
	_wake_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wake_label.visible = false
	add_child(_wake_label)
	_end_box = VBoxContainer.new()
	_end_box.set_anchors_preset(Control.PRESET_CENTER)
	_end_box.position = Vector2(-240, -140)
	_end_label = _label_of("", 32)
	_end_box.add_child(_end_label)
	_end_box.add_child(_label_of("Pass your worst object to a friend. Sign it (optional):", 16))
	_handle_edit = LineEdit.new()
	_handle_edit.max_length = PassLink.MAX_HANDLE
	_handle_edit.placeholder_text = "your name"
	_handle_edit.text_changed.connect(func(_t: String) -> void: _pass_edit.text = pass_text())
	_end_box.add_child(_handle_edit)
	var pass_row := HBoxContainer.new()
	_pass_edit = LineEdit.new()
	_pass_edit.editable = false
	_pass_edit.custom_minimum_size = Vector2(420, 0)
	pass_row.add_child(_pass_edit)
	var copy := Button.new()
	copy.text = "Copy"
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(_pass_edit.text))
	pass_row.add_child(copy)
	_end_box.add_child(pass_row)
	_gift_edit = LineEdit.new()
	_gift_edit.placeholder_text = "Paste a friend's link to start with their object"
	_end_box.add_child(_gift_edit)
	var again := Button.new()
	again.text = "New run"
	again.pressed.connect(_on_new_run)
	_end_box.add_child(again)
	_end_box.visible = false
	add_child(_end_box)


## Instant replay of the last wake: rebuilds the run a few commands before it and plays them back into the room.
func start_replay() -> void:
	if rec.wake_at.is_empty() or _replay_run != null:
		return
	var clip: Vector2i = rec.wake_clip(rec.wake_at.size() - 1, REPLAY_BEFORE)
	_replay_run = rec.replay(catalog, clip.x)
	_replay_cmds.clear()
	for i: int in range(clip.x, clip.y):
		_replay_cmds.append(rec.commands[i])
	_replay_wait = REPLAY_STEP_SECS
	_room.setup(_replay_run)
	_log("REPLAY: the moments before it woke...")
	_refresh()


func _replay_tick(delta: float) -> void:
	_replay_wait -= delta
	if _replay_wait > 0.0:
		return
	if _replay_cmds.is_empty():
		_replay_run = null
		_room.setup(run)
		_log("Back to the shop.")
		_refresh()
		return
	var ev: Array[Dictionary] = _replay_run.apply(_replay_cmds.pop_front())
	_room.set_dread(_replay_run.dread)
	_room.apply_events(ev)
	_replay_wait = REPLAY_TAIL_SECS if _replay_cmds.is_empty() else REPLAY_STEP_SECS


func _on_new_run() -> void:
	var gift: Dictionary = _gift_from_text(_gift_edit.text)
	var tried: bool = _gift_edit.text.strip_edges() != ""
	_gift_edit.text = ""
	new_run(seed_now + 1, gift)
	if tried and gift.is_empty():
		_log("That link didn't take. The object is still out there somewhere.")
	elif not gift.is_empty():
		_log("A parcel arrives: %s." % gift["name"])
	_refresh()
