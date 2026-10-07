# =============================================================================
# dialogue.gd  (autoload: Dialogue)
# -----------------------------------------------------------------------------
# WHAT:  Runs conversations: loads .dlg scripts (cached), owns the text box,
#        and knows every speaking character (data/characters/*.tres).
#          Dialogue.start("res://data/dialogue/prologue.dlg", "maya", maya_npc)
#          await Dialogue.ended
# WHY:   One place that answers "is someone talking?" The kid stops walking,
#        NPCs turn to face him, triggers wait, all by asking Dialogue.
#
# SIGNALS (also mirrored on EventBus as dialogue_started / dialogue_ended):
#   started(node), ended(node), command(name, args) for scene @commands
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

signal started(node_name: String)
signal ended(node_name: String)
## A scene @command from the script (@time night 3, @fade out, ...).
signal command(command_name: String, args: PackedStringArray)

const CHARACTER_DIR := "res://data/characters/"
const BOX_SCENE := preload("res://ui/dialogue/dialogue_box.tscn")

## Who started the current conversation (an Npc, a trigger...), or null.
var speaker_node: Node = null

var _characters: Dictionary = {}
var _scripts: Dictionary = {}
var _runner: DialogueRunner
var _box: DialogueBox
var _node := ""
var _active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_characters()
	_box = BOX_SCENE.instantiate()
	add_child(_box)
	_box.hide_box()
	_box.advance_requested.connect(_on_advance)
	_box.choice_made.connect(_on_choice)


func is_active() -> bool:
	return _active


func get_box() -> DialogueBox:
	return _box


func has_character(id: String) -> bool:
	return _characters.has(id)


func character(id: String) -> CharacterData:
	return _characters.get(id)


## Parsed script (cached). Errors are logged once; the script may be unusable.
func get_script_data(path: String) -> DialogueScript:
	if not _scripts.has(path):
		var s := DialogueScript.load_file(path)
		for e in s.errors:
			Debug.log_error("Dialogue: " + e)
		_scripts[path] = s
	return _scripts[path]


## Start a conversation. Returns false if one is already running or the
## script/node is bad (the reason is logged).
func start(path: String, node_name: String, who: Node = null) -> bool:
	if _active:
		return false
	var s := get_script_data(path)
	_runner = DialogueRunner.new()
	_runner.command.connect(func(n: String, a: PackedStringArray) -> void: command.emit(n, a))
	if not _runner.start(s, node_name):
		return false
	_active = true
	_node = node_name
	speaker_node = who
	started.emit(node_name)
	EventBus.dialogue_started.emit(node_name)
	Debug.log_verbose("Dialogue started: %s (%s)" % [node_name, path])
	_on_advance()
	return true


func _on_advance() -> void:
	if not _active:
		return
	var beat := _runner.advance()
	match beat["type"]:
		"line":
			var c: CharacterData = _characters.get(beat["speaker"])
			if c == null and not beat["speaker"].is_empty():
				Debug.log_warn("Dialogue: no character file for speaker %s" % beat["speaker"])
			var speaker_name: String = c.display_name() if c else ""
			_box.show_line(speaker_name, beat["text"], c.portrait(beat["emotion"]) if c else null,
					c.color if c else Color.WHITE)
		"choices":
			_box.show_choices(beat["options"])
		"end":
			_finish()


func _on_choice(index: int) -> void:
	if not _active:
		return
	_runner.choose(index)
	_on_advance()


func _finish() -> void:
	_box.hide_box()
	_active = false
	var finished_node := _node
	speaker_node = null
	ended.emit(finished_node)
	EventBus.dialogue_ended.emit(finished_node)
	Debug.log_verbose("Dialogue ended: %s" % finished_node)


func _load_characters() -> void:
	var dir := DirAccess.open(CHARACTER_DIR)
	if dir == null:
		Debug.log_warn("Dialogue: %s not found, no speakers loaded" % CHARACTER_DIR)
		return
	for f in dir.get_files():
		# Exported builds list .tres as .tres.remap; strip that to get the ID.
		var file := f.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var data := load(CHARACTER_DIR + file) as CharacterData
		if data:
			_characters[file.get_basename()] = data
	Debug.log_verbose("Dialogue: %d characters loaded" % _characters.size())
