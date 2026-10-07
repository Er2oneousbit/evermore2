# =============================================================================
# dialogue_script.gd  -  Parses .dlg dialogue files into nodes the runner plays
# -----------------------------------------------------------------------------
# WHAT:  A small plain-text format for conversations, made to be written and
#        diffed by humans (no editor plugin needed). One file holds many
#        conversation "nodes"; NPCs and triggers start one by name.
#
# WHY:   Dialogue is most of a story game's content. It has to be quick to
#        write, readable in a pull request, and loud about mistakes: every
#        error names the file and line.
#
# FORMAT (one statement per line; indentation is ignored):
#   # comment
#   == node_name                 starts a node (letters, digits, _ and .)
#   DAD: Eat your peas.          a line: SPEAKER id (data/characters/<id>.tres)
#   DAD (tired): Long day.       optional emotion (portrait variant; falls back)
#   : The fridge hums.           narration (no speaker, no portrait)
#   {kid} / {dog} / {any_key}    in text: the player's names, or a names.json key
#   * Why not?  -> why           a choice; consecutive * lines form one menu
#   * Okay.                      a choice with no jump continues after the menu
#   -> node_name                 jump to another node
#   -> END                       end the conversation
#   @set flag.name               set a story flag to true
#   @set flag.name = 3           ... or to a number, true/false, or "text"
#   @clear flag.name             set a story flag to false
#   @time night 3                any other @command goes to the scene to handle
#   [flag] / [!flag] at the start of any statement (choices too) = only when
#                                the flag is truthy / falsy. Example:
#   * [!prologue.dared] What's the dare? -> dare
#
#   A node ends the conversation when it runs out of statements, unless it
#   jumps. Nothing falls through into the next node by accident.
#
# USAGE: var s := DialogueScript.load_file("res://data/dialogue/prologue.dlg")
#        if s.errors.is_empty(): runner.start(s, "dinner")
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name DialogueScript
extends RefCounted

const END := "END"

## Where it came from (for error messages).
var path := ""
## node name -> Array of statements (Dictionaries, see _parse_statement).
var nodes: Dictionary = {}
## "path:line: message" for every problem found. Empty = good to play.
var errors: PackedStringArray = []

var _node_regex := RegEx.create_from_string("^==\\s*([A-Za-z0-9_.]+)\\s*$")
var _line_regex := RegEx.create_from_string("^([A-Z][A-Z0-9_]*)\\s*(?:\\(([^)]*)\\))?\\s*:\\s?(.*)$")
var _cond_regex := RegEx.create_from_string("^\\[(!?)([A-Za-z0-9_.]+)\\]\\s*")
var _choice_regex := RegEx.create_from_string("^(.*?)\\s*->\\s*([A-Za-z0-9_.]+)\\s*$")


## Read and parse a .dlg file. Problems end up in .errors (never crashes).
static func load_file(file_path: String) -> DialogueScript:
	var s := DialogueScript.new()
	s.path = file_path
	if not FileAccess.file_exists(file_path):
		s.errors.append("%s: file not found" % file_path)
		return s
	s.parse(FileAccess.get_file_as_string(file_path))
	return s


## Parse dialogue text (load_file calls this; tests call it directly).
func parse(text: String) -> void:
	nodes.clear()
	errors.clear()
	var current := ""
	var skipping := false  # inside a duplicate node: report once, ignore its body
	var menu: Dictionary = {}  # the menu being filled by consecutive * lines
	var lines := text.split("\n")
	for i in lines.size():
		var line_no := i + 1
		var raw := lines[i].strip_edges()
		if raw.is_empty() or raw.begins_with("#"):
			continue
		var m := _node_regex.search(raw)
		if m:
			current = m.get_string(1)
			menu = {}
			# A second node with the same name is reported and skipped; it must
			# never wipe out the first one (that would hide its errors too).
			skipping = nodes.has(current)
			if skipping:
				_error(line_no, "node '%s' is defined twice" % current)
			else:
				nodes[current] = []
			continue
		if skipping:
			continue
		if current.is_empty():
			_error(line_no, "text before the first '== node' line")
			continue
		var stmt := _parse_statement(raw, line_no)
		if stmt.is_empty():
			continue
		if stmt["type"] == "choice":
			if menu.is_empty():
				menu = {"type": "menu", "cond": "", "line": line_no, "options": []}
				nodes[current].append(menu)
			menu["options"].append(stmt)
		else:
			menu = {}
			nodes[current].append(stmt)
	_check_jumps()


