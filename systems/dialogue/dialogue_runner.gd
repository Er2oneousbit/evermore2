# =============================================================================
# dialogue_runner.gd  -  Steps through a DialogueScript, one beat at a time
# -----------------------------------------------------------------------------
# WHAT:  The "playhead" for a conversation. It knows nothing about the screen:
#        the text box asks it for the next beat and draws whatever comes back.
#          runner.start(script, "dinner")
#          var beat := runner.advance()   # {"type": "line" | "choices" | "end", ...}
#          runner.choose(1)               # after a "choices" beat
#        Flags (@set, [cond]) and @commands are handled in between beats, so
#        the caller only ever sees lines, menus and the end.
#
# WHY SEPARATE FROM THE UI: tests can play a whole conversation headlessly,
#        and a different presentation (speech bubbles, a phone chat) can reuse it.
#
# HOOKS (Callables, so tests can swap them):
#   get_flag(name) -> Variant      default: GameState.get_flag
#   set_flag(name, value)          default: GameState.set_flag
#   resolve_name(key) -> String    default: {kid}/{dog} -> player names, else Names.text
#   gender                         "boy"/"girl" for {he} and {boy|girl} (default: GameState.kid_gender)
#   signal command(name, args)     for @time, @fade, ... (the scene handles them)
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name DialogueRunner
extends RefCounted

## An @command other than set/clear: the scene decides what it means.
signal command(command_name: String, args: PackedStringArray)

## Guard against a script that jumps in a circle without showing anything.
const MAX_STEPS_PER_BEAT := 1000

var get_flag := func(flag: String) -> Variant: return GameState.get_flag(flag)
var set_flag := func(flag: String, value: Variant) -> void: GameState.set_flag(flag, value)
var resolve_name := func(key: String) -> String: return DialogueRunner.default_name(key)

## Whose pronouns {he} and {boy|girl} use. Empty = the kid's (GameState).
var gender := ""

var script_data: DialogueScript
var node_name := ""
var finished := true

var _index := 0
var _pending_menu: Dictionary = {}  # the menu waiting for choose()
var _shown_options: Array = []      # its options that passed their [cond]


## The player's names for {kid} and {dog}; any other key comes from names.json
## (Names.default_name).
static func default_name(key: String) -> String:
	return Names.default_name(key)


## Begin at a node. Returns false (and logs) if the script or node is bad.
func start(script: DialogueScript, start_node: String) -> bool:
	script_data = script
	_pending_menu = {}
	if script == null or not script.errors.is_empty():
		Debug.log_error("Dialogue: can't start '%s', the script has errors" % start_node)
		finished = true
		return false
	if not script.nodes.has(start_node):
		Debug.log_error("Dialogue: no node '%s' in %s" % [start_node, script.path])
		finished = true
		return false
	node_name = start_node
	_index = 0
	finished = false
	return true


## The next thing to show: a line, a menu, or the end.
##   {"type": "line", "speaker": "DAD", "emotion": "", "text": "..."}
##   {"type": "choices", "options": PackedStringArray([...])}
##   {"type": "end"}
func advance() -> Dictionary:
	if finished:
		return {"type": "end"}
	if not _pending_menu.is_empty():
		# Asking again without choosing: show the same menu again.
		return _menu_beat()
	for _step in MAX_STEPS_PER_BEAT:
		var stmts: Array = script_data.nodes[node_name]
		if _index >= stmts.size():
			return _end()
		var stmt: Dictionary = stmts[_index]
		_index += 1
		if not _passes(stmt["cond"]):
			continue
		match stmt["type"]:
			"line":
				return {"type": "line", "speaker": stmt["speaker"], "emotion": stmt["emotion"],
						"text": substitute(stmt["text"])}
			"set":
				set_flag.call(stmt["flag"], stmt["value"])
			"command":
				command.emit(stmt["name"], PackedStringArray(stmt["args"]))
			"jump":
				if stmt["target"] == DialogueScript.END:
					return _end()
				node_name = stmt["target"]
				_index = 0
			"menu":
				_shown_options = stmt["options"].filter(func(o: Dictionary) -> bool: return _passes(o["cond"]))
				if _shown_options.is_empty():
					continue  # every option hidden: carry on after the menu
				_pending_menu = stmt
				return _menu_beat()
	Debug.log_error("Dialogue: %s node '%s' loops without showing anything" % [script_data.path, node_name])
	return _end()


## Pick option `i` (0-based, in the order they were shown).
func choose(i: int) -> void:
	if _pending_menu.is_empty():
		Debug.log_warn("Dialogue: choose(%d) called with no menu open" % i)
		return
	if i < 0 or i >= _shown_options.size():
		Debug.log_warn("Dialogue: choice %d out of range (%d options)" % [i, _shown_options.size()])
		return
	var target: String = _shown_options[i]["target"]
	_pending_menu = {}
	_shown_options = []
	if target.is_empty():
		return  # no jump: continue after the menu
	if target == DialogueScript.END:
		_end()
		return
	node_name = target
	_index = 0


## Expand every {token}: names via resolve_name, pronouns and {boy|girl}
## splits for `gender` (see GenderedText).
func substitute(text: String) -> String:
	return GenderedText.expand(text, gender if not gender.is_empty() else GameState.kid_gender, resolve_name)


func _menu_beat() -> Dictionary:
	var labels := PackedStringArray()
	for o: Dictionary in _shown_options:
		labels.append(substitute(o["text"]))
	return {"type": "choices", "options": labels}


func _passes(cond: String) -> bool:
	if cond.is_empty():
		return true
	var negate := cond.begins_with("!")
	var flag := cond.substr(1) if negate else cond
	var truthy := _truthy(get_flag.call(flag))
	return not truthy if negate else truthy


static func _truthy(v: Variant) -> bool:
	if v == null:
		return false
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING:
			return not String(v).is_empty()
	return true


func _end() -> Dictionary:
	finished = true
	_pending_menu = {}
	return {"type": "end"}
