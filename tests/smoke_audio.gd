# =============================================================================
# smoke_audio.gd  -  Headless checks for sound and music
# -----------------------------------------------------------------------------
# WHAT:  1. Every sound and music file the Audio table names exists and loads
#        2. Unknown names are refused; the same sound starts at most twice a
#           frame (a sweep through five rats is one thump)
#        3. The game makes its sounds: the swing, hits (with the stick's crack
#           on charged hits), the rat's warning, bite, pain and death, the
#           kid getting hurt, footsteps on grass and on the dirt road, the
#           dog's paws, bite, yelp and bark, the kid's whistle, the switch chime
#        4. Music: each map plays its track (looping), the prologue starts on
#           "home" for dinner, crossfades and stops work
#        5. Menus and dialogue: pause opens/moves/closes with ticks, the text
#           box blips while typing
#        7. Voices: talking to Maya, she says hello in her voice; an emotion
#           tag plays a voiced reaction; the kid and Dex stay silent
#        6. Ambience: birds by day, crickets at night (following the time of
#           day), loops, a bird now and then by day, silence when a map asks,
#           none during dinner
#        Headless Audio picks and logs sounds without playing them (no audio
#        device), so this checks the wiring; ears check the mix.
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_audio.tscn
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const ARENA := "res://realms/test/combat_arena.tscn"
const LOT := "res://realms/podunk/ruffleberg_lot.tscn"
const RAT := preload("res://data/enemies/rat.tres")

var _failures: PackedStringArray = []
var _heard: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Audio.played.connect(func(s: String) -> void: _heard.append(s))
	_run.call_deferred()


func _run() -> void:
	_test_files()
	await _test_rules()
	await _test_combat()
	await _test_duo()
	await _test_footsteps()
	await _test_music()
	await _test_menus_and_text()
	await _test_ambience()
	await _test_voices()
	if _failures.is_empty():
		print("[TEST] PASS  smoke_audio")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _test_files() -> void:
	for sound: String in Audio.SOUNDS:
		for f: String in Audio.SOUNDS[sound]["files"]:
			var path := Audio.SFX_DIR + f + ".ogg"
			_check(ResourceLoader.exists(path) and load(path) is AudioStream, "sound file %s loads (for '%s')" % [path, sound])
	for v: String in Audio.VOICES:
		for kind: String in Audio.VOICES[v]["kinds"]:
			for f: String in Audio.VOICES[v]["kinds"][kind]:
				var vpath: String = Audio.VOICE_DIR + f + ".ogg"
				_check(ResourceLoader.exists(vpath) and load(vpath) is AudioStream, "voice %s loads" % vpath)
	for amb: String in Audio.AMBIENCE:
		var apath: String = Audio.AMBIENCE_DIR + Audio.AMBIENCE[amb][0] + ".ogg"
		_check(ResourceLoader.exists(apath) and load(apath) is AudioStream, "ambience %s loads" % apath)
	for track: String in Audio.MUSIC:
		var path: String = Audio.MUSIC_DIR + Audio.MUSIC[track] + ".ogg"
		_check(ResourceLoader.exists(path) and load(path) is AudioStream, "music %s loads" % path)
	_check(FileAccess.file_exists("res://credits/audio/credits.txt"), "the audio credits file exists")


func _test_rules() -> void:
	_check(not Audio.play("no_such_sound"), "an unknown sound is refused")
	await _frames(1)
	_heard.clear()
	for i in 5:
		Audio.play("hit")
	_check(_heard.count("hit") == 2, "the same sound starts at most twice a frame (got %d)" % _heard.count("hit"))