## Names of every node, for tools and tests.
func node_names() -> PackedStringArray:
	return PackedStringArray(nodes.keys())


## One statement. Returns {} (and records an error) if the line is unreadable.
func _parse_statement(raw: String, line_no: int) -> Dictionary:
	var cond := ""
	var is_choice := raw.begins_with("*")
	var body := raw.substr(1).strip_edges() if is_choice else raw
	var c := _cond_regex.search(body)
	if c:
		cond = c.get_string(1) + c.get_string(2)
		body = body.substr(c.get_end()).strip_edges()

	if is_choice:
		var target := ""
		var text := body
		var cm := _choice_regex.search(body)
		if cm:
			text = cm.get_string(1).strip_edges()
			target = cm.get_string(2)
		if text.is_empty():
			_error(line_no, "a choice needs some text")
			return {}
		return {"type": "choice", "cond": cond, "line": line_no, "text": text, "target": target}

	if body.begins_with("->"):
		var target := body.substr(2).strip_edges()
		if target.is_empty():
			_error(line_no, "'->' needs a node name (or END)")
			return {}
		return {"type": "jump", "cond": cond, "line": line_no, "target": target}

	if body.begins_with("@"):
		var parts := body.substr(1).strip_edges().split(" ", false)
		if parts.is_empty():
			_error(line_no, "'@' needs a command name")
			return {}
		var cmd := parts[0]
		if cmd == "set" or cmd == "clear":
			# Everything after the command word: "flag", "flag = 3" or "flag=3".
			var rest := body.substr(1).strip_edges().substr(cmd.length()).strip_edges()
			var flag := rest
			var value: Variant = cmd == "set"
			var eq := rest.find("=")
			if eq >= 0:
				flag = rest.substr(0, eq).strip_edges()
				if cmd == "clear":
					_error(line_no, "'@clear' takes only a flag name")
					return {}
				value = _parse_value(rest.substr(eq + 1).strip_edges(), line_no)
			if flag.is_empty() or flag.contains(" "):
				_error(line_no, "'@%s' needs one flag name" % cmd)
				return {}
			return {"type": "set", "cond": cond, "line": line_no, "flag": flag, "value": value}
		return {"type": "command", "cond": cond, "line": line_no, "name": cmd, "args": parts.slice(1)}

	if body.begins_with(":"):
		return {"type": "line", "cond": cond, "line": line_no, "speaker": "", "emotion": "",
				"text": body.substr(1).strip_edges()}

	var lm := _line_regex.search(body)
	if lm:
		return {"type": "line", "cond": cond, "line": line_no, "speaker": lm.get_string(1),
				"emotion": lm.get_string(2).strip_edges(), "text": lm.get_string(3).strip_edges()}

	_error(line_no, "can't read this line (speaker lines look like 'DAD: text', narration like ': text')")
	return {}


func _parse_value(text: String, line_no: int) -> Variant:
	if text == "true":
		return true
	if text == "false":
		return false
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	_error(line_no, "can't read the value '%s' (use a number, true/false, or \"text\")" % text)
	return true


## Every '->' must land somewhere: a typo in a node name is caught at load,
## not when a player finally picks that choice.
func _check_jumps() -> void:
	for node_name: String in nodes:
		for stmt: Dictionary in nodes[node_name]:
			var targets: Array = []
			if stmt["type"] == "jump":
				targets.append([stmt["target"], stmt["line"]])
			elif stmt["type"] == "menu":
				for opt: Dictionary in stmt["options"]:
					if not opt["target"].is_empty():
						targets.append([opt["target"], opt["line"]])
			for t: Array in targets:
				if t[0] != END and not nodes.has(t[0]):
					_error(t[1], "jump to unknown node '%s'" % t[0])


func _error(line_no: int, message: String) -> void:
	errors.append("%s:%d: %s" % [path if not path.is_empty() else "<text>", line_no, message])
