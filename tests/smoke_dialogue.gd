# =============================================================================
# smoke_dialogue.gd  -  Headless checks for the dialogue system
# -----------------------------------------------------------------------------
# WHAT:  1. DialogueScript: every statement type parses; bad lines, unknown
#           jumps, duplicate nodes and text before a node are reported with
#           their line numbers
#        2. DialogueRunner: plays conversations beat by beat: lines, narration,
#           emotions, {name} substitution, choices with and without jumps,
#           [flag]/[!flag] conditions, @set/@clear, @commands, END, a jump
#           loop that must not hang
#        3. The real game scripts in data/dialogue/ all load with no errors,
#           and every speaker in them has a character file
#        4. Talking to an NPC in the prologue lot: the prompt appears, the
#           text box opens, the kid can't walk while talking, choices work,
#           and the conversation ends cleanly
#        4b. The text box fits its text: short lines make a short box, a
#           portrait sets the minimum height, long text turns into pages that
#           each fit inside the box, no word is lost across pages, and a press
#           turns the page before the conversation moves on
#        5. The same in the HD-2D view (where the 2D World is hidden): Maya
#           is still talkable and drawn in 3D
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_dialogue.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const SAMPLE := """
# A sample covering every statement type.
== start
: The fridge hums.
DAD: Hey, {kid}.
DAD (tired): Long day.
@set test.greeted
[test.greeted] KID: You already said hi.
[!test.greeted] KID: This line must be skipped.
@time night 3
* Ask about the house -> house
* [test.secret] Hidden option -> END
* Say nothing
KID: (after the menu)
-> END

== house
DAD: Stay away from that house.
@set test.mood = 2
@clear test.greeted
[!test.greeted] DAD: That's the end of it.
"""

const LOOP := """
== a
@set test.x
-> b
== b
-> a
"""

const BROKEN := """
DAD: before any node
== one
DAD: fine
this line has no colon
-> nowhere
* -> one
@set
== one
"""

