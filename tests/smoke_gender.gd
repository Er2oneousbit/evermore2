# =============================================================================
# smoke_gender.gd  -  The kid is a boy or a girl: state, text tokens, sprite
# -----------------------------------------------------------------------------
# WHAT:  1. GenderedText: {boy|girl} splits, every pronoun token for both
#           genders, capitalised forms, names, and what is left alone
#        2. problems(): unbalanced braces, a split without exactly two parts,
#           unknown and empty tokens
#        3. DialogueScript turns those into "file:line:" errors, and every
#           shipped .dlg file parses with none
#        4. a prologue line renders differently for a boy and a girl; Names.expand
#           (HUD notices, signs) follows GameState.kid_gender
#        5. GameState.set_kid_gender (and the signal), the KID portrait sheet
#        6. the debug menu's "Play as" sets GameState before the map loads, the
#           kid on the map wears the girl sheet (2D sprite and the HD Sprite3D),
#           and switching live swaps both
#
# RUN:   godot --headless --path . --audio-driver Dummy --fixed-fps 60 res://tests/smoke_gender.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const STREET := "res://realms/podunk/ruffleberg_lot_hd.tscn"
const BOY_SHEET := "res://assets/characters/kid/kid_lpc.png"
const GIRL_SHEET := "res://assets/characters/kid_girl/kid_girl_lpc.png"

var _failures: PackedStringArray = []
var _resolver := func(key: String) -> String: return "<%s>" % key


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node.new()
	holder.name = "Holder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	_test_resolver()
	_test_problems()
	_test_script_errors()
	_test_dialogue_and_names()
	await _test_menu_and_sprite()
	GameState.set_kid_gender("boy")
	if _failures.is_empty():
		print("[TEST] PASS  smoke_gender")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


func _x(text: String, gender: String) -> String:
	return GenderedText.expand(text, gender, _resolver)


func _test_resolver() -> void:
	_check(_x("Hey you, {boy|girl}!", "boy") == "Hey you, boy!", "split: boy")
	_check(_x("Hey you, {boy|girl}!", "girl") == "Hey you, girl!", "split: girl")
	_check(_x("{young man|young lady} and {sir|ma'am}", "girl") == "young lady and ma'am", "splits with spaces, twice")
	var table := {"he": ["he", "she"], "him": ["him", "her"], "his": ["his", "her"], "He": ["He", "She"],
		"Him": ["Him", "Her"], "His": ["His", "Her"], "son": ["son", "daughter"], "Son": ["Son", "Daughter"],
		"boy": ["boy", "girl"], "Boy": ["Boy", "Girl"]}
	for tok: String in table:
		_check(_x("{%s}" % tok, "boy") == table[tok][0], "{%s} for a boy" % tok)
		_check(_x("{%s}" % tok, "girl") == table[tok][1], "{%s} for a girl" % tok)
	_check(_x("{He} said {he} lost {his} dog, {kid}.", "girl") == "She said she lost her dog, <kid>.", "a sentence, with a name")
	_check(_x("no tokens", "girl") == "no tokens", "plain text is untouched")
	_check(_x("{nope} stays a lookup", "boy") == "<nope> stays a lookup", "other keys go to the name resolver")
	_check(_x("{he", "girl") == "{he", "an unbalanced brace is left alone, not crashed on")
	_check(_x("{a|b|c}", "girl") == "{a|b|c}", "a three-part split is left alone")


func _test_problems() -> void:
	var has := func(key: String) -> bool: return key in ["robot", "town"]
	_check(GenderedText.problems("Hey {boy|girl}, {he} saw {robot} in {town}. {kid} {dog} {His} {son}", has).is_empty(), "good text has no problems")
	_check(GenderedText.problems("oops {he", has).size() == 1, "missing }")
	_check(GenderedText.problems("oops he}", has).size() == 1, "stray }")
	_check(GenderedText.problems("{a {b} c}", has).size() >= 1, "nested braces")
	_check(GenderedText.problems("{a|b|c}", has).size() == 1, "a split with 3 parts")
	_check(GenderedText.problems("{only}", has).size() == 1, "a lone word that is no key is unknown")
	_check(GenderedText.problems("{a|}", has).is_empty(), "an empty part is allowed (it can be on purpose)")
	_check(GenderedText.problems("{|}", has).is_empty(), "a bare split is two (empty) parts")
	_check(GenderedText.problems("{}", has).size() == 1, "an empty token")
	_check(GenderedText.problems("{one|two|three|four}", has)[0].contains("4"), "the message says how many parts")


func _test_script_errors() -> void:
	var s := DialogueScript.new()
	s.path = "res://t.dlg"
	s.parse("== a\nDAD: Fine, {he}.\nKID: Bad {boy|girl|x} here.\n: Loose {brace\n* Take {nothing_here} -> END\nDAD: Stray } brace.\n")
	_check(s.errors.size() == 4, "four bad lines give four errors (%d: %s)" % [s.errors.size(), s.errors])
	var all := "\n".join(s.errors)
	_check(all.contains("res://t.dlg:3:") and all.contains("exactly 2 parts"), "the split error names line 3")
	_check(all.contains("res://t.dlg:4:") and all.contains("unbalanced '{'"), "the open brace error names line 4")
	_check(all.contains("res://t.dlg:5:") and all.contains("unknown token {nothing_here}"), "the unknown token (in a choice) names line 5")
	_check(all.contains("res://t.dlg:6:") and all.contains("unbalanced '}'"), "the stray brace names line 6")
	_check(not all.contains("res://t.dlg:2:"), "the good line has no error")
	var dir := DirAccess.open("res://data/dialogue")
	var files := 0
	for f in dir.get_files():
		if f.ends_with(".dlg"):
			files += 1
			var sc := DialogueScript.load_file("res://data/dialogue/" + f)
			_check(sc.errors.is_empty(), "%s parses with no errors %s" % [f, sc.errors])
	_check(files >= 2, "found the shipped .dlg files (%d)" % files)


