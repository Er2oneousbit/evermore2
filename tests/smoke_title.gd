# =============================================================================
# smoke_title.gd  -  Headless checks for the title screen and New Game
# -----------------------------------------------------------------------------
# WHAT:  1. the title builds: logo, subtitle, prompt, the five menu items;
#           Continue is disabled and the cursor skips it; the pause menu is
#           blocked there; --yard still bypasses (Debug.start_scene_for)
#        2. a key press reveals the menu and puts the cursor on New Game
#        3. Debug opens the debug menu, which has "Back to title"; Settings
#           opens the settings screen and closes back on its item
#        4. New Game: gender (Girl) -> kid name (neutral default for the
#           gender, typing, Backspace, empty rejected, 10 letters max) -> dog
#           name (Biscuit) -> confirm -> the prologue loads from the start
#           with its flags cleared and {kid}/{dog} resolving to the names
#        5. the end of the prologue slice and the pause menu's "Quit to title"
#           both return to the title (and unblock the pause menu elsewhere)
#
# RUN:   godot --headless --path . --audio-driver Dummy --fixed-fps 60 res://tests/smoke_title.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const STREET := "res://realms/podunk/ruffleberg_lot_hd.tscn"

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node.new()
	holder.name = "Holder"
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	_check(ProjectSettings.get_setting("application/run/main_scene") == TitleScreen.SCENE, "the title is the main scene")
	_check(Debug.start_scene_for(PackedStringArray(["--yard"])) != "", "--yard still bypasses the title")
	for leg: Callable in [_test_intro, _test_build, _test_mansion, _test_reveal, _test_debug_settings, _test_new_game, _test_returns]:
		await leg.call()
		if not _failures.is_empty():
			break
	if _failures.is_empty():
		print("[TEST] PASS  smoke_title")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


## The first visit of a session scrolls up from the street into the sky; any
## key skips to the settled title (logo + prompt, no menu yet); a later visit
## starts settled.
func _test_intro() -> void:
	TitleScreen.intro_played = false
	await _go_title()
	var t := _title()
	_check(t.phase == TitleScreen.Phase.INTRO, "the first visit plays the intro")
	var cam := (t._hd as HdView).camera()
	var start_tilt := cam.rotation.x
	var start_y := cam.position.y
	for i in 120:
		await get_tree().physics_frame
	_check(cam.rotation.x > start_tilt + deg_to_rad(1.0), "the camera tilts up over time (%.1f deg -> %.1f)" % [rad_to_deg(start_tilt), rad_to_deg(cam.rotation.x)])
	_check(cam.position.y > start_y, "and rises a little")
	_check(t.logo_label.modulate.a < 0.05, "the logo has not appeared yet")
	_check(t.scroll > 0.1 and t.scroll < 0.5, "the scroll is under way (%.2f)" % t.scroll)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	for i in 120:
		await get_tree().physics_frame
	_check(t.phase == TitleScreen.Phase.LOGO and not t._menu_box.visible, "a key skips to the settled title, not the menu")
	_check(is_equal_approx(t.scroll, 1.0), "the scroll has landed")
	_check(cam.rotation.x > deg_to_rad(8.0), "the camera ended tilted up at the sky (%.1f deg)" % rad_to_deg(cam.rotation.x))
	for i in 150:
		await get_tree().physics_frame
	_check(t.logo_label.modulate.a > 0.95 and t.prompt_label.modulate.a > 0.2, "the logo and the prompt come up after a skip")
	_check(TitleScreen.intro_played, "the session remembers the intro played")
	# A second visit goes straight to the settled title.
	await _go_title()
	t = _title()
	_check(t.phase == TitleScreen.Phase.LOGO and is_equal_approx(t.scroll, 1.0), "a second visit skips the intro")
	_check((t._hd as HdView).camera().rotation.x > deg_to_rad(8.0), "and starts on the settled view")