var _failures: PackedStringArray = []
var _flags := {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_parse()
	_test_errors()
	_test_runner()
	_test_loop_guard()
	_test_game_scripts()
	await _test_box_sizing()
	await _test_npc_talk()
	await _test_hd_talk()
	if _failures.is_empty():
		print("[TEST] PASS  smoke_dialogue")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _test_parse() -> void:
	var s := DialogueScript.new()
	s.parse(SAMPLE)
	_check(s.errors.is_empty(), "sample should parse cleanly: %s" % [s.errors])
	_check(s.nodes.size() == 2, "sample has 2 nodes, got %d" % s.nodes.size())
	var stmts: Array = s.nodes.get("start", [])
	var types := stmts.map(func(st: Dictionary) -> String: return st["type"])
	_check(types == ["line", "line", "line", "set", "line", "line", "command", "menu", "line", "jump"],
			"start node statement types: %s" % [types])
	if stmts.size() >= 8:
		var menu: Dictionary = stmts[7]
		_check(menu["options"].size() == 3, "menu should have 3 options")
		_check(menu["options"][1]["cond"] == "test.secret", "option 2 condition: %s" % menu["options"][1]["cond"])
		_check(menu["options"][2]["target"] == "", "option 3 has no jump")
		_check(stmts[2]["emotion"] == "tired", "emotion parsed: '%s'" % stmts[2]["emotion"])
		_check(stmts[0]["speaker"] == "", "narration has no speaker")
	var house: Array = s.nodes.get("house", [])
	if house.size() >= 3:
		_check(house[1]["value"] == 2, "@set value = 2, got %s" % house[1]["value"])
	# "flag=3" without spaces reads the same as "flag = 3".
	var t := DialogueScript.new()
	t.parse("== n\n@set a.b=3\n")
	_check(t.errors.is_empty() and t.nodes["n"][0]["flag"] == "a.b" and t.nodes["n"][0]["value"] == 3,
			"'@set a.b=3' should set a.b to 3: %s %s" % [t.errors, t.nodes.get("n", [])])


func _test_errors() -> void:
	var s := DialogueScript.new()
	s.path = "broken.dlg"
	s.parse(BROKEN)
	var text := "\n".join(s.errors)
	for want: String in ["broken.dlg:2: text before the first", "broken.dlg:5: can't read this line",
			"broken.dlg:6: jump to unknown node 'nowhere'", "broken.dlg:7: a choice needs some text",
			"broken.dlg:8: '@set' needs one flag name", "broken.dlg:9: node 'one' is defined twice"]:
		_check(text.contains(want), "expected error '%s' in:\n%s" % [want, text])


func _test_runner() -> void:
	var s := DialogueScript.new()
	s.parse(SAMPLE)
	var r := _runner()
	var commands: Array = []
	r.command.connect(func(n: String, a: PackedStringArray) -> void: commands.append([n, a]))
	_check(r.start(s, "start"), "runner should start")
	_expect(r.advance(), "line", "", "The fridge hums.")
	_expect(r.advance(), "line", "DAD", "Hey, Sam.")
	var tired := r.advance()
	_check(tired.get("emotion") == "tired", "emotion reaches the beat")
	_expect(r.advance(), "line", "KID", "You already said hi.")
	var menu := r.advance()
	_check(menu["type"] == "choices", "expected a menu, got %s" % menu)
	_check(commands == [["time", PackedStringArray(["night", "3"])]], "@time command emitted once: %s" % [commands])
	_check(menu.get("options", PackedStringArray()) == PackedStringArray(["Ask about the house", "Say nothing"]),
			"hidden option must not show: %s" % [menu.get("options")])
	# Choice without a jump continues after the menu.
	r.choose(1)
	_expect(r.advance(), "line", "KID", "(after the menu)")
	_check(r.advance()["type"] == "end" and r.finished, "-> END finishes")

	# Second run: the jumping choice, @set value, @clear, [!flag].
	_flags.clear()
	r.start(s, "start")
	for i in 4:
		r.advance()
	r.advance()  # the menu
	r.choose(0)
	_expect(r.advance(), "line", "DAD", "Stay away from that house.")
	_expect(r.advance(), "line", "DAD", "That's the end of it.")
	_check(_flags.get("test.mood") == 2 and _flags.get("test.greeted") == false, "flags after house: %s" % _flags)
	_check(r.advance()["type"] == "end", "running out of statements ends the conversation")

	# A secret flag reveals the hidden option.
	_flags.clear()
	_flags["test.secret"] = true
	r.start(s, "start")
	for i in 4:
		r.advance()
	var menu2 := r.advance()
	_check(menu2.get("options", PackedStringArray()).size() == 3, "secret option shows when its flag is set")
	_check(not r.start(s, "missing_node"), "starting a missing node fails")


func _test_loop_guard() -> void:
	var s := DialogueScript.new()
	s.parse(LOOP)
	var r := _runner()
	r.start(s, "a")
	var beat := r.advance()
	_check(beat["type"] == "end", "an endless jump loop must end, not hang")


func _test_game_scripts() -> void:
	var dir := DirAccess.open("res://data/dialogue")
	_check(dir != null, "data/dialogue/ is missing")
	if dir == null:
		return
	var count := 0
	for f in dir.get_files():
		if not f.ends_with(".dlg"):
			continue
		count += 1
		var s := DialogueScript.load_file("res://data/dialogue/" + f)
		_check(s.errors.is_empty(), "%s has errors:\n%s" % [f, "\n".join(s.errors)])
		for node_name: String in s.nodes:
			for stmt: Dictionary in s.nodes[node_name]:
				if stmt["type"] == "line" and not stmt["speaker"].is_empty():
					_check(Dialogue.has_character(stmt["speaker"]),
							"%s:%d: speaker %s has no data/characters file" % [f, stmt["line"], stmt["speaker"]])
	_check(count > 0, "no .dlg files found in data/dialogue/")


# -----------------------------------------------------------------------------
func _test_npc_talk() -> void:
	var scene: Node = load("res://realms/podunk/ruffleberg_lot.tscn").instantiate()
	scene.skip_intro = true
	add_child(scene)
	await _frames(10)
	var kid: Kid = scene.get_node("World/Kid")
	var maya: Npc = null
	for n in get_tree().get_nodes_in_group("npc"):
		if (n as Npc).character_id == "MAYA":
			maya = n
	_check(maya != null, "Maya should be standing in the lot")
	if maya == null:
		return
	# Stand to Maya's right, facing her. She idles facing down, so turning to
	# face the kid (right) is a real change the test can see.
	kid.global_position = maya.global_position + Vector2(30, 0)
	kid.facing = Vector2.LEFT
	await _frames(3)
	_check(Interaction.current_target() == maya, "Maya should be the interaction target")
	var hud_prompt: Label = scene.get_node("HUD/SafeFrame/InteractPrompt")
	_check(hud_prompt.visible and hud_prompt.text.contains(Names.text("npc_maya")), "talk prompt should name Maya: '%s'" % hud_prompt.text)

	_tap("interact")
	await _frames(3)
	_check(Dialogue.is_active(), "talking should open the dialogue")
	var box: DialogueBox = Dialogue.get_box()
	_check(box != null and box.visible, "the text box should be visible")
	# The kid must not walk while talking.
	var before := kid.global_position
	Input.action_press("move_left")
	await _frames(20)
	Input.action_release("move_left")
	_check(kid.global_position.distance_to(before) < 1.0, "kid moved during dialogue")
	_check(maya.sprite_dir() == DirectionalSprite.Dir.RIGHT, "Maya should turn to face the kid (right), faces %s" % maya.sprite_dir())

	# Click through: finish typing, advance, pick the first option at menus.
	for i in 60:
		if not Dialogue.is_active():
			break
		if box.is_showing_choices():
			_tap("interact")
		else:
			_tap("interact")
		await _frames(4)
	_check(not Dialogue.is_active(), "the conversation should end")
	_check(GameState.get_flag("prologue.talked_to_maya"), "talking to Maya sets prologue.talked_to_maya")
	before = kid.global_position
	Input.action_press("move_left")
	await _frames(20)
	Input.action_release("move_left")
	_check(kid.global_position.distance_to(before) > 5.0, "kid should walk again after the dialogue")
	scene.queue_free()
	await _frames(2)


func _test_box_sizing() -> void:
	var box: DialogueBox = Dialogue.get_box()
	var portrait: Texture2D = Dialogue.character("DAD").portrait()
	await _frames(2)

	box.show_line("", "Short.", null)
	await _frames(2)
	var narration_h := box.box_height()
	box.show_line("Dad", "Short.", portrait)
	await _frames(2)
	var portrait_h := box.box_height()
	_check(portrait_h >= DialogueBox.PORTRAIT_PX, "a portrait line must be at least portrait height (%.0f)" % portrait_h)
	_check(narration_h < portrait_h, "one-line narration (%.0f) should be shorter than a portrait line (%.0f)" % [narration_h, portrait_h])

	var three := "Line one is here and it goes on for a while so that it wraps around. " \
			+ "It keeps going a little more to make a third line in the box for sure."
	box.show_line("", three, null)
	await _frames(2)
	_check(box.box_height() > narration_h, "longer narration should grow the box (%.0f vs %.0f)" % [box.box_height(), narration_h])

	var words: PackedStringArray = []
	for i in 120:
		words.append("word%d" % i)
	words.append("Supercalifragilisticexpialidociousandthensomemorelettersuntilitistoowideforanyline")
	var long_text := " ".join(words)
	box.show_line("Dad", long_text, portrait)
	await _frames(2)
	_check(box.page_count() >= 2, "long text should split into pages (got %d)" % box.page_count())
	var width := box._text_width()
	var font := box._font()
	var rebuilt := ""
	for p in box.paginate(long_text, width):
		var lines := p.split("\n")
		_check(lines.size() <= DialogueBox.MAX_LINES, "a page has %d lines (max %d)" % [lines.size(), DialogueBox.MAX_LINES])
		for l in lines:
			_check(box._width_of(font, l) <= width + 0.5, "a line is wider than the box: '%s'" % l)
		rebuilt += p.replace("\n", "")
	_check(rebuilt.replace(" ", "") == long_text.replace(" ", ""), "pagination lost or changed text")
	_check(box.box_height() <= DialogueBox.MAX_LINES * box._line_height() + DialogueBox.PAD * 2 + 1,
			"a full page must still fit the max box height (%.0f)" % box.box_height())

	# Presses turn pages first; only after the last page does it ask for more.
	var asked := [0]
	var on_advance := func() -> void: asked[0] += 1
	box.advance_requested.connect(on_advance)
	await _frames(12)  # past the open guard
	var pages := box.page_count()
	for i in pages * 2:
		_tap("interact")  # finish typing
		await _frames(2)
		if asked[0] > 0:
			break
		_tap("interact")  # next page (or the next beat on the last one)
		await _frames(2)
		if asked[0] > 0:
			break
	_check(asked[0] == 1 and box.current_page() == pages - 1,
			"should reach the last page (%d/%d) before asking for the next line (asked %d)" % [box.current_page() + 1, pages, asked[0]])
	box.advance_requested.disconnect(on_advance)
	box.hide_box()
	await _frames(2)


func _test_hd_talk() -> void:
	var scene: Node = load("res://realms/podunk/ruffleberg_lot_hd.tscn").instantiate()
	scene.get_node("Yard").skip_intro = true
	add_child(scene)
	await _frames(10)
	var kid: Kid = scene.get_node("Yard/World/Kid")
	var maya: Npc = null
	for n in get_tree().get_nodes_in_group("npc"):
		if (n as Npc).character_id == "MAYA":
			maya = n
	if maya == null:
		_check(false, "HD: Maya missing")
		return
	kid.global_position = maya.global_position + Vector2(30, 0)
	kid.facing = Vector2.LEFT
	await _frames(3)
	_check(Interaction.current_target() == maya, "HD: Maya should be talkable in the HD-2D view")
	var maya3d := scene.get_node_or_null("HdView/Maya") as Sprite3D
	_check(maya3d != null and maya3d.visible, "HD: Maya should be drawn in 3D")
	scene.queue_free()
	await _frames(2)


# -----------------------------------------------------------------------------
func _runner() -> DialogueRunner:
	var r := DialogueRunner.new()
	r.get_flag = func(f: String) -> Variant: return _flags.get(f, false)
	r.set_flag = func(f: String, v: Variant) -> void: _flags[f] = v
	r.resolve_name = func(k: String) -> String: return "Sam" if k == "kid" else "<%s>" % k
	return r


func _expect(beat: Dictionary, type: String, speaker: String, text: String) -> void:
	var ok: bool = beat.get("type") == type and beat.get("speaker", "") == speaker and beat.get("text", "") == text
	_check(ok, "expected %s %s '%s', got %s" % [type, speaker, text, beat])


func _tap(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
