extends SceneTree
## Runs every tests/unit/test_*.gd (or one file via -- --only=test_name, or one shard via -- --shard=i --nshards=n). Prints failures only, then one summary line.
## Exit code 0 = all pass, 1 = any failure or a script that would not load.


## Deferred so autoload singletons (Flags, Controls) exist before test scripts compile.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only: String = ""
	var shard: int = 0
	var nshards: int = 1
	var claims: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		elif a.begins_with("--shard="):
			shard = int(a.trim_prefix("--shard="))
		elif a.begins_with("--nshards="):
			nshards = maxi(1, int(a.trim_prefix("--nshards=")))
		elif a.begins_with("--claims="):
			claims = a.trim_prefix("--claims=")
	var passed: int = 0
	var failed: int = 0
	var dir: PackedStringArray = DirAccess.get_files_at("res://tests/unit")
	dir.sort()
	var mindex: int = -1  ## test methods seen so far, across files: shards split by method so one slow file is not one slow shard
	for f: String in dir:
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		if only != "" and f.get_basename() != only:
			continue
		var script: GDScript = load("res://tests/unit/" + f)
		if script == null or not script.can_instantiate():
			printerr("LOAD FAIL %s" % f)
			failed += 1
			continue
		for m: Dictionary in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			mindex += 1
			if only == "" and not rn_mine(mindex, shard, nshards, claims):
				continue
			var t: TestCase = script.new()
			t.call(name)
			if t.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for msg: String in t.failures:
					printerr("FAIL %s::%s  %s" % [f.get_basename(), name, msg])
	print("TESTS passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 or (passed == 0 and claims == "") else 0)  ## a queue process may find nothing left to take


## Parallel runs. With --claims=<dir> (tools/run_tests.sh), processes share one queue: each takes the next test method
## no one has claimed yet (mkdir is atomic), so a slow test doesn't hold up a fixed share of the others. Without it,
## --shard=i --nshards=n takes every n-th method.
static func rn_mine(mindex: int, shard: int, nshards: int, claims: String) -> bool:
	if claims != "":
		return DirAccess.make_dir_absolute(claims.path_join(str(mindex))) == OK
	return mindex % nshards == shard