func _test_dialogue_and_names() -> void:
	var sc := DialogueScript.load_file("res://data/dialogue/prologue.dlg")
	var said := {}
	for g in GenderedText.GENDERS:
		var r := DialogueRunner.new()
		r.gender = g
		r.start(sc, "dex")
		var beat := r.advance()
		said[g] = beat["text"]
	_check(said["boy"] != said["girl"], "the Dex line differs by gender (%s | %s)" % [said["boy"], said["girl"]])
	_check(said["boy"].contains("he brought a dog") and said["girl"].contains("she brought a dog"), "he / she in the prologue")
	_check(not said["boy"].contains("{") and not said["girl"].contains("{"), "no raw braces left")
	GameState.set_kid_gender("girl")
	var r2 := DialogueRunner.new()  # no gender set: follows GameState
	r2.start(sc, "dex")
	_check(r2.advance()["text"] == said["girl"], "a runner follows GameState.kid_gender by default")
	_check(Names.expand("{He} lost {his} way, {kid}.") == "She lost her way, %s." % GameState.get_kid_name(), "Names.expand follows the kid and the player name")
	_check(Names.expand("The {robot} waits") == "The %s waits" % Names.text("robot"), "Names.expand fills names.json keys")
	GameState.set_kid_gender("boy")
	_check(Names.expand("{He} lost {his} way") == "He lost his way", "and flips back for a boy")
	_check(Names.expand("{boy|girl}", "girl") == "girl", "an explicit gender wins")
	# names.json values may hold tokens (and a value naming itself must not loop)
	Names._names["_t_tok"] = "{son|daughter} of {_t_tok}"
	_check(Names.text("_t_tok").begins_with("son of "), "a names.json value expands its tokens, with a guard against a loop")
	Names._names.erase("_t_tok")


func _test_menu_and_sprite() -> void:
	var seen := []
	var on_changed := func(g: String) -> void: seen.append(g)
	EventBus.kid_gender_changed.connect(on_changed)
	_check(GameState.kid_gender == "boy", "the kid starts as a boy")
	_check(not GameState.set_kid_gender("robot") and GameState.kid_gender == "boy", "an unknown gender is refused")
	_check(GameState.set_kid_gender("girl") and GameState.kid_gender == "girl" and seen == ["girl"], "set_kid_gender sets it and fires the signal once")
	GameState.set_kid_gender("girl")
	_check(seen.size() == 1, "setting the same gender again fires nothing")
	var kid_data := load("res://data/characters/KID.tres") as CharacterData
	var girl_at := kid_data.portrait() as AtlasTexture
	_check(girl_at.atlas.resource_path == GIRL_SHEET, "the KID portrait crops the girl sheet")
	GameState.set_kid_gender("boy")
	_check((kid_data.portrait() as AtlasTexture).atlas.resource_path == BOY_SHEET, "and the boy sheet for a boy")
	EventBus.kid_gender_changed.disconnect(on_changed)

	await _go_menu()
	var menu := get_tree().current_scene as DebugMenu
	_check(menu.gender_button != null and menu.gender_button.text.contains("Boy"), "the menu has 'Play as: < Boy >' (%s)" % menu.gender_button.text)
	menu.step_option(menu.gender_button, 1)
	_check(menu.selected_gender() == "girl" and menu.gender_button.text.contains("Girl"), "stepping Play as picks Girl (%s)" % menu.gender_button.text)
	menu.map_buttons["street"].pressed.emit()
	_check(GameState.kid_gender == "girl", "pressing a map sets GameState before the map loads")
	_check(DebugMenu.last["gender"] == "girl", "and the choice is remembered for the menu")
	await _arrive(STREET)
	var kid := get_tree().get_first_node_in_group("kid") as Kid
	_check(kid != null and (kid.get_node("Sprite") as Sprite2D).texture.resource_path == GIRL_SHEET, "the kid on the map wears the girl sheet (2D)")
	var hd := get_tree().get_first_node_in_group("hd_view") as HdView
	_check(hd != null and (hd.get_node("Kid") as Sprite3D).texture.resource_path == GIRL_SHEET, "and so does the HD sprite")
	GameState.set_kid_gender("boy")
	for i in 5:
		await get_tree().physics_frame
	_check((kid.get_node("Sprite") as Sprite2D).texture.resource_path == BOY_SHEET, "switching live swaps the 2D sheet back")
	_check((hd.get_node("Kid") as Sprite3D).texture.resource_path == BOY_SHEET, "and the HD sprite follows")


func _go_menu() -> void:
	get_tree().change_scene_to_file(DebugMenu.SCENE)
	await get_tree().scene_changed
	for i in 5:
		await get_tree().physics_frame


func _arrive(scene: String) -> void:
	var frames := 0
	while frames < 900 and not (get_tree().current_scene != null and get_tree().current_scene.scene_file_path == scene
			and not Travel.busy and frames > 5):
		await get_tree().physics_frame
		frames += 1
	_check(get_tree().current_scene.scene_file_path == scene, "arrived on %s" % scene.get_file())
	for i in 5:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("[TEST] ok    ", what)
	else:
		_failures.append(what)
		printerr("[TEST] FAIL  ", what)
