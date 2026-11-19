extends Node
## Run-wide flags and the state hash.
## User args come after "--" on the command line: godot --path . -- --scripted --dev --seed=7
## The web build also reads WEB_QUERY_KEYS from the page address: index.html?scripted&bot=greedy&seed=7

var args: Dictionary = {}
var frame: int = 0
var commands: int = 0  ## player commands issued; compare state hashes only on frames where this is 0
var _hash_providers: Array[Callable] = []
var _web_ready_sent: bool = false

## Page-address keys the web build accepts. Only test switches: --dev stays command-line only, so the public site
## never opens dev entries or cheats.
const WEB_QUERY_KEYS: PackedStringArray = ["scripted", "bot", "bot_nights", "bot_steps", "seed"]


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if OS.has_feature("web"):
		args.merge(query_args(str(JavaScriptBridge.eval("location.search", true))), true)


## "?a=1&b" -> {"a": "1", "b": "1"}, keeping only WEB_QUERY_KEYS.
static func query_args(query: String) -> Dictionary:
	var out: Dictionary = {}
	for part: String in query.trim_prefix("?").split("&", false):
		var kv: PackedStringArray = part.split("=", true, 1)
		var key: String = kv[0].uri_decode()
		if WEB_QUERY_KEYS.has(key):
			out[key] = kv[1].uri_decode() if kv.size() > 1 else "1"
	return out


func _physics_process(_delta: float) -> void:
	frame += 1


## Web build: sets window.cursedPawnReady on the first frame after the main scene is ready, whatever the main scene
## is, so tools/web_smoke.mjs waits on game state instead of guessing from pixels.
func _process(_delta: float) -> void:
	if _web_ready_sent or get_tree().current_scene == null:
		return
	_web_ready_sent = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.cursedPawnReady = true", true)


## Captures, tests and gates: no saves, no writes to player data.
func is_scripted_run() -> bool:
	return args.has("scripted") or args.has("capture") or DisplayServer.get_name() == "headless"


## Dev menu entries and cheats only with --dev.
func dev_menu() -> bool:
	return args.has("dev")


func get_arg(key: String, default: String = "") -> String:
	return args.get(key, default)


func seed_value() -> int:
	return int(get_arg("seed", "1"))


## Systems register a Callable returning an int that summarises their state.
func register_hash(provider: Callable) -> void:
	_hash_providers.append(provider)


func state_hash() -> int:
	var h: int = 1469598103934665603
	for p: Callable in _hash_providers:
		if p.is_valid():
			h = hash([h, p.call()])
	return h
