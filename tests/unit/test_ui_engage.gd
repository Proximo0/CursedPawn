extends TestCase

const UE_HAUNTS: Array = [
	{"level": 2, "name": "Cold Rent", "text": "Rent is 20% higher."},
	{"level": 1, "name": "The Hush", "text": "Fewer tells — the décor listens."},
	{"level": 3, "name": "Short Days", "text": "The day is shorter."},
]
const UE_OMENS: Array = [
	{"id": "moth", "name": "The Moth", "text": "Buyers pay more; one tool is dead."},
	{"id": "bell", "name": "The Bell", "text": "Free spell; sellers lie."},
	{"id": "crow", "name": "The Crow", "text": "Double table; all cursed."},
	{"id": "salt", "name": "The Salt", "text": "Safe; slow."},
]


func ue_setup() -> void:
	UiEngage.force_hauntings = UE_HAUNTS
	UiEngage.force_omens = UE_OMENS


func ue_teardown() -> void:
	UiEngage.force_hauntings = []
	UiEngage.force_omens = []
	UiEngage.force_date = {}


func ue_ev(list: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in list:
		out.append(e as Dictionary)
	return out


func test_ascii_up_folds_accents_and_drops_the_rest() -> void:
	assert_eq(UiEngage.ascii_up("Séance — a’s"), "SEANCE - A'S")
	assert_eq(UiEngage.ascii_up("x\U01F56Fy"), "XY")


func test_rules_stack_in_level_order() -> void:
	ue_setup()
	var rows: Array[Dictionary] = UiEngage.rule_rows(2)
	assert_eq(rows.size(), 2)
	assert_eq(int(rows[0]["level"]), 1)
	assert_eq(str(rows[0]["text"]), "FEWER TELLS - THE DECOR LISTENS.")
	assert_eq(int(rows[1]["level"]), 2)
	assert_eq(UiEngage.rule_rows(0).size(), 0)
	ue_teardown()


func test_picker_max_is_capped_by_unlock_and_data() -> void:
	ue_setup()
	assert_eq(UiEngage.picker_max(0), 0)
	assert_eq(UiEngage.picker_max(2), 2)
	assert_eq(UiEngage.picker_max(9), 3, "the data only goes to 3")
	assert_eq(UiEngage.haunting_name(0), "A QUIET SHOP")
	assert_eq(UiEngage.haunting_name(2), "COLD RENT")
	ue_teardown()


func test_opts_empty_keeps_todays_start_path() -> void:
	assert_true(UiEngage.opts_empty({}))
	assert_true(UiEngage.opts_empty(UiEngage.make_opts(0, "", false)))
	assert_false(UiEngage.opts_empty(UiEngage.make_opts(1, "", false)))
	assert_false(UiEngage.opts_empty(UiEngage.make_opts(0, "moth", false)))
	assert_false(UiEngage.opts_empty(UiEngage.make_opts(0, "", true)))


func test_guarded_begin_starts_a_run_whatever_the_logic_accepts() -> void:
	var run := RunState.new()
	var rec: RunRecording = UiEngage.begin(run, 5, Catalog.load_default(), Tuning.new(), {}, UiEngage.make_opts(1, "moth", false))
	assert_true(rec != null)
	assert_eq(run.night, 1)
	assert_eq(UiEngage.begin(RunState.new(), 5, Catalog.load_default(), Tuning.new(), {}, {}).seed_value, 5)


func test_date_key_and_forced_date() -> void:
	ue_setup()
	UiEngage.force_date = {"year": 2026, "month": 12, "day": 3}
	assert_eq(UiEngage.date_key(UiEngage.today()), "2026-12-03")
	ue_teardown()


func test_played_line_reads_the_profile_fields_when_present() -> void:
	var d: Dictionary = {"year": 2026, "month": 12, "day": 18}
	var store := RefCounted.new()
	assert_eq(UiEngage.played_line(store, d), "", "no field: not played")
	assert_eq(UiEngage.played_line(null, d), "")
	var fake := UeFakeStore.new()
	assert_eq(UiEngage.played_line(fake, d), "")
	fake.daily_last = "2026-12-18"
	assert_eq(UiEngage.played_line(fake, d), "ALREADY PLAYED")
	fake.daily_best = {"2026-12-18": {"night": 5, "cash": 412}}
	assert_eq(UiEngage.played_line(fake, d), "NIGHT 5, 412 COINS")


class UeFakeStore extends RefCounted:
	var daily_last: String = ""
	var daily_best: Dictionary = {}


func test_request_wording() -> void:
	assert_eq(UiEngage.want_text({"category": "doll", "cursed": true}), "CURSED DOLL")
	assert_eq(UiEngage.want_text({"category": "", "cursed": true}), "ANY CURSED THING")
	assert_eq(UiEngage.want_text({"category": "", "cursed": false}), "ANYTHING")
	assert_eq(UiEngage.request_line({"who": "Mrs Pell", "want": {"category": "clock", "cursed": false}}), "MRS PELL WANTS CLOCK")
	assert_eq(UiEngage.request_line({"who": "Mr X", "want_text": "a music box"}), "MR X WANTS A MUSIC BOX")


func test_board_pins_stamps_and_tears() -> void:
	var b := UiRequests.new()
	b.feed(ue_ev([{"e": "request_new", "id": "a", "who": "Pell", "want": {}, "due": 2},
		{"e": "request_new", "id": "b", "who": "Voss", "want": {}, "due": 3}]))
	assert_eq(b.notes.size(), 2)
	b.feed(ue_ev([{"e": "request_new", "id": "a", "who": "Pell", "due": 2}]))
	assert_eq(b.notes.size(), 2, "a repeat does not pin twice")
	b.feed(ue_ev([{"e": "request_due", "id": "a"}, {"e": "request_done", "id": "a"}, {"e": "request_failed", "id": "b"}]))
	assert_eq(str(b.notes[0]["fate"]), "done")
	assert_eq(str(b.notes[1]["fate"]), "failed")
	b.tick(0.1)
	assert_eq(b.notes.size(), 2, "still animating")
	b.tick(3.0)
	assert_eq(b.notes.size(), 0, "both gone after their animations")


func test_board_shows_at_most_three_and_sync_pins_open_requests() -> void:
	var b := UiRequests.new()
	var open: Array = []
	for i: int in range(5):
		open.append({"id": "r%d" % i, "who": "W", "want": {}, "due": 2})
	b.sync(open)
	assert_eq(b.visible_notes().size(), 3)
	assert_eq(UiRequests.drop_amount("", 5.0), 0.0)
	assert_true(UiRequests.drop_amount("failed", 2.0) >= 1.0)


func test_board_draws_without_error() -> void:
	var b := UiRequests.new()
	b.feed(ue_ev([{"e": "request_new", "id": "a", "who": "Pell", "want": {"category": "doll", "cursed": true}, "due": 2}]))
	var ci := Control.new()
	b.draw(ci, 0.0)  # outside a draw pass the calls are no-ops on a canvas item, but must not crash
	ci.free()
	assert_true(true)


func test_setup_ids_and_flow() -> void:
	ue_setup()
	var s := UiRunSetup.new()
	s.settings = TsSettings.new()
	s.unlocked = 2
	s.omen_ids = ["moth", "bell", "crow"] as Array[String]
	s.level = 2
	s.stage = UiRunSetup.STAGE_HAUNT
	assert_eq(s.ts_menu_ids(), ["h_dec", "h_inc", "h_go", "back"] as Array[String])
	s.ts_activate_menu("h_dec")
	assert_eq(s.level, 1)
	s.ts_activate_menu("h_dec")
	s.ts_activate_menu("h_dec")
	assert_eq(s.level, 0, "clamped at 0")
	s.ts_activate_menu("h_inc")
	s.ts_activate_menu("h_inc")
	s.ts_activate_menu("h_inc")
	assert_eq(s.level, 2, "clamped at the unlocked level")
	s.stage = UiRunSetup.STAGE_OMEN
	assert_eq(s.ts_menu_ids(), ["card0", "card1", "card2", "none", "back"] as Array[String])
	assert_eq(UiEngage.make_opts(2, "bell", false), s.current_opts(1))
	assert_eq(s.current_opts(-1)["omen"], "")
	s.free()
	ue_teardown()


func test_setup_without_hauntings_has_no_back_and_pick_emits_once() -> void:
	ue_setup()
	var s := UiRunSetup.new()
	s.settings = TsSettings.new()
	s.unlocked = 0
	s.omen_ids = ["moth", "bell", "crow"] as Array[String]
	s.stage = UiRunSetup.STAGE_OMEN
	assert_eq(s.ts_menu_ids(), ["card0", "card1", "card2", "none"] as Array[String])
	s.ts_activate_menu("card2")
	assert_eq(s.picked, 2)
	s.ts_activate_menu("none")
	assert_eq(s.picked, 2, "a pick is final")
	s.free()
	ue_teardown()


func test_deal_is_staggered_and_overshoots_home() -> void:
	var s := UiRunSetup.new()
	assert_near(s.deal_progress(0, 0.0), 0.0)
	assert_true(s.deal_progress(0, 0.2) > s.deal_progress(1, 0.2), "card 0 deals first")
	assert_near(s.deal_progress(2, 5.0), 1.0, 0.001)
	s.free()


func test_title_lists_the_daily_after_new_run() -> void:
	ue_setup()
	var ids: Array[String] = []
	for e: Dictionary in TitleScreen.ts_entries(true, false, true, 12):
		ids.append(str(e["id"]))
	assert_eq(ids, ["continue", "new", "daily", "settings", "quit"] as Array[String])
	assert_eq(str(TitleScreen.ts_entries(false, true, true, 12)[1]["label"]), "DAILY SEANCE #12")
	ue_teardown()
