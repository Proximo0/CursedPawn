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
	assert_eq(c.problems(), PackedStringArray(["curse k has no tell"]))


func test_curse_lookup() -> void:
	var c := Catalog.load_default()
	assert_eq(str(c.curse("lucky_paw").get("name", "")), "Lucky paw")
	assert_true(c.curse("nope").is_empty())