func _test_combat() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	dog.set_physics_process(false)
	var rat := _add_rat(arena, kid.global_position + Vector2(0, 24))
	await _frames(2)
	rat.set_physics_process(false)
	kid.facing = Vector2.DOWN
	kid.charge.value = 2.0
	_heard.clear()
	kid.attack()
	await _wait(0.6)
	_expect("swing", "the kid's swing whooshes")
	_expect("hit", "a landed blow thumps")
	_expect("thwack", "a charged hit adds the stick's crack")
	_expect("rat_pain", "the rat squeals when hit")

	# The rat's turn: warning squeak, bite, the kid gets hurt.
	rat.health.reset(200)
	rat.set_physics_process(true)
	rat.state = Enemy.State.CHASE
	rat.target = kid
	kid.set_physics_process(false)
	_heard.clear()
	for i in 240:
		await get_tree().physics_frame
		if _heard.has("hurt"):
			break
	_expect("rat_squeak", "the rat squeaks before it bites (the warning)")
	_expect("rat_bite", "its bite snaps")
	_expect("hurt", "the kid getting hit makes a sound")
	_heard.clear()
	rat.get_node("Hurtbox").receive(HitInfo.make(999.0, kid.global_position, rat.global_position, 0.0, "player", kid))
	await _frames(2)
	_expect("rat_death", "a dying rat squeals")
	arena.queue_free()
	await _frames(2)


func _test_duo() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	_heard.clear()
	Party.set_staying(true)
	await _frames(2)
	_expect("dog_bark", "the dog barks when told to Stay put")
	_heard.clear()
	Party.set_staying(false)
	await _frames(2)
	_expect("whistle", "calling him back, the kid whistles")
	await _wait(0.6)
	_expect("dog_bark", "and the dog answers")
	_heard.clear()
	Party.cycle_stance(dog)
	_expect("ui_move", "changing a stance ticks")
	Party.switch_control()
	await _frames(2)
	_expect("switch", "switching control chimes")
	kid.set_physics_process(false)
	var rat := _add_rat(arena, dog.global_position + Vector2(24, 0))
	await _frames(2)
	rat.set_physics_process(false)
	dog.facing = Vector2.RIGHT
	_heard.clear()
	dog.attack()
	await _wait(0.5)
	_expect("dog_bite", "the dog's bite snaps")
	dog.get_node("Hurtbox").receive(HitInfo.make(1.0, rat.global_position, dog.global_position, 0.0, "enemy", rat))
	await _frames(2)
	_expect("dog_yelp", "the dog yelps when hit")
	arena.queue_free()
	await _frames(2)


func _test_footsteps() -> void:
	var arena := await _load(ARENA)
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	_heard.clear()
	# Long enough for a walking kid (not running) to get well past the dog.
	Input.action_press("move_right")
	await _wait(1.6)
	Input.action_release("move_right")
	_check(_heard.count("step_grass") >= 3, "walking on grass makes steps (%d)" % _heard.count("step_grass"))
	await _wait(0.8)
	_expect("paw_grass", "the dog's paws patter behind")
	arena.queue_free()
	await _frames(2)

	var lot: Node = load(LOT).instantiate()
	lot.skip_intro = true
	add_child(lot)
	await _frames(10)
	var kid: Kid = lot.get_node("World/Kid")
	var road := Vector2(6 * 32 + 16, 11 * 32 + 20)
	_check(AsciiRealm.surface_at(get_tree(), road) == "stone", "the dirt road counts as hard ground")
	_check(AsciiRealm.surface_at(get_tree(), Vector2(6 * 32 + 16, 13 * 32 + 16)) == "grass", "the verge is grass")
	kid.global_position = road
	await _frames(2)
	_heard.clear()
	Input.action_press("move_right")
	await _wait(0.8)
	Input.action_release("move_right")
	_check(_heard.count("step_stone") >= 2, "walking the road sounds harder (%d stone steps)" % _heard.count("step_stone"))
	lot.queue_free()
	await _frames(2)


func _test_music() -> void:
	var arena := await _load(ARENA)
	_check(Audio.music_name == "arena", "the arena plays its music (%s)" % Audio.music_name)
	var stream := Audio.music_player().stream as AudioStreamOggVorbis
	_check(stream != null and stream.loop, "music loops")
	Audio.play_music("yard", 0.0)
	_check(Audio.music_name == "yard" and Audio.music_player().stream.resource_path.ends_with("yard.ogg"), "play_music switches tracks")
	Audio.stop_music(0.0)
	_check(Audio.music_name == "", "stop_music stops it")
	arena.queue_free()
	await _frames(2)
	var lot: Node = load(LOT).instantiate()
	add_child(lot)  # with the intro: dinner first
	await _frames(10)
	_check(Audio.music_name == "home", "dinner plays the home theme (%s)" % Audio.music_name)
	Dialogue._finish()
	lot.queue_free()
	await _frames(2)