func _test_build() -> void:
	await _go_title()
	var t := _title()
	_check(t.logo_label != null and t.logo_label.text == "Secret of Evermore 2", "the logo reads the game title (%s)" % t.logo_label.text)
	_check(t.subtitle_label != null and t.subtitle_label.text == "Return to Evermore", "with 'Return to Evermore' beneath")
	_check(t.prompt_label != null and t.prompt_label.text == "Press any key", "and the prompt")
	for id in ["new_game", "continue", "settings", "debug", "quit"]:
		_check(t.menu_buttons.has(id), "menu item %s exists" % id)
	var cont: Button = t.menu_buttons["continue"]
	_check(cont.disabled and cont.focus_mode == Control.FOCUS_NONE, "Continue is greyed out and unfocusable")
	_check(t.selectable_ids() == ["new_game", "settings", "debug", "quit"], "navigation skips Continue (%s)" % str(t.selectable_ids()))
	_check(PauseMenu.blocked, "the pause menu is blocked on the title")
	_check(t.phase == TitleScreen.Phase.LOGO and not t._menu_box.visible, "the menu is hidden until a key is pressed")
	t.activate("quit")  # in the logo phase this must do nothing (the test is still running)


## The mansion on the hill, its flickering lab window, and the eerie sound.
func _test_mansion() -> void:
	await _go_title()
	var t := _title()
	var m := t.mansion
	_check(m != null and m.is_inside_tree(), "the title builds the mansion")
	for n in ["Hall", "HallRoof", "Wing", "Tower", "TowerRoof", "Hill", "Apron", "LabWindow", "AtticWindow", "Trees"]:
		_check(m.get_node_or_null(n) != null, "the mansion has %s" % n)
	_check(m.get_node("Trees").get_child_count() >= 5, "with dead trees around it")
	var bad := _no_coplanar_faces(m)
	_check(bad.is_empty(), "mansion: no coplanar faces within 1 cm (z-fight): %s" % ", ".join(bad))
	# The lab light is a pure function of time and the seed: it stutters and
	# blacks out now and then, is the same on every run, differs by seed.
	var lo := 1.0
	var hi := 0.0
	var same := true
	var differs := false
	var t_s := 0.0
	while t_s < 60.0:
		var v := MansionBuilding3D.lab_level(t_s, 1995)
		lo = minf(lo, v)
		hi = maxf(hi, v)
		same = same and v == MansionBuilding3D.lab_level(t_s, 1995)
		differs = differs or v != MansionBuilding3D.lab_level(t_s, 7)
		t_s += 0.05
	_check(hi > 0.7 and lo < 0.1, "the lab window flickers (range %.2f to %.2f over a minute)" % [lo, hi])
	_check(same and differs, "the flicker is seeded: same seed, same light; another seed differs")
	var lit := 0.0
	var dark := 0.0
	t_s = 0.0
	while t_s < 38.0:
		var a := MansionBuilding3D.attic_level(t_s, 1995)
		lit += 1.0 if a > 0.0 else 0.0
		dark += 1.0 if a == 0.0 else 0.0
		t_s += 0.05
	_check(lit > 0.0 and dark > lit, "the tower window lights briefly and goes dark")
	# Running: the lab window follows the light over game time.
	var seen := {}
	for i in 240:
		await get_tree().physics_frame
		seen[snappedf(m.lab_glow(), 0.01)] = true
	_check(seen.size() > 3, "the live lab glow changes over time (%d levels)" % seen.size())
	_check(Audio.music_name == "mansion", "the title plays the creepy music box (%s)" % Audio.music_name)
	_check(Audio.ambience_set == "haunted" and Audio.ambience_name == "wind", "with wind for ambience (%s/%s)" % [Audio.ambience_set, Audio.ambience_name])


