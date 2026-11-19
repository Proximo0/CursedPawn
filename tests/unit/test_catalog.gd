extends TestCase


func test_default_catalog_has_no_problems() -> void:
	var c := Catalog.load_default()
	assert_eq(c.problems(), PackedStringArray(), "problems")
	assert_true(c.objects.size() >= 10, "objects")
	assert_true(c.categories().size() >= 2, "categories")


func test_curse_without_tell_is_a_problem() -> void:
	var c := Catalog.new()
	c.objects = [{"id": "a", "name": "A", "category": "x", "value": 10}]
	c.curses = [{"id": "k", "name": "K", "dread": 1.0, "sale_mult": 1.0, "imposter_every": 0, "tells": {}}]
	c.tarot = [{"id": "t", "name": "T", "weight": 1, "mult": 0.5, "dread": 0.0, "text": ""}]
	c.customers = [{"id": "s", "name": "S", "kind": "seller", "weight": 1, "line": ""}, {"id": "b", "name": "B", "kind": "buyer", "weight": 1, "line": ""}]
	assert_eq(c.problems(), PackedStringArray(["curse k has no tell"]))


func test_curse_lookup() -> void:
	var c := Catalog.load_default()
	assert_eq(str(c.curse("lucky_paw").get("name", "")), "Lucky paw")
	assert_true(c.curse("nope").is_empty())


func test_tarot_deck_that_favors_player_is_a_problem() -> void:
	var c := Catalog.load_default()
	c.tarot = [{"id": "t", "name": "T", "weight": 1, "mult": 1.5, "dread": 0.0, "text": ""}]
	assert_true(c.problems().size() == 1, "one problem")


func test_occult_data() -> void:
	var c := Catalog.load_default()
	assert_eq(c.spells.size(), 6)
	assert_eq(c.curios.size(), 24)
	var rarity: Dictionary = {}
	var sets: Dictionary = {}
	for cu: Dictionary in c.curios:
		rarity[cu["rarity"]] = int(rarity.get(cu["rarity"], 0)) + 1
		sets[cu["set"]] = true
		assert_true(str(cu["text"]) != "" and not str(cu["name"]).begins_with("Placeholder"), str(cu["id"]))
	assert_eq(rarity, {"common": 14, "rare": 7, "legendary": 3})
	assert_eq(sets.keys().size(), 4)
	for n: int in range(1, 13):
		assert_true(not c.curio("curio_%02d" % n).is_empty(), "old id %d kept" % n)
	assert_true(not c.table.is_empty())


func test_fifty_six_objects_each_with_text() -> void:
	var c := Catalog.load_default()
	assert_eq(c.objects.size(), 56)
	for o: Dictionary in c.objects:
		assert_true(str(o.get("text", "")) != "", "%s has text" % o["id"])
		assert_true(str(o["text"]).length() <= 80, "%s text is short" % o["id"])
	var counts: Dictionary = {}
	for o: Dictionary in c.objects:
		counts[o["category"]] = int(counts.get(o["category"], 0)) + 1
	for cat: String in counts:
		assert_true(int(counts[cat]) >= 10, "%s has at least 10 objects" % cat)


func test_object_without_text_is_a_problem() -> void:
	var c := Catalog.load_default()
	c.objects[0].erase("text")
	assert_true(c.problems().size() == 1, "one problem")
