class_name RelicShopPanel
extends CanvasLayer
## Debug reliquary shop and collection book over CurioCollection and RelicStore. No real payment: the confirm
## step calls RelicStore.fulfill directly. Toggle with F3 or ShopDebug's "Reliquary" button.

const REVEAL_SECS: float = 1.5
const CLOSED_TEXT: String = "The reliquary is closed to you."
const LOCK_TEXT: String = "Curios from sealed reliquaries are bound to you and cannot be traded"
const COLOR_COMMON: Color = Color(0.55, 0.55, 0.58)
const COLOR_RARE: Color = Color(0.6, 0.3, 0.85)
const COLOR_LEGENDARY: Color = Color(0.95, 0.78, 0.2)

var collection: CurioCollection
var store: RelicStore
var payments: int = 0
var reveal_left: float = 0.0
var no_save: bool = false  ## the test menu's throwaway profile: nothing is ever written

var _root: Control
var _age_box: VBoxContainer
var _age_spin: SpinBox
var _terms_check: CheckBox
var _closed_label: Label
var _shop_box: VBoxContainer
var _stats_label: Label
var _featured_label: Label
var _products_box: VBoxContainer
var _open_btn: Button
var _book_box: VBoxContainer
var _log_label: Label
var _confirm_panel: PanelContainer
var _confirm_label: Label
var _confirm_id: String = ""
var _reveal_panel: PanelContainer
var _reveal_label: Label
var _reveal_style: StyleBoxFlat
var _featured_pick: OptionButton
var _log_lines: Array[String] = []