## Z-fighting guard (as in smoke_hd for the shops): no two boxes, gables or
## panes of the mansion that face the same way may lie within 1 cm of each
## other and overlap. Faces are rebuilt from each mesh's transform.
func _no_coplanar_faces(b: Node3D) -> PackedStringArray:
	var faces: Array = []   # [name, normal, center, u, v, hu, hv, (triangle)]
	for mi: MeshInstance3D in b.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D):
		var basis := mi.transform.basis.orthonormalized()
		if mi.mesh is BoxMesh:
			var size := (mi.mesh as BoxMesh).size * mi.scale
			for axis in 3:
				for sgn in [-1.0, 1.0]:
					var n: Vector3 = basis[axis] * sgn
					if n.y < -0.99 and absf(mi.position.y - size.y * 0.5) < 1e-4:
						continue  # a bottom standing on the ground
					var u: Vector3 = basis[(axis + 1) % 3]
					var v: Vector3 = basis[(axis + 2) % 3]
					faces.append([mi.name, n, mi.position + n * size[axis] * 0.5, u, v,
							size[(axis + 1) % 3] * 0.5, size[(axis + 2) % 3] * 0.5])
		elif mi.mesh is PrismMesh:
			var ps := (mi.mesh as PrismMesh).size
			for sgn in [-1.0, 1.0]:
				var n: Vector3 = basis[2] * sgn
				faces.append([mi.name, n, mi.position + n * ps.z * 0.5, basis[0], basis[1], ps.x * 0.5, ps.y * 0.5, true])
		elif mi.mesh is QuadMesh:
			var q := (mi.mesh as QuadMesh).size
			faces.append([mi.name, basis[2], mi.position, basis[0], basis[1], q.x * 0.5, q.y * 0.5])
	var bad := PackedStringArray()
	for i in faces.size():
		for j in range(i + 1, faces.size()):
			var fa: Array = faces[i]
			var fb: Array = faces[j]
			if (fa[1] as Vector3).dot(fb[1]) < 0.9998:
				continue
			if absf((fa[1] as Vector3).dot((fb[2] as Vector3) - (fa[2] as Vector3))) >= 0.01:
				continue
			if _face_overlap(fa, fb) or _face_overlap(fb, fa):
				bad.append("%s/%s" % [fa[0], fb[0]])
	return bad


func _face_overlap(a: Array, b: Array) -> bool:
	for i in 15:
		for j in 15:
			var p: Vector3 = (a[2] as Vector3) + (a[3] as Vector3) * (a[5] * (2.0 * (i + 0.5) / 15.0 - 1.0)) \
					+ (a[4] as Vector3) * (a[6] * (2.0 * (j + 0.5) / 15.0 - 1.0))
			var d: Vector3 = p - (b[2] as Vector3)
			var half_u: float = b[5]
			if b.size() > 7:  # a triangle: narrows to the apex
				half_u *= 1.0 - (d.dot(b[4]) + b[6]) / (2.0 * b[6])
			if absf(d.dot(b[3])) < half_u - 1e-4 and absf(d.dot(b[4])) < b[6] - 1e-4:
				return true
	return false


func _test_reveal() -> void:
	var t := _title()
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	for i in 10:
		await get_tree().physics_frame
	_check(t.phase == TitleScreen.Phase.MENU and t._menu_box.visible, "a key press reveals the menu")
	_check(get_viewport().gui_get_focus_owner() == t.menu_buttons["new_game"], "the cursor starts on New Game")
	var ng: Button = t.menu_buttons["new_game"]
	_check(ng.find_valid_focus_neighbor(SIDE_BOTTOM) == t.menu_buttons["settings"], "down from New Game lands on Settings, skipping Continue")


func _test_debug_settings() -> void:
	var t := _title()
	(t.menu_buttons["settings"] as Button).pressed.emit()
	for i in 5:
		await get_tree().physics_frame
	var s := t._settings
	_check(s != null and not t._layout.visible, "Settings opens the settings screen")
	s.closed.emit()
	for i in 5:
		await get_tree().physics_frame
	_check(t._settings == null and t._layout.visible, "and closes back to the menu")
	(t.menu_buttons["debug"] as Button).pressed.emit()
	await _arrive(DebugMenu.SCENE)
	var dm := get_tree().current_scene as DebugMenu
	_check(dm != null and dm.title_button != null, "Debug opens the debug menu, which has Back to title")
	_check(not PauseMenu.blocked, "the pause menu works again off the title")
	dm.title_button.pressed.emit()
	await _arrive(TitleScreen.SCENE)
	t = _title()
	t.reveal_menu()
	for i in 5:
		await get_tree().physics_frame