func _test_menus_and_text() -> void:
	var arena := await _load(ARENA)
	_heard.clear()
	PauseMenu.open()
	await _frames(2)
	_expect("ui_open", "the pause menu opens with a sound")
	_check(not _heard.has("ui_move"), "opening doesn't also tick for its own focus")
	PauseMenu._settings_button.grab_focus()
	await _frames(1)
	_expect("ui_move", "moving the highlight ticks")
	PauseMenu.close()
	_expect("ui_back", "closing it plays the back sound")
	_heard.clear()
	var box: DialogueBox = Dialogue.get_box()
	box.show_line("", "Some words to type out letter by letter, with a blip now and then.", null)
	await _wait(0.5)
	_check(_heard.count("text_blip") >= 3, "typing text blips (%d)" % _heard.count("text_blip"))
	box.hide_box()
	arena.queue_free()
	await _frames(2)


func _test_ambience() -> void:
	var arena := await _load(ARENA)  # starts in daylight
	_check(Audio.ambience_set == "outdoor" and Audio.ambience_name == "day", "outdoors by day: the birds loop (%s)" % Audio.ambience_name)
	var stream := Audio.ambience_player().stream as AudioStreamOggVorbis
	_check(stream != null and stream.loop and stream.resource_path.ends_with("day.ogg"), "the day ambience loops")
	_heard.clear()
	Audio._bird_timer = 0.0
	await _frames(2)
	_expect("bird", "a bird calls now and then by day")
	var atmo: Atmosphere = arena.get_node("Atmosphere")
	atmo.set_time("night", 0.0)
	await _frames(2)
	_check(Audio.ambience_name == "night", "night brings the crickets (%s)" % Audio.ambience_name)
	_heard.clear()
	Audio._bird_timer = 0.0
	await _frames(2)
	_check(not _heard.has("bird"), "no birds at night")
	atmo.set_time("golden", 0.0)
	await _frames(2)
	_check(Audio.ambience_name == "day", "golden hour is still birds")
	Audio.set_ambience("")
	_check(Audio.ambience_name == "", "a map can ask for silence")
	arena.queue_free()
	await _frames(2)
	var lot: Node = load(LOT).instantiate()
	add_child(lot)  # with the intro: dinner, indoors
	await _frames(10)
	_check(Audio.ambience_name == "", "no birds during dinner (%s)" % Audio.ambience_name)
	Dialogue._finish()
	lot.queue_free()
	await _frames(2)


func _test_voices() -> void:
	_check(Dialogue.character("KID").voice == "", "the kid stays silent (the player's character)")
	_check(not Audio.voice("bright", "no_such_kind"), "a kind a voice doesn't have plays nothing")
	var lot: Node = load(LOT).instantiate()
	lot.skip_intro = true
	add_child(lot)
	await _frames(10)
	var kid: Kid = lot.get_node("World/Kid")
	var maya: Npc = null
	for n in get_tree().get_nodes_in_group("npc"):
		if n.character_id == "MAYA":
			maya = n
	kid.global_position = maya.global_position + Vector2(30, 0)
	kid.facing = Vector2.LEFT
	await _frames(3)
	_heard.clear()
	Interaction.try_interact()
	await _frames(2)
	_expect("voice:bright:greet", "talking to Maya, she says hello")
	# Her relieved line ("Good. Watching is good.") comes with an "okay".
	_heard.clear()
	Dialogue._finish()
	Dialogue.start("res://data/dialogue/prologue.dlg", "maya_watch")
	for i in 6:
		await _frames(2)
		Dialogue._on_advance()
	_expect("voice:bright:agree", "an emotion tag plays a voiced reaction")
	Dialogue._finish()
	lot.queue_free()
	await _frames(2)


# -----------------------------------------------------------------------------
func _expect(sound: String, message: String) -> void:
	_check(_heard.has(sound), "%s ('%s' not heard; heard %s)" % [message, sound, _heard])


func _load(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	add_child(scene)
	await _frames(8)
	return scene


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()


func _add_rat(arena: Node, at: Vector2) -> Enemy:
	var e := Enemy.create(RAT, at)
	arena.get_node("World").add_child(e)
	return e


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await _frames(ceili(seconds * Engine.physics_ticks_per_second))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
