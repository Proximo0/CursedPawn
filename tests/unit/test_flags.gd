extends TestCase


func test_state_hash_changes_with_provider() -> void:
	var f: Node = load("res://game/autoload/flags.gd").new()
	var before: int = f.state_hash()
	f.register_hash(func() -> int: return 7)
	assert_true(f.state_hash() != before)
	f.free()


func test_query_args_keeps_only_test_keys() -> void:
	var f: GDScript = load("res://game/autoload/flags.gd")
	var got: Dictionary = f.query_args("?scripted&bot=greedy&seed=7&dev&x=1")
	assert_eq(got, {"scripted": "1", "bot": "greedy", "seed": "7"})
	assert_eq(f.query_args(""), {})
