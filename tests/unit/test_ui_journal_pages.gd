extends TestCase
## The journal's extra pages: grimoire, curios, bestiary and runs, their paging, focus and the replay button.


func test_six_tabs_each_with_a_label_and_heading() -> void:
	assert_eq(UiLedger.TABS.size(), 6)
	for t: String in UiLedger.TABS:
		assert_true(UiLedger.TAB_LABELS.has(t) and UiLedger.TAB_HEADS.has(t), t)
		assert_true(UiPixelFont.ui_width(str(UiLedger.TAB_LABELS[t])) <= 70, "label fits " + t)


func test_spell_rows_show_known_and_unknown() -> void:
	var rows: Array[Dictionary] = UiJournalPages.spell_rows(PackedStringArray(["scry"]))
	assert_eq(rows.size(), 6)
	assert_true(bool(rows[0]["known"]))
	assert_false(bool(rows[1]["known"]))


func test_bestiary_hides_what_is_unmet() -> void:
	var cat: Catalog = Catalog.load_default()
	var log := UiJournalLog.new()
	var rows: Array[Dictionary] = UiJournalPages.beast_rows(cat, log)
	assert_eq(rows.size(), cat.curses.size() + cat.customers.size())
	assert_eq(rows[0]["name"], "? ? ? ?")
	log.note_curse(str(cat.curses[0]["id"]))
	log.note_customer(str(cat.customers[0]["id"]))
	rows = UiJournalPages.beast_rows(cat, log)
	assert_true(bool(rows[0]["known"]))
	assert_eq(rows[0]["name"], str(cat.curses[0]["name"]).to_upper())
	assert_true(bool(rows[cat.curses.size()]["known"]))


func test_curio_rows_count_owned() -> void:
	var defs: Array[Dictionary] = UiOccult.curio_defs()
	if defs.is_empty():
		return
	var rows: Array[Dictionary] = UiJournalPages.curio_rows({str(defs[0]["id"]): 1})
	var have: int = 0
	for r: Dictionary in rows:
		have += int(r["have"])
	assert_eq(have, 1)


func test_run_lines_name_the_ending() -> void:
	var win: PackedStringArray = UiJournalPages.run_lines({"n": 3, "seed": 17, "haunting": 2, "omen_name": "The Moth", "nights": 5, "cash": 120, "won": true, "ending": "collector"})
	assert_true(win[0].contains("SEED 17") and win[0].contains("THE MOTH"))
	assert_true(win[1].contains("THE DRAWERS ARE FULL"))
	assert_true(UiJournalPages.run_lines({"won": false})[1].contains("LOST"))


func test_replay_button_hands_back_the_entry() -> void:
	var l := UiLedger.new()
	l.log = UiJournalLog.new()
	l.log.runs.append({"n": 1, "seed": 9, "haunting": 1, "omen": "", "omen_name": "", "nights": 5, "cash": 1, "won": true, "ending": "", "daily": false})
	l.tab = UiLedger.TAB_RUNS
	assert_true(l.focus_ids().has("run_replay:0"))
	assert_true(l.activate("run_replay:0"))
	assert_eq(int(l.replay_entry["seed"]), 9)
	assert_eq(l.pages(), 1)