func _test_new_game() -> void:
	var t := _title()
	GameState.set_flag("prologue.intro_done")
	GameState.set_flag("prologue.talked_to_maya")
	t.activate("new_game")
	for i in 10:
		await get_tree().physics_frame
	var flow := t._flow
	_check(flow != null and flow.step == NewGameFlow.Step.GENDER, "New Game opens the boy or girl screen")
	_check(flow.gender_buttons.size() == 2, "with both kids shown")
	flow.choose_gender("girl")
	for i in 10:
		await get_tree().physics_frame
	var e := flow.entry()
	_check(flow.step == NewGameFlow.Step.KID and e != null, "then the kid's name")
	_check(e.text == Names.text("kid_default_girl") and e.text != "", "pre-filled with the girl's default (%s)" % e.text)
	_check(NameEntry.MAX_LENGTH == 10, "names hold up to ten characters")
	# Clear, then try to accept nothing.
	for i in 12:
		e.backspace()
	_check(e.text == "" and not e.submit() and e.error != "", "an empty name is rejected with a message")
	for c in "Zoe":
		_check(e.type_char(c), "typing %s" % c)
	e.backspace()
	_check(e.text == "Zo", "Backspace deletes (%s)" % e.text)
	for c in "ABCDEFGHIJKL":
		e.type_char(c)
	_check(e.text.length() == 10, "typing stops at ten (%s)" % e.text)
	_check(not e.type_char("Q"), "an eleventh character is refused")
	_check(not e.type_char("!") , "so is a symbol")
	for i in 8:
		e.backspace()
	_check(e.text == "Zo", "back to two letters")
	_check(e.submit(), "a real name is accepted")
	for i in 10:
		await get_tree().physics_frame
	_check(flow.step == NewGameFlow.Step.DOG and flow.entry() != null, "then the dog's name")
	_check(flow.entry().text == "Biscuit", "pre-filled with Biscuit (%s)" % flow.entry().text)
	flow.entry().submit()
	for i in 10:
		await get_tree().physics_frame
	_check(flow.step == NewGameFlow.Step.CONFIRM and flow.begin_button != null, "then the summary")
	flow.begin_button.pressed.emit()
	await _arrive(STREET)
	_check(GameState.kid_gender == "girl", "the kid is a girl")
	_check(GameState.get_kid_name() == "Zo" and GameState.get_dog_name() == "Biscuit", "names are set (%s, %s)" % [GameState.get_kid_name(), GameState.get_dog_name()])
	_check(Names.expand("{kid} and {dog}") == "Zo and Biscuit", "{kid} and {dog} resolve to them")
	_check(not GameState.get_flag("prologue.intro_done") and not GameState.get_flag("prologue.talked_to_maya"), "the prologue flags are cleared")
	var lot := get_tree().current_scene.get_node("Yard") as AsciiRealm
	_check(lot._black.visible, "and the prologue starts from its title card (black overlay up)")


func _test_returns() -> void:
	PauseMenu.back_to_title()
	await _arrive(TitleScreen.SCENE)
	_check(PauseMenu.blocked and not get_tree().paused, "pause menu 'Quit to title': back on the title, unpaused")
	_title().reveal_menu()
	_title().menu_buttons["debug"].pressed.emit()
	await _arrive(DebugMenu.SCENE)
	get_tree().current_scene.map_buttons["street"].pressed.emit()
	await _arrive(STREET)
	var lot := get_tree().current_scene.get_node("Yard")
	lot.end_card_seconds = 0.5
	lot._end_slice()
	var frames := 0
	while frames < 900 and not (get_tree().current_scene != null and get_tree().current_scene.scene_file_path == TitleScreen.SCENE and not Travel.busy):
		await get_tree().physics_frame
		frames += 1
	_check(frames < 900, "the end of the slice returns to the title (%d frames)" % frames)


# -----------------------------------------------------------------------------
func _go_title() -> void:
	get_tree().change_scene_to_file(TitleScreen.SCENE)
	await get_tree().scene_changed
	for i in 30:
		await get_tree().physics_frame


func _title() -> TitleScreen:
	return get_tree().current_scene as TitleScreen


func _arrive(scene: String) -> void:
	var frames := 0
	while frames < 900 and not (get_tree().current_scene != null and get_tree().current_scene.scene_file_path == scene
			and not Travel.busy and frames > 5):
		await get_tree().physics_frame
		frames += 1
	_check(get_tree().current_scene.scene_file_path == scene, "arrived on %s" % scene.get_file())
	for i in 30:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("[TEST] ok    ", what)
	else:
		_failures.append(what)
		printerr("[TEST] FAIL  ", what)