## "Common 70% - Rare 25% - Legendary 5%" from CurioCollection.odds().
static func rsp_odds_text(odds: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r: String in CurioCollection.RARITIES:
		parts.append("%s %d%%" % [r.capitalize(), int(round(float(odds.get(r, 0.0)) * 100.0))])
	return " · ".join(parts)


static func rsp_rarity_color(rarity: String) -> Color:
	match rarity:
		CurioCollection.RARE:
			return COLOR_RARE
		CurioCollection.LEGENDARY:
			return COLOR_LEGENDARY
	return COLOR_COMMON


## The confirm dialog body for a RelicStore.quote() dictionary.
static func rsp_quote_text(q: Dictionary) -> String:
	if q.is_empty():
		return CLOSED_TEXT
	var lines: PackedStringArray = ["DEBUG: no real payment", "", str(q["label"]), "Price: %s" % str(q["price"])]
	if q.has("odds"):
		lines.append("Odds per box: %s" % rsp_odds_text(q["odds"]))
		lines.append("Boxes until a guaranteed legendary: %d" % int(q["pity_left"]))
	if q.has("shows"):
		var c: Dictionary = q["shows"]
		lines.append("Contains: %s (%s)" % [str(c.get("name", "nothing")), str(c.get("rarity", "?"))])
	lines.append(LOCK_TEXT + "." if not bool(q.get("tradeable", false)) else "Tradeable")
	return "\n".join(lines)


## The reveal text for a CurioCollection.open_box() result.
static func rsp_reveal_text(r: Dictionary) -> String:
	if r.is_empty():
		return "No reliquary to open."
	var lines: PackedStringArray = [str(r["rarity"]).to_upper(), str(r["name"]),
		"NEW" if bool(r["new"]) else "Duplicate"]
	if int(r["shards"]) > 0:
		lines.append("+%d shards (bound)" % int(r["shards"]))
	if bool(r.get("pity", false)):
		lines.append("Pity legendary")
	lines.append("Tradeable" if bool(r["tradeable"]) else "Bound to you")
	return "\n".join(lines)


## One collection book cell: "<name>\n<rarity> x<owned> (<tradeable> tradeable)" plus the curio's text when it has one.
static func rsp_cell_text(c: Dictionary, owned: int, trade: int) -> String:
	var body: String = "%s\n%s  x%d (%d tradeable)" % [str(c["name"]), str(c["rarity"]), owned, trade]
	if str(c.get("text", "")) != "":
		body += "\n" + str(c["text"])
	return body


## "Parlor set 3/6 (complete)": a set header with its completion count.
static func rsp_set_header(set_name: String, have: int, total: int) -> String:
	return "%s set  %d / %d%s" % [set_name.capitalize(), have, total, "  (complete)" if total > 0 and have >= total else ""]


static func rsp_set_done_text(set_name: String) -> String:
	return "Set complete: %s shop theme unlocked" % set_name


func _ready() -> void:
	layer = 5
	collection = CurioCollection.create(Flags.seed_value(), Tuning.shared())
	store = RelicStore.create(collection)
	if not Flags.is_scripted_run():
		PlayerProfile.load_into(store)
	_build_ui()
	_root.visible = false
	_refresh()


func _process(delta: float) -> void:
	if reveal_left > 0.0:
		reveal_left -= delta
		if reveal_left <= 0.0:
			_reveal_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_root.visible = not _root.visible
	_refresh()


func is_shown() -> bool:
	return _root.visible


## The gate (once): 18+ and the Terms of Sale accepted, or the shop stays closed.
func submit_age(years: int, accepts_terms: bool) -> void:
	store.set_age(years, accepts_terms)
	_refresh()


## Opens the confirm dialog for a product.
func ask_buy(id: String) -> void:
	var q: Dictionary = store.quote(id)
	if q.is_empty():
		return
	_confirm_id = id
	_confirm_label.text = rsp_quote_text(q)
	_confirm_panel.visible = true


func confirm_buy() -> void:
	_confirm_panel.visible = false
	if _confirm_id == "":
		return
	payments += 1
	var entry: Dictionary = store.fulfill(_confirm_id, "debug-%d" % payments)
	if entry.is_empty():
		_log("Could not deliver %s." % _confirm_id)
	else:
		_log("Bought %s for %s." % [str(store.product(_confirm_id)["label"]), RelicStore.dollars(int(entry["price_cents"]))])
		for c: Variant in entry["delivered"]:
			_log("Received %s (tradeable)." % str((c as Dictionary).get("name", "?")))
	_confirm_id = ""
	_refresh()


func open_one() -> Dictionary:
	var r: Dictionary = collection.open_box()
	if r.is_empty():
		return r
	_reveal_style.bg_color = rsp_rarity_color(str(r["rarity"])).darkened(0.35)
	_reveal_style.border_color = rsp_rarity_color(str(r["rarity"]))
	_reveal_label.text = rsp_reveal_text(r)
	_confirm_panel.visible = false
	_reveal_panel.visible = true
	reveal_left = REVEAL_SECS
	_log("Opened: %s." % str(r["name"]))
	_refresh()
	return r


func craft_one(id: String) -> void:
	var r: Dictionary = collection.craft(id)
	_log("Crafted %s." % str(collection.curio(id)["name"]) if not r.is_empty() else "Not enough shards.")
	_refresh()


## Free reliquary for a won run (called by ShopDebug).
func reward_run(run: RunState) -> int:
	var n: int = collection.reward_run(run)
	if n > 0:
		_log("A free reliquary appears on the counter.")
	_refresh()
	return n


func _log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > 6:
		_log_lines.pop_front()
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)


func _refresh() -> void:
	if not Flags.is_scripted_run() and not no_save:
		PlayerProfile.save(store)
	if _root == null:
		return
	for s: String in collection.claim_completed_sets():
		_log(rsp_set_done_text(s))
	var gated: bool = not store.age_checked
	_age_box.visible = gated
	_closed_label.visible = store.age_checked and not store.age_ok
	_shop_box.visible = store.is_open()
	if not store.is_open():
		return
	var c: CurioCollection = collection
	_stats_label.text = "Boxes %d (free %d / paid %d)   Shards %d (free %d / bound %d)   Pity in %d" % [
		c.boxes(), c.free_boxes, c.paid_boxes, c.shards_free + c.shards_locked, c.shards_free, c.shards_locked,
		c.pity_left()]
	var feat: Dictionary = c.curio(c.featured_id)
	_featured_label.text = "Featured: %s" % (str(feat["name"]) if not feat.is_empty() else "none")
	_open_btn.disabled = c.boxes() <= 0
	_open_btn.text = "Open a reliquary (%d)" % c.boxes()
	_rebuild_products()
	_rebuild_book()
	_log_label.text = "\n".join(_log_lines)


func _rebuild_products() -> void:
	_clear(_products_box)
	for p: Dictionary in store.products:
		var b := Button.new()
		b.text = "%s  %s" % [str(p["label"]), RelicStore.dollars(int(p["price_cents"]))]
		b.tooltip_text = str(p.get("blurb", ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(ask_buy.bind(str(p["id"])))
		_products_box.add_child(b)
		var blurb := _label_of(str(p.get("blurb", "")), 13, 520.0)
		blurb.add_theme_color_override("font_color", Color(0.65, 0.62, 0.7))
		_products_box.add_child(blurb)


func _rebuild_book() -> void:
	_clear(_book_box)
	_book_box.add_child(_label_of("Collection book (%d / %d owned)" % [collection.owned.size(), collection.curios.size()], 18))
	var counts: Dictionary = UiOccult.set_groups(collection.curios, collection.owned)
	var groups: Dictionary = collection.sets()
	var order: Array[String] = []
	for set_name: String in UiOccult.SET_IDS:
		if groups.has(set_name):
			order.append(set_name)
	for set_name: String in groups:
		if not order.has(set_name):
			order.append(set_name)
	for set_name: String in order:
		var cnt: Dictionary = counts.get(set_name, {"have": 0, "total": 0}) as Dictionary
		var head: Label = _label_of(rsp_set_header(set_name, int(cnt["have"]), int(cnt["total"])), 16)
		if collection.claimed_sets.has(set_name):
			head.add_theme_color_override("font_color", COLOR_LEGENDARY)
		_book_box.add_child(head)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		_book_box.add_child(flow)
		for id: Variant in groups[set_name]:
			flow.add_child(_cell(collection.curio(str(id))))


## Writes the profile (never for scripted runs).
func save_profile() -> void:
	if not Flags.is_scripted_run() and not no_save:
		PlayerProfile.save(store)


## Hands the finished run's finds to the profile: pages join the grimoire, curios go to the collection. Guarded so the
## game runs on logic without PlayerProfile.bank_finds, and never for scripted runs (tests, captures).
func bank_finds(run: RunState) -> void:
	if Flags.is_scripted_run():
		return
	if not UiOccult.static_has(PlayerProfile as GDScript, "bank_finds"):
		return
	(PlayerProfile as GDScript).call("bank_finds", run, store)
	_refresh()


func _cell(cur: Dictionary) -> Control:
	var id: String = str(cur["id"])
	var have: int = int(collection.owned.get(id, 0))
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(190, 0)
	pc.tooltip_text = str(cur.get("text", ""))
	var sb := StyleBoxFlat.new()
	var col: Color = rsp_rarity_color(str(cur["rarity"]))
	sb.bg_color = col.darkened(0.6) if have > 0 else Color(0.14, 0.13, 0.16)
	sb.border_color = col if have > 0 else Color(0.25, 0.25, 0.28)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(6.0)
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	pc.add_child(v)
	var l := _label_of(rsp_cell_text(cur, have, int(collection.tradeable.get(id, 0))), 13, 175.0)
	l.add_theme_color_override("font_color", rsp_rarity_color(str(cur["rarity"])).lightened(0.3))
	if have <= 0:
		l.modulate = Color(1, 1, 1, 0.4)
	v.add_child(l)
	var cost: int = collection.craft_cost(id)
	var craft := Button.new()
	craft.text = "Craft (%d)" % cost
	craft.disabled = collection.shards_free + collection.shards_locked < cost
	craft.pressed.connect(craft_one.bind(id))
	v.add_child(craft)
	return pc


func _clear(box: Control) -> void:
	for ch: Node in box.get_children():
		box.remove_child(ch)
		ch.queue_free()


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
	th.default_font_size = 16
	var states: Dictionary = {
		"normal": Color(0.28, 0.26, 0.36), "hover": Color(0.38, 0.35, 0.5),
		"pressed": Color(0.5, 0.3, 0.3), "disabled": Color(0.18, 0.17, 0.2),
	}
	for st: String in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[st]
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		sb.content_margin_top = 4.0
		sb.content_margin_bottom = 4.0
		th.set_stylebox(st, "Button", sb)
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.18, 0.16, 0.22)
	panel.set_content_margin_all(10.0)
	th.set_stylebox("panel", "PanelContainer", panel)
	return th


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.07, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_root.add_child(margin)
	var page := VBoxContainer.new()
	margin.add_child(page)
	var head := HBoxContainer.new()
	page.add_child(head)
	var title := _label_of("The Reliquary  (F3 to close)", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(toggle)
	head.add_child(close)
	_build_age_gate(page)
	_closed_label = _label_of(CLOSED_TEXT, 28)
	_closed_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_closed_label.visible = false
	page.add_child(_closed_label)
	_shop_box = VBoxContainer.new()
	_shop_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_shop_box)
	_build_shop(_shop_box)
	_build_overlays()


func _build_age_gate(page: VBoxContainer) -> void:
	_age_box = VBoxContainer.new()
	page.add_child(_age_box)
	_age_box.add_child(_label_of("Before the reliquary opens: how old are you?", 20))
	var row := HBoxContainer.new()
	_age_box.add_child(row)
	_age_spin = SpinBox.new()
	_age_spin.min_value = 0
	_age_spin.max_value = 120
	_age_spin.value = 0
	row.add_child(_age_spin)
	_terms_check = CheckBox.new()
	_terms_check.text = "I am 18 or older and accept the Terms of Sale, including binding individual arbitration and a class-action waiver"
	row.add_child(_terms_check)
	var go := Button.new()
	go.text = "Continue"
	go.pressed.connect(func() -> void: submit_age(int(_age_spin.value), _terms_check.button_pressed))
	row.add_child(go)


func _build_shop(box: VBoxContainer) -> void:
	_stats_label = _label_of("", 16)
	box.add_child(_stats_label)
	var feat_row := HBoxContainer.new()
	box.add_child(feat_row)
	_featured_label = _label_of("", 16)
	feat_row.add_child(_featured_label)
	if Flags.dev_menu():
		_featured_pick = OptionButton.new()
		_featured_pick.add_item("Set featured: none")
		for c: Dictionary in collection.curios:
			_featured_pick.add_item(str(c["name"]))
		_featured_pick.item_selected.connect(_on_featured_picked)
		feat_row.add_child(_featured_pick)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	box.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	cols.add_child(left)
	left.add_child(_label_of("Products (prices in dollars)", 18))
	_products_box = VBoxContainer.new()
	left.add_child(_products_box)
	_open_btn = Button.new()
	_open_btn.pressed.connect(open_one)
	left.add_child(_open_btn)
	_log_label = _label_of("", 14, 420.0)
	left.add_child(_log_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(scroll)
	_book_box = VBoxContainer.new()
	_book_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_book_box)


func _build_overlays() -> void:
	_confirm_panel = PanelContainer.new()
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.custom_minimum_size = Vector2(520, 0)
	_confirm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var cv := VBoxContainer.new()
	_confirm_panel.add_child(cv)
	_confirm_label = _label_of("", 18, 500.0)
	cv.add_child(_confirm_label)
	var row := HBoxContainer.new()
	cv.add_child(row)
	var ok := Button.new()
	ok.text = "Confirm"
	ok.pressed.connect(confirm_buy)
	row.add_child(ok)
	var no := Button.new()
	no.text = "Cancel"
	no.pressed.connect(func() -> void: _confirm_panel.visible = false)
	row.add_child(no)
	_confirm_panel.visible = false
	_root.add_child(_confirm_panel)
	_reveal_panel = PanelContainer.new()
	_reveal_panel.set_anchors_preset(Control.PRESET_CENTER)
	_reveal_panel.custom_minimum_size = Vector2(360, 200)
	_reveal_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_reveal_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_reveal_style = StyleBoxFlat.new()
	_reveal_style.set_border_width_all(4)
	_reveal_style.set_content_margin_all(16.0)
	_reveal_panel.add_theme_stylebox_override("panel", _reveal_style)
	_reveal_label = _label_of("", 24)
	_reveal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_panel.add_child(_reveal_label)
	_reveal_panel.visible = false
	_root.add_child(_reveal_panel)


func _on_featured_picked(index: int) -> void:
	collection.set_featured("" if index == 0 else str(collection.curios[index - 1]["id"]))
	_refresh()
